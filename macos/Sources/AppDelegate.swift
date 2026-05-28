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

            // Mini/Full mode toggle — repaint the menu bar when user flips % visibility
            viewModel.$showMenuBarText
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
        popover.contentSize = NSSize(width: 360, height: 500)
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
        if syncing {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Syncing")?.withSymbolConfiguration(config)
        } else {
            let pct = viewModel.usage.isConnected ? viewModel.usage.sessionUsagePercent : 0
            button.image = createMenuBarIcon(size: NSSize(width: 18, height: 18), percent: pct)
        }

        let text = viewModel.menuBarText
        button.title = text.isEmpty ? "" : " \(text)"
        button.imagePosition = .imageLeading
    }

    // MARK: - Bounce Animation

    private func startBounceAnimation() {
        guard bounceTimer == nil else { return }
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
