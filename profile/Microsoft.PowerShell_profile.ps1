fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# PSReadLine — better command-line editing. Windows PowerShell 5.1 ships
# with 2.0.0 preloaded from System32 and won't swap it for a newer PSGallery
# version in-session, so -PredictionSource (added in 2.1.0) is version-gated.
Import-Module PSReadLine -ErrorAction SilentlyContinue
$psrl = Get-Module PSReadLine
if ($psrl) {
    Set-PSReadLineOption -EditMode Windows
    if ($psrl.Version -ge [Version]'2.1.0') {
        Set-PSReadLineOption -PredictionSource History
    }
}

Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module posh-git       -ErrorAction SilentlyContinue
