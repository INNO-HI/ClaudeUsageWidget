# Changelog

All notable changes to **Claude Usage Widget (macOS)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
