import AppKit
import SwiftUI
import Combine
import Sparkle

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private var viewModel = UsageViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var bounceTimer: Timer?
    private var bouncePhase: CGFloat = 0
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0
    private var blinkTimer: Timer?
    private var blinkOpen: Bool = false  // true = dots (.idle), false = slits (.syncing)
    private var wobbleTimer: Timer?
    private var wobblePhase: CGFloat = 0

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

            // Re-paint when Claude Code activity changes — drives the .activeClaude face
            viewModel.$claudeActivelyRunning
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

        // Event monitor to close popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.popover.performClose(event)
            }
        }
    }

    private func updateStatusBarIcon(button: NSStatusBarButton, syncing: Bool = false) {
        let pct = viewModel.usage.isConnected ? viewModel.usage.sessionUsagePercent : 0
        // Three faces — picked by priority: syncing > claude active > idle.
        // The syncing face blinks (handled by startBlinkAnimation below).
        // If the user has turned the animated face off in Settings, always
        // use .idle regardless of state.
        let expression: IconExpression
        if !viewModel.showMenuBarExpressions {
            expression = .idle
        } else if syncing {
            expression = .syncing
        } else if viewModel.claudeActivelyRunning {
            expression = .activeClaude
        } else {
            expression = .idle
        }
        button.image = createMenuBarIcon(size: NSSize(width: 18, height: 18),
                                          percent: pct,
                                          expression: expression)

        let text = viewModel.menuBarText
        button.title = text.isEmpty ? "" : " \(text)"
        button.imagePosition = .imageLeading

        // Rich tooltip — hover the menu bar icon for the full status
        button.toolTip = buildTooltip()

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
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            lines.append("⟳ \(df.string(from: last))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Bounce Animation

    private func startBounceAnimation() {
        guard bounceTimer == nil else { return }
        // Respect Reduce Motion system setting
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        bouncePhase = 0
        bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.bouncePhase += 0.15
            let offset = sin(self.bouncePhase) * 2.0  // 2px up/down
            button.frame.origin.y = offset
        }
    }

    private func stopBounceAnimation() {
        bounceTimer?.invalidate()
        bounceTimer = nil
        if let button = statusItem.button {
            button.frame.origin.y = 0
        }
    }

    // MARK: - Warning Pulse (>=80%)

    private func startPulseAnimation() {
        guard pulseTimer == nil else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        pulsePhase = 0
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.pulsePhase += 0.18
            // Breathing alpha 0.55..1.0
            let alpha = 0.55 + (sin(self.pulsePhase) + 1) / 2 * 0.45
            button.alphaValue = alpha
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
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
            button.image = createMenuBarIcon(size: NSSize(width: 18, height: 18),
                                              percent: pct,
                                              expression: face)
        }
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
    private func startWobbleAnimation() {
        guard wobbleTimer == nil else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        wobblePhase = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.wobblePhase += 0.6
            let offset = sin(self.wobblePhase) * 1.5
            button.frame.origin.x = offset
        }
        wobbleTimer = timer
    }

    private func stopWobbleAnimation() {
        wobbleTimer?.invalidate()
        wobbleTimer = nil
        if let button = statusItem.button {
            button.frame.origin.x = 0
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            eventMonitor?.stop()
        } else if let button = statusItem.button {
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
