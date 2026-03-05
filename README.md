# git_rush

Sandbox automation for Git/GitHub achievement workflows.

## What is included

- `scripts/run-achievements.ps1`
  - local-first git flow: commits, merges, conflict + resolution
- `scripts/run-github-achievements.ps1`
  - GitHub API flow: issue open/close, PR creation, PR merge, optional co-author trailer

## Achievement coverage map

- `Quickdraw`
  - status: automated
  - how: open issue and close it immediately via API
- `Pull Shark`
  - status: automated
  - how: create and merge multiple PRs
- `YOLO`
  - status: automated
  - how: merge your own PR without review
- `Pair Extraordinaire`
  - status: partially automated
  - how: add co-author trailer with `-CoAuthorName` and `-CoAuthorEmail`, then merge PR
  - note: co-author should map to a real GitHub account
- `Galaxy Brain`
  - status: manual
  - reason: requires accepted answer in GitHub Discussions flow
- `Starstruck`
  - status: manual/external
  - reason: depends on other users starring your repository
- `Public Sponsor`
  - status: manual/external
  - reason: requires sponsorship action on GitHub billing side
- `Arctic Code Vault Contributor`
  - status: not currently obtainable in normal workflows

## Prerequisites

- Git installed and authenticated to push this repo
- PowerShell 7+
- GitHub token with repo scope in environment:

```powershell
$env:GITHUB_TOKEN = "ghp_xxx"
```

## Run commands

Local git-only workflow:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-achievements.ps1
```

GitHub API workflow (recommended for max unlock attempts):

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-github-achievements.ps1 -PullRequestCount 5
```

Pair Extraordinaire attempt:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-github-achievements.ps1 `
  -PullRequestCount 3 `
  -CoAuthorName "SECOND_ACCOUNT_NAME" `
  -CoAuthorEmail "second-account-email@example.com"
```

Dry-run (no API calls):

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\run-github-achievements.ps1 -DryRun -SkipPush -AllowDirty
```

## Notes

- Use this repository only as a sandbox.
- For repeated Pull Shark progress, rerun with larger `-PullRequestCount`.
- If you hit API or abuse limits, wait before the next run.