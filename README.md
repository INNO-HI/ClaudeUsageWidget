<p align="center">
  <svg viewBox="0 0 24 24" width="64" height="64" xmlns="http://www.w3.org/2000/svg">
    <path clip-rule="evenodd" d="M20.998 10.949H24v3.102h-3v3.028h-1.487V20H18v-2.921h-1.487V20H15v-2.921H9V20H7.488v-2.921H6V20H4.487v-2.921H3V14.05H0V10.95h3V5h17.998v5.949zM6 10.949h1.488V8.102H6v2.847zm10.51 0H18V8.102h-1.49v2.847z" fill="#D97757" fill-rule="evenodd"/>
  </svg>
</p>

<h1 align="center">Claude Usage Widget</h1>

<p align="center">
  <strong>Track your Claude Code usage in real-time</strong><br>
  Glassmorphism desktop widget for macOS & Windows
</p>

<p align="center">
  <a href="https://inno-hi.github.io/ClaudeUsageWidget/">Homepage</a> ·
  <a href="https://github.com/INNO-HI/ClaudeUsageWidget/releases">Downloads</a> ·
  <a href="https://velog.io/@khwee2000/Claude-Code-%EC%82%AC%EC%9A%A9%EB%9F%89-%ED%99%95%EC%9D%B8%ED%95%98%EB%8B%A4%EA%B0%80-%EA%B2%B0%EA%B5%AD-%EC%A7%81%EC%A0%91-%EC%9C%84%EC%A0%AF-%EB%A7%8C%EB%93%A4%EC%96%B4%EB%B2%84%EB%A0%B8%EB%8B%A4">Blog</a> ·
  <a href="https://github.com/INNO-HI/ClaudeUsageWidget/issues">Issues</a>
</p>

---

## Features

- **Real-time Monitoring** — 5-hour session usage & 7-day weekly limits with a spring-animated session ring
- **Burn-rate ETA** — Predicts when you'll hit the session limit at current pace
- **7-day Sparkline** — Usage trend strip in the Weekly Limits card (history persisted locally)
- **Custom Alert Thresholds** — Two sliders replace the fixed 80% / 90%; the menu-bar icon pulses at the lower one
- **Rich Menu-Bar Tooltip** — Hover the icon for current %, ETA, weekly usage, and last sync without opening the popover
- **CSV / JSON Export** — Send your 7-day history to a spreadsheet or notebook (Settings → Data)
- **Multi-account** — Point the widget at a non-default `~/.claude/.credentials.json` to monitor a second account
- **Menu Bar Format** — Off / `%` / Time / Both (segmented picker)
- **3-step Onboarding** — Intro → `claude login` copy button → notifications opt-in
- **Friendly Error Banner** — Classified errors (credentials / rate-limit / network / server) with Retry & Open Terminal actions
- **Auto-Update via Sparkle** — One-click "Check for Updates" inside the app (macOS, EdDSA-signed)
- **Launch at Login** — Optional auto-start when you log in to macOS
- **Universal Binary** — Native on Apple Silicon and Intel Macs (macOS 13+)
- **Rate-Limit Safe** — ±10% jitter between syncs and 2×→16× exponential backoff on 429
- **Light & Dark Theme** — Off-white surface in light mode, dark surface in dark mode
- **에이투지체 (A2Z)** Typography — Clean Korean-optimised font system across the popover
- **4 Languages** — English · 한국어 · 日本語 · 中文 (switch instantly inside Settings)
- **Accessibility** — VoiceOver labels, ⌘R refresh, ⌘Q quit, ⌘, settings, system **Reduce Motion** honoured
- **Zero Token Cost** — Uses OAuth usage API only, no Claude messages sent
- **Auto Sync** — Configurable intervals: 1m / 5m / 10m / 30m / 1h / manual
- **Tested** — 22-test pure-logic suite (`swift test`) for ETA, sparkline, thresholds, formatting
- **CI/CD** — GitHub Actions for tests + auto build/sign/notarize/release/appcast on `v*-macos` tags
- **Claude Code Buddy** — Official terminal pet integration (18 species, 5 rarity tiers, ASCII art)
- **Cross Platform** — Native Swift on macOS, Node.js web widget on Windows & Linux

---

## Screenshots

<table>
  <tr>
    <td align="center"><strong>Web Widget</strong></td>
    <td align="center"><strong>macOS Desktop Widget</strong></td>
  </tr>
  <tr>
    <td><img src="screenshots/04-web-widget-clean.png" width="280" alt="Web Widget"/></td>
    <td><img src="screenshots/10-desktop-widget-crop.png" width="280" alt="Desktop Widget"/></td>
  </tr>
