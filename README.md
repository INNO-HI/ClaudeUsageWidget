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

- **Real-time Monitoring** — 5-hour session usage & 7-day weekly limits
- **Glassmorphism UI** — Frosted glass design with smooth animations
- **Zero Token Cost** — Uses OAuth usage API only, no Claude messages sent
- **Auto Sync** — Configurable intervals: 5m / 10m / 30m / 1h / manual
- **Claude Code Buddy** — Official terminal pet system integrated (18 species, 5 rarity tiers, ASCII art)
- **Cross Platform** — Native Swift on macOS, Node.js web widget on Windows & Linux
- **Bilingual** — English / 한국어

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

> Requires macOS 13.0+

**Download** from [Releases](https://github.com/INNO-HI/ClaudeUsageWidget/releases) or build from source:

```bash
git clone https://github.com/INNO-HI/ClaudeUsageWidget.git
cd ClaudeUsageWidget
bash build.sh
open "build/Claude Widget.app"
```

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

• Reads OAuth credentials from ~/.claude/.credentials.json
• Calls GET https://api.anthropic.com/api/oauth/usage
• Auto-refreshes expired tokens
• No messages sent to Claude = zero token cost
```

---

## Configuration

| Setting | Options | Default |
|---------|---------|---------|
| Auto-sync | manual / 5m / 10m / 30m / 1h | 5m |
| Language | English / 한국어 | English |
| Buddy | /buddy · /buddy pet · /buddy off | off |

---

## Tech Stack

| Platform | Stack |
|----------|-------|
| macOS (native) | Swift, SwiftUI, AppKit, Security (Keychain) |
| Cross-platform | Node.js, HTML/CSS/JS |

---

## License

MIT

---

<p align="center">
  Built with ♥ for Claude Code users
</p>
