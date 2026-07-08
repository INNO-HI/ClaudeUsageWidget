import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Main Popover View

struct PopoverContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var summaryCopied = false

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
                    if viewModel.errorKind != nil {
                        ErrorBannerView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
            .accessibilityHidden(true)  // shortcut carriers only — invisible to VoiceOver
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

            menuBarMetricRow

            settingsToggleRow(label: L.showBuddy, isOn: $viewModel.showBuddy)

            settingsToggleRow(label: L.compactMode, isOn: $viewModel.compactMode)

            settingsToggleRow(label: L.menuBarExpressions, isOn: $viewModel.showMenuBarExpressions)

            // ── Notifications ────────────────────────
            categoryHeader(L.sectionNotifications, icon: "bell.fill")

            settingsToggleRow(label: L.enableNotifications, isOn: $viewModel.notificationsEnabled)

            if viewModel.notificationsEnabled {
                thresholdRow

                settingsToggleRow(label: L.notifyNewSession, isOn: $viewModel.notifyOnSessionReset)
            }

            // ── Data ─────────────────────────────────
            categoryHeader(L.sectionData, icon: "tray.and.arrow.down.fill")

            dataExportRow

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

    // MARK: Settings — Data export

    private var dataExportRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.historyCount(viewModel.usageHistory.count))
                    .font(AppFont.regular(10))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            HStack(spacing: 8) {
                pillButton(icon: "doc.text", title: L.exportCSV) {
                    saveExport(content: viewModel.exportHistoryCSV(), suggestedName: "claude-usage.csv")
                }
                pillButton(icon: "curlybraces", title: L.exportJSON) {
                    saveExport(content: viewModel.exportHistoryJSON(), suggestedName: "claude-usage.json")
                }
                Spacer()
                Button(action: confirmClearHistory) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .semibold))
                        Text(L.clearHistory).font(AppFont.semibold(10))
                    }
                    .foregroundColor(Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.clearHistory)
                .disabled(viewModel.usageHistory.isEmpty)
            }
        }
    }

    /// Show an NSSavePanel and write the export string to the chosen location.
    private func saveExport(content: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        // Run the save panel as a modal sheet on the popover window if possible,
        // falling back to a free-standing modal otherwise.
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow {
            NSApp.activate(ignoringOtherApps: true)
            response = panel.runModal()
            _ = window  // silence unused warning
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = L.clearHistoryConfirm
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.deleteAction)
        alert.addButton(withTitle: L.cancelAction)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            viewModel.clearHistory()
        }
    }

    // MARK: Settings — Notification thresholds

    private var thresholdRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L.alertThresholds)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(L.thresholdLabel(low: viewModel.alertThresholdLow, high: viewModel.alertThresholdHigh))
                    .font(AppFont.bold(11))
                    .foregroundColor(Theme.claudeOrange)
            }
            HStack(spacing: 8) {
                Text(L.alertLow)
                    .font(AppFont.regular(10))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 52, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.alertThresholdLow) },
                        set: { newVal in
                            let low = Int(newVal.rounded())
                            viewModel.alertThresholdLow = low
                            if viewModel.alertThresholdHigh <= low {
                                viewModel.alertThresholdHigh = min(99, low + 5)
                            }
                        }
                    ),
                    in: 50...95,
                    step: 5
                )
                .tint(Theme.claudeOrange)
                .accessibilityLabel("\(L.alertLow) \(viewModel.alertThresholdLow)%")
            }
            HStack(spacing: 8) {
                Text(L.alertHigh)
                    .font(AppFont.regular(10))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 52, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.alertThresholdHigh) },
                        set: { newVal in
                            let high = Int(newVal.rounded())
                            viewModel.alertThresholdHigh = high
                            if viewModel.alertThresholdLow >= high {
                                viewModel.alertThresholdLow = max(50, high - 5)
                            }
                        }
                    ),
                    in: 60...99,
                    step: 5
                )
                .tint(Theme.danger)
                .accessibilityLabel("\(L.alertHigh) \(viewModel.alertThresholdHigh)%")
            }
        }
        .padding(.leading, 16)
        .padding(.top, -2)
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

    // MARK: Settings — Menu bar metric picker (session vs weekly %)

    private var menuBarMetricRow: some View {
        HStack(spacing: 6) {
            Text(L.menuBarMetric)
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            ForEach([UsageViewModel.MenuBarMetric.session, .weekly], id: \.rawValue) { metric in
                Button(action: { viewModel.menuBarMetric = metric }) {
                    Text(metric == .session ? L.metricSession : L.metricWeekly)
                        .font(viewModel.menuBarMetric == metric ? AppFont.bold(10) : AppFont.regular(10))
                        .foregroundColor(viewModel.menuBarMetric == metric ? Theme.claudeOrange : Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(viewModel.menuBarMetric == metric ? Theme.claudeOrange.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(viewModel.menuBarMetric == metric ? Theme.claudeOrange.opacity(0.3) : Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(L.menuBarMetric): \(metric == .session ? L.metricSession : L.metricWeekly)")
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
                    viewModel.checkCredentials(forceRefresh: true)
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

            credentialPathRow
        }
    }

    // MARK: Settings — Multi-account credential path override

    private var credentialPathRow: some View {
        HStack(spacing: 8) {
            Text(L.credentialPath)
                .font(AppFont.regular(10))
                .foregroundColor(Theme.textSecondary)

            Text(currentCredPathDisplay)
                .font(AppFont.mono(9))
                .foregroundColor(viewModel.credentialPathOverride == nil ? Theme.textSecondary.opacity(0.7) : Theme.claudeOrange)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: pickCredentialFile) {
                Text(L.customPath)
                    .font(AppFont.semibold(9))
                    .foregroundColor(Theme.claudeOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.claudeOrange.opacity(0.08))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.customPath)

            if viewModel.credentialPathOverride != nil {
                Button(action: { viewModel.credentialPathOverride = nil; viewModel.checkCredentials(forceRefresh: true); viewModel.fetchUsage() }) {
                    Text(L.clearOverride)
                        .font(AppFont.semibold(9))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.clearOverride)
            }
        }
    }

    private var currentCredPathDisplay: String {
        let path = viewModel.credentialPathOverride ?? "~/.claude/.credentials.json"
        return path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func pickCredentialFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude", isDirectory: true)
        panel.message = L.credentialPath
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.credentialPathOverride = url.path
            viewModel.checkCredentials(forceRefresh: true)
            viewModel.fetchUsage()
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
                    isDisconnected: !viewModel.usage.isConnected && !viewModel.isSyncing,
                    pulseThreshold: Double(viewModel.alertThresholdLow)
                )
                .frame(width: viewModel.compactMode ? 72 : 92,
                       height: viewModel.compactMode ? 72 : 92)
                .accessibilityLabel(L.currentSession)
                .accessibilityValue("\(Int(viewModel.usage.sessionUsagePercent))% — \(viewModel.sessionResetText)")

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

                UsageProgressBar(percent: viewModel.usage.weeklyAllModelsPercent)

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

                UsageProgressBar(percent: viewModel.usage.weeklySonnetPercent)

                // Opus pool — only plans that have one (seven_day_opus non-null)
                if viewModel.usage.hasOpusLimit {
                    Divider().background(Theme.border.opacity(0.3))

                    HStack {
                        Text(L.opusOnly)
                            .font(AppFont.medium(12))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(viewModel.usage.weeklyOpusPercent))%")
                            .font(AppFont.bold(12))
                            .foregroundColor(percentColor(viewModel.usage.weeklyOpusPercent))
                    }

                    UsageProgressBar(percent: viewModel.usage.weeklyOpusPercent)
                }

                // Dynamically discovered model pools (Fable, Mythos, future tiers)
                ForEach(viewModel.usage.extraWeeklyPools, id: \.slug) { pool in
                    Divider().background(Theme.border.opacity(0.3))

                    HStack {
                        Text(L.modelOnly(pool.slug.capitalized))
                            .font(AppFont.medium(12))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(pool.percent))%")
                            .font(AppFont.bold(12))
                            .foregroundColor(percentColor(pool.percent))
                    }

                    UsageProgressBar(percent: pool.percent)
                }

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
                        Text(interval == .manual ? L.syncManual : interval.rawValue)
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
            Text("v1.6.2")
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(viewModel.lastSyncText)
                .font(AppFont.regular(11))
                .foregroundColor(Theme.textSecondary)

            Button(action: copySummaryToClipboard) {
                Image(systemName: summaryCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(summaryCopied ? Theme.success : Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L.copySummary + " (⌘⇧C)")
            .accessibilityLabel(L.copySummary)
            .keyboardShortcut("c", modifiers: [.command, .shift])

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

                    Text(L.hatching)
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

    private func copySummaryToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.usageSummaryText, forType: .string)
        withAnimation { summaryCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { summaryCopied = false }
        }
    }

    // MARK: - Helpers

    private func percentColor(_ percent: Double) -> Color {
        if percent >= 80 { return Theme.danger }
        if percent >= 50 { return Theme.warning }
        return Theme.success
    }
}


// MARK: - Error Banner (friendly recovery surface)

struct ErrorBannerView: View {
    @ObservedObject var viewModel: UsageViewModel

    private var spec: (icon: String, color: Color, title: String, body: String) {
        switch viewModel.errorKind ?? .unknown {
        case .credentials: return ("person.crop.circle.badge.exclamationmark", Theme.danger,  L.errorCredentialsTitle, L.errorCredentialsBody)
        case .rateLimited: return ("hourglass.tophalf.filled",                 Theme.warning, L.errorRateTitle,        L.errorRateBody)
        case .network:     return ("wifi.exclamationmark",                     Theme.warning, L.errorNetworkTitle,     L.errorNetworkBody)
        case .server:      return ("server.rack",                              Theme.warning, L.errorServerTitle,      L.errorServerBody)
        case .unknown:     return ("exclamationmark.triangle.fill",            Theme.danger,  L.errorUnknownTitle,     viewModel.errorMessage ?? "")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: spec.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(spec.color)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(spec.title)
                    .font(AppFont.bold(12))
                    .foregroundColor(Theme.textPrimary)

                Text(spec.body)
                    .font(AppFont.regular(10))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if viewModel.errorKind == .credentials {
                        actionButton(L.openTerminal, icon: "terminal", color: Theme.claudeOrange) {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
                            }
                        }
                    }

                    actionButton(L.retryNow, icon: "arrow.clockwise", color: Theme.claudeOrange) {
                        viewModel.checkCredentials(forceRefresh: true)
                        viewModel.fetchUsage()
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.errorKind = nil
                            viewModel.errorMessage = nil
                        }
                    }) {
                        Text(L.dismissError)
                            .font(AppFont.semibold(10))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.dismissError)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(spec.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(spec.color.opacity(0.35), lineWidth: 1)
        )
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(AppFont.semibold(10))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
        // Bucketing walks the full history; compute once per render instead
        // of once per Path closure (fill + line + dot = 3-4 passes before).
        let s = samples
        return GeometryReader { geo in
            if s.count < 2 {
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
                        let pts = Self.projectPoints(s, size: geo.size)
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
                        let pts = Self.projectPoints(s, size: geo.size)
                        guard let first = pts.first else { return }
                        path.move(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Theme.claudeOrange, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                    // Last-point dot
                    if let last = Self.projectPoints(s, size: geo.size).last {
                        Circle()
                            .fill(Theme.claudeOrange)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                }
            }
        }
    }

    /// Pure projection — samples are computed once in body and passed in.
    private static func projectPoints(_ s: [Double], size: CGSize) -> [CGPoint] {
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


// MARK: - Usage Progress Bar

struct UsageProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.progressBg.opacity(0.5))
                    .frame(height: 24)

                if percent > 0 {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(progressGradient)
                        .frame(
                            width: max(10, geometry.size.width * CGFloat(min(percent, 100)) / 100),
                            height: 24
                        )
                }
            }
        }
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(percent))%")
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