</table>

---

## Claude Code Buddy

The widget integrates the official [Claude Code Buddy](https://docs.anthropic.com/en/docs/claude-code) terminal pet system.

```
  /buddy        → Hatch your buddy
  /buddy pet    → Pet your buddy (mood +1)
  /buddy off    → Put buddy to sleep
```

**18 species** — Each buddy is deterministically generated from your account ID. You can't choose or reroll.

```
  Cat         Dragon        Duck          Ghost         Owl
 /\_/\       /\_/\_          __          .___.        {o,o}
( · · )     (  · · )       >(··)__     | · · |      /)___)
 > ^ <       \ ~~ /         (  __)>    |  o  |       " "
             /|  |\          ||         \^^^/
```

**5 rarity tiers** — Common (60%) · Uncommon (25%) · Rare (10%) · Epic (4%) · Legendary (1%)

**5 stats** — DEBUGGING · PATIENCE · CHAOS · WISDOM · SNARK

**1% Shiny** variant with sparkle effects

---

## Installation

### macOS (Native App)

> Requires macOS 13.0+ · Apple Silicon & Intel (Universal Binary)

**Download** the latest signed & notarized DMG from [Releases](https://github.com/INNO-HI/ClaudeUsageWidget/releases), drag the app to `/Applications`, and launch.

> ✅ Signed with `Developer ID Application: INNO-HI Inc.` and notarized by Apple.
> Future updates ship via in-app **Settings → Check for Updates** (Sparkle).

Or build from source (requires an Apple Developer account for full signing):

```bash
git clone https://github.com/INNO-HI/ClaudeUsageWidget.git
cd ClaudeUsageWidget/macos
bash build.sh
open "build/Claude Usage Widget.app"
```

> The macOS Swift source lives under [`macos/`](macos/). Sparkle 2.x is vendored at `macos/vendor/Sparkle.framework`.

### Windows / Linux (Cross-platform)

> Requires Node.js 18+

```bash
git clone https://github.com/INNO-HI/ClaudeUsageWidget.git
cd ClaudeUsageWidget
node src/server.js
```

Opens automatically at `http://127.0.0.1:19522`.

---

## Prerequisites

1. Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
2. Run `claude login` in your terminal
3. Launch the widget

Credentials are read from `~/.claude/.credentials.json` (or macOS Keychain).

---

## How It Works

```
┌─────────────┐     OAuth Token     ┌──────────────────────┐
│  Widget App  │ ──────────────────► │  Anthropic Usage API │
│  (local)     │ ◄────────────────── │  /api/oauth/usage    │
└─────────────┘    Usage Data (%)    └──────────────────────┘
       │
       ▼
   ~/.claude-usage-widget-history.json   (7-day rolling, exportable)
```

• Reads OAuth credentials from `~/.claude/.credentials.json` (or any user-picked JSON for multi-account use)
• Calls `GET https://api.anthropic.com/api/oauth/usage`
• Auto-refreshes expired tokens; ±10% jitter + 2×→16× exponential backoff on 429
• Stores each successful sync as a 7-day rolling history file used by the **Sparkline** and **Burn-rate ETA**
• No messages sent to Claude → zero token cost

---

## Configuration

All settings live behind the gear icon in the popover.

| Setting | Options | Default |
|---------|---------|---------|
| Language | English · 한국어 · 日本語 · 中文 | English |
| Credentials file | `~/.claude/.credentials.json` (default) or any user-picked JSON | default |
| Auto-sync | manual / 1m / 5m / 10m / 30m / 1h | 5m |
| Launch at Login | on / off | off |
| Menu Bar Text | Off / % / Time / Both | % |
| Compact mode | on / off | off |
| Keep on Top | on / off | off |
| Show Buddy | on / off | on |
| Usage Alerts | on / off | off |
| Alert thresholds (1st / 2nd) | 50–95% / 60–99% sliders | 80% / 90% |
| Data export | CSV · JSON · Clear history | — |
| Check for Updates | one-click (Sparkle) | — |
| Buddy commands | /buddy · /buddy pet · /buddy feed · /buddy off | off |

---

## Troubleshooting

### "Claude Widget is damaged and can't be opened. You should move it to the Trash."
This is macOS Gatekeeper rejecting a quarantined file whose Developer ID signature didn't survive the download (a known issue with some browsers and older builds — see [#1](https://github.com/INNO-HI/ClaudeUsageWidget/issues/1)). The current release is **signed (Developer ID) and notarized**, but if you still hit the message:

1. Move the app to `/Applications` first (don't open from the DMG).
2. Strip the quarantine attribute:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Claude Usage Widget.app"
   ```

3. Re-launch — you may be asked once for permission, then it stays approved.

If that still fails, the download was likely corrupted — re-download from [Releases](https://github.com/INNO-HI/ClaudeUsageWidget/releases) and verify the DMG size matches the release listing.

### Widget shows `--` or `Token expired`
Your Claude Code OAuth token has expired. Run in Terminal:

```bash
claude login
```

Then click **Refresh** in the widget settings.

### Launch at Login isn't sticking
macOS may have queued a permission prompt under **System Settings → General → Login Items**. Enable the entry there, or toggle the option off/on inside the widget.

### No notifications appearing
First time you enable **Usage Alerts**, macOS asks for notification permission. If you missed it: **System Settings → Notifications → Claude Usage Widget → Allow Notifications**.

### "Check for Updates" says nothing happens
You're already on the latest version. Sparkle silently confirms when you're up to date.

---

## Change Log

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

### v1.6.2 (latest)
- **Dynamic model pools** — a Weekly Limits row appears for any `seven_day_<model>` the API returns (Fable/Mythos-ready, no update needed)

### v1.6.1
- **Motion system 2.0** — natural idle blink · floating sleep-z + breathing · typing-burst work rhythm · wake-up pop · happy hop on sync success. Still 0% CPU, % text pinned, Reduce Motion respected

### v1.6.0
- **36 improvements**: Opus weekly pool row · session-reset notifications · copy usage summary (⌘⇧C) · menu-bar metric picker · working "Keep on Top" · big performance pass (launch writes, file I/O off main, icon cache, event-driven subprocess waits) · full 4-language tooltips/VoiceOver · monospaced menu-bar digits · icon-only animation (the % text no longer moves)
- 9 pre-release defects caught by adversarial review, including a settings-loss regression for upgrading users

### v1.5.6
- Fixed **~20% constant CPU usage** — wobble/pulse/bounce moved from main-thread Timers to Core Animation (render server). Measured 20%+ → 0.0%

### v1.5.5
- Smaller **idle dots** (calm resting face) and matched menu-bar silhouette to popover icon
- Merged Claude activity into a **single `@Published` enum** (no more idle flicker during ACTIVE↔SLEEPING)
- **5-second subprocess timeout** + reentrancy guard so ticks can't stack on slow filesystems
- VoiceOver + tooltip surface the current Claude activity state
- 5 new regression tests (40 total)

### v1.5.4
- Added **sleeping face** (closed eyes + z) when Claude is running but no recent session activity
- "Active" now means real work — `~/.claude/projects/` file modified in last 60s, not just process exists
- Fixes the v1.5.3 UX where VS Code Claude Code kept the icon in active state forever

### v1.5.3
- Added **Wobble Shake** motion — menu-bar icon vibrates ±1.5 px side-to-side at ~3 Hz when Claude Code is actively running ("working hard" signal)
- **Eyes switched to solid white** rectangles instead of transparent cutouts (which revealed the wallpaper through the menu bar)

### v1.5.2
- Fixed **eyes were invisible** on the menu-bar icon — `NSColor.clear` doesn't actually carve through, so the body stayed solid. Now uses `windingRule=.evenOdd` to produce real transparent cutouts. Eye box doubled for visibility at 18×18

### v1.5.1
- Fixed **the "Claude active" face that never lit up** — v1.5.0 watched `~/.claude-status.json` mtime which only updates if you've configured a status-line script. Now uses `pgrep -x claude` every 10 s, which directly reflects whether the CLI binary is alive
- Added **Settings → "Animated menu-bar face"** toggle to disable the syncing blink if it's distracting

### v1.5.0
- Added **3-expression menu-bar face** — idle dots (●●), blinking slits (−−) while syncing, wide alert eyes (◉◉) while Claude Code is actively running
- Claude activity detected via `~/.claude-status.json` mtime (writes within last 30 s = active)
- All eye animation honours the system **Reduce Motion** setting

### v1.4.3
- Fixed **thread-race on the credential cache** (URLSession bg ↔ main thread mutation)
- Added **5-minute denial cooldown** so Keychain "Always Allow" applied after the first prompt is picked up without restarting
- Defended `isCachedTokenExpired` against **NaN / Infinity** in corrupted credential files
- Trim whitespace from `credentialPathOverride` before using it as a file path
- Added 13 regression tests (total 35) covering ms/sec detection, NaN, Infinity, and the exact user-reported `expiresAt` value

### v1.4.2
- Fixed **`expiresAt` unit mismatch** that re-prompted the Keychain on every sync when Claude Code stored the value in milliseconds — the cache check now auto-detects ms vs seconds
- Added **unified-logging diagnostics** under subsystem `com.innohi.claudeusagewidget` / category `creds` so users can verify themselves when the Keychain is actually queried

### v1.4.1
- Fixed **repeated macOS Keychain access prompts** — credentials are now cached in memory between syncs; the Keychain is only queried again when the token actually expires, the server returns 401/403, or the user explicitly hits Refresh

### v1.4.0
- Added **CSV / JSON export** of usage history (Settings → Data) + Clear history
- Added **Multi-account credential path** — point the widget at a non-default credentials file
- Added **Rich menu-bar tooltip** — hover the icon for current %, ETA, weekly %, last sync
- Added **GitHub Actions** CI for tests + release automation (auto build/sign/notarize/DMG/appcast on tag push)
- Added **Mac App Store submission scaffolding** — entitlements + dual-build guide
- Added **22-test unit suite** (`swift test`) for pure logic (ETA, sparkline, thresholds, formatting)
- Added **Homebrew Cask submission guide**

### v1.3.0
- Added **Custom alert thresholds** — two sliders replace fixed 80/90%
- Added **3-step onboarding** with `claude login` copy button + notifications opt-in
- Added **Friendly error banner** (credentials / rate-limit / network / server) with Retry & Open Terminal
- Added **Japanese (日本語) and Simplified Chinese (中文)** localisation — picker now EN / KO / JA / ZH
- Pulse + ring glow now follow the user's lower notification threshold
- Internal refactor: `Theme.swift`, `BuddyViews.swift`, `OnboardingView.swift` split out

### v1.2.0
- Added **Burn-rate ETA** — predicts when the session limit will be hit
- Added **7-day Sparkline** trend in the Weekly Limits card
- Added **Menu Bar Text format** — Off / `%` / Time / Both
- Added **Warning pulse** — menu bar icon breathes at ≥80%, session ring gets a soft glow halo
- Added **Skeleton loading** + spring-animated session ring
- Refreshed **Onboarding** with animated ring hero and gradient CTA
- New **에이투지체 (A2Z) typography** across the popover, wider 400 px layout, larger ring & progress bars
- Switched popover background from glassmorphism blur to solid off-white / dark surface
- Added **accessibility labels**, `⌘Q` quit shortcut, system **Reduce Motion** support
- Fixed deprecated `NSWorkspace.launchApplication` and stale footer version label

### v1.1.0
- Added **Sparkle auto-update** (signed via EdDSA)
- Added **Launch at Login** option
- Added **Mini / Full mode** toggle (hide menu-bar %)
- Added **Usage Alerts** (80% / 90% session thresholds)
- Added **Universal Binary** (Intel + Apple Silicon)
- Added **API rate-limit safety** — ±10% jitter and 2×→16× exponential backoff on 429
- Build pipeline now produces signed & notarized DMG

### v1.0.0
- Initial public release with menu-bar widget, glassmorphism UI, OAuth-based usage monitoring

---

## Tech Stack

| Platform | Stack |
|----------|-------|
| macOS (native) | Swift 5.9, SwiftUI, AppKit, ServiceManagement, UserNotifications, Security (Keychain), [Sparkle 2.x](https://sparkle-project.org/) |
| Pure logic library | Swift Package (`macos/Package.swift`) — testable on any platform |
| Cross-platform | Node.js, HTML/CSS/JS |
| CI | GitHub Actions: `swift test` on every push/PR, build/sign/notarize/release on `v*-macos` tags |

---

## Development

```bash
# Run the test suite (22 tests covering ETA, sparkline, thresholds, formatting)
cd macos
swift test

# Build a local unsigned .app for development
SKIP_SIGN=1 ./build.sh
open "build/Claude Usage Widget.app"

# Full signed + notarized release build (needs Developer ID identity + notary profile)
./build.sh
```

See:
- [`macos/MAS-SUBMISSION.md`](macos/MAS-SUBMISSION.md) — Mac App Store submission roadmap
- [`macos/HOMEBREW-PR-GUIDE.md`](macos/HOMEBREW-PR-GUIDE.md) — Homebrew Cask submission instructions
- [`.github/workflows/release-macos.yml`](.github/workflows/release-macos.yml) — required CI secrets

---

## License

MIT

---

<p align="center">
  Built with ♥ for Claude Code users
</p>
