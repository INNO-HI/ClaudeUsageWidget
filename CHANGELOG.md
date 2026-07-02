# Changelog

All notable changes to **Claude Usage Widget (macOS)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.5.5] — 2026-06-17

### Changed
- **Idle eyes shrunk to small tidy dots** (0.55× the previous rectangles). Reads as a calm resting face instead of a robot stare.

### Fixed
- **Menu-bar silhouette parity** — the AppKit body path was missing the `(7.488, 20)` vertex present in the SwiftUI `ClaudeCodeIconShape`, cutting off one of the "hat prongs" on the menu-bar version only. The two icons now match pixel-for-pixel at the silhouette level.
- **`ACTIVE → SLEEPING` face-flicker.** The two `@Published` bools (`claudeActivelyRunning` + `claudeSleeping`) transitioned separately, so the icon briefly rendered as `.idle` between the two Combine emissions. Consolidated into a single `@Published var claudeActivity: ClaudeActivity` enum — one publisher, one transition per detection tick.
- **Subprocess hang / stack-up.** `find` on a network-mounted `~/.claude/projects` or a huge project count could have exceeded the 10 s poll interval, and concurrent ticks would stack rather than skip. `runProcessWithTimeout` now hard-caps every subprocess at 5 s (SIGTERM → 200 ms grace → SIGKILL), and a serial `activity` dispatch queue plus an in-flight flag guarantees at most one detection query is running at any time.

### Added
- **VoiceOver labels** on the menu-bar face state: `Claude Code active`, `Claude Code sleeping`, `syncing`, or the default title. The rich tooltip also gains a Claude-activity line so hover users know what the changing face means.
- **5 regression tests** for the three-tier `classifyClaudeActivity(recentlyWorking:processAlive:)` classifier in `CoreLogic`. Precedence pinned (recent file > binary alive > nothing) so the v1.5.3 mistake (treating "process exists" as active) can't silently return. **Total: 40 tests.**

### Internal
- Dead `_ = zMid` cleanup in the sleeping-face `z`-mark drawing.
- `queryClaudeRunning` refactored around `runProcessWithTimeout(launchPath:arguments:captureStdout:timeout:)`, tightening the two `Process` blocks into a single named path with a return type.

---

## [1.5.4] — 2026-06-16

### Added
- **Fourth menu-bar expression: `.sleeping`** — closed eyes with a small "z" mark in the top-right corner. Shown when the `claude` CLI binary is running but no session file under `~/.claude/projects/` has been written in the last 60 s (e.g. VS Code Claude Code extension parked open between requests).
- Three-tier activity detection driving four faces:
  - **ACTIVE** (wide eyes + wobble) — `~/.claude/projects/` file modified in last 60 s
  - **SLEEPING** (closed eyes + z) — `claude` running but no recent file activity
  - **SYNCING** (slits, blinking) — widget is fetching usage
  - **IDLE** (calm dots) — Claude isn't running at all

### Changed
- `queryClaudeRunning()` now uses `find ~/.claude/projects -mmin -1 -type f -print -quit` for the "actively working" check, with `pgrep -x claude` running alongside to distinguish ACTIVE from SLEEPING. Logs now read:
  ```
  claude → ACTIVE   (recentFile=yes procAlive=yes)
  claude → SLEEPING (recentFile=no  procAlive=yes)
  claude → idle     (recentFile=no  procAlive=no)
  ```
- This fixes the v1.5.3 UX issue where the icon stayed in the wide-eyed ACTIVE face whenever Claude Code was running in the background — most VS Code users were never seeing the calm default eyes.

### Internal
- New `@Published var claudeSleeping: Bool` on `UsageViewModel`; AppDelegate's Combine sinks now include `$claudeSleeping`.
- Icon priority unchanged at the top: syncing > activeClaude > sleeping > idle.

---

## [1.5.3] — 2026-06-16

### Added
- **Wobble Shake motion** — when Claude Code is actively running, the menu-bar icon now vibrates side-to-side ±1.5 px at ~3 Hz so the icon visibly "works hard" rather than just changing eye shape. Disables itself during sync (the bounce takes the y axis) and when the user turns off "Animated menu-bar face" in Settings. Respects system Reduce Motion.

### Changed
- **Eyes are now solid white rectangles** instead of transparent cutouts. The v1.5.2 even-odd hole approach revealed whatever wallpaper happened to sit behind the menu bar, which looked random and inconsistent. White reads cleanly on the warm orange / amber / red body colour at every usage threshold and on both light and dark menu bars.

### Internal
- New `wobbleTimer` + `wobblePhase` in AppDelegate; 0.03 s interval, `sin(phase) * 1.5` x-offset.
- Start/stop driven by `(shouldWobble = !syncing && claudeActivelyRunning && showMenuBarExpressions)` inside the existing `updateStatusBarIcon` decision tree.

---

## [1.5.2] — 2026-06-15