/// Four expressions the menu-bar face can wear. The body silhouette stays
/// constant; only the eyes (and a tiny "z" mark for sleeping) change.
///   .idle         — calm dots ●● (Claude binary not running)
///   .syncing      — horizontal slits −− (blinking; AppDelegate alternates with .idle)
///   .activeClaude — wide alert eyes ◉◉ + side-to-side wobble (Claude working)
///   .sleeping     — eyes closed + small "z" mark (Claude running but no recent activity)
enum IconExpression {
    case idle, syncing, activeClaude, sleeping
}

/// Cache — the icon space is tiny (3 colour buckets × 4 expressions = 12
/// distinct 18×18 images) but createMenuBarIcon was re-rasterizing a fresh
/// NSBezierPath render on every repaint and 4×/sec during the sync blink.
private var menuBarIconCache: [String: NSImage] = [:]

func createMenuBarIcon(
    size: NSSize = NSSize(width: 18, height: 18),
    percent: Double = 0,
    expression: IconExpression = .idle,
    bakeSleepZ: Bool = true
) -> NSImage {
    let colorBucket = percent >= 80 ? 2 : (percent >= 50 ? 1 : 0)
    let cacheKey = "\(expression)-\(colorBucket)-\(Int(size.width))-\(bakeSleepZ)"
    if let cached = menuBarIconCache[cacheKey] { return cached }

    let fillColor = menuBarIconColor(for: percent)
    // Eyes painted in white — high contrast on the warm orange/red/amber
    // body so they read clearly on both light and dark menu bars.
    let eyeColor = NSColor.white
    let image = NSImage(size: size, flipped: false) { rect in
        let w = rect.width / 24
        let h = rect.height / 24

        let path = NSBezierPath()

        // Main body (unchanged across expressions)
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
        path.line(to: NSPoint(x: 7.488 * w, y: rect.height - 20 * h))       // restore hat prong
        path.line(to: NSPoint(x: 7.488 * w, y: rect.height - 17.079 * h))
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

        // Eye geometry — bumped up to ~2× the original SVG eye box so it
        // actually reads as a face at 18×18 pixels. Each expression tweaks
        // the rectangle, then we append it as a sub-path to the same body
        // path. Even-odd fill turns the sub-paths into real cutouts.
        let baseLeftCenterX  = 6.7  * w
        let baseRightCenterX = 17.3 * w
        let baseCenterY      = rect.height - 9.5 * h
        let baseW: CGFloat   = 2.8 * w
        let baseH: CGFloat   = 4.0 * h

        let leftRect:  NSRect
        let rightRect: NSRect

        switch expression {
        case .idle:
            // ▪▪ — small tidy dots (roughly half the base size for a
            // minimalist, non-staring default look)
            let dotW = baseW * 0.55
            let dotH = baseH * 0.55
            leftRect  = NSRect(x: baseLeftCenterX  - dotW/2, y: baseCenterY - dotH/2,
                               width: dotW, height: dotH)
            rightRect = NSRect(x: baseRightCenterX - dotW/2, y: baseCenterY - dotH/2,
                               width: dotW, height: dotH)

        case .syncing:
            // −− — short horizontal slits (blinking; AppDelegate alternates with .idle)
            let slitH = baseH * 0.30
            leftRect  = NSRect(x: baseLeftCenterX  - baseW/2, y: baseCenterY - slitH/2,
                               width: baseW, height: slitH)
            rightRect = NSRect(x: baseRightCenterX - baseW/2, y: baseCenterY - slitH/2,
                               width: baseW, height: slitH)

        case .activeClaude:
            // ◉◉ — wider and taller "alert" eyes
            let wider  = baseW * 1.35
            let taller = baseH * 1.25
            leftRect  = NSRect(x: baseLeftCenterX  - wider/2, y: baseCenterY - taller/2,
                               width: wider, height: taller)
            rightRect = NSRect(x: baseRightCenterX - wider/2, y: baseCenterY - taller/2,
                               width: wider, height: taller)

        case .sleeping:
            // −− closed eyes (slim horizontal lines, static — no blink)
            let lidH = max(1, h * 0.4)  // ~1 px on a 18×18 icon
            leftRect  = NSRect(x: baseLeftCenterX  - baseW/2, y: baseCenterY - lidH/2,
                               width: baseW, height: lidH)
            rightRect = NSRect(x: baseRightCenterX - baseW/2, y: baseCenterY - lidH/2,
                               width: baseW, height: lidH)
        }

        // Body first (solid fill), then eyes on top as solid white rectangles.
        fillColor.setFill()
        path.fill()

        eyeColor.setFill()
        NSBezierPath(rect: leftRect).fill()
        NSBezierPath(rect: rightRect).fill()

        // .sleeping gets a tiny "z" mark in the top-right corner so the
        // closed eyes read as "sleeping" rather than "syncing slits".
        // Drawn as a thin Z made of three short segments.
        if expression == .sleeping && bakeSleepZ {
            let zPath = NSBezierPath()
            zPath.lineWidth = max(0.75, w * 0.5)
            zPath.lineCapStyle = .round
            let zLeft   = 20.5 * w
            let zRight  = 23.0 * w
            let zTop    = rect.height - 4.0 * h
            let zBottom = rect.height - 7.0 * h
            zPath.move(to: NSPoint(x: zLeft,  y: zTop))     // top horizontal
            zPath.line(to: NSPoint(x: zRight, y: zTop))
            zPath.line(to: NSPoint(x: zLeft,  y: zBottom))  // diagonal
            zPath.line(to: NSPoint(x: zRight, y: zBottom))  // bottom horizontal
            eyeColor.setStroke()
            zPath.stroke()
        }

        return true
    }

    image.isTemplate = false
    menuBarIconCache[cacheKey] = image
    return image
}


// MARK: - Session Ring (circular progress with center label)

struct SessionRingView: View {
    let percent: Double          // 0.0 .. 100.0
    let color: Color
    var isLoading: Bool = false
    var isDisconnected: Bool = false
    var pulseThreshold: Double = 80

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsePhase: Double = 0
    @State private var loadingPhase: Double = 0

    private var fraction: Double {
        guard !isDisconnected else { return 0 }
        return max(0, min(percent / 100.0, 1.0))
    }

    private var shouldPulse: Bool {
        !reduceMotion && percent >= pulseThreshold && !isLoading && !isDisconnected
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
