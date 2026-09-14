<#
.SYNOPSIS
  Install VS Code extensions listed in vscode/extensions.txt.

.DESCRIPTION
  Reads vscode/extensions.txt (one extension ID per line; `#` comments
  and blank lines allowed). For each entry checks `code --list-extensions`
  and installs only what's missing. Idempotent; safe to re-run.

  Run standalone (`just vscode`) or from bootstrap.ps1.
#>

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }

$extList = Join-Path $RepoRoot 'vscode\extensions.txt'

Write-Host ""
Write-Host "==> VS Code extensions" -ForegroundColor Cyan

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "code CLI not found - VS Code not installed or 'Add to PATH' was declined at install." -ForegroundColor Yellow
    return
}

if (-not (Test-Path $extList)) {
    Write-Host "extensions list not found: $extList" -ForegroundColor Yellow
    return
}

$want = Get-Content $extList |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

# code --list-extensions returns one ID per line; case matches marketplace.
$have = @(code --list-extensions)

$installed = 0
$skipped   = 0
foreach ($ext in $want) {
    if ($have -contains $ext) {
        Write-Host "  ok:   $ext"
        $skipped++
        continue
    }
    # `code` is Node under the hood and prints deprecation warnings to
    # stderr. PS 5.1 wraps native stderr as NativeCommandError and throws
    # under EAP=Stop, AND clobbers $LASTEXITCODE (usually to -1) even when
    # the install actually succeeded. Catch it and use `--list-extensions`
    # as the source of truth for whether the extension is now present.
    try {
        code --install-extension $ext --force 2>&1 | Out-Null
    } catch { }
    $global:LASTEXITCODE = 0
    $have = @(code --list-extensions)
    if ($have -contains $ext) {
        Write-Host "  add:  $ext" -ForegroundColor Green
        $installed++
    } else {
        Write-Host "  fail: $ext" -ForegroundColor Yellow
    }
}
Write-Host "$installed installed, $skipped already present." -ForegroundColor Green
