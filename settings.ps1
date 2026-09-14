<#
.SYNOPSIS
  Personal Windows/Explorer/taskbar tweaks. Idempotent; safe to re-run.

.DESCRIPTION
  Most tweaks live in HKCU (per-user) and need no admin. The single
  HKLM tweak (long paths) triggers a UAC prompt when not already set.

  Run standalone, or from bootstrap.ps1 which invokes it at the end.

.NOTES
  Re-running `Set-ItemProperty` with the same value is a no-op, so the
  script does not bother checking current values first (except for the
  admin-gated ones, where the check avoids a needless UAC bounce).
#>

$ErrorActionPreference = 'Stop'

function Set-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord','String')][string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value `
        -PropertyType $Type -Force | Out-Null
}

Write-Host ""
Write-Host "==> Applying Windows tweaks" -ForegroundColor Cyan

# --- Explorer ---
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-RegistryValue $adv 'HideFileExt'        0    # show file extensions
Set-RegistryValue $adv 'Hidden'             1    # show hidden files
Set-RegistryValue $adv 'ShowSuperHidden'    0    # but not OS-protected
Set-RegistryValue $adv 'LaunchTo'           1    # open File Explorer to This PC
Set-RegistryValue $adv 'Start_TrackDocs'    0    # no "recent files" in Start
Set-RegistryValue $adv 'Start_TrackProgs'   0    # no "recent apps" in Start

# --- Taskbar ---
Set-RegistryValue $adv 'TaskbarAl'          0    # align left (Win10 style)
Set-RegistryValue $adv 'TaskbarMn'          0    # hide Chat button
Set-RegistryValue $adv 'ShowTaskViewButton' 0    # hide Task View button

# --- Theme (dark mode) ---
$theme = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-RegistryValue $theme 'AppsUseLightTheme'   0
Set-RegistryValue $theme 'SystemUsesLightTheme' 0

# --- Search (kill Bing/web results in Start menu) ---
$search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
Set-RegistryValue $search 'BingSearchEnabled' 0
Set-RegistryValue $search 'CortanaConsent'    0
Set-RegistryValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' `
    'DisableSearchBoxSuggestions' 1

# --- Ads / advertising id (per-user telemetry surface) ---
Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' `
    'Enabled' 0

# --- Restore Win10-style right-click context menu (drop "Show more options") ---
$ctxKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if (-not (Test-Path $ctxKey)) { New-Item -Path $ctxKey -Force | Out-Null }
# The (Default) value must exist and be empty; New-ItemProperty won't set (Default).
Set-ItemProperty -Path $ctxKey -Name '(default)' -Value '' -Force

# --- Long paths (HKLM; admin only; skip if already on) ---
$fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
$fsVal = (Get-ItemProperty -Path $fsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
if ($fsVal -eq 1) {
    Write-Host "  ok:   long paths already enabled"
} else {
    Write-Host "  Enabling long paths (UAC prompt incoming)..." -ForegroundColor Yellow
    $cmd = "New-ItemProperty -Path '$fsKey' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWord -Force | Out-Null"
    Start-Process powershell -ArgumentList '-NoProfile','-Command',$cmd -Verb RunAs -Wait
    $fsVal = (Get-ItemProperty -Path $fsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
    if ($fsVal -eq 1) {
        Write-Host "  ok:   long paths enabled" -ForegroundColor Green
    } else {
        Write-Host "  warn: long paths NOT enabled (UAC declined?)" -ForegroundColor Yellow
    }
}

# --- Restart Explorer so taskbar/theme/context-menu changes take effect ---
Write-Host "  Restarting Explorer to apply changes..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
# Explorer normally auto-respawns; guarantee it.
Start-Sleep -Seconds 1
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
}

Write-Host "Done." -ForegroundColor Green
