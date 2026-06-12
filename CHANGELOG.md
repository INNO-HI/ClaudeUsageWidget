# Changelog

All notable changes to **Claude Usage Widget (macOS)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.2] — 2026-06-12

### Fixed
- **`expiresAt` unit mismatch could mark every cached token as expired.** Claude Code stores the token's `expiresAt` in milliseconds (13-digit value) but historically used seconds (10-digit) in some builds. The previous comparison assumed milliseconds only — if a user landed on a seconds-format file, the cache check would treat every token as already expired and re-query the Keychain on every sync. The unit is now auto-detected (values > 1e11 are ms; below that, seconds).

### Added
- **Unified-logging diagnostics** under subsystem `com.innohi.claudeusagewidget`, category `creds`. Stream live with:

  ```bash
  log stream --predicate 'subsystem == "com.innohi.claudeusagewidget" AND category == "creds"' --style compact
  ```

  Markers emitted: `cache-hit`, `cache-expired`, `file-hit`, `file-miss`, `keychain-denied-cached`, `keychain-query START`, `keychain-query OK (Nms)`, `keychain-query FAIL status=N`, `expires-check now=… expiresAt=… expiresSec=… expired=…`, `invalidate-cache`. These let users (and us) verify exactly when — and whether — the macOS Keychain prompt is triggered.

### Internal
- `UsageService` switched to `os_log` with `%{public}@` markers (previously NSLog, which was redacted as `<private>` in unified logging).

---

## [1.4.1] — 2026-06-11

### Fixed
- **Repeated macOS Keychain access prompts.** Every auto-sync re-queried the Keychain because the credentials were re-read from disk + Keychain on every tick. The widget now holds the parsed `OAuthCredentials` in memory and only re-reads when:
  - the cached `expiresAt` is within 30 s of now (Claude Code has rotated the token),
  - the server returns 401 / 403 (the cache is invalidated automatically),
  - the user explicitly triggers Refresh / Retry / picks a new credentials file (these call `checkCredentials(forceRefresh: true)`),
  - the `credentialPathOverride` changes (the new path resets both the cache and the "Keychain denied" flag).
- If the Keychain prompt is cancelled or denied once during a session, the widget no longer re-prompts on subsequent auto-syncs — it surfaces "Not logged in" until the user explicitly retries.

### Internal
- `UsageService` gains `cachedCredentials`, `keychainDeniedThisSession`, `invalidateCachedCredentials()`, and `isCachedTokenExpired(_:)`.
- The fetch path invalidates the cache on `401/403` before raising `.unauthorized`, so the next sync pulls Claude Code's freshly-rotated token from disk.

---

## [1.4.0] — 2026-06-02

### Added
- **CSV / JSON export** of the 7-day usage history (Settings → Data) with a save panel, plus a "Clear history" action behind an `NSAlert` confirmation.
- **Multi-account credential path** — Settings → Account exposes a "Credentials file" row that lets users point the widget at a non-default `~/.claude/.credentials.json`. Persisted via `credentialPathOverride` in the config file.
- **Rich menu-bar tooltip** — hovering the status item now shows the current session %, reset time, ETA, weekly %, and last-sync timestamp without opening the popover.
- **Unit test suite** (Swift Package at `macos/Package.swift`) covering the pure-logic surface: ETA estimation, sparkline bucketing, threshold sanitisation, time formatting, and `UsageHistoryPoint` Codable round-trip. 22 tests, runs with `swift test`.
- **GitHub Actions CI** — `.github/workflows/test.yml` runs the test suite on every push and PR; `.github/workflows/release-macos.yml` rewritten to build / sign / notarize / DMG / upload on every `v*-macos` tag and to update `appcast.xml` automatically.
- **Mac App Store submission scaffolding** — sandbox entitlements at `Resources/entitlements/Sandbox-MAS.entitlements`, plus `MAS-SUBMISSION.md` covering Bundle ID separation, security-scoped bookmarks, and the dual-build pipeline.
- **Homebrew Cask submission guide** at `macos/HOMEBREW-PR-GUIDE.md` (local audit, PR template, automated bump action).

### Changed
- `UsageService.credentialFilePath` is now a mutable property the ViewModel drives — service no longer hardcodes the home-directory path.
- Settings layout grows a new "Data" category between Notifications and Updates.

