# One script to keep this fork current and publish it:
#
#   1. fetches upstream and replays the fork's own commits on top of it (rebase)
#   2. pushes main to the fork on GitHub (asks first)
#   3. tags the next version and pushes the tag (asks first); GitHub Actions then builds the
#      installer and creates the release that the app's "Check for updates" looks at
#
#   usage:  double-click release.cmd in the repository root, or run
#           powershell -ExecutionPolicy Bypass -File scripts\release.ps1 [-DryRun] [-Yes]
#
# Each step is skipped when there is nothing to do, so it is safe to run at any time. It stops
# without changing anything when there is uncommitted work, and leaves the rebase open for you to
# finish when upstream and the fork changed the same lines (run it again afterwards).
#
# Version scheme: <upstream version>.<fork build>, e.g. v1.0.4.1, v1.0.4.2, then v1.0.5.1 once the
# fork sits on upstream 1.0.5. The upstream part is the newest upstream release that main contains;
# the last number counts the fork's own releases on top of it.
#
# -Yes answers every question with yes. It is for the weekly "sync upstream" workflow, which runs
# this script unattended; a conflict still stops it.
param([switch]$DryRun, [switch]$Yes)

$UpstreamUrl = "git@github.com:krisgfx9/Wireless-Device-Battery-Monitor.git"
$Branch = "main"

function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# Anything but a clear yes counts as no, including no input at all.
function Confirm($question) {
    if ($Yes) { Write-Host "$question (y/n): yes (-Yes)"; return $true }
    return "$(Read-Host "$question (y/n)")".Trim() -match '^(y|yes)$'
}

# Tags of a remote as name -> commit (annotated tags resolved to the commit they point at).
function RemoteTags($remote) {
    $map = @{}
    foreach ($line in (git ls-remote --tags $remote)) {
        if ($line -match '^([0-9a-f]+)\s+refs/tags/(.+?)(\^\{\})?$') {
            if ($Matches[3] -or -not $map.ContainsKey($Matches[2])) { $map[$Matches[2]] = $Matches[1] }
        }
    }
    if ($LASTEXITCODE -ne 0) { Fail "Could not read the tags of '$remote'." }
    return $map
}

Set-Location (Split-Path $PSScriptRoot -Parent)
$gitDir = git rev-parse --git-dir
if ($LASTEXITCODE -ne 0) { Fail "Not a git repository." }
if ((Test-Path (Join-Path $gitDir "rebase-merge")) -or (Test-Path (Join-Path $gitDir "rebase-apply"))) {
    Fail "A rebase is still in progress. Finish it (git rebase --continue) or cancel it (git rebase --abort), then run this again."
}
if ((git rev-parse --abbrev-ref HEAD) -ne $Branch) { Fail "Switch to '$Branch' first (git switch $Branch)." }
if (git status --porcelain --untracked-files=no) { Fail "There are uncommitted changes. Commit them first." }

# The upstream remote is fetch-only and brings no tags: a pushed upstream tag would start a release build here.
if (-not (git remote | Where-Object { $_ -eq "upstream" })) {
    git remote add upstream $UpstreamUrl
    git remote set-url --push upstream DISABLED
    git config remote.upstream.tagOpt --no-tags
}

# ---- 1. upstream ------------------------------------------------------------------------------
Write-Host "[1/3] Getting upstream..." -ForegroundColor Cyan
git fetch upstream
if ($LASTEXITCODE -ne 0) { Fail "Could not fetch upstream." }
git fetch origin
if ($LASTEXITCODE -ne 0) { Fail "Could not fetch origin (your fork)." }

$behind = [int](git rev-list --count "$Branch..upstream/$Branch")
$ahead = [int](git rev-list --count "upstream/$Branch..$Branch")
if ($behind -eq 0) {
    Write-Host "      Nothing new upstream ($ahead of your own commits on top)."
} elseif ($DryRun) {
    Write-Host "      Upstream has $behind new commit(s); a real run would replay your $ahead commit(s) on top of:"
    git log --oneline "$Branch..upstream/$Branch"
} else {
    Write-Host "      Upstream has $behind new commit(s). Replaying your $ahead commit(s) on top of:"
    git log --oneline "$Branch..upstream/$Branch"
    git rebase "upstream/$Branch"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Upstream changed the same lines as your commits. The rebase is paused." -ForegroundColor Yellow
        Write-Host "  1. Fix the files listed above (look for <<<<<<< markers), then: git add <file>"
        Write-Host "  2. Continue with:  git rebase --continue"
        Write-Host "  3. Or undo it all: git rebase --abort"
        Write-Host "When it is done, run this script again."
        exit 1
    }
}

