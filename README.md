# Claude Code Discord notifier (DEPRECATED)

This is a deprecated repo and will not be updated, just use Claude's discord plugin.

Discord notifications from [Claude Code](https://claude.com/claude-code) using hooks and webhooks. No bot, no token, nothing to host. There are three independent feeds and you can run any combination of them.

**Ping feed.** Sends a real @-mention, but only when Claude is actually blocked on you: a permission prompt, a question, an MCP elicitation, or the ~60 second idle signal. It's gated on `notification_type`, so routine turn-ends and informational notices don't reach you. The embed includes your official usage (5-hour and weekly percentages, from the same endpoint `/usage` reads) and the token cost of your last prompt.

**Activity feed.** A separate channel that never pings. It streams your prompts, subagents starting and finishing (task, model, tools used, result), `ultracode` workflow results, and Claude's messages. Every entry is tagged with the project directory, model, effort, and a timestamp.

**Usage tracker.** Posts a compact embed each time your official usage crosses a whole percent, on either the 5-hour or weekly window, so you can watch the limit climb. Silent for routine ticks. It @-mentions you when a window crosses 25, 50, 80, 90, or 100 percent, and when a window resets. Resets get their own message per window, with a distinct one for the case where Anthropic clears a limit early for everyone. It runs on `PostToolUse` and `Stop` but only posts on a real crossing or reset.

Two implementations, same behavior:

| Platform | Scripts | Runtime |
|---|---|---|
| Windows | [`windows/`](windows/) (`*.ps1`) | built-in Windows PowerShell 5.1 |
| macOS / Linux | [`macos-linux/`](macos-linux/) (`*.sh`) | `bash` + `curl` + `jq` |

There are no secrets in this repo. The scripts read your webhook URLs from local files (`~/.claude/discord_webhook.txt`, `~/.claude/discord_activity_webhook.txt`, `~/.claude/discord_usage_webhook.txt`) and never embed them. Treat those URLs like passwords.

## What you'll need

1. A Discord server channel. Not a DM, since pings only fire in servers you're a member of.
2. One or more webhooks (Channel > Edit > Integrations > Webhooks > New Webhook > Copy Webhook URL). Use separate channels if you want the chatty activity feed away from your pings.
3. Your numeric Discord user ID (User Settings > Advanced > Developer Mode on, then right-click your name > Copy User ID). Only the ping feed uses it.
4. On macOS/Linux, `jq` and `curl`. curl is usually already there; `brew install jq` or `sudo apt install jq` for the other.

## Setup

### 1. Copy the scripts to `~/.claude/`

On Windows, copy `windows\notify-discord.ps1`, `windows\notify-discord-activity.ps1`, and `windows\notify-discord-usage.ps1` into `%USERPROFILE%\.claude\`, or just run `.\deploy.ps1`.

On macOS/Linux, copy the three `macos-linux/notify-discord*.sh` files into `~/.claude/` and `chmod +x` them, or just run `bash deploy.sh`.

### 2. Save your webhook URLs

```bash
# macOS/Linux
printf '%s' 'PASTE_PING_WEBHOOK_URL'     > ~/.claude/discord_webhook.txt
printf '%s' 'PASTE_ACTIVITY_WEBHOOK_URL' > ~/.claude/discord_activity_webhook.txt   # optional
printf '%s' 'PASTE_USAGE_WEBHOOK_URL'    > ~/.claude/discord_usage_webhook.txt      # optional
```
```powershell
# Windows
'PASTE_PING_WEBHOOK_URL'     | Set-Content "$env:USERPROFILE\.claude\discord_webhook.txt" -NoNewline
'PASTE_ACTIVITY_WEBHOOK_URL' | Set-Content "$env:USERPROFILE\.claude\discord_activity_webhook.txt" -NoNewline
'PASTE_USAGE_WEBHOOK_URL'    | Set-Content "$env:USERPROFILE\.claude\discord_usage_webhook.txt" -NoNewline
```

All three files can point at the same webhook if you want everything in one channel.

### 3. Add the hooks to `settings.json`

Merge the `"hooks"` block from the matching `settings.example.json` ([windows](windows/settings.example.json) / [macos-linux](macos-linux/settings.example.json)) into `~/.claude/settings.json`, creating it if it doesn't exist. Replace `YOUR_DISCORD_USER_ID` with your ID. For the ping feed alone, include only the `Notification` hook.

### 4. Reload

Open the `/hooks` menu once, which reloads hook config, or restart Claude Code.

### 5. Test

```bash
# macOS/Linux
echo '{"message":"setup test"}' | bash ~/.claude/notify-discord.sh Notification YOUR_DISCORD_USER_ID
```
```powershell
# Windows
'{"message":"setup test"}' | & "$env:USERPROFILE\.claude\notify-discord.ps1" -Event Notification -UserId YOUR_DISCORD_USER_ID
```

## Activity feed events

| Event (hook) | Embed | Shows |
|---|---|---|
| `UserPromptSubmit` | Your prompt | your prompt text |
| `SubagentStart` | Agent started | task it was given, agent type, model |
| `SubagentStop` | Agent done | result, model, effort, tools used, parent workflow |
| `PostToolUse` (`Workflow`) | Workflow finished | consolidated workflow result |
| `MessageDisplay` | Claude | the assistant's reply text, model, effort |

Every embed carries the project directory on the author line and a dated timestamp in the footer. This feed makes no calls to the usage API at all. It's purely event data, so it never touches `api.anthropic.com`; the usage tracker is the only feed that reports usage percentages.

## Usage percentages (ping feed)

The ping embed shows real usage by calling `GET https://api.anthropic.com/api/oauth/usage`, the same endpoint the `/usage` command uses, with your locally stored OAuth token. On Linux and Windows that token comes from `~/.claude/.credentials.json`. On macOS it comes from the login Keychain via `security find-generic-password -s "Claude Code-credentials" -w`; if the usage line reads "live usage unavailable", check that the service name matches on your Mac.

This is an undocumented internal endpoint and may change between Claude Code versions. If it stops working the embed just omits usage and everything else keeps running. The token is only ever sent to `api.anthropic.com`.

## Usage tracker

The tracker fires on `PostToolUse` and `Stop`, reads the same usage endpoint as the ping feed, and posts only when `floor(utilization)` increases on the 5-hour or weekly window, so roughly once per percent. Each post shows a progress bar and both percentages; a step that jumps more than one percent renders as `old% -> new%`.

**API throttle.** `PostToolUse` fires on every tool call, so an unthrottled fetch would hit the usage API dozens of times per turn and risk rate limiting. The tracker calls the endpoint at most once every 5 minutes and reuses the cached snapshot in between, stored in `~/.claude/discord_usage_throttle.json` alongside the fetch time, both utilizations, and both reset times. Three consequences:

- Crossings and resets are detected at up-to-5-minute granularity. A turn that burns several percent between fetches still posts, rendered as `old% -> new%`, so nothing is lost, just batched.
- The throttle gates attempts, not just successes. The attempt time is stamped even on a failed or rate-limited fetch, so a `429` waits out the window instead of retrying on every tool call. Worst case is one request per 5 minutes, even during an outage.
- A manual reset can be reported up to ~5 minutes late. To make it snappier at the cost of more API calls, lower the `$ttl` / `TTL` value at the top of `notify-discord-usage.{ps1,sh}`.

**State.** The last posted whole percent and the reset times for each window live in `~/.claude/discord_usage_pct_state.json`. The first run only establishes a baseline and doesn't post.

**Resets.** When a window's usage drops below the stored value, that window has reset, and the tracker posts a separate pinged message per window (5-hour and weekly are never combined). A scheduled rollover is bright green. A reset Anthropic applies to everyone early, detected when usage drops while the previously known reset time is still in the future, is gold, so you know the moment limits get cleared for all users.

**Milestones.** Crossing into 25, 50, 80, 90, or 100 percent on either window @-mentions you via `-UserId`. The embed turns amber, or red at 100. Every other crossing posts silently. Edit the `$Milestones` / `MILESTONES` list at the top of the script to change them, or drop `-UserId` from both hook commands to make the feed silent entirely.

**Webhook.** Read from `~/.claude/discord_usage_webhook.txt`, which can point at the same channel as another feed.

## Customizing

- **Hard blocks only:** to ping only for permission prompts, questions, and elicitations, and skip the ~60 second idle signal, remove `idle_prompt` from the `Notification` `matcher` and from the script allowlist.
- **Idle delay:** `idle_prompt` fires after about 60 seconds; set `messageIdleNotifThresholdMs` in `settings.json` (default `60000`). It tracks main-thread idle, so a long background workflow can trigger it.
- **Ping feed only:** omit the activity hooks (`UserPromptSubmit`, `SubagentStart`, `SubagentStop`, `PostToolUse`, `MessageDisplay`).
- **One channel for everything:** point all the webhook files at the same URL.

## Known limits

These come from what Claude Code hooks expose, not from the scripts:

- The model's thinking is not exposed to any hook, so it can't be forwarded.
- Live workflow phase progress isn't exposed either. You get per-agent start/done events and the final workflow result, not phase-by-phase narration.
- Main-agent effort isn't in any payload. It's read from `settings.json` `effortLevel`, so it won't reflect a live `/effort` or fast-mode override.
- The `MessageDisplay` feed posts on every assistant message, which can get chatty.

## Troubleshooting

| Symptom | Fix |
|---|---|
| No message at all | Check the webhook file exists and has the right URL; run the test command in step 5. |
| Message posts but no ping | Wrong user ID, you're not in that server, or the webhook is a DM channel. |
| Hooks never fire | Reload via `/hooks` or restart; verify `settings.json` is valid JSON. |
| `jq: command not found` (macOS/Linux) | Install jq. |
| Usage shows "live usage unavailable" | Token expired between refreshes, or on macOS the Keychain service name differs. |

## License

MIT, see [LICENSE](LICENSE).
