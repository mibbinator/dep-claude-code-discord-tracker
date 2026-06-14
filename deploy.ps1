# deploy.ps1 -- copy the Windows hook scripts from this repo into ~/.claude so they run live.
# Run after editing windows/*.ps1 here, to make your changes take effect in Claude Code.
$ErrorActionPreference = 'Stop'
$dest = Join-Path $HOME '.claude'
Copy-Item -Force (Join-Path $PSScriptRoot 'windows\notify-discord.ps1')          $dest
Copy-Item -Force (Join-Path $PSScriptRoot 'windows\notify-discord-activity.ps1') $dest
Copy-Item -Force (Join-Path $PSScriptRoot 'windows\notify-discord-usage.ps1')    $dest
Write-Host "Deployed Windows scripts to $dest  (open /hooks once or restart Claude Code to reload)"