# ---- 2. push main -----------------------------------------------------------------------------
Write-Host "[2/3] Updating your fork on GitHub..." -ForegroundColor Cyan
$head = git rev-parse $Branch
if ($head -eq (git rev-parse "origin/$Branch")) {
    Write-Host "      Already has everything."
} elseif ($DryRun) {
    Write-Host "      Local '$Branch' differs from GitHub; a real run would ask to push it."
} else {
    Write-Host "      Commits GitHub does not have yet:"
    git log --oneline "origin/$Branch..$Branch"
    if (-not (Confirm "      Push '$Branch' to your fork? This replaces what is there")) {
        Write-Host "Not pushed, so nothing to release. Run this again when you are ready."
        exit 0
    }
    git push --force-with-lease origin $Branch
    if ($LASTEXITCODE -ne 0) { Fail "Push failed." }
}

# ---- 3. release -------------------------------------------------------------------------------
Write-Host "[3/3] Release..." -ForegroundColor Cyan

# Newest upstream release contained in this branch.
$base = $null
$upstreamTags = RemoteTags "upstream"
foreach ($name in $upstreamTags.Keys) {
    if ($name -notmatch '^v(\d+\.\d+\.\d+)$') { continue }
    $v = [version]$Matches[1]
    git cat-file -e "$($upstreamTags[$name])^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { continue }  # a release this clone does not have
    git merge-base --is-ancestor $upstreamTags[$name] $head
    if ($LASTEXITCODE -eq 0 -and ($null -eq $base -or $v -gt $base)) { $base = $v }
}
if ($null -eq $base) { Fail "No upstream release found in this branch's history." }

# Next fork build number on top of that upstream version.
$build = 0
$lastTag = $null
$forkTags = RemoteTags "origin"
foreach ($name in $forkTags.Keys) {
    if ($name -match "^v$([regex]::Escape($base.ToString()))\.(\d+)$" -and [int]$Matches[1] -gt $build) {
        $build = [int]$Matches[1]
        $lastTag = $name
    }
}
if ($lastTag -and $forkTags[$lastTag] -eq $head) {
    Write-Host "      Nothing new to release: $lastTag already is the current '$Branch'." -ForegroundColor Green
    exit 0
}
$tag = "v$base.$($build + 1)"

Write-Host "      Upstream version in this fork: $base"
Write-Host "      Last fork release:             $(if ($lastTag) { $lastTag } else { 'none' })"
Write-Host "      New release:                   $tag" -ForegroundColor Green
Write-Host "      Changes since $(if ($lastTag) { $lastTag } else { "upstream $base" }):"
git log --oneline "$(if ($lastTag) { $forkTags[$lastTag] } else { $upstreamTags["v$base"] })..$head"

if ($DryRun) { Write-Host "Dry run: nothing rebased, pushed or tagged."; exit 0 }

if (-not (Confirm "      Publish $tag as a public release on GitHub?")) {
    Write-Host "Nothing tagged."
    exit 0
}
# -f: the fork does not have this tag (checked above), so a local one is a leftover from a failed run.
git tag -f -a $tag -m "Wireless Battery $($tag.Substring(1))"
if ($LASTEXITCODE -ne 0) { Fail "Could not create the tag." }
git push origin $tag
if ($LASTEXITCODE -ne 0) { git tag -d $tag | Out-Null; Fail "Could not push the tag (removed it locally again)." }

$repo = (git remote get-url origin) -replace '^.*github\.com[:/]', '' -replace '\.git$', ''
Write-Host ""
Write-Host "Tag $tag pushed. GitHub Actions is building the release (a few minutes):" -ForegroundColor Green
Write-Host "  https://github.com/$repo/actions"
Write-Host "It will appear at:"
Write-Host "  https://github.com/$repo/releases/latest"
