# Changelog

All notable changes to **Claude Usage Widget (macOS)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
