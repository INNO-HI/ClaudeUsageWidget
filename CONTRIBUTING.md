# Contributing to Claude Usage Widget

Thanks for your interest in contributing! This document covers how to file issues, propose features, and submit pull requests.

---

## Before You Open an Issue

1. **Search [existing issues](https://github.com/INNO-HI/ClaudeUsageWidget/issues?q=is%3Aissue)** to avoid duplicates.
2. **Check the [Troubleshooting section in README](README.md#troubleshooting)** — most install problems are answered there.
3. If you're on the unsigned older build, the "damaged" Gatekeeper error is fixed by upgrading to v1.1.0+.

---

## Filing a Bug Report

Use the **Bug Report** issue template and include:

- macOS version (e.g. 14.4.1) and Mac model (`About This Mac`)
- App version (Settings → About, or right-click `Claude Usage Widget.app` → Info)
- Steps to reproduce
- Expected vs. actual behavior
- Console logs if available: open **Console.app**, filter by `ClaudeUsageWidget`, copy relevant lines

---

## Proposing a Feature

Use the **Feature Request** issue template and explain:

- The problem you're trying to solve (not just the proposed solution)
- Why existing options don't fit
- Mockups, screenshots, or examples from other apps if helpful

We prioritize features that:
- Reduce user friction (e.g. better defaults, clearer errors)
- Fit the menu-bar widget paradigm (lightweight, glanceable)
- Don't introduce token cost or send messages to Claude

---

## Submitting a Pull Request

1. **Open an issue first** for non-trivial changes so we can align on approach.
2. Fork the repo and create a feature branch.
3. Keep the PR focused — one logical change per PR.
4. Update [CHANGELOG.md](CHANGELOG.md) under an `[Unreleased]` section.
5. For macOS code changes, ensure `bash build.sh` succeeds locally with signing.
6. Open the PR with a clear description, screenshots/GIFs for UI changes, and reference the issue.

---

## Code Style

- **Swift**: Follow the patterns already in `Sources/`. SwiftUI for views, Combine for reactive state.
- **JS/Node** (Cross-platform widget): Plain ES modules, no frameworks beyond what's in `package.json`.
- **Keep functions small**, name things clearly, prefer direct code over heavy abstractions.

---

## Questions?

Open a [GitHub Discussion](https://github.com/INNO-HI/ClaudeUsageWidget/discussions) for design questions or general help. Keep the issue tracker for bugs and concrete feature proposals.

---

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).
