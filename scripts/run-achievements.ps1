param(
    [string]$Remote = "origin",
    [string]$BaseBranch = "main",
    [switch]$SkipPush,
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    Write-Host ("`n> git " + ($Args -join " ")) -ForegroundColor Cyan
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Args -join ' ')"
    }
}

function Require-CleanWorkingTree {
    $status = & git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read git status."
    }

    if ($status) {
        throw "Working tree is not clean. Commit/stash changes before running this script."
    }
}

Write-Host "Starting achievement workflow..." -ForegroundColor Green

if (-not $AllowDirty) {
    Require-CleanWorkingTree
}
else {
    Write-Host "Warning: running with dirty working tree due to -AllowDirty." -ForegroundColor Yellow
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$workDir = ".achievement"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

if (-not $SkipPush) {
    Invoke-Git fetch $Remote
}

Invoke-Git checkout $BaseBranch

if (-not $SkipPush) {
    Invoke-Git pull --rebase $Remote $BaseBranch
}

# 1) Direct commit on base branch
$mainLogFile = Join-Path $workDir "main-commit-log.txt"
Add-Content -Path $mainLogFile -Value "main commit at $timestamp"
Invoke-Git add $mainLogFile
Invoke-Git commit -m "chore: direct commit for achievements $timestamp"

if (-not $SkipPush) {
    Invoke-Git push $Remote $BaseBranch
}

# 2) Feature branch commit + push
$featureBranch = "ach/feature-$timestamp"
Invoke-Git checkout -b $featureBranch
$featureFile = Join-Path $workDir "feature-$timestamp.txt"
Set-Content -Path $featureFile -Value "feature branch work at $timestamp"
Invoke-Git add $featureFile
Invoke-Git commit -m "feat: feature branch commit $timestamp"

if (-not $SkipPush) {
    Invoke-Git push -u $Remote $featureBranch
}

# 3) Merge branch (no conflict)
Invoke-Git checkout $BaseBranch
$mergeBranch = "ach/merge-$timestamp"
Invoke-Git checkout -b $mergeBranch
$mergeFile = Join-Path $workDir "merge-$timestamp.txt"
Set-Content -Path $mergeFile -Value "merge branch work at $timestamp"
Invoke-Git add $mergeFile
Invoke-Git commit -m "chore: merge branch prep $timestamp"

if (-not $SkipPush) {
    Invoke-Git push -u $Remote $mergeBranch
}

Invoke-Git checkout $BaseBranch
Invoke-Git merge --no-ff $mergeBranch -m "merge: merge $mergeBranch into $BaseBranch"

if (-not $SkipPush) {
    Invoke-Git push $Remote $BaseBranch
}

# 4) Intentional merge conflict + resolution
$conflictFile = Join-Path $workDir "conflict-target.txt"
Set-Content -Path $conflictFile -Value "CONFLICT_TARGET=base-$timestamp"
Invoke-Git add $conflictFile
Invoke-Git commit -m "chore: seed conflict target $timestamp"

if (-not $SkipPush) {
    Invoke-Git push $Remote $BaseBranch
}

$leftBranch = "ach/conflict-left-$timestamp"
$rightBranch = "ach/conflict-right-$timestamp"

Invoke-Git checkout -b $leftBranch
Set-Content -Path $conflictFile -Value "CONFLICT_TARGET=left-$timestamp"
Invoke-Git add $conflictFile
Invoke-Git commit -m "chore: conflict left change $timestamp"

if (-not $SkipPush) {
    Invoke-Git push -u $Remote $leftBranch
}

Invoke-Git checkout $BaseBranch
Invoke-Git checkout -b $rightBranch
Set-Content -Path $conflictFile -Value "CONFLICT_TARGET=right-$timestamp"
Invoke-Git add $conflictFile
Invoke-Git commit -m "chore: conflict right change $timestamp"

if (-not $SkipPush) {
    Invoke-Git push -u $Remote $rightBranch
}

Invoke-Git checkout $BaseBranch
Invoke-Git merge --no-ff $leftBranch -m "merge: merge $leftBranch into $BaseBranch"

Write-Host "`n> git merge --no-ff $rightBranch -m ""merge: merge $rightBranch into $BaseBranch""" -ForegroundColor Cyan
& git merge --no-ff $rightBranch -m "merge: merge $rightBranch into $BaseBranch"
$mergeExit = $LASTEXITCODE

if ($mergeExit -eq 0) {
    throw "Expected a merge conflict but merge completed cleanly."
}

Write-Host "Conflict detected. Applying scripted resolution..." -ForegroundColor Yellow
Set-Content -Path $conflictFile -Value "CONFLICT_TARGET=resolved-$timestamp(left+right)"
Invoke-Git add $conflictFile
Invoke-Git commit -m "fix: resolve conflict between $leftBranch and $rightBranch"

if (-not $SkipPush) {
    Invoke-Git push $Remote $BaseBranch
}

Invoke-Git checkout $BaseBranch

Write-Host "`nWorkflow completed successfully." -ForegroundColor Green
Write-Host "Branches created:"
Write-Host " - $featureBranch"
Write-Host " - $mergeBranch"
Write-Host " - $leftBranch"
Write-Host " - $rightBranch"
