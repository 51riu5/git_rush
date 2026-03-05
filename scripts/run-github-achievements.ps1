param(
    [string]$Remote = "origin",
    [string]$BaseBranch = "main",
    [int]$PullRequestCount = 3,
    [switch]$SkipPush,
    [switch]$AllowDirty,
    [switch]$DryRun,
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$CoAuthorName = "",
    [string]$CoAuthorEmail = "",
    [switch]$SkipIssueQuickdraw,
    [switch]$StopOnApiError
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

function Get-RepoSlug {
    param([string]$RemoteName)
    $url = (& git remote get-url $RemoteName).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($url)) {
        throw "Unable to resolve git remote '$RemoteName'."
    }

    if ($url -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$") {
        return "$($Matches.owner)/$($Matches.repo)"
    }

    throw "Remote URL '$url' does not look like a GitHub repository URL."
}

function Invoke-GitHubApi {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )

    if ($DryRun) {
        Write-Host "[DRY-RUN] API $Method $Path" -ForegroundColor DarkYellow
        if ($Body -ne $null) {
            Write-Host ("[DRY-RUN] Body: " + ($Body | ConvertTo-Json -Depth 10 -Compress)) -ForegroundColor DarkYellow
        }
        return @{
            number = 0
            html_url = "https://example.local/dry-run"
        }
    }

    if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
        throw "Missing GitHub token. Set env:GITHUB_TOKEN or pass -GitHubToken."
    }

    $headers = @{
        Authorization = "Bearer $GitHubToken"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $uri = "https://api.github.com$Path"
    try {
        if ($Body -eq $null) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }

        $json = $Body | ConvertTo-Json -Depth 10
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json -ContentType "application/json"
    }
    catch {
        $message = $_.Exception.Message
        throw @"
GitHub API call failed: $Method $Path
$message

Common fix:
- Use a token with repository permissions for this repo:
  - Issues: Read and write
  - Pull requests: Read and write
  - Contents: Read and write
"@
    }
}

Write-Host "Starting advanced GitHub achievement workflow..." -ForegroundColor Green

if (-not $AllowDirty) {
    Require-CleanWorkingTree
}
else {
    Write-Host "Warning: running with dirty working tree due to -AllowDirty." -ForegroundColor Yellow
}

if ($PullRequestCount -lt 1) {
    throw "-PullRequestCount must be at least 1."
}

$repoSlug = Get-RepoSlug -RemoteName $Remote
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$workDir = ".achievement"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

Invoke-Git checkout $BaseBranch

if (-not $SkipPush -and -not $AllowDirty) {
    Invoke-Git fetch $Remote
    Invoke-Git pull --rebase $Remote $BaseBranch
}
elseif (-not $SkipPush -and $AllowDirty) {
    Write-Host "Skipping fetch/pull because -AllowDirty is enabled." -ForegroundColor Yellow
}

$issue = $null
if (-not $SkipIssueQuickdraw) {
    # Quickdraw path: open + close issue rapidly.
    $issue = Invoke-GitHubApi -Method "POST" -Path "/repos/$repoSlug/issues" -Body @{
        title = "quickdraw-$timestamp"
        body = "Auto-created for GitHub achievement workflow."
    }
    Invoke-GitHubApi -Method "PATCH" -Path "/repos/$repoSlug/issues/$($issue.number)" -Body @{
        state = "closed"
        state_reason = "completed"
    }
    Write-Host "Created and closed issue #$($issue.number) for Quickdraw attempt." -ForegroundColor Green
}
else {
    Write-Host "Skipping Quickdraw issue flow due to -SkipIssueQuickdraw." -ForegroundColor Yellow
}

$prLinks = @()
$manualPrLinks = @()

for ($i = 1; $i -le $PullRequestCount; $i++) {
    $branch = "ach/pr-$timestamp-$i"
    Invoke-Git checkout -b $branch

    $file = Join-Path $workDir "pr-$timestamp-$i.txt"
    Set-Content -Path $file -Value "PR $i generated at $timestamp"
    Invoke-Git add $file

    if (-not [string]::IsNullOrWhiteSpace($CoAuthorName) -and -not [string]::IsNullOrWhiteSpace($CoAuthorEmail)) {
        Invoke-Git commit -m "feat: automated PR $i for achievements $timestamp" -m "Co-authored-by: $CoAuthorName <$CoAuthorEmail>"
    }
    else {
        Invoke-Git commit -m "feat: automated PR $i for achievements $timestamp"
    }

    if (-not $SkipPush) {
        Invoke-Git push -u $Remote $branch
    }

    try {
        $pr = Invoke-GitHubApi -Method "POST" -Path "/repos/$repoSlug/pulls" -Body @{
            title = "achievement-pr-$timestamp-$i"
            head = $branch
            base = $BaseBranch
            body = "Automated PR #$i for achievement workflow."
            maintainer_can_modify = $true
        }

        # YOLO path: merge without review.
        Invoke-GitHubApi -Method "PUT" -Path "/repos/$repoSlug/pulls/$($pr.number)/merge" -Body @{
            merge_method = "squash"
            commit_title = "merge: achievement PR $i ($timestamp)"
        } | Out-Null

        $prLinks += $pr.html_url
        Write-Host "Merged PR #$($pr.number): $($pr.html_url)" -ForegroundColor Green
    }
    catch {
        $manualLink = "https://github.com/$repoSlug/pull/new/$branch"
        $manualPrLinks += $manualLink
        Write-Host "PR API step failed for branch '$branch'." -ForegroundColor Yellow
        Write-Host "Open manually: $manualLink" -ForegroundColor Yellow
        if ($StopOnApiError) {
            throw
        }
    }
    finally {
        Invoke-Git checkout $BaseBranch
    }
}

Write-Host "`nAdvanced workflow completed." -ForegroundColor Green
Write-Host "Repository: $repoSlug"
if ($issue -ne $null) {
    Write-Host "Issue URL: $($issue.html_url)"
}
else {
    Write-Host "Issue URL: (skipped)"
}
Write-Host "PR URLs:"
foreach ($link in $prLinks) {
    Write-Host " - $link"
}
if ($manualPrLinks.Count -gt 0) {
    Write-Host "Manual PR URLs (API permission missing):" -ForegroundColor Yellow
    foreach ($link in $manualPrLinks) {
        Write-Host " - $link"
    }
}

if (-not [string]::IsNullOrWhiteSpace($CoAuthorName) -and -not [string]::IsNullOrWhiteSpace($CoAuthorEmail)) {
    Write-Host "Co-author trailer was included for Pair Extraordinaire attempt." -ForegroundColor Green
}
else {
    Write-Host "Tip: pass -CoAuthorName and -CoAuthorEmail to attempt Pair Extraordinaire." -ForegroundColor Yellow
}