### Internal
- Extracted pure logic into `macos/CoreLogic/CoreLogic.swift` so the test target can import it without dragging in AppKit / SwiftUI / Sparkle.
- `build.sh` now uses the `SIGN_IDENTITY` env var that CI passes (still defaults to the maintainer's Developer ID locally).

---

## [1.3.0] — 2026-06-02

### Added
- **Custom alert thresholds** — replace the fixed 80% / 90% notifications with two user-tunable sliders (50–95% / 60–99%) inside Settings → Notifications. Menu-bar pulse + ring glow follow the lower threshold automatically.
- **3-step Onboarding** — Intro (animated ring) → Login guidance (copy-`claude login` button) → Notifications opt-in. Includes Back/Skip and page indicator dots.
- **Friendly Error Banner** — surfaces classified errors (credentials / rate-limited / network / server / unknown) with `Retry`, `Open Terminal` (when relevant), and `Dismiss` actions inline above the session card.
- **Japanese (日本語) & Simplified Chinese (中文)** localisation. The Language picker in Settings now offers EN / KO / JA / ZH.

### Changed
- `Localization.swift` switched to a 4-way `t(en:ko:ja:zh:)` helper so new strings only require additions in one place.
- `Models.swift` exposes `errorKind: ErrorKind` and `alertThresholdLow / alertThresholdHigh` (persisted to `~/.claude-usage-widget-config.json`).
- Source files split for maintainability — `Theme.swift`, `BuddyViews.swift`, `OnboardingView.swift` are now siblings of `PopoverContentView.swift` (1840 → ~1290 lines on the main view).

### Internal
- Build pipeline (`build.sh`) now compiles the additional Swift sources in the Universal Binary lipo step.

---

## [1.2.0] — 2026-05-28

### Added
- **Burn-rate ETA** — predicts when the session limit will be hit at current pace, shown in the session card
- **7-day sparkline** — usage trend strip in the Weekly Limits card; history persisted to `~/.claude-usage-widget-history.json`
- **Menu bar text format** — choose between Off / `%` / Time / Both via segmented picker
- **Warning pulse** — menu bar icon breathes when session ≥ 80%; session ring gets a soft glow halo
- **Skeleton loading** — indeterminate rotating arc + `--` while the first sync is in flight
- **Spring-animated ring** — percent changes now ease in with a SwiftUI spring; numeric label uses `contentTransition(.numericText())`
- **Refreshed Onboarding** — animated ring hero, gradient CTA with arrow, centered layout
- **Category icons in Settings** — Account / General / Notifications / Updates each carry an SF Symbol header

### Changed
- Default progress arc animation upgraded from `easeOut` to spring
- Settings rows now expose proper `accessibilityLabel`s; category headers tagged as `.isHeader`
- `⌘Q` quits the app from anywhere inside the popover

### Fixed
- Footer build label corrected (`v1.3.0` → `v1.2.0`)
- Deprecated `NSWorkspace.launchApplication` replaced with `openApplication(at:configuration:)`
- All animations honour the system **Reduce Motion** preference (ring pulse, menu bar breathing, bounce, onboarding hero)

---

## [1.1.0] — 2026-04-29

### Added
- **Sparkle auto-update** — signed (EdDSA) and verified updates via in-app `Settings → Check for Updates`
- **Launch at Login** option (uses `SMAppService.mainApp`, macOS 13+)
- **Mini / Full mode toggle** — show or hide the menu-bar `%` text
- **Usage Alerts** — optional macOS notifications at 80% and 90% session usage
- **Universal Binary** — runs natively on both Apple Silicon and Intel Macs
- **API rate-limit safety** — ±10% jitter between syncs, 2× → 16× exponential backoff on HTTP 429
- Signed & notarized **DMG** as the primary distribution format

### Changed
- Build pipeline now performs codesigning of all Sparkle nested binaries before notarization
- Settings UI reorganized to surface new toggles

### Documentation
- Added Troubleshooting and Change Log sections to README
- Added [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and Privacy Policy
- Added [appcast.xml](https://inno-hi.github.io/ClaudeUsageWidget/appcast.xml) feed for Sparkle

---

## [1.0.0] — 2026-04-14

### Added
- Initial public release of the macOS native widget
- Real-time monitoring of 5-hour session and 7-day weekly limits
- Glassmorphism popover UI with English and Korean localization
- OAuth-based usage fetch (zero token cost — no Claude messages sent)
- Configurable auto-sync (5m / 10m / 30m / 1h / manual)
- Claude Code Buddy easter egg system (18 species, 5 rarity tiers)
- MIT-licensed source

[1.1.0]: https://github.com/INNO-HI/ClaudeUsageWidget/releases/tag/v1.1.0-macos
[1.0.0]: https://github.com/INNO-HI/ClaudeUsageWidget/releases/tag/v1.0.0-macos
