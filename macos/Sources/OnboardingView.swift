import SwiftUI
import AppKit

// MARK: - Onboarding (first-run, 3-step)

struct OnboardingView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroPulse: Double = 0
    @State private var page: Int = 0
    @State private var copied: Bool = false
    private let totalPages = 3

    var body: some View {
        VStack(spacing: 18) {
            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.claudeOrange : Theme.border)
                        .frame(width: i == page ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                }
            }
            .padding(.top, 4)

            // Page content (cross-fades)
            Group {
                switch page {
                case 0: introPage
                case 1: loginPage
                default: notifPage
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer(minLength: 0)

            // Navigation row
            HStack {
                if page > 0 {
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { page -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text(L.backStep)
                                .font(AppFont.semibold(11))
                        }
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                primaryAction
            }
        }
        .frame(minHeight: 380)
        .padding(20)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Page 1 — Intro (hero ring + welcome)
    private var introPage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Theme.progressBg, lineWidth: 7)
                    .frame(width: 78, height: 78)
                Circle()
                    .trim(from: 0, to: 0.42)
                    .stroke(Theme.claudeOrange, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 78, height: 78)
                ClaudeCodeIconView()
                    .frame(width: 30, height: 30)
                    .scaleEffect(1.0 + heroPulse * 0.04)
            }
            .padding(.top, 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    heroPulse = 1.0
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(L.welcomeTitle)
                    .font(AppFont.bold(17))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L.welcomeBody1)
                    .font(AppFont.regular(12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Page 2 — Login guidance
    private var loginPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 38))
                .foregroundColor(Theme.claudeOrange)
                .padding(.top, 6)

            VStack(spacing: 6) {
                Text(L.loginPageTitle)
                    .font(AppFont.bold(15))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L.loginPageBody)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("claude login")
                    .font(AppFont.mono(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: copyLoginCommand) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(copied ? L.copied : L.loginPageCopy)
                            .font(AppFont.semibold(10))
                    }
                    .foregroundColor(copied ? Theme.success : Theme.claudeOrange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Page 3 — Notifications
    private var notifPage: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 38))
                .foregroundColor(Theme.claudeOrange)
                .padding(.top, 6)

            VStack(spacing: 6) {
                Text(L.notifPageTitle)
                    .font(AppFont.bold(15))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L.notifPageBody)
                    .font(AppFont.regular(11))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                thresholdChip(value: 60)
                thresholdChip(value: 80)
                thresholdChip(value: 90)
            }
            .padding(.top, 4)
        }
    }

    private func thresholdChip(value: Int) -> some View {
        Text("\(value)%")
            .font(AppFont.bold(10))
            .foregroundColor(value >= 80 ? Theme.danger : Theme.warning)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background((value >= 80 ? Theme.danger : Theme.warning).opacity(0.12))
            .cornerRadius(10)
    }

    // MARK: - Primary CTA per page
    private var primaryAction: some View {
        Group {
            if page < totalPages - 1 {
                ctaButton(label: L.nextStep, icon: "arrow.right") {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                }
            } else {
                HStack(spacing: 8) {
                    Button(action: { viewModel.hasCompletedOnboarding = true }) {
                        Text(L.notifPageSkip)
                            .font(AppFont.semibold(11))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    ctaButton(label: L.notifPageEnable, icon: "bell.fill") {
                        viewModel.notificationsEnabled = true
                        viewModel.hasCompletedOnboarding = true
                    }
                }
            }
        }
    }

    private func ctaButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(AppFont.bold(12))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
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
        .accessibilityLabel(label)
    }

    private func copyLoginCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("claude login", forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}
