<#
.SYNOPSIS
  Fresh-Windows dev bootstrap: Scoop + common tools + WSL.

.DESCRIPTION
  Run in a NON-admin PowerShell for the Scoop portion.
  WSL install at the end re-launches itself elevated and requires a reboot.

  Usage:
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    .\bootstrap.ps1

  Re-running is safe: Scoop skips anything already installed.
#>

$ErrorActionPreference = 'Stop'

function Section($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# 1. Install Scoop (if missing)
# ---------------------------------------------------------------------------
Section "Scoop"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop already installed."
}

scoop update

# ---------------------------------------------------------------------------
# 2. Buckets
# ---------------------------------------------------------------------------
Section "Buckets"
# git is required for adding non-default buckets — install it first from main
scoop install git

$buckets = @('extras', 'java', 'nerd-fonts', 'versions')
foreach ($b in $buckets) {
    if (-not (scoop bucket list | Select-String -SimpleMatch $b)) {
        scoop bucket add $b
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

# ---------------------------------------------------------------------------
# 4. Language version managers + runtimes
# ---------------------------------------------------------------------------
Section "Language version managers"

# Node — fnm (matches what you're already using)
scoop install fnm

# Python — uv for fast per-project envs; miniconda for data/science work
scoop install uv miniconda3

# Java — install Scoop's java bucket JDKs; swap active with `scoop reset`
#   e.g.  scoop reset temurin21-jdk
scoop install temurin17-jdk temurin21-jdk

# R — rig is r-lib's official R version manager
scoop install rig

# ---------------------------------------------------------------------------
# 5. GUI apps
# ---------------------------------------------------------------------------
Section "GUI apps"
$gui = @(
    'vscode',
    'windows-terminal',
    'docker',            # Docker CLI
    'docker-desktop',    # Docker Desktop
    'notepadplusplus'
)
scoop install @gui

# ---------------------------------------------------------------------------
# 6. Fonts (needs admin on some systems; scoop handles the elevation prompt)
# ---------------------------------------------------------------------------
Section "Fonts"
scoop install CascadiaCode-NF FiraCode-NF JetBrainsMono-NF

# ---------------------------------------------------------------------------
# 7. WSL (Ubuntu) — requires admin + reboot
# ---------------------------------------------------------------------------
Section "WSL"
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    wsl --install -d Ubuntu
    Write-Host "WSL install started. A reboot is required to finish." -ForegroundColor Yellow
} else {
    Write-Host "Skipping WSL: not running as admin." -ForegroundColor Yellow
    Write-Host "Run this in an elevated PowerShell to finish:" -ForegroundColor Yellow
    Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Section "Done"
Write-Host "Installed apps:" -ForegroundColor Green
scoop list

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  * Open a new terminal so PATH updates take effect."
Write-Host "  * fnm install --lts             # install a Node LTS"
Write-Host "  * uv python install 3.12        # install a Python for uv projects"
Write-Host "  * rig add release               # install current R"
Write-Host "  * scoop reset temurin21-jdk   # pick active Java"
Write-Host "  * Reboot if WSL was installed."