### Fixed
- **Eyes were invisible on the menu-bar icon.** The original code drew the eye rectangles with `NSColor.clear.setFill()`, which paints transparent pixels on top of the orange body — and a transparent paint composites to "no change", so the body stayed solid. The eye notches that v1.5.0 advertised never actually appeared.
- The fix: the eye rectangles are now appended as sub-paths to the same body path, and the path's `windingRule` is set to `.evenOdd`. A single `path.fill()` then turns the eye regions into genuine transparent holes — visible at 18×18 px in both light and dark menu bars.
- While I was in there: bumped the eye box to ~2× the original SVG size (which was sub-pixel at menu-bar resolution and effectively invisible even with the cutout fix). Now the three expressions are visually distinguishable:
  - **Idle** — short rectangular eyes
  - **Syncing** — horizontal slits (30 % of idle height)
  - **Active** — wider × taller eyes (35 % wider, 25 % taller than idle)

### Internal
- Removed the now-unused `NSBezierPath.fill(using:)` helper.
- `createMenuBarIcon` ends with a single `path.fill()` call (down from three: body + two eye overpaints) — cheaper draw, fewer state changes.

---

## [1.5.1] — 2026-06-15

### Fixed
- **v1.5.0's "Claude active" face never lit up in practice.** The detection looked at `~/.claude-status.json`'s mtime, but that file is only written by users who have configured a status-line script — most don't. A quick check on a fresh system: Claude Code had 4 processes running, but the status file was 62 days stale. The widget now spawns `pgrep -x claude` every 10 s instead, which directly reflects whether the CLI binary is alive. Verified live via the new `activity` log channel:

      log stream --predicate 'subsystem == "com.innohi.claudeusagewidget" AND category == "activity"'

  emits `pgrep claude → ACTIVE` / `pgrep claude → idle` on every poll.

### Added
- **Settings → General → "Animated menu-bar face"** toggle. When off, the static idle dots are used regardless of state — useful if the 0.25 s sync blink is distracting. Default: on.

### Internal
- pgrep runs on a `.utility` background queue; the result hops to main before mutating `claudeActivelyRunning`. The polling interval is bumped 5 s → 10 s since "Claude is running" doesn't flip faster than that anyway.

---

## [1.5.0] — 2026-06-15

### Added
- **Menu-bar face has three expressions** that swap based on what the widget knows about your machine:
  - **Idle (default)** — calm dots `●●` when nothing is happening.
  - **Syncing** — horizontal slits `−−` blinking every 0.25 s while a fetch is in flight (Reduce Motion turns the blink off; the slit shape stays).
  - **Active Claude** — wider, taller eyes `◉◉` when Claude Code itself is currently running on your machine.
- **Claude Code activity detection** — the widget polls `~/.claude-status.json`'s modification time every 5 s. If it was written within the last 30 s, Claude Code is treated as active and the icon switches to the alert face. Exposed via `UsageViewModel.claudeActivelyRunning` and surfaced to AppDelegate via a Combine sink.

### Internal
- `createMenuBarIcon(size:percent:expression:)` gains an `expression: IconExpression` parameter (`.idle / .syncing / .activeClaude`). The body silhouette is unchanged across expressions; only the two eye rectangles are re-sized and re-positioned.
- New `blinkTimer` in `AppDelegate` toggles the `.syncing` face every 250 ms; respects `accessibilityDisplayShouldReduceMotion` so it stops on a single slit frame for users with Reduce Motion on.
- New `claudeActivityTimer` in `UsageViewModel` (5 s repeat, main run-loop, `.common` mode).

---

## [1.4.3] — 2026-06-15

### Fixed
- **Race condition on the credential cache.** `keychainDeniedThisSession` and `cachedCredentials` were written from a URLSession background queue (when the API returned 401/403) while read on the main thread. A struct-copy interleaved with a write-to-nil could yield garbage. `invalidateCachedCredentials()` now `dispatchPrecondition`'s main-thread, and the 401/403 path hops to `DispatchQueue.main.async` before mutating.
- **Permanent "denied" lockout when the user enables "Always Allow" later.** If the user cancelled the first Keychain prompt and then approved it via System Settings, the `keychainDeniedThisSession` flag stayed `true` forever and the widget refused to retry. A **5-minute denial cooldown** is now applied — after 5 min the next sync retries the Keychain once (subsequent denials reset the timer).
- **NaN / Infinity in `expiresAt` could make a token appear permanently valid.** `isCachedTokenExpired` and `isOAuthTokenExpired` both gain an `isFinite` guard so a corrupted credentials file can no longer poison the cache silently — the server's 401/403 path will surface the real failure instead.
- **Whitespace-only `credentialPathOverride`** was accepted from the config file and resulted in silent I/O failure. `loadConfig` now trims with `.whitespacesAndNewlines` before checking emptiness.

### Added
- 13 new `TokenExpiryTests` covering seconds/milliseconds detection, NaN, Infinity, the exact `expiresAt` value reported by a real user (1781266616544), and the seconds-format scenario that pre-1.4.2 would have corrupted. **Total: 35 tests.**

### Internal
- Tightened the cache-state contract: all mutations to `cachedCredentials`, `keychainDeniedThisSession`, and `keychainDeniedAt` are now main-thread-only and enforced by `dispatchPrecondition(condition: .onQueue(.main))`.

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
