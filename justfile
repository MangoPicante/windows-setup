# windows-setup task runner. Run `just` to list targets.

set shell := ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

# Show available recipes
default:
    @just --list

# Run the full Windows bootstrap
bootstrap:
    ./bootstrap.ps1

# Apply Windows/Explorer/taskbar tweaks
settings:
    ./settings.ps1

# Install VS Code extensions listed in vscode/extensions.txt
vscode:
    ./vscode.ps1

# Verify installed tools are on PATH
verify:
    ./verify.ps1

# Parse-check all PowerShell scripts (fast, no lint rules)
parse:
    $ok = $true; foreach ($f in 'bootstrap.ps1','settings.ps1','verify.ps1','vscode.ps1') { $errs = $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$errs) | Out-Null; if ($errs) { Write-Host "${f}: FAIL" -ForegroundColor Red; $errs | Format-List Message, Extent; $ok = $false } else { Write-Host "${f}: OK" -ForegroundColor Green } }; if (-not $ok) { exit 1 }

# Lint with PSScriptAnalyzer (install with: Install-Module PSScriptAnalyzer -Scope CurrentUser)
lint:
    Invoke-ScriptAnalyzer -Path bootstrap.ps1, settings.ps1, verify.ps1, vscode.ps1 -Severity Warning, Error
