<#
.SYNOPSIS
  Fresh-Windows dev bootstrap: Developer Mode + Scoop (CLI/dev tools) +
  winget (GUI apps, from apps.json) + Claude Code.

.DESCRIPTION
  Run this in a NON-ADMIN PowerShell. Scoop refuses to install from an
  elevated shell, so the whole script assumes non-admin. A single UAC
  prompt is triggered up front to enable Developer Mode (so later
  symlink steps work without admin).

  WSL setup is intentionally NOT part of this script — it needs admin
  plus a reboot and is a one-time-per-machine step. Run it manually:
    wsl --install -d Ubuntu   # elevated shell, reboot after

  Usage:
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    .\bootstrap.ps1

  Re-running is safe: every step skips work that is already done.
#>

$ErrorActionPreference = 'Stop'

function Section($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# Guard rail for native commands ($ErrorActionPreference = 'Stop' does not
# catch non-zero exits from scoop/winget/npm/etc.). Fatal by default; pass
# -NonFatal to warn and continue (and clear $LASTEXITCODE so a later check
# does not see the stale value).
function Assert-Native {
    param(
        [Parameter(Mandatory)][string]$What,
        [switch]$NonFatal
    )
    if ($LASTEXITCODE) {
        $msg = "$What failed (exit $LASTEXITCODE)"
        if ($NonFatal) {
            Write-Host "  warn: $msg" -ForegroundColor Yellow
            $global:LASTEXITCODE = 0
        } else {
            throw $msg
        }
    }
}

# Collected at dotfile-linking time so we can surface a summary at the end.
$script:DotfileFallbacks = @()

# Absolute path to this repo, referenced by later sections (winget import,
# dotfile linking, etc.) even if $PWD changes.
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }

# ---------------------------------------------------------------------------
# 0. Developer Mode (lets symlinks work non-admin later on)
# ---------------------------------------------------------------------------
Section "Developer Mode"
$devKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$devVal = (Get-ItemProperty -Path $devKey -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devVal -eq 1) {
    Write-Host "Developer Mode already enabled."
} else {
    Write-Host "Enabling Developer Mode (UAC prompt incoming)..." -ForegroundColor Yellow
    $devCmd = "New-ItemProperty -Path '$devKey' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -PropertyType DWord -Force | Out-Null"
    Start-Process powershell -ArgumentList '-NoProfile','-Command',$devCmd -Verb RunAs -Wait
    $devVal = (Get-ItemProperty -Path $devKey -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    if ($devVal -eq 1) {
        Write-Host "Developer Mode enabled." -ForegroundColor Green
    } else {
        Write-Host "Developer Mode NOT enabled — symlink steps will fall back to copies." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# 1. Install Scoop (if missing)
# ---------------------------------------------------------------------------
Section "Scoop"
$scoopAlreadyInstalled = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
if (-not $scoopAlreadyInstalled) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop already installed."
    scoop update
    Assert-Native 'scoop update' -NonFatal
}

# ---------------------------------------------------------------------------
# 2. Buckets
# ---------------------------------------------------------------------------
Section "Buckets"
# git is required for adding non-default buckets — install it first from main
scoop install git
Assert-Native 'scoop install git'

# Match bucket names exactly (via the Name column) rather than substring-
# searching the whole table.
$installedBuckets = @(scoop bucket list).Name
$buckets = @('extras', 'java', 'nerd-fonts', 'versions')
foreach ($b in $buckets) {
    if ($installedBuckets -notcontains $b) {
        scoop bucket add $b
        Assert-Native "scoop bucket add $b" -NonFatal
    }
}

# ---------------------------------------------------------------------------
# 3. Core CLI utilities
# ---------------------------------------------------------------------------
Section "Core CLI"
$cli = @(
    'gh',            # GitHub CLI
    'ripgrep',       # rg
    'fd',            # fast find
    'fzf',           # fuzzy finder
    'bat',           # cat with syntax highlighting
    'jq',            # JSON processor
    'yq',            # YAML processor
    '7zip',
    'curl',
    'wget',
    'just',          # command runner (you already use a justfile)
    'eza',           # modern ls
    'delta'          # pretty git diffs
)
scoop install @cli
Assert-Native 'scoop install (core CLI)' -NonFatal

# ---------------------------------------------------------------------------
# 4. Language version managers + runtimes
# ---------------------------------------------------------------------------
Section "Language version managers"

# Node — fnm (matches what you're already using)
scoop install fnm
Assert-Native 'scoop install fnm'

# Python — uv for fast per-project envs; miniconda for data/science work
scoop install uv miniconda3
Assert-Native 'scoop install (python)' -NonFatal

# Java — install Scoop's java bucket JDKs; swap active with `scoop reset`
#   e.g.  scoop reset temurin21-jdk
scoop install temurin17-jdk temurin21-jdk
Assert-Native 'scoop install (java)' -NonFatal

# R — rig is r-lib's official R version manager
scoop install rig
Assert-Native 'scoop install rig' -NonFatal

# ---------------------------------------------------------------------------
# 5. Winget apps (GUI + general software) — see apps.json
# ---------------------------------------------------------------------------
Section "Winget apps"
$appsJson = Join-Path $RepoRoot 'apps.json'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    if (Test-Path $appsJson) {
        winget import --import-file $appsJson --accept-package-agreements --accept-source-agreements --ignore-unavailable
    } else {
        Write-Host "apps.json not found at $appsJson — skipping." -ForegroundColor Yellow
    }
} else {
    Write-Host "winget not found. Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5.5. Remove default Windows bloat (best-effort; missing packages ignored)
# ---------------------------------------------------------------------------
Section "Remove default bloat"
$bloat = @(
    # Nobody uses
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.BingSearch',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MixedReality.Portal',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',                 # Tips
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.549981C3F5F10',              # Cortana

    # Microsoft-pushed
    'Microsoft.OneDrive',
    'Microsoft.MicrosoftOfficeHub',         # M365 upsell
    'MicrosoftTeams',                       # consumer Teams
    'Microsoft.SkypeApp',
    'Microsoft.Copilot',

    # Superseded
    'Microsoft.ZuneMusic',                  # replaced by Media Player
    'Microsoft.ZuneVideo',                  # Films & TV
    'Microsoft.XboxSpeechToTextOverlay',

    # Personal preference
    'Microsoft.WindowsMaps',
    'Microsoft.WindowsCommunicationsApps',  # Mail & Calendar
    'Microsoft.YourPhone',                  # Phone Link
    'Microsoft.MicrosoftStickyNotes',
    'Microsoft.Todos',
    'Microsoft.WindowsCamera',
    'MicrosoftCorporationII.MicrosoftFamily',
    'MicrosoftCorporationII.QuickAssist'
)
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $removed = 0
    foreach ($id in $bloat) {
        # --exact + --id: require full-Id match. Redirect all streams: a
        # not-installed package prints noise + returns non-zero, both fine.
        winget uninstall --id $id --exact --silent --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { $removed++ }
        $global:LASTEXITCODE = 0
    }
    Write-Host "Uninstalled $removed of $($bloat.Count) bloat packages (missing = ignored)." -ForegroundColor Green
} else {
    Write-Host "winget not found — skipping bloat removal." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 6. Fonts (nerd-fonts bucket installs per-user; no admin needed)
# ---------------------------------------------------------------------------
Section "Fonts"
scoop install CascadiaCode-NF FiraCode-NF JetBrainsMono-NF
Assert-Native 'scoop install (fonts)' -NonFatal

# ---------------------------------------------------------------------------
# 7. Dotfiles (PowerShell profile + .gitconfig)
# ---------------------------------------------------------------------------
Section "Dotfiles"

function Set-ConfigLink {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-Path $Source)) {
        Write-Host "  skip: source not found: $Source" -ForegroundColor Yellow
        return
    }

    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    if (Test-Path $Target) {
        $existing = Get-Item $Target -Force
        # .Target can be a string in PS7 or a string[] in PS5.1, and may be
        # a resolved absolute path with different casing/slashes than $Source.
        # Normalize both sides before comparing.
        $isLinkToUs = $false
        if ($existing.LinkType -eq 'SymbolicLink') {
            $existingTarget = @($existing.Target)[0]
            try {
                $isLinkToUs = [IO.Path]::GetFullPath($existingTarget) `
                    -ieq [IO.Path]::GetFullPath($Source)
            } catch { }
        }
        if ($isLinkToUs) {
            Write-Host "  ok:   $Target -> $Source"
            return
        }
        $backup = "$Target.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item $Target $backup
        Write-Host "  backup: $Target -> $backup" -ForegroundColor Yellow
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source `
            -ErrorAction Stop | Out-Null
        Write-Host "  link: $Target -> $Source" -ForegroundColor Green
    } catch {
        Copy-Item $Source $Target -Force
        Write-Host "  copy: $Target (symlink failed; enable Developer Mode for live updates)" -ForegroundColor Yellow
        $script:DotfileFallbacks += $Target
    }
}

$home5   = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
$home7   = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
$profSrc = Join-Path $RepoRoot 'profile\Microsoft.PowerShell_profile.ps1'
$gitSrc  = Join-Path $RepoRoot 'git\.gitconfig'
$gitDst  = Join-Path $env:USERPROFILE '.gitconfig'

Set-ConfigLink -Source $profSrc -Target $home5
Set-ConfigLink -Source $profSrc -Target $home7
Set-ConfigLink -Source $gitSrc  -Target $gitDst

# Windows Terminal — path has a version hash (Store vs Preview); glob it.
# LocalState only exists after Terminal has been launched at least once.
$termSrc = Join-Path $RepoRoot 'terminal\settings.json'
$termLocalState = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState" `
    -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($termLocalState) {
    Set-ConfigLink -Source $termSrc -Target (Join-Path $termLocalState.FullName 'settings.json')
} else {
    Write-Host "  skip: Windows Terminal LocalState not found (launch Terminal once, then re-run)." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 8. Claude Code — installed globally via npm on a fnm-managed Node LTS
# ---------------------------------------------------------------------------
Section "Claude Code"
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    # Ensure a Node LTS is present and set as fnm's default.
    fnm install --lts
    Assert-Native 'fnm install --lts'

    # `lts-latest` is an alias fnm creates via `--lts`, but if fnm ever
    # changes that we want to see it, not swallow it silently.
    fnm default lts-latest
    if ($LASTEXITCODE) {
        Write-Host "  warn: 'fnm default lts-latest' failed (exit $LASTEXITCODE); leaving fnm default unchanged." -ForegroundColor Yellow
        $global:LASTEXITCODE = 0
    }

    # Load fnm's shell env into THIS session so npm is on PATH.
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g "@anthropic-ai/claude-code"
        Assert-Native 'npm install -g @anthropic-ai/claude-code'
        Write-Host "Claude Code installed. Run 'claude' in any project." -ForegroundColor Green
    } else {
        Write-Host "npm not found after fnm setup — install manually with:" -ForegroundColor Yellow
        Write-Host "  npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
    }
} else {
    Write-Host "fnm missing — skipping Claude Code install." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 8.5. VS Code extensions (see vscode/extensions.txt)
# ---------------------------------------------------------------------------
$vscodeScript = Join-Path $RepoRoot 'vscode.ps1'
if (Test-Path $vscodeScript) {
    & $vscodeScript
} else {
    Write-Host "vscode.ps1 not found at $vscodeScript — skipping." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 9. Windows tweaks (Explorer / taskbar / theme / long paths)
# ---------------------------------------------------------------------------
$settingsScript = Join-Path $RepoRoot 'settings.ps1'
if (Test-Path $settingsScript) {
    & $settingsScript
} else {
    Write-Host "settings.ps1 not found at $settingsScript — skipping." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Section "Done"
Write-Host "Installed apps:" -ForegroundColor Green
scoop list

if ($script:DotfileFallbacks.Count -gt 0) {
    Write-Host ""
    Write-Host "Dotfiles were COPIED (not linked); repo edits will not propagate:" -ForegroundColor Yellow
    foreach ($p in $script:DotfileFallbacks) {
        Write-Host "  $p" -ForegroundColor Yellow
    }
    Write-Host "Fix: enable Developer Mode, delete the copies above, and re-run bootstrap." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  * Open a new terminal so PATH updates take effect."
Write-Host "  * uv python install 3.12        # install a Python for uv projects"
Write-Host "  * rig add release               # install current R"
Write-Host "  * scoop reset temurin21-jdk     # pick active Java"
Write-Host "  * claude login                  # authenticate Claude Code"
Write-Host "  * wsl --install -d Ubuntu       # (elevated) if you want WSL — reboot after"
