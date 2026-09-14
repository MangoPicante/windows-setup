<#
.SYNOPSIS
  Verify the tools bootstrap.ps1 installs are on PATH and runnable.

.DESCRIPTION
  Prints a pass/fail table. Exits 0 if everything resolves, 1 if any
  tool is missing. Loads fnm's shell env first so node/npm/claude are
  discoverable in the current session without relying on the profile
  being loaded.
#>

$ErrorActionPreference = 'Continue'

# Load fnm shims into this session so node/npm/claude resolve.
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

$tools = @(
    # Scoop + core CLI
    'scoop', 'git', 'gh', 'rg', 'fd', 'fzf', 'bat', 'jq', 'yq',
    '7z', 'curl', 'wget', 'just', 'eza', 'delta',
    # Language version managers + runtimes
    'fnm', 'uv', 'rig', 'java',
    # fnm-provided Node LTS + Claude Code
    'node', 'npm', 'claude'
)

$results = foreach ($name in $tools) {
    # -CommandType Application avoids matching PowerShell aliases
    # (e.g. curl/wget alias Invoke-WebRequest in Windows PowerShell).
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) {
        [PSCustomObject]@{ Tool = $name; Status = 'OK';      Path = $cmd.Source }
    } else {
        [PSCustomObject]@{ Tool = $name; Status = 'MISSING'; Path = '' }
    }
}

$results | Format-Table -AutoSize

$missing = @($results | Where-Object { $_.Status -ne 'OK' })
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "$($missing.Count) of $($results.Count) tools missing." -ForegroundColor Red
    Write-Host "Missing: $(($missing.Tool) -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "All $($results.Count) tools OK." -ForegroundColor Green
exit 0
