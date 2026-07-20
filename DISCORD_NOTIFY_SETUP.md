# Setup notes

The [README](README.md) covers installing all three feeds. This file goes into the details that don't fit there: how the hook wiring works, where to scope it, and what to check when something misbehaves.

## Creating the webhook

Open the Discord server channel you want the notifications in. It has to be a server channel, not a DM, because mentions only push a notification in servers you're a member of. Click the gear next to the channel, then Edit Channel > Integrations > Webhooks > New Webhook. Name it something like "Claude Waiting" and click Copy Webhook URL.

The URL looks like `https://discord.com/api/webhooks/123456.../AbCdEf...`. Treat it like a password. Anyone holding it can post to your channel, so don't paste it into public chats or commit it anywhere. If one leaks, delete the webhook in Discord, create a new one, and overwrite the file in `~/.claude/`. Nothing else needs to change.

## Getting your user ID

A plain message won't push a phone or desktop notification, but an @-mention will, and that needs your numeric user ID. Turn on Developer Mode under User Settings > Advanced, then right-click your own name anywhere and pick Copy User ID. You'll get a number like `291428797595516928`.

If you'd rather not be hard-pinged for a given feed, leave the user ID off that hook. The message still posts, it just won't notify.

## Why there's no Stop hook on the ping feed

Stop fires at the end of every turn, including phase boundaries and background workflow steps, so wiring it up means getting pinged when Claude isn't waiting on anything, and double-pinged whenever a real "needs input" Notification lands at the same time. Only the `Notification` event actually means Claude needs you.

The `matcher` narrows that further to the `notification_type` values that mean Claude is genuinely blocked: tool permission prompts, MCP elicitation dialogs, and the idle "waiting for your input" prompt. Informational types (`auth_success`, `elicitation_complete`, `elicitation_response`, `computer_use_*`, `push_notification`) are deliberately dropped. To get pings only for hard blocks, drop `idle_prompt` from the matcher.

The usage tracker does use `Stop`, for a different reason: it's a cheap place to catch a usage crossing at the end of a turn. It posts nothing unless the percentage actually moved.

## Activating hooks

Editing `settings.json` while Claude Code is running doesn't take effect immediately. Either open the `/hooks` menu once, which reloads hook config, or restart Claude Code.

After that it's automatic. Claude Code only surfaces a "Ran N hooks" line when a hook errors or runs slowly, so seeing nothing in the UI is the expected result on success.

## User-level vs project-level

The README installs everything at the user level in `~/.claude/settings.json`, so the hooks fire in every project on that machine. That's the simplest setup for personal use.

You can scope the hooks to a single project instead, which is useful if you only want notifications for one repo or want to share the setup with a team.

| File | User level | Project level |
|---|---|---|
| Hooks (`settings.json`) | `~/.claude/settings.json` | `<project>/.claude/settings.json` (shared, committed) or `<project>/.claude/settings.local.json` (personal, git-ignored) |
| Notifier scripts | `~/.claude/notify-discord*.{sh,ps1}` | Keep them in `~/.claude/` and reference by absolute path |
| Webhook URLs | `~/.claude/discord_*_webhook.txt` | Keep in `~/.claude/`. Never commit a webhook URL |

The hook commands are identical either way, since they already point at `$HOME/.claude/...` or `$env:USERPROFILE\.claude\...`. Only the `hooks` block moves.

To scope to one project: remove the `"hooks"` block from `~/.claude/settings.json`, put the same block in `<project>/.claude/settings.json`, and leave the scripts and webhook files where they are.

One thing to watch: settings layer user > project > local, but hooks don't override each other, they stack. Keeping hooks at the user level *and* adding them in a project gives you two notifications per event inside that project. Pick one scope.

## Sharing with a team

A committed `<project>/.claude/settings.json` reaches everyone who clones the repo, which works for a team that all wants notifications, with two caveats.

Each teammate has a different Discord user ID, so a hardcoded one would ping you for their turns. Either drop the user ID from the committed hook so messages post without pinging anyone, or have each person override it in their own git-ignored `settings.local.json`.

Everyone still has to do the per-machine steps themselves: install the scripts and create their own webhook files, since neither is committed.

## Turning it off

Set `"disableAllHooks": true` in `settings.json`, or delete the `"hooks"` block.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No message at all | Webhook file missing, empty, or holding the wrong URL. Test the script directly first. |
| Message posts but no ping | Wrong user ID, you're not a member of that server, or the webhook points at a DM channel. |
| PowerShell errors about unexpected tokens | The `.ps1` got saved with literal emoji in a non-UTF-8 encoding. Re-copy from `windows/`; those scripts build glyphs from code points at runtime for exactly this reason. |
| Hooks never fire | Reload via `/hooks` or restart. Verify `settings.json` is valid JSON, since a syntax error silently disables every setting in the file. |
| `curl: command not found` | `sudo apt install curl`. |
| `jq: command not found` | `brew install jq` or `sudo apt install jq`. The bash scripts require it. |

## How it works

Hooks are commands Claude Code runs at lifecycle events. Each one pipes a small JSON payload to the script on stdin, and the script formats a Discord embed and POSTs it to the webhook.

`allowed_mentions` is scoped to your user ID alone, so the `<@id>` pushes a notification and nothing else can slip through, no accidental `@everyone`. The activity feed sets it to an empty parse list instead, which is what keeps that feed from ever pinging.

`"async": true` runs the hook in the background so it never adds latency to your session.
