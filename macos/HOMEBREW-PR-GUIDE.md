# Homebrew Cask submission guide

This document walks through publishing the widget to the official `homebrew-cask` tap so users can `brew install --cask claude-usage-widget`.

## Files involved

- `macos/HOMEBREW_CASK.rb` — the cask formula (current `version` and `sha256` updated automatically by `build.sh`'s SHA stamp).
- `macos/HOMEBREW-PR-GUIDE.md` — this file (instructions only).

## Pre-flight checks

Before opening a PR, **always** test the cask locally:

```bash
# From this repo's root
brew install --cask --no-quarantine macos/HOMEBREW_CASK.rb

# Verify the app launched (menu bar icon visible)
ls /Applications/"Claude Usage Widget.app"

# Audit the cask the same way Homebrew CI will
brew audit --strict --online --cask macos/HOMEBREW_CASK.rb
brew style --fix --cask macos/HOMEBREW_CASK.rb

# Uninstall when done
brew uninstall --cask claude-usage-widget
```

If any audit step fails, fix the cask before submitting — Homebrew's CI runs the same checks and will reject the PR otherwise.

## Submitting the PR

1. **Fork** [Homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask).
2. Clone your fork and create a topic branch:

   ```bash
   git clone https://github.com/<your-handle>/homebrew-cask
   cd homebrew-cask
   git checkout -b add-claude-usage-widget
   ```

3. Copy the cask file into the sharded path (the directory name is the first letter of the cask name):

   ```bash
   cp /path/to/ClaudeUsageWidget-Cross/macos/HOMEBREW_CASK.rb Casks/c/claude-usage-widget.rb
   ```

4. Commit using Homebrew's preferred message style:

   ```bash
   git add Casks/c/claude-usage-widget.rb
   git commit -m "Add Claude Usage Widget"
   git push origin add-claude-usage-widget
   ```

5. Open the PR against `Homebrew/homebrew-cask:master`. Title and body:

   **Title**: `Add Claude Usage Widget`

   **Body** (paste the template below):

   ```markdown
   - [x] Have you followed the [guidelines for contributing](https://docs.brew.sh/Cask-Cookbook)?
   - [x] Have you checked that there aren't other open [pull requests](https://github.com/Homebrew/homebrew-cask/pulls) for the same change?
   - [x] Have you typed `brew audit --strict --online --cask Casks/c/claude-usage-widget.rb`?
   - [x] Have you typed `brew style --fix --cask Casks/c/claude-usage-widget.rb`?
   - [x] Have you tested your cask with `brew install --cask ./Casks/c/claude-usage-widget.rb`?

   ### About this cask

   Claude Usage Widget is a free, MIT-licensed macOS menu bar app that surfaces
   Claude Code's current session usage (the 5-hour rolling window) and weekly
   limits in real time. The app is built natively in Swift, ships as a
   Universal Binary, and is **signed (Developer ID Application: INNO-HI Inc.)
   and notarized**. Auto-updates ship via Sparkle 2.

   Homepage: https://inno-hi.github.io/ClaudeUsageWidget/
   Source:   https://github.com/INNO-HI/ClaudeUsageWidget
   License:  MIT
   ```

6. Wait for review. Homebrew's bots will run `brew audit` and `brew style`; a maintainer typically reviews within 24–72 h.

7. Once merged, users can install with:

   ```bash
   brew install --cask claude-usage-widget
   brew upgrade --cask claude-usage-widget
   ```

## Updating the cask on each release

Two options:

### A. Manual

After each notarized release, open a new PR in your fork that bumps `version` and `sha256` to the new DMG. The CI workflow at `.github/workflows/release-macos.yml` prints the new SHA in its logs.

### B. Automated (recommended once stable)

Set up an Action that opens the PR for you on every `v*-macos` tag:

```yaml
# .github/workflows/homebrew-cask-bump.yml
name: Bump Homebrew Cask
on:
  release:
    types: [published]
jobs:
  bump:
    runs-on: macos-latest
    steps:
      - uses: macauley/action-homebrew-bump-cask@v1
        with:
          token: ${{ secrets.HOMEBREW_PAT }}
          tap: homebrew/cask
          cask: claude-usage-widget
          tag: ${{ github.event.release.tag_name }}
```

The action computes the new SHA, opens a PR against `Homebrew/homebrew-cask`, and tags you for review.

## Notes / gotchas

- The cask name must be lowercase, kebab-cased: `claude-usage-widget`. Match this in the `.rb` filename.
- Pre-1.1.0 builds used a different Bundle ID (`com.innohi.claudemonitor`). The `zap trash` block already handles both for clean removal.
- Sparkle's auto-update will silently win the race against `brew upgrade`. That's fine — `auto_updates true` in the cask tells Homebrew not to fight it.
- If you ever ship to MAS as well, the cask should keep pointing at the Developer-ID DMG (Homebrew won't install MAS builds).
