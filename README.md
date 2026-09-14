# windows-setup

Personal bootstrap for a fresh Windows 11 dev machine. One PowerShell script
that installs [Scoop](https://scoop.sh/), the tools I use, and (optionally)
WSL with Ubuntu.

## Usage

From a fresh install, open PowerShell (non-admin is fine for most of it) and
run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
irm https://raw.githubusercontent.com/MangoPicante/windows-setup/main/bootstrap.ps1 | iex
```

Or clone and run locally:

```powershell
git clone https://github.com/MangoPicante/windows-setup.git
cd windows-setup
./bootstrap.ps1
```

Re-running is safe — Scoop skips anything already installed.

For the WSL step, launch the script from an elevated PowerShell; otherwise it
skips WSL and prints the command to run later.

## What it installs

**Core CLI**
`git`, `gh`, `ripgrep`, `fd`, `fzf`, `bat`, `jq`, `yq`, `7zip`, `curl`, `wget`,
`just`, `eza`, `delta`

**Language tooling**
- Node — [`fnm`](https://github.com/Schniz/fnm)
- Python — [`uv`](https://github.com/astral-sh/uv) for project envs, Miniconda
  for data/science
- Java — Temurin 17 & 21 JDKs (switch active with `scoop reset <jdk>`)
- R — [`rig`](https://github.com/r-lib/rig)

**GUI apps**
VS Code, Windows Terminal, Docker CLI + Docker Desktop, Notepad++

**Fonts**
CascadiaCode Nerd Font, FiraCode Nerd Font, JetBrainsMono Nerd Font

**Dotfiles**
- `profile/Microsoft.PowerShell_profile.ps1` — linked to both the Windows
  PowerShell 5.1 and PowerShell 7 profile paths under `Documents\`
- `git/.gitconfig` — linked to `~/.gitconfig`

Existing files at those paths are backed up as `<path>.bak-<timestamp>`
before being replaced. Symlinks need admin or **Developer Mode** enabled
(Settings → For developers); if creation fails, the script falls back to a
plain copy and prints a warning.

**Optional**
WSL2 with Ubuntu (admin + reboot required)

## Post-install

```powershell
fnm install --lts             # a Node LTS
uv python install 3.12        # a Python for uv projects
rig add release               # current R
scoop reset temurin21-jdk     # pick active Java
```

## Gotchas

- Docker Desktop needs WSL2 running, so do the WSL install + reboot first if
  this is a truly fresh machine.
- Miniconda's `python.exe` only takes over your PATH when a conda env is
  active. `uv` manages its own per-project `.venv`, so the two don't fight.
