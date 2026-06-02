import SwiftUI
import AppKit

// MARK: - Typography (에이투지체 / A2Z)

enum AppFont {
    static func thin(_ size: CGFloat) -> Font      { Font.custom("A2Z 1 Thin", size: size) }
    static func light(_ size: CGFloat) -> Font     { Font.custom("A2Z 3 Light", size: size) }
    static func regular(_ size: CGFloat) -> Font   { Font.custom("A2Z 4 Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font    { Font.custom("A2Z 5 Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font  { Font.custom("A2Z 6 SemiBold", size: size) }
    static func bold(_ size: CGFloat) -> Font      { Font.custom("A2Z 7 Bold", size: size) }
    static func extraBold(_ size: CGFloat) -> Font { Font.custom("A2Z 8 ExtraBold", size: size) }
    static func black(_ size: CGFloat) -> Font     { Font.custom("A2Z 9 Black", size: size) }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Color Theme (Light + Dark adaptive)

struct Theme {
    // Base — adapt to system appearance
    static let background = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    // Card surface — sits on popoverBg (#FAFAFA / #1C1C1E)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)

    // Text
    static let textPrimary = Color.dynamic(light: 0x1F2937, dark: 0xF2F2F7)
    static let textSecondary = Color.dynamic(light: 0x6B7280, dark: 0xAEAEB2)

    // Status colors (same in both modes — kept readable on glass)
    static let danger = Color(hex: 0xF87171)       // Soft red
    static let warning = Color(hex: 0xF59E0B)      // Warm orange
    static let success = Color(hex: 0x10B981)      // Green
    static let claudeOrange = Color(hex: 0xD97757) // Claude brand

    // Accent = Claude orange for brand consistency
    static let accent = Color(hex: 0xD97757)
    static let accentDim = Color(hex: 0xD97757).opacity(0.6)

    // UI elements
    static let progressBg = Color.dynamic(light: 0xE5E7EB, dark: 0x3A3A3C)
    static let border = Color.dynamic(light: 0xE5E7EB, dark: 0x3A3A3C)
    static let cardBorder = Color.dynamic(light: 0xFFFFFF, dark: 0x48484A).opacity(0.6)

    // Glassmorphism (kept for cards; popover itself uses a solid background)
    static let glassBg = Color.dynamic(light: 0xFFFFFF, dark: 0x2C2C2E).opacity(0.7)
    static let glassBorder = Color.dynamic(light: 0xFFFFFF, dark: 0x48484A).opacity(0.5)
    static let glassShadow = Color.black.opacity(0.04)

    // Solid popover background — off-white in light mode, dark surface in dark mode
    static let popoverBg = Color.dynamic(light: 0xFAFAFA, dark: 0x1C1C1E)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Dynamic color that follows the system appearance (light/dark mode).
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green:   CGFloat((hex >> 8)  & 0xFF) / 255.0,
                blue:    CGFloat( hex        & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}

// MARK: - Main Popover View

struct PopoverContentView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        Group {
            if !viewModel.hasCompletedOnboarding {
                OnboardingView(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .frame(width: viewModel.compactMode ? 320 : 400)
        .background(Theme.popoverBg)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().background(Theme.border.opacity(0.4))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.showSettings {
                        settingsSection
                    }
                    currentSessionSection
                    if !viewModel.compactMode {
                        weeklyLimitsSection
                    }
                    autoSyncSection
                    if viewModel.showBuddy && !viewModel.compactMode {
                        buddySection
                    }
                }
                .padding(.horizontal, viewModel.compactMode ? 16 : 20)
                .padding(.vertical, viewModel.compactMode ? 16 : 20)
            }

            Divider().background(Theme.border.opacity(0.4))
            footerSection

            // Hidden keyboard-shortcut buttons (⌘R refresh, ⌘, settings)
            ZStack {
                Button("") { viewModel.fetchUsage() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("") { viewModel.showSettings.toggle() }
                    .keyboardShortcut(",", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ClaudeCodeIconView()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(L.appTitle)
                        .font(AppFont.bold(15))
                        .foregroundColor(Theme.textPrimary)

                    Text(viewModel.usage.planName)
                        .font(AppFont.semibold(9))
                        .foregroundColor(Theme.claudeOrange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.claudeOrange.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.claudeOrange.opacity(0.3), lineWidth: 1)
                        )
                }

                HStack(spacing: 4) {
                    switch viewModel.credentialStatus {
                    case .checking:
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textSecondary)
                        Text(L.checkingCredentials)
                            .font(AppFont.regular(10))
                            .foregroundColor(Theme.textSecondary)
                    case .found:
                        if let error = viewModel.errorMessage {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.danger)
                            Text(error)
                                .font(AppFont.regular(10))
                                .foregroundColor(Theme.danger)
                                .lineLimit(1)
                        } else if viewModel.usage.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.success)
                            Text(L.connectedOAuth)
                                .font(AppFont.regular(10))
                                .foregroundColor(Theme.success)
                        }
                    case .notFound:
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.danger)
                        Text(L.notLoggedIn)
                            .font(AppFont.regular(10))
                            .foregroundColor(Theme.danger)
                    }
                }
            }

            Spacer()

            Button(action: { viewModel.showSettings.toggle() }) {
                Image(systemName: viewModel.showSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.showSettings ? Theme.claudeOrange : Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        viewModel.showSettings
                            ? Theme.claudeOrange.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L.settings)
            .accessibilityLabel(L.settings)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Account ──────────────────────────────
            categoryHeader(L.sectionAccount, icon: "person.crop.circle")

            languageRow

            credentialsRow

            // ── General ──────────────────────────────
            categoryHeader(L.sectionGeneral, icon: "slider.horizontal.3")

            settingsToggleRow(label: L.keepOnTop, isOn: $viewModel.keepOnTop) {
                viewModel.saveConfig()
            }

            settingsToggleRow(label: L.launchAtLogin, isOn: $viewModel.launchAtLogin)

            menuBarFormatRow

            settingsToggleRow(label: L.showBuddy, isOn: $viewModel.showBuddy)

            settingsToggleRow(label: L.compactMode, isOn: $viewModel.compactMode)

            // ── Notifications ────────────────────────
            categoryHeader(L.sectionNotifications, icon: "bell.fill")

            settingsToggleRow(label: L.enableNotifications, isOn: $viewModel.notificationsEnabled)

            // ── Updates ──────────────────────────────
            categoryHeader(L.sectionUpdates, icon: "arrow.triangle.2.circlepath")

            HStack {
                pillButton(icon: "arrow.down.circle", title: L.checkForUpdates) {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.updaterController.checkForUpdates(nil)
                    }
                }
                Spacer()
            }

            Divider().background(Theme.border.opacity(0.5))
        }
    }

    // MARK: Settings — small reusable pieces

    private func categoryHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.claudeOrange.opacity(0.85))
            }
            Text(title)
                .font(AppFont.bold(9))
                .foregroundColor(Theme.textSecondary.opacity(0.85))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func settingsToggleRow(label: String, isOn: Binding<Bool>, onChange: (() -> Void)? = nil) -> some View {
        HStack {
            Toggle(label, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(AppFont.regular(12))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.claudeOrange)
                .onChange(of: isOn.wrappedValue) { _ in onChange?() }
            Spacer()
        }
    }

    private func pillButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(AppFont.semibold(11))
            }
            .foregroundColor(Theme.claudeOrange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.claudeOrange.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.claudeOrange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings — Menu bar format picker

    private var menuBarFormatRow: some View {
        HStack(spacing: 6) {
            Text(L.menuBarFormat)
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            ForEach(MenuBarFormat.allCases, id: \.self) { fmt in
                Button(action: { viewModel.menuBarFormat = fmt }) {
                    Text(fmt.displayName)
                        .font(viewModel.menuBarFormat == fmt ? AppFont.bold(10) : AppFont.regular(10))
                        .foregroundColor(viewModel.menuBarFormat == fmt ? Theme.claudeOrange : Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(viewModel.menuBarFormat == fmt ? Theme.claudeOrange.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(viewModel.menuBarFormat == fmt ? Theme.claudeOrange.opacity(0.3) : Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(L.menuBarFormat): \(fmt.displayName)")
            }
        }
    }

    // MARK: Settings — Account rows

    private var languageRow: some View {
        HStack(spacing: 8) {
            Text(L.language)
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                Button(action: { viewModel.language = lang }) {
                    Text(lang.displayName)
                        .font(viewModel.language == lang ? AppFont.bold(11) : AppFont.regular(11))
                        .foregroundColor(viewModel.language == lang ? Theme.claudeOrange : Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(viewModel.language == lang ? Theme.claudeOrange.opacity(0.1) : Color.clear)
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(viewModel.language == lang ? Theme.claudeOrange.opacity(0.3) : Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var credentialsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(credentialDotColor)
                    .frame(width: 8, height: 8)

                Text(credentialStatusText)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                if viewModel.credentialStatus == .notFound {
                    pillButton(icon: "terminal", title: L.openTerminal) {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
                        }
                    }
                }

                Button(action: {
                    viewModel.checkCredentials()
                    viewModel.fetchUsage()
                }) {
                    Text(L.refresh)
                        .font(AppFont.semibold(10))
                        .foregroundColor(Theme.claudeOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.claudeOrange.opacity(0.08))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.claudeOrange.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if viewModel.credentialStatus == .notFound {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.toFixThis)
                        .font(AppFont.semibold(10))
                        .foregroundColor(Theme.claudeOrange)
                    Text(L.step1Terminal).font(AppFont.regular(10)).foregroundColor(Theme.textSecondary)
                    Text(L.step2Login).font(AppFont.regular(10)).foregroundColor(Theme.textSecondary)
                    Text(L.step3Refresh).font(AppFont.regular(10)).foregroundColor(Theme.textSecondary)
                }
                .padding(10)
                .background(Theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1)
                )
            }
        }
    }

    private var credentialDotColor: Color {
        switch viewModel.credentialStatus {
        case .found:    return Theme.success
        case .checking: return Theme.textSecondary
        case .notFound: return Theme.danger
        }
    }

    private var credentialStatusText: String {
        switch viewModel.credentialStatus {
        case .found:    return L.autoDetected
        case .checking: return L.checkingCredentials
        case .notFound: return L.notFound
        }
    }

    // MARK: - Current Session

    private var currentSessionSection: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 20) {
                SessionRingView(
                    percent: viewModel.usage.sessionUsagePercent,
                    color: percentColor(viewModel.usage.sessionUsagePercent),
                    isLoading: viewModel.isSyncing && !viewModel.usage.isConnected,
                    isDisconnected: !viewModel.usage.isConnected && !viewModel.isSyncing
                )
                .frame(width: viewModel.compactMode ? 72 : 92,
                       height: viewModel.compactMode ? 72 : 92)
                .accessibilityLabel("\(L.currentSession): \(Int(viewModel.usage.sessionUsagePercent)) percent")

                VStack(alignment: .leading, spacing: 6) {
                    Text(L.currentSession)
                        .font(AppFont.semibold(11))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(percentColor(viewModel.usage.sessionUsagePercent))
                        Text(viewModel.sessionResetText)
                            .font(AppFont.semibold(13))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if viewModel.usage.isConnected, let eta = viewModel.etaText {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.warning)
                            Text(eta)
                                .font(AppFont.medium(11))
                                .foregroundColor(Theme.warning)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.3), value: viewModel.etaText)
        }
    }

    // MARK: - Weekly Limits

    private var weeklyLimitsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L.weeklyLimits)
                        .font(AppFont.bold(13))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Button(L.learnMore) {
                        NSWorkspace.shared.open(URL(string: "https://support.anthropic.com/en/articles/9964580-how-does-usage-work-on-claude-ai")!)
                    }
                    .buttonStyle(.plain)
                    .font(AppFont.regular(10))
                    .foregroundColor(Theme.claudeOrange)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }

                // All models
                HStack {
                    Text(L.allModels)
                        .font(AppFont.medium(12))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.usage.weeklyAllModelsPercent))%")
                        .font(AppFont.bold(12))
                        .foregroundColor(percentColor(viewModel.usage.weeklyAllModelsPercent))
                }

                UsageProgressBar(
                    percent: viewModel.usage.weeklyAllModelsPercent,
                    showScale: false,
                    showIcon: false
                )

                if !viewModel.usage.weeklyAllModelsResetDate.isEmpty {
                    Text(L.resetsAt(viewModel.usage.weeklyAllModelsResetDate))
                        .font(AppFont.regular(11))
                        .foregroundColor(Theme.textSecondary)
                }

                Divider().background(Theme.border.opacity(0.3))

                // Sonnet only
                HStack {
                    Text(L.sonnetOnly)
                        .font(AppFont.medium(12))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.usage.weeklySonnetPercent))%")
                        .font(AppFont.bold(12))
                        .foregroundColor(percentColor(viewModel.usage.weeklySonnetPercent))
                }

                UsageProgressBar(
                    percent: viewModel.usage.weeklySonnetPercent,
                    showScale: false,
                    showIcon: false
                )

                Divider().background(Theme.border.opacity(0.3))

                // Sparkline trend
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                    Text(L.sevenDayTrend)
                        .font(AppFont.medium(11))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }

                SparklineView(points: viewModel.usageHistory)
                    .frame(height: 36)
                    .accessibilityLabel(L.sevenDayTrend)
            }
        }
    }

    // MARK: - Auto Sync

    private var autoSyncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.autoSync)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                ForEach(SyncInterval.allCases, id: \.self) { interval in
                    Button(action: { viewModel.syncInterval = interval }) {
                        Text(interval.rawValue)
                            .font(viewModel.syncInterval == interval ? AppFont.bold(11) : AppFont.regular(11))
                            .foregroundColor(viewModel.syncInterval == interval ? Theme.claudeOrange : Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                viewModel.syncInterval == interval
                                    ? Theme.claudeOrange.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        viewModel.syncInterval == interval
                                            ? Theme.claudeOrange.opacity(0.3)
                                            : Theme.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(L.syncNote)
                .font(AppFont.regular(9))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 12) {
            Text("v1.2.0")
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(viewModel.lastSyncText)
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textSecondary)

            Button(action: { viewModel.fetchUsage() }) {
                HStack(spacing: 5) {
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.claudeOrange)
                    }
                    Text(L.sync)
                        .font(AppFont.semibold(11))
                        .foregroundColor(Theme.claudeOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.claudeOrange.opacity(0.08))
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSyncing)
            .accessibilityLabel(L.sync)
            .help("\(L.sync) (⌘R)")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text(L.quit)
                    .font(AppFont.semibold(11))
                    .foregroundColor(Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.quit)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Buddy

    private var buddySection: some View {
        GlassCard {
            VStack(spacing: 10) {
                if viewModel.buddyState == .off {
                    // Unhatched state
                    BuddyEggView(state: viewModel.buddyState)
                        .frame(height: 80)

                    Button(action: { viewModel.buddyHatch() }) {
                        Label("/buddy", systemImage: "egg.fill")
                            .font(AppFont.semibold(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.claudeOrange)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                } else if viewModel.buddyState == .egg {
                    // Hatching animation
                    BuddyEggView(state: viewModel.buddyState)
                        .frame(height: 80)

                    Text("Hatching...")
                        .font(AppFont.medium(11))
                        .foregroundColor(Theme.textSecondary)

                } else if let spec = viewModel.buddySpec {
                    // Full buddy card
                    BuddyCardView(
                        spec: spec,
                        state: viewModel.buddyState,
                        mood: viewModel.buddyMood,
                        bonusStats: viewModel.buddyBonusStats,
                        canFeed: viewModel.canFeed,
                        onPet: { viewModel.buddyPet() },
                        onFeed: { viewModel.buddyFeed() },
                        onSleep: { viewModel.buddySleep() }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func percentColor(_ percent: Double) -> Color {
        if percent >= 80 { return Theme.danger }
        if percent >= 50 { return Theme.warning }
        return Theme.success
    }
}

// MARK: - Buddy Egg View (off / hatching states)

struct BuddyEggView: View {
    let state: BuddyState
    @State private var animPhase: CGFloat = 0

    var body: some View {
        ZStack {
            if state == .off {
                VStack(spacing: 6) {
                    Text("  _____\n /     \\\n|  ???  |\n \\_____/")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Text("Hatch your buddy!")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Text("  _____\n /     \\\n| *  * |\n \\_____/")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(animPhase))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.15).repeatCount(10, autoreverses: true)) {
                            animPhase = 5
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rarity Color Helper

func rarityColor(_ rarity: BuddyRarity) -> Color {
    switch rarity {
    case .common:    return Color.gray
    case .uncommon:  return Color(hex: 0x10B981)
    case .rare:      return Color(hex: 0x3B82F6)
    case .epic:      return Color(hex: 0x8B5CF6)
    case .legendary: return Color(hex: 0xF59E0B)
    }
}

// MARK: - ASCII Art Species

func asciiArt(for species: BuddySpecies, eyes: String, hat: BuddyHat) -> String {
    let e = eyes
    let hatLine: String = {
        switch hat {
        case .none:      return ""
        case .crown:     return "  \\|/\n"
        case .tophat:    return "  ___\n  |_|\n"
        case .propeller: return "  -+- \n"
        case .halo:      return "  ooo\n"
        case .wizard:    return "  /\\\n / \\\n"
        case .beanie:    return "  .-.\n"
        case .tinyduck:  return "  >o)\n"
        }
    }()

    let body: String = {
        switch species {
        case .cat:
            return " /\\_/\\\n( \(e) \(e) )\n > ^ <"
        case .rabbit:
            return " (\\(\\  \n ( \(e)\(e) )\n o(\")(\") "
        case .duck:
            return "   __\n >(\(e)\(e))__\n  (  __)>\n   ||"
        case .dragon:
            return "  /\\_/\\_\n (  \(e) \(e) )\n  \\ ~~ /\n  /|  |\\"
        case .owl:
            return "  {o,o}\n /)___)\n  \" \""
        case .penguin:
            return "   _\n  (\(e)\(e))\n /( oo )\\\n  \" \""
        case .ghost:
            return "  .___.\n | \(e) \(e) |\n |  o  |\n  \\^^^/"
        case .octopus:
            return "   ___\n  (\(e) \(e))\n /||||||\\"
        case .turtle:
            return "     __\n  .-(\(e)\(e))\n /   ____\\\n|_\\_/____/"
        case .snail:
            return "    @  @\n  _(\(e)  \(e))_\n (________)"
        case .mushroom:
            return "  .--.\n / \(e)\(e) \\\n|------|\n  ||||"
        case .robot:
            return " [====]\n |\(e)  \(e)|\n |_--_|\n  d  b"
        case .goose:
            return "   ,\n  (\(e)>\n  / |\n _/ /"
        case .cactus:
            return "  _\n | |\n/|\(e)|\\\n | |\n |_|"
        case .axolotl:
            return " \\(\(e) \(e))/\n  (  u  )\n  /| | |\\"
        case .blob:
            return "  .oOo.\n ( \(e) \(e) )\n  `oOo'"
        case .capybara:
            return "  ____\n (\(e)  \(e))\n (    )\n /|  |\\"
        case .chonk:
            return " /\\_/\\\n( \(e) \(e) )\n(  >o< )\n (     )"
        }
    }()

    return hatLine + body
}

// MARK: - Full Buddy Card View (ASCII Art)

struct BuddyCardView: View {
    let spec: BuddySpec
    let state: BuddyState
    let mood: Int
    let bonusStats: [Int]
    let canFeed: Bool
    let onPet: () -> Void
    let onFeed: () -> Void
    let onSleep: () -> Void

    @State private var animPhase: CGFloat = 0
    @State private var shinyPhase: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            buddyAsciiSection
            buddyInfoSection
            buddyStatsSection
            buddyControlsSection
        }
        .onChange(of: state) { _ in
            animPhase = 0
        }
    }

    // MARK: - ASCII Avatar

    private var buddyAsciiSection: some View {
        ZStack {
            // Shiny glow
            if spec.isShiny {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.yellow.opacity(0.15 + 0.1 * sin(shinyPhase)),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(height: 90)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            shinyPhase = .pi
                        }
                    }
            }

            VStack(spacing: 0) {
                asciiAnimated
                    .frame(height: 80)

                // Shadow line
                Text("~~~~~~~~")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Theme.textSecondary.opacity(0.2))
            }

            // State decorations (ASCII style)
            if state == .happy {
                Text("*")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .offset(x: -50, y: -20)
                Text("<3")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.danger)
                    .offset(x: 50, y: -25)
            }

            if state == .working {
                Text("[...]")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .offset(x: 50, y: -20)
            }

            if state == .sleepy {
                Text("z Z z")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .offset(x: 45, y: -25)
            }

            if spec.isShiny {
                Text("*")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.yellow)
                    .offset(x: -55, y: -30)
                Text("*")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.yellow)
                    .offset(x: 55, y: -10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var asciiAnimated: some View {
        let art = asciiArt(for: spec.species, eyes: spec.eyes, hat: spec.hat)
        return Group {
            switch state {
            case .idle:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .offset(y: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            animPhase = -3
                        }
                    }
            case .happy:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .offset(y: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
                            animPhase = -6
                        }
                    }
            case .working:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .offset(x: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                            animPhase = 2
                        }
                    }
            case .sleepy:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(animPhase))
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.0)) {
                            animPhase = -10
                        }
                    }
            default:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Info

    private var buddyInfoSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if spec.isShiny {
                    Text("*")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                Text(spec.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                if spec.isShiny {
                    Text("*")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }

            HStack(spacing: 6) {
                Text(spec.species.displayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)

                Text("[\(spec.eyes)]")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)

                Text(spec.rarity.displayName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rarityColor(spec.rarity))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Stats (ASCII bar)

    private var buddyStatsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<5) { i in
                BuddyStatBar(
                    name: BuddyStats.statNames[i],
                    value: spec.stats.asArray[i],
                    bonus: bonusStats[i],
                    rarity: spec.rarity
                )
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Controls

    private var buddyControlsSection: some View {
        VStack(spacing: 6) {
            // Mood hearts (ASCII)
            Text(String(repeating: "<3 ", count: mood) + String(repeating: ".. ", count: 5 - mood))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.danger)

            // Tip text
            Text(buddyTip)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)

            if state == .idle || state == .happy {
                HStack(spacing: 6) {
                    Button(action: onPet) {
                        Text("/buddy pet")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.claudeOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.claudeOrange.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.claudeOrange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onFeed) {
                        Text("/buddy feed")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(canFeed ? Theme.success : Theme.textSecondary.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(canFeed ? Theme.success.opacity(0.1) : Theme.textSecondary.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(canFeed ? Theme.success.opacity(0.3) : Theme.border.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canFeed)

                    Button(action: onSleep) {
                        Text("/buddy off")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.textSecondary.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border, lineWidth: 1)
                                )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var buddyTip: String {
        if L.lang == .ko {
            if mood == 0 { return "!! 배고파요... 능력치가 떨어지고 있어요" }
            if mood < 2 { return "tip: 밥 주면 능력치가 올라가요 (하루 1회)" }
            if !canFeed { return "tip: 오늘 밥은 먹었어요. 내일 또 주세요~" }
            if state == .happy { return "냠냠! 맛있다~ 고마워요!" }
            return "tip: /buddy feed 로 밥을 주세요"
        } else {
            if mood == 0 { return "!! hungry... stats are dropping" }
            if mood < 2 { return "tip: feed me to boost stats (1x/day)" }
            if !canFeed { return "tip: already fed today. come back tomorrow~" }
            if state == .happy { return "yum! delicious~ thank you!" }
            return "tip: /buddy feed to boost a random stat"
        }
    }
}

// MARK: - Buddy Stat Bar (Graph)

struct BuddyStatBar: View {
    let name: String
    let value: Int
    let bonus: Int
    let rarity: BuddyRarity

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 58, alignment: .trailing)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Theme.progressBg.opacity(0.4))
                        .frame(height: 6)

                    // Base stat
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(rarityColor(rarity).opacity(0.8))
                        .frame(
                            width: max(3, geometry.size.width * CGFloat(min(value + bonus, 15)) / 15.0),
                            height: 6
                        )

                    // Bonus overlay (brighter)
                    if bonus > 0 {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Theme.success.opacity(0.9))
                            .frame(
                                width: max(3, geometry.size.width * CGFloat(bonus) / 15.0),
                                height: 6
                            )
                            .offset(x: geometry.size.width * CGFloat(value) / 15.0)
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                if bonus > 0 {
                    Text("+\(bonus)")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
            }
            .frame(width: 30, alignment: .leading)
        }
    }
}

// MARK: - Sparkline (7-day session usage trend)

struct SparklineView: View {
    let points: [UsageHistoryPoint]

    private var samples: [Double] {
        // Bucket the last 7 days into ~24 equal buckets of avg sessionPercent.
        let buckets = 24
        let now = Date()
        let span: TimeInterval = 7 * 86400
        let start = now.addingTimeInterval(-span)
        let recent = points.filter { $0.timestamp >= start }
        // Need at least 2 readings spanning a non-trivial range to draw a meaningful trend.
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last,
              last.timestamp.timeIntervalSince(first.timestamp) > 60
        else { return [] }

        var sums = [Double](repeating: 0, count: buckets)
        var counts = [Int](repeating: 0, count: buckets)
        for p in recent {
            let idx = min(buckets - 1, max(0, Int(p.timestamp.timeIntervalSince(start) / span * Double(buckets))))
            sums[idx] += p.sessionPercent
            counts[idx] += 1
        }
        // Seed carry-forward with the earliest known sample so empty leading buckets
        // baseline to the first reading instead of dropping to zero.
        var out: [Double] = []
        var lastVal: Double = first.sessionPercent
        for i in 0..<buckets {
            if counts[i] > 0 {
                lastVal = sums[i] / Double(counts[i])
            }
            out.append(lastVal)
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            if samples.count < 2 {
                VStack {
                    Spacer()
                    Text(L.noTrendYet)
                        .font(AppFont.regular(9))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ZStack {
                    // Fill under line
                    Path { path in
                        let pts = points(for: geo.size)
                        guard let first = pts.first else { return }
                        path.move(to: CGPoint(x: first.x, y: geo.size.height))
                        path.addLine(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                        if let last = pts.last {
                            path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Theme.claudeOrange.opacity(0.25), Theme.claudeOrange.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        let pts = points(for: geo.size)
                        guard let first = pts.first else { return }
                        path.move(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Theme.claudeOrange, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                    // Last-point dot
                    if let last = points(for: geo.size).last {
                        Circle()
                            .fill(Theme.claudeOrange)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                }
            }
        }
    }

    private func points(for size: CGSize) -> [CGPoint] {
        let s = samples
        guard s.count >= 2 else { return [] }
        let maxV: Double = max(20, s.max() ?? 1) // floor at 20% so tiny noise doesn't look spiky
        let stepX = size.width / Double(s.count - 1)
        return s.enumerated().map { i, v in
            let x = Double(i) * stepX
            let y = size.height - (v / maxV) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Glass Card Container

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface)
                    .shadow(color: Theme.glassShadow, radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Usage Progress Bar

struct UsageProgressBar: View {
    let percent: Double
    let showScale: Bool
    let showIcon: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Theme.progressBg.opacity(0.5))
                        .frame(height: 24)

                    if percent > 0 {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(progressGradient)
                                .frame(
                                    width: max(10, geometry.size.width * CGFloat(min(percent, 100)) / 100),
                                    height: 24
                                )

                            if showIcon && percent > 5 {
                                ClaudeCodeIconView()
                                    .frame(width: 18, height: 18)
                                    .offset(x: -2)
                            }
                        }
                    }
                }
            }
            .frame(height: 24)

            if showScale {
                HStack {
                    Text("0")
                    Spacer()
                    Text("25")
                    Spacer()
                    Text("50")
                    Spacer()
                    Text("75")
                    Spacer()
                    Text("100")
                }
                .font(AppFont.regular(9))
                .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var progressGradient: LinearGradient {
        let color: Color = {
            if percent >= 80 { return Theme.danger }
            if percent >= 50 { return Theme.warning }
            return Theme.success
        }()

        return LinearGradient(
            gradient: Gradient(colors: [color.opacity(0.7), color]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Claude Code Icon (SVG-based)

struct ClaudeCodeIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width / 24
        let h = rect.height / 24

        var path = Path()

        // Main body - simplified from the SVG path
        path.move(to: CGPoint(x: 20.998 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 24 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 24 * w, y: 14.051 * h))
        path.addLine(to: CGPoint(x: 21 * w, y: 14.051 * h))
        path.addLine(to: CGPoint(x: 21 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 19.513 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 19.513 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 18 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 18 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 16.513 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 16.513 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 15 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 15 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 9 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 9 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 7.488 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 7.488 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 6 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 6 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 4.487 * w, y: 20 * h))
        path.addLine(to: CGPoint(x: 4.487 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 3 * w, y: 17.079 * h))
        path.addLine(to: CGPoint(x: 3 * w, y: 14.05 * h))
        path.addLine(to: CGPoint(x: 0, y: 14.05 * h))
        path.addLine(to: CGPoint(x: 0, y: 10.95 * h))
        path.addLine(to: CGPoint(x: 3 * w, y: 10.95 * h))
        path.addLine(to: CGPoint(x: 3 * w, y: 5 * h))
        path.addLine(to: CGPoint(x: 20.998 * w, y: 5 * h))
        path.closeSubpath()

        // Left eye
        path.move(to: CGPoint(x: 6 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 7.488 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 7.488 * w, y: 8.102 * h))
        path.addLine(to: CGPoint(x: 6 * w, y: 8.102 * h))
        path.closeSubpath()

        // Right eye
        path.move(to: CGPoint(x: 16.51 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 18 * w, y: 10.949 * h))
        path.addLine(to: CGPoint(x: 18 * w, y: 8.102 * h))
        path.addLine(to: CGPoint(x: 16.51 * w, y: 8.102 * h))
        path.closeSubpath()

        return path
    }
}

struct ClaudeCodeIconView: View {
    var body: some View {
        ClaudeCodeIconShape()
            .fill(Theme.claudeOrange)
    }
}

// MARK: - Menu Bar Icon Helper

/// Returns an icon coloured by usage percent:
/// - <50%  : Claude orange (default brand)
/// - 50–80%: warning (amber)
/// - ≥80%  : danger (red)
private func menuBarIconColor(for percent: Double) -> NSColor {
    if percent >= 80 {
        return NSColor(red: 248.0/255.0, green: 113.0/255.0, blue: 113.0/255.0, alpha: 1.0)  // #F87171
    } else if percent >= 50 {
        return NSColor(red: 245.0/255.0, green: 158.0/255.0, blue: 11.0/255.0, alpha: 1.0)   // #F59E0B
    }
    return NSColor(red: 217.0/255.0, green: 119.0/255.0, blue: 87.0/255.0, alpha: 1.0)        // #D97757 (Claude orange)
}

func createMenuBarIcon(size: NSSize = NSSize(width: 18, height: 18), percent: Double = 0) -> NSImage {
    let fillColor = menuBarIconColor(for: percent)
    let image = NSImage(size: size, flipped: false) { rect in
        let w = rect.width / 24
        let h = rect.height / 24

        let path = NSBezierPath()

        // Main body
        path.move(to: NSPoint(x: 20.998 * w, y: rect.height - 10.949 * h))
        path.line(to: NSPoint(x: 24 * w, y: rect.height - 10.949 * h))
        path.line(to: NSPoint(x: 24 * w, y: rect.height - 14.051 * h))
        path.line(to: NSPoint(x: 21 * w, y: rect.height - 14.051 * h))
        path.line(to: NSPoint(x: 21 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 19.513 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 19.513 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 18 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 18 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 16.513 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 16.513 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 15 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 15 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 9 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 9 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 7.488 * w, y: rect.height - 17.079 * h))  // Fix: skip to match
        path.line(to: NSPoint(x: 6 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 6 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 4.487 * w, y: rect.height - 20 * h))
        path.line(to: NSPoint(x: 4.487 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 3 * w, y: rect.height - 17.079 * h))
        path.line(to: NSPoint(x: 3 * w, y: rect.height - 14.05 * h))
        path.line(to: NSPoint(x: 0, y: rect.height - 14.05 * h))
        path.line(to: NSPoint(x: 0, y: rect.height - 10.95 * h))
        path.line(to: NSPoint(x: 3 * w, y: rect.height - 10.95 * h))
        path.line(to: NSPoint(x: 3 * w, y: rect.height - 5 * h))
        path.line(to: NSPoint(x: 20.998 * w, y: rect.height - 5 * h))
        path.close()

        // Draw filled body (color reflects usage percent)
        fillColor.setFill()
        path.fill()

        // Eyes (cutout - draw in background color for template)
        let leftEye = NSBezierPath(rect: NSRect(
            x: 6 * w, y: rect.height - 10.949 * h,
            width: 1.488 * w, height: -(10.949 - 8.102) * h
        ))
        let rightEye = NSBezierPath(rect: NSRect(
            x: 16.51 * w, y: rect.height - 10.949 * h,
            width: 1.49 * w, height: -(10.949 - 8.102) * h
        ))

        NSColor.clear.setFill()
        leftEye.fill()
        rightEye.fill()

        return true
    }

    image.isTemplate = false
    return image
}

// MARK: - Onboarding (first-run welcome screen)

struct OnboardingView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroPulse: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero — animated ring preview at 42%
            ZStack {
                Circle()
                    .stroke(Theme.progressBg, lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: 0.42)
                    .stroke(Theme.claudeOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)
                ClaudeCodeIconView()
                    .frame(width: 26, height: 26)
                    .scaleEffect(1.0 + heroPulse * 0.04)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    heroPulse = 1.0
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(L.welcomeTitle)
                    .font(AppFont.bold(16))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L.welcomeBody1)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: 1, icon: "terminal", text: L.welcomeStep1)
                stepRow(number: 2, icon: "checkmark.shield", text: L.welcomeStep2)
                stepRow(number: 3, icon: "gearshape", text: L.welcomeStep3)
            }
            .padding(12)
            .background(Theme.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1)
            )

            HStack {
                Spacer()
                Button(action: { viewModel.hasCompletedOnboarding = true }) {
                    HStack(spacing: 6) {
                        Text(L.getStarted)
                            .font(AppFont.bold(12))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Theme.claudeOrange, Theme.claudeOrange.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(9)
                    .shadow(color: Theme.claudeOrange.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(L.getStarted)
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(20)
    }

    @ViewBuilder
    private func stepRow(number: Int, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(AppFont.bold(11))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Theme.claudeOrange)
                .clipShape(Circle())

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.claudeOrange)
                Text(text)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Session Ring (circular progress with center label)

struct SessionRingView: View {
    let percent: Double          // 0.0 .. 100.0
    let color: Color
    var isLoading: Bool = false
    var isDisconnected: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsePhase: Double = 0
    @State private var loadingPhase: Double = 0

    private var fraction: Double {
        guard !isDisconnected else { return 0 }
        return max(0, min(percent / 100.0, 1.0))
    }

    private var shouldPulse: Bool {
        !reduceMotion && percent >= 80 && !isLoading && !isDisconnected
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Theme.progressBg, lineWidth: 10)

            if isLoading {
                // Indeterminate skeleton arc
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(
                        Theme.accentDim,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(loadingPhase))
                    .onAppear {
                        if reduceMotion {
                            loadingPhase = 0
                        } else {
                            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                loadingPhase = 360
                            }
                        }
                    }
            } else {
                // Progress arc
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0)
                            : .spring(response: 0.7, dampingFraction: 0.78),
                        value: fraction
                    )
            }

            // Danger pulse glow (80%+)
            if shouldPulse {
                Circle()
                    .stroke(color.opacity(0.4 - pulsePhase * 0.3), lineWidth: 10 + pulsePhase * 6)
                    .blur(radius: 3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            pulsePhase = 1.0
                        }
                    }
            }

            // Center label
            VStack(spacing: 0) {
                if isLoading || isDisconnected {
                    Text("--")
                        .font(AppFont.bold(22))
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Text("\(Int(percent))")
                        .font(AppFont.black(28))
                        .foregroundColor(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(AppFont.semibold(10))
                        .foregroundColor(Theme.textSecondary)
                        .offset(y: -2)
                }
            }
        }
    }
}
