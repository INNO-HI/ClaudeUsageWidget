import AppKit
import SwiftUI
import Combine
import QuartzCore
import Sparkle

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!  // set in applicationDidFinishLaunching; sinks use popover? for the pre-init window
    private var eventMonitor: EventMonitor?
    private var viewModel = UsageViewModel()
    private var cancellables = Set<AnyCancellable>()
    // Motion is Core Animation-driven (render server, ~0 CPU in-process).
    // The old Timer-based approach mutated frame/alpha 12–33×/sec on the
    // main thread and held the widget at ~20% CPU whenever Claude was active.
    private var bounceActive = false
    private var pulseActive = false
    private var wobbleActive = false
    /// Dedicated layer that hosts ONLY the icon image. All motion (wobble /
    /// bounce / pulse / blink) targets this layer, so the % text — which
    /// lives in the button's own title — never moves.
    private var iconLayer: CALayer?
    /// Transparent 18×18 placeholder assigned to button.image purely to
    /// reserve the icon's layout slot; the visible icon is iconLayer.contents.
    private static let iconSpacer: NSImage = {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in true }
    }()
    private var blinkTimer: Timer?   // blink swaps NSImage content — CA can't animate that; 4 Hz is cheap
    private var blinkOpen: Bool = false  // true = dots (.idle), false = slits (.syncing)

    // Sparkle auto-updater (starts checking on launch per Info.plist settings)
    let updaterController: SPUStandardUpdaterController

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure status bar button
        if let button = statusItem.button {
            updateStatusBarIcon(button: button)
            button.action = #selector(togglePopover)
            button.target = self

            // Observe usage changes to update menu bar text
            viewModel.$usage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)

            viewModel.$isSyncing
                .receive(on: DispatchQueue.main)
                .sink { [weak self] syncing in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn, syncing: syncing)
                    }
                    if syncing {
                        self?.startBounceAnimation()
                    } else {
                        self?.stopBounceAnimation()
                    }
                }
                .store(in: &cancellables)

            // Repaint when the metric (session vs weekly %) changes —
            // without this the picker looks broken in manual-sync mode.
            viewModel.$menuBarMetric
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)

            // Repaint the menu bar when the user changes the display format
            viewModel.$menuBarFormat
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)

            // Re-evaluate pulse whenever the warning threshold changes
            viewModel.$alertThresholdLow
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)

            // Re-paint whenever the Claude activity state transitions between
            // idle / sleeping / active. Single publisher means AppDelegate
            // sees one change per detection tick, avoiding a stale
            // intermediate face during the ACTIVE ↔ SLEEPING crossover.
            viewModel.$claudeActivity
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)

            // Re-paint when the user toggles the animated face off / on
            viewModel.$showMenuBarExpressions
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    if let btn = self?.statusItem.button {
                        self?.updateStatusBarIcon(button: btn)
                    }
                }
                .store(in: &cancellables)
        }

        // Live-apply "Keep on Top": update the open popover's behavior
        // immediately instead of only on the next open.
        viewModel.$keepOnTop
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pinned in
                guard let self = self else { return }
                self.popover?.behavior = pinned ? .applicationDefined : .transient
            }
            .store(in: &cancellables)

        // Reconcile Launch-at-Login flag with actual system state
        // (user may have toggled it from System Settings → General → Login Items)
        viewModel.refreshLaunchAtLoginStatus()

        // Create popover with transparent background for glassmorphism
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 540)
        popover.behavior = .transient
        popover.animates = true

        let hostingController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel)
        )
        // Remove default SwiftUI hosting view background
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear
        popover.contentViewController = hostingController

        // Event monitor to close popover when clicking outside.
        // With "Keep on Top" enabled the popover is pinned: outside clicks
        // no longer dismiss it (this is what the previously-dead setting
        // was always meant to do).
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            if self.viewModel.keepOnTop { return }
            self.popover.performClose(event)
            self.eventMonitor?.stop()  // symmetric with togglePopover's close path
        }
    }

    private func updateStatusBarIcon(button: NSStatusBarButton, syncing: Bool = false) {
        let pct = viewModel.usage.isConnected ? viewModel.usage.sessionUsagePercent : 0
        // Four faces — picked by priority:
        //   syncing > claude actively working > claude sleeping > idle
        // If the user has turned the animated face off in Settings, always
        // use .idle regardless of state.
        let expression: IconExpression
        if !viewModel.showMenuBarExpressions {
            expression = .idle
        } else if syncing {
            expression = .syncing
        } else if viewModel.claudeActivelyRunning {
            expression = .activeClaude
        } else if viewModel.claudeSleeping {
            expression = .sleeping
        } else {
            expression = .idle
        }
        let iconImage = createMenuBarIcon(size: NSSize(width: 18, height: 18),
                                           percent: pct,
                                           expression: expression)
        button.image = Self.iconSpacer  // reserves layout space only
        positionIconLayer(on: button, image: iconImage)

        let text = viewModel.menuBarText
        if text.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            // Monospaced digits stop the title (and every icon to its left)
            // from shifting horizontally as the numbers tick over.
            button.attributedTitle = NSAttributedString(
                string: " \(text)",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)]
            )
        }
        button.imagePosition = .imageLeading

        // Rich tooltip — hover the menu bar icon for the full status
        button.toolTip = buildTooltip()
        button.setAccessibilityLabel(accessibilityLabelForCurrentState(syncing: syncing))
        // VoiceOver value: the headline number the sighted user sees.
        if viewModel.usage.isConnected {
            button.setAccessibilityValue("\(L.currentSession): \(Int(viewModel.usage.sessionUsagePercent))%")
        } else {
            button.setAccessibilityValue(L.notLoggedIn)
        }

        // Sync-state blink: alternate slit ↔ dots every 250 ms while syncing.
        if syncing {
            startBlinkAnimation()
        } else {
            stopBlinkAnimation()
        }

        // Manage warning pulse based on user's low threshold
        let shouldPulse = !syncing
            && viewModel.usage.isConnected
            && viewModel.usage.sessionUsagePercent >= Double(viewModel.alertThresholdLow)
        if shouldPulse {
            startPulseAnimation()
        } else {
            stopPulseAnimation()
        }

        // Wobble shake when Claude Code is actively running (and we're not
        // already syncing — sync's bounce takes priority on the y axis).
        let shouldWobble = !syncing
            && viewModel.claudeActivelyRunning
            && viewModel.showMenuBarExpressions
        if shouldWobble {
            startWobbleAnimation()
        } else {
            stopWobbleAnimation()
        }
    }

    private func buildTooltip() -> String {
        guard viewModel.usage.isConnected else {
            return "Claude Usage Widget — \(viewModel.credentialStatus == .notFound ? L.notLoggedIn : L.never)"
        }

        let pct = Int(viewModel.usage.sessionUsagePercent)
        let reset = viewModel.sessionResetText
        var lines = [
            "Claude Usage Widget",
            "\(L.currentSession): \(pct)%",
            reset,
        ]
        if let eta = viewModel.etaText {
            lines.append(eta)
        }
        if viewModel.usage.weeklyAllModelsPercent > 0 {
            let weekly = Int(viewModel.usage.weeklyAllModelsPercent)
            lines.append("\(L.weeklyLimits): \(weekly)%")
        }
        if let last = viewModel.usage.lastSyncTime {
            lines.append("⟳ \(Self.tooltipTimeFormatter.string(from: last))")
        }
        // Surface the Claude Code activity state on hover so users know
        // what the changing face means.
        switch viewModel.claudeActivity {
        case .active:   lines.append(L.tooltipClaudeActive)
        case .sleeping: lines.append(L.tooltipClaudeSleeping)
        case .idle:     break  // no line when Claude isn't running
        }
        return lines.joined(separator: "\n")
    }

    /// VoiceOver announcement for the current menu-bar face.
    private func accessibilityLabelForCurrentState(syncing: Bool) -> String {
        if syncing { return "\(L.appTitle) — \(L.sync)" }
        switch viewModel.claudeActivity {
        case .active:   return "\(L.appTitle) — \(L.tooltipClaudeActive)"
        case .sleeping: return "\(L.appTitle) — \(L.tooltipClaudeSleeping)"
        case .idle:     return L.appTitle
        }
    }

    // MARK: - Bounce Animation

    private func startBounceAnimation() {
        guard !bounceActive else { return }
        // Respect Reduce Motion system setting
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        guard let layer = animatableLayer() else { return }
        bounceActive = true
        let anim = CABasicAnimation(keyPath: "transform.translation.y")
        anim.fromValue = -2.0
        anim.toValue = 2.0
        anim.duration = 0.45
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: Self.bounceAnimKey)
    }

    private func stopBounceAnimation() {
        bounceActive = false
        statusItem.button?.layer?.removeAnimation(forKey: Self.bounceAnimKey)
    }

    // MARK: - Warning Pulse (>= alert threshold)

    private func startPulseAnimation() {
        guard !pulseActive else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        guard let layer = animatableLayer() else { return }
        pulseActive = true
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.55
        anim.duration = 0.7
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: Self.pulseAnimKey)
    }

    private func stopPulseAnimation() {
        pulseActive = false
        statusItem.button?.layer?.removeAnimation(forKey: Self.pulseAnimKey)
        statusItem.button?.alphaValue = 1.0
    }

    // MARK: - Sync Blink (alternates eyes between dots and slits)

    private func startBlinkAnimation() {
        guard blinkTimer == nil else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        blinkOpen = false
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.blinkOpen.toggle()
            let pct = self.viewModel.usage.isConnected ? self.viewModel.usage.sessionUsagePercent : 0
            let face: IconExpression = self.blinkOpen ? .idle : .syncing
            self.iconLayer?.contents = createMenuBarIcon(size: NSSize(width: 18, height: 18),
                                                          percent: pct,
                                                          expression: face)
        }
        timer.tolerance = 0.05
        blinkTimer = timer
    }

    private func stopBlinkAnimation() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    // MARK: - Wobble Shake (Claude actively running)

    /// Energetic horizontal vibration to signal "Claude Code is actively
    /// running on this machine". ±1.5 px at ~3 Hz — visible enough to draw
    /// the eye but not big enough to bump neighbouring menu-bar icons.
    /// Runs entirely on the render server via Core Animation.
    private func startWobbleAnimation() {
        guard !wobbleActive else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        guard let layer = animatableLayer() else { return }
        wobbleActive = true
        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = -1.5
        anim.toValue = 1.5
        anim.duration = 0.16   // full left↔right sweep ≈ 3 Hz round trip
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: Self.wobbleAnimKey)
    }

    private func stopWobbleAnimation() {
        wobbleActive = false
        statusItem.button?.layer?.removeAnimation(forKey: Self.wobbleAnimKey)
    }

    /// "HH:mm" for the hover tooltip — cached; DateFormatter init is ~ms.
    private static let tooltipTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Core Animation plumbing

    private static let bounceAnimKey = "cuw.bounce"
    private static let pulseAnimKey  = "cuw.pulse"
    private static let wobbleAnimKey = "cuw.wobble"

    /// The icon's dedicated sublayer, created on demand. All motion runs as
    /// repeating CABasicAnimations on this layer — the render server
    /// composites them without waking our process, and because only the icon
    /// lives here the % text in the button title stays perfectly still.
    private func animatableLayer() -> CALayer? {
        guard let button = statusItem.button else { return nil }
        return ensureIconLayer(on: button)
    }

    private func ensureIconLayer(on button: NSStatusBarButton) -> CALayer {
        button.wantsLayer = true
        if let l = iconLayer, l.superlayer === button.layer { return l }
        let l = CALayer()
        l.contentsGravity = .resizeAspect
        button.layer?.addSublayer(l)
        iconLayer = l
        return l
    }

    /// Sync the sublayer's image + frame with the button's current layout.
    /// Called on every repaint; the frame tracks the (invisible) spacer
    /// image's rect so the icon sits exactly where AppKit would draw it.
    private func positionIconLayer(on button: NSStatusBarButton, image: NSImage) {
        let layer = ensureIconLayer(on: button)
        layer.contents = image
        button.layoutSubtreeIfNeeded()
        if let cell = button.cell as? NSButtonCell {
            layer.frame = cell.imageRect(forBounds: button.bounds)
        } else {
            layer.frame = CGRect(x: 4,
                                 y: (button.bounds.height - 18) / 2,
                                 width: 18, height: 18)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.flushPendingWrites()
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            eventMonitor?.stop()
        } else if let button = statusItem.button {
            // Pinned popovers must not be .transient or AppKit closes them
            // on focus loss before our event monitor gets a say.
            popover.behavior = viewModel.keepOnTop ? .applicationDefined : .transient
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // IMPORTANT: Activate app and make popover key window
            NSApp.activate(ignoringOtherApps: true)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            eventMonitor?.start()
        }
    }
}
