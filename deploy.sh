#!/usr/bin/env bash
# deploy.sh -- copy the macOS/Linux hook scripts from this repo into ~/.claude so they run live.
# Run after editing macos-linux/*.sh here, to make your changes take effect in Claude Code.
set -e
dir="$(cd "$(dirname "$0")" && pwd)"
cp "$dir/macos-linux/notify-discord.sh"          "$HOME/.claude/"
cp "$dir/macos-linux/notify-discord-activity.sh" "$HOME/.claude/"
cp "$dir/macos-linux/notify-discord-usage.sh"    "$HOME/.claude/"
chmod +x "$HOME/.claude/notify-discord.sh" "$HOME/.claude/notify-discord-activity.sh" "$HOME/.claude/notify-discord-usage.sh"
echo "Deployed macOS/Linux scripts to $HOME/.claude/  (open /hooks once or restart Claude Code to reload)"
