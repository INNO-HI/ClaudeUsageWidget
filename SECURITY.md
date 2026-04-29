# Security Policy

## Supported Versions

Only the latest minor release receives security fixes.

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :x:                |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not file a public issue for security vulnerabilities.**

Instead, report privately to **board@innohi.ai.kr** with the subject `[SECURITY] Claude Usage Widget`.

Include:
- A description of the vulnerability
- Steps to reproduce
- The version(s) affected
- Any proof-of-concept code (if applicable)
- Your name/handle for credit (optional)

We will:
1. Acknowledge receipt within **3 business days**
2. Confirm or dispute the issue within **7 business days**
3. Issue a patched release as soon as practical (typically within 30 days for high-severity issues)
4. Credit the reporter in the release notes (unless they prefer to remain anonymous)

## Out of Scope

- Issues in dependencies (please report upstream)
- Bugs that require physical access to the user's unlocked Mac
- Social engineering attacks against the maintainer
- Theoretical risks without a working PoC

## Threat Model

This widget reads OAuth credentials from `~/.claude/.credentials.json` (created by Claude Code itself) and queries `https://api.anthropic.com/api/oauth/usage`. It does **not**:

- Send messages to Claude (zero token cost)
- Transmit data to any third party
- Persist credentials beyond the file Claude Code already maintains
- Run any privileged operations (no `sudo`, no system file modification)

The auto-update mechanism uses **Sparkle 2.x with EdDSA signature verification** — updates are cryptographically verified before installation.
