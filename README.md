# windows-setup

Personal bootstrap for a fresh Windows 11 machine. One PowerShell script
that enables Developer Mode, installs [Scoop](https://scoop.sh/) with my
dev CLI tools and language managers, imports my GUI apps via
[winget](https://learn.microsoft.com/windows/package-manager/), links my
PowerShell profile and `.gitconfig`, sets up Claude Code, and (optionally)
installs WSL with Ubuntu.

## Usage

Clone and run locally (recommended — the script needs the repo files for
`apps.json` and the dotfile links):

```powershell
git clone https://github.com/MangoPicante/windows-setup.git
cd windows-setup
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1
```

Non-admin PowerShell is fine. A single UAC prompt is triggered up front to
enable Developer Mode. For WSL, launch the whole script from an elevated
PowerShell; otherwise it skips WSL and prints the command to run later.

Re-running is safe — every step skips work that is already done.

## What it installs

**Developer Mode** — enabled up front so symlinks work non-admin.

**Scoop (dev CLI + language tooling)**
- CLI: `git`, `gh`, `ripgrep`, `fd`, `fzf`, `bat`, `jq`, `yq`, `7zip`,
  `curl`, `wget`, `just`, `eza`, `delta`
- Node — [`fnm`](https://github.com/Schniz/fnm)
- Python — [`uv`](https://github.com/astral-sh/uv) for project envs,
  Miniconda for data/science
- Java — Temurin 17 & 21 JDKs (switch active with `scoop reset <jdk>`)
- R — [`rig`](https://github.com/r-lib/rig)

**winget (GUI apps + general software)** — see [`apps.json`](./apps.json).
Includes VS Code, Windows Terminal, Docker Desktop, Notepad++, Firefox,
Brave, Discord, Steam, VLC, PowerToys, and more. Regenerate with:

```powershell
winget export --output apps.json
```

**Fonts** — CascadiaCode, FiraCode, JetBrainsMono (Nerd Font variants).

**Dotfiles**
- `profile/Microsoft.PowerShell_profile.ps1` — linked to both the Windows
  PowerShell 5.1 and PowerShell 7 profile paths under `Documents\`
- `git/.gitconfig` — linked to `~/.gitconfig`

Existing files at those paths are backed up as `<path>.bak-<timestamp>`
before being replaced. Symlinks require Developer Mode (the script enables
it for you) or admin; falls back to a plain copy with a warning if
creation is denied.

**Claude Code** — installed globally via npm on the fnm-managed Node LTS.
Run `claude login` after the script finishes.

**Optional** — WSL2 with Ubuntu (admin + reboot required).

## Post-install

```powershell
uv python install 3.12        # a Python for uv projects
rig add release               # current R
scoop reset temurin21-jdk     # pick active Java
claude login                  # authenticate Claude Code
```

## Adding new tools

**CLI tool from Scoop** (e.g. `sops`, `age`, `helm`, `kubectl`)

1. Confirm it's available: `scoop search <name>`. Most tools live in the
   `main` bucket; the script already adds `extras`, `java`, `nerd-fonts`,
   and `versions` as well.
2. Append the tool name to the `$cli` array in `bootstrap.ps1`
   (section 3, "Core CLI utilities"). Group language runtimes or version
   managers with section 4 instead.
3. Re-run `.\bootstrap.ps1`. `scoop install` is a no-op for anything
   already present, so it's safe.

Worked example — adding `sops` and `age`:

```powershell
# One-off on this machine:
scoop install sops age

# So a fresh box picks them up, edit bootstrap.ps1 section 3:
$cli = @(
    'gh', 'ripgrep', 'fd', 'fzf', 'bat', 'jq', 'yq', '7zip',
    'curl', 'wget', 'just', 'eza', 'delta',
    'sops', 'age'      # secrets encryption
)
```

If the tool is only in a bucket you don't have yet, add it to the
`$buckets` array in section 2 first.

**GUI or Store app from winget** — add the package id directly to
`apps.json` under `Sources[0].Packages`.

1. Find the id: `winget search <name>` (the "Id" column), or browse
   [winstall.app](https://winstall.app/) / [winget.run](https://winget.run/).
2. Add a `{ "PackageIdentifier": "<id>" }` object to the `Packages`
   array. Order doesn't matter.
3. Re-run `.\bootstrap.ps1` (or just `winget import --import-file apps.json
   --accept-package-agreements --accept-source-agreements
   --ignore-unavailable`). Already-installed apps are skipped.

Example — adding Obsidian:

```json
{
    "PackageIdentifier": "Obsidian.Obsidian"
}
```

Regenerating with `winget export` still works if you'd rather resync
from what's actually installed, but it will rewrite the whole file
(and reset the `CreationDate`).

## Gotchas

- Docker Desktop needs WSL2 running, so if this is a truly fresh machine
  do the WSL install + reboot before launching Docker.
- Miniconda's `python.exe` only takes over your PATH when a conda env is
  active. `uv` manages its own per-project `.venv`, so the two don't fight.
- Windows Terminal ships with Windows 11 — `winget import` will skip it
  if already installed.
