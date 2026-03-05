# git_rush

Automation helper to practice common Git flows that can contribute to GitHub achievements:
- commit
- pull
- push
- branch work
- merge commit
- merge conflict + resolution

## Usage

Run from repo root in PowerShell:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-achievements.ps1
```

Optional flags:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-achievements.ps1 -BaseBranch main -Remote origin
pwsh -ExecutionPolicy Bypass -File .\scripts\run-achievements.ps1 -SkipPush
pwsh -ExecutionPolicy Bypass -File .\scripts\run-achievements.ps1 -AllowDirty -SkipPush
```

## Notes

- Keep this repo as a sandbox; do not spam active production repos.
- The script requires a clean working tree before it starts.
- Some GitHub achievements still require GitHub-side actions (for example PR workflows), which this script does not fully automate.