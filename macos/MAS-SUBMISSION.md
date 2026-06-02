# Mac App Store submission guide — Claude Usage Widget

This document captures the steps required to ship the widget through the Mac App Store. The Developer-ID DMG distribution (`build.sh`) is unaffected and continues to work in parallel.

> Why two channels? MAS apps must run inside the App Sandbox and update through the store, which conflicts with Sparkle. We keep both — the same source compiles to either target via different build flags.

## 1. Bundle ID & App Store Connect

| | Developer-ID build | MAS build |
|---|---|---|
| Bundle ID | `com.innohi.claudeusagewidget` | `com.innohi.claudeusagewidget.mas` |
| Category | Productivity | Productivity |
| Provisioning profile | n/a (notarization) | App Store profile generated from App Store Connect |

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com).
2. **My Apps → +** → New macOS app with Bundle ID `com.innohi.claudeusagewidget.mas`.
3. Set SKU `claude-usage-widget-mas`, category `Productivity`.
4. Fill in privacy disclosures — the widget only sends OAuth-authenticated requests to `api.anthropic.com`. No analytics, no third-party SDKs.

## 2. Sandbox-compatible source changes

The current code reads `~/.claude/.credentials.json` directly. Sandbox forbids that path. v1.4.0 already introduces the `credentialPathOverride` setting and an `NSOpenPanel`. For MAS:

- The first-run onboarding **must** show the file picker (Sandbox grants the bookmark, not the path).
- Persist the resulting URL as a *security-scoped bookmark* in `UserDefaults` (`url.bookmarkData(options: .withSecurityScope)`).
- On every launch, resolve the bookmark before reading credentials and call `url.startAccessingSecurityScopedResource()`. Release at app exit.

The Onboarding `loginPage` already documents `claude login`; we'll add a fourth pre-onboarding step on the MAS build that runs the picker and explains why.

## 3. Entitlements

The MAS-specific entitlements file lives at `Resources/entitlements/Sandbox-MAS.entitlements`:

```xml
com.apple.security.app-sandbox            = YES
com.apple.security.network.client         = YES
com.apple.security.files.user-selected.read-only = YES
```

For Developer-ID builds keep the existing empty `<dict/>` entitlements (build.sh already writes it).

## 4. Build script branching

Two new env vars on `build.sh`:

```bash
MAS_BUILD=1                 # switches Bundle ID, entitlements, drops Sparkle
APP_STORE_PROFILE="…path…"  # path to the .provisionprofile downloaded from ASC
```

When `MAS_BUILD=1`:

- Skip the `Sparkle.framework` copy step.
- Use `Resources/entitlements/Sandbox-MAS.entitlements`.
- Sign with **3rd Party Mac Developer Application: INNO-HI Inc. (4AL4PF4BK4)** (separate identity from Developer ID).
- After signing, run `productbuild --component …` to produce a `.pkg` instead of `.dmg`.
- Submit with `xcrun altool --upload-app -f ClaudeUsageWidget.pkg`.

## 5. App Store review notes

Reviewers don't have Claude Code installed. Provide:

- A short text in the **Notes** field: *"This widget reads an OAuth token from a file that Claude Code (CLI) creates after `claude login`. Reviewers can test the UI flow without signing in — the widget will simply show the 'Not logged in' state."*
- A demo screenshot of the popover in disconnected state.

## 6. Differences sticky-note

| Feature | Developer-ID | MAS |
|---|---|---|
| Auto-update | Sparkle | App Store |
| Credential read | direct file | bookmark via NSOpenPanel |
| Bundle ID | `com.innohi.claudeusagewidget` | `com.innohi.claudeusagewidget.mas` |
| Distribution artefact | DMG | PKG |
| Update channel | `appcast.xml` | App Store servers |

## 7. Timeline estimate

- Sandbox migration code (bookmark logic + onboarding update): **~1 day**
- ASC + provisioning + first submission: **~0.5 day**
- Review wait (Apple): **1–7 days**

## 8. Open questions

- Pricing: free or paid? Currently distributed free on GitHub.
- Subscription? The widget calls Anthropic's API on the user's quota — no recurring revenue to back a subscription.
- Whether to retire the Developer-ID DMG once MAS ships, or keep both as the README suggests.

— Last updated: 2026-06-02
