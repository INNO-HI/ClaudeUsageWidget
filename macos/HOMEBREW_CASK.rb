# Draft Homebrew Cask formula for Claude Usage Widget.
#
# To submit:
#   1. Fork https://github.com/Homebrew/homebrew-cask
#   2. Place this file at: Casks/c/claude-usage-widget.rb
#      (Homebrew Cask uses a 2-letter sharding scheme — "c" for names starting with c)
#   3. Update version, sha256, and url to match the latest GitHub Release
#   4. Test locally:
#        brew install --cask --no-quarantine ./claude-usage-widget.rb
#        brew uninstall --cask claude-usage-widget
#   5. Open a PR with the title:  "Add Claude Usage Widget"
#   6. Wait for review (typically 1–3 days)
#
# After acceptance, users can install with:
#   brew install --cask claude-usage-widget
#
# Update procedure for new versions:
#   - PR to homebrew-cask updating `version` and `sha256`
#   - OR set up a GitHub Action that auto-PRs on each tag (see actions/cask-updater)

cask "claude-usage-widget" do
  version "1.5.6"
  sha256 "e9850b26d94ed52bbc3c73ec396992c5798cbb843437a161496fed4f8f424ecc"

  url "https://github.com/INNO-HI/ClaudeUsageWidget/releases/download/v#{version}-macos/ClaudeUsageWidget.dmg",
      verified: "github.com/INNO-HI/ClaudeUsageWidget/"
  name "Claude Usage Widget"
  desc "Menu-bar widget showing real-time Claude Code usage"
  homepage "https://inno-hi.github.io/ClaudeUsageWidget/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Claude Usage Widget.app"

  zap trash: [
    "~/.claude-usage-widget-config.json",
    "~/.claude-usage-widget-history.json",  # 7-day sparkline history (v1.2.0+)
    "~/.claude-monitor-config.json",        # legacy pre-1.1.0 path
    "~/Library/Preferences/com.innohi.claudeusagewidget.plist",
    "~/Library/Caches/com.innohi.claudeusagewidget",
  ]
end
