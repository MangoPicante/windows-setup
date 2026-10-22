fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# PSReadLine — better command-line editing. Ships with Windows but we pull a
# newer version from PSGallery; `-ErrorAction SilentlyContinue` keeps a fresh
# box without the newer module silent instead of noisy.
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -EditMode Windows
}

Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module posh-git       -ErrorAction SilentlyContinue
