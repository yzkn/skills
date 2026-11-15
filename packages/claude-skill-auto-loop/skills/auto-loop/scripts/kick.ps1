#requires -Version 7.0
<#
.SYNOPSIS
  起動時（ログオン時）・スリープ解除時に、やることがあれば新しいウィンドウで Claude Code のセッションを起こす。
.DESCRIPTION
  タスク AutoLoopKick（install.ps1 -EnableKick で登録）が起動する。判断は git とファイルだけで行い、利用枠（トークン）を使わない。
  起こすのは、次のすべてを満たすときだけ。見送ったときは、理由を logs/auto-loop.log に残す。
    1. config.json の kick.enabled が true
    2. auto-resume-global が導入済みで、停止中（disabled）でない
    3. 前に起こしたセッションが動いていない（auto-resume-global が再開したセッションは、開いたまま残ることが多いので、5 で見る）
    4. 上限の解除待ちでない（復帰タスク ClaudeAutoResumeGlobal-Wake が先の時刻に登録されていない）
    5. この PC でほかのセッションが動いていない（~/.claude/projects の記録が kick.busyMinutes 分の内に書かれていない）
    6. 前に起こしてから kick.minIntervalHours 時間が過ぎている
    7. やることがある: 自分が担当の doing / 回答の届いた waiting・blocked / 自分に合う ready / 受付の未整理（work）。
       どれも無ければ、手が空いたときの作業（idle。kick.idle が true で、前の idle から kick.idleMinIntervalHours 時間が過ぎているとき）
  起こしたセッションは /auto-loop next を実行する（指令リポジトリの AGENTS.md「7. 着手の順」）。
  終了コード: 0 = 起こした・見送った / 1 = 設定が読めない
.PARAMETER DryRun
  判断だけを表示する（起こさない・記録を書かない・kick.enabled を見ない）
.PARAMETER Force
  kick.enabled と 6 の間隔を見ない（手で試すとき）
.PARAMETER SkipSystemChecks
  3〜4 のうち、プロセスとタスクスケジューラを見る部分を飛ばす（試験用）
.EXAMPLE
  pwsh -NoProfile -File kick.ps1 -DryRun
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipSystemChecks
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$me = [string]$cfg.agentId
$kick = Get-KickConfig $cfg
$utf8 = [Text.UTF8Encoding]::new($false)
$stateDir = Join-Path (Get-LoopHome) 'state'
$histFile = Join-Path $stateDir 'kick.json'
$runFile = Join-Path $stateDir 'kick-running.json'
$arHome = if ($env:AUTO_LOOP_AUTO_RESUME_HOME) { $env:AUTO_LOOP_AUTO_RESUME_HOME } else { Join-Path $HOME '.claude/auto-resume-global' }
$projects = if ($env:AUTO_LOOP_CLAUDE_PROJECTS) { $env:AUTO_LOOP_CLAUDE_PROJECTS } else { Join-Path $HOME '.claude/projects' }

function Skip([string]$Reason) {
    Write-LoopLog 'kick' "見送り$(if ($DryRun) { '（DryRun）' }): $Reason"
    Write-Output "SKIP $Reason"
    exit 0
}
# 印の pid のプロセスが、印を書いた時刻より前から動いているか（pid の使い回しを、動いていると取り違えない）
function Test-Pid($Id, [string]$StartedAt) {
    if (-not $Id) { return $false }
    $p = Get-Process -Id ([int]$Id) -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    try { return ($p.StartTime -le [datetimeoffset]::Parse($StartedAt).LocalDateTime.AddMinutes(1)) } catch { return $true }
}
function Get-HoursSince([string]$Iso) {
    if (-not $Iso) { return $null }
    try { return ([datetimeoffset]::Now - [datetimeoffset]::Parse($Iso)).TotalHours } catch { return $null }
}

# 1. 有効か
if (-not $kick.enabled -and -not $DryRun -and -not $Force) { Skip 'kick.enabled が false（install.ps1 -EnableKick で有効にする）' }

# 2. auto-resume-global
$arCfgFile = Join-Path $arHome 'config.json'
if (-not (Test-Path -LiteralPath $arCfgFile)) { Skip "auto-resume-global が導入されていない（$arCfgFile が無い）" }
if (Test-Path -LiteralPath (Join-Path $arHome 'disabled')) { Skip 'auto-resume-global が停止中（disabled がある）' }
$arCfg = [IO.File]::ReadAllText($arCfgFile, $utf8) | ConvertFrom-Json

# 3. 動いているセッション
if (-not $SkipSystemChecks) {
    if (Test-Path -LiteralPath $runFile) {
        $run = $null
        try { $run = [IO.File]::ReadAllText($runFile, $utf8) | ConvertFrom-Json } catch { }
        if ($run -and (Test-Pid $run.pid ([string]$run.startedAt))) { Skip "前に起こしたセッションが動いている（pid $($run.pid)、$($run.startedAt) から）" }
        if (-not $DryRun) { Remove-Item -LiteralPath $runFile -Force -ErrorAction SilentlyContinue }   # 印だけが残っている（再起動など）
    }

    # 4. 上限の解除待ち（いま起こしても、すぐ上限で止まる）
    if ($IsWindows) {
        try {
            $info = Get-ScheduledTaskInfo -TaskName 'ClaudeAutoResumeGlobal-Wake' -ErrorAction Stop
            if ($info.NextRunTime -and $info.NextRunTime -gt (Get-Date)) { Skip "上限の解除待ち（復帰タスクが $($info.NextRunTime.ToString('MM/dd HH:mm')) に登録されている）" }
        }
        catch { }
    }
}

# 5. ほかのセッションが動いている（共倒れを防ぐ。AGENTS.md 7.3）
if ($kick.busyMinutes -gt 0 -and (Test-Path -LiteralPath $projects)) {
    $cutoff = (Get-Date).AddMinutes(-[double]$kick.busyMinutes)
    $busy = $null
    foreach ($d in @(Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue)) {
        $busy = Get-ChildItem -LiteralPath $d.FullName -Filter '*.jsonl' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $cutoff } | Select-Object -First 1
        if ($busy) { break }
    }
    if ($busy) { Skip "ほかのセッションが動いている（$($busy.Directory.Name) の記録が $($kick.busyMinutes) 分の内に書かれた）" }
}

# 6. 間隔
$hist = [pscustomobject]@{ lastLaunchedAt = ''; lastKind = ''; lastIdleAt = '' }
if (Test-Path -LiteralPath $histFile) {
    try {
        $h = [IO.File]::ReadAllText($histFile, $utf8) | ConvertFrom-Json
        foreach ($k in @('lastLaunchedAt', 'lastKind', 'lastIdleAt')) { if ($h.PSObject.Properties.Name -contains $k) { $hist.$k = [string]$h.$k } }
    }
    catch { }
}
$since = Get-HoursSince $hist.lastLaunchedAt
if (-not $Force -and $null -ne $since -and $since -lt [double]$kick.minIntervalHours) {
    Skip ("前に起こしてから {0:0.0} 時間（kick.minIntervalHours = {1}）" -f $since, $kick.minIntervalHours)
}

# 7. やることがあるか
$pull = Update-ControlRepo $cfg
$pullNote = if ($pull.Ok) { '' } else { "。指令リポジトリを取り込めなかった（$($pull.Reason)）ので手元の版で判断" }
$tasks = @(Get-LoopTasks $cfg)
$repo = [string]$cfg.controlRepoPath
$doing = @($tasks | Where-Object { $_.claimedBy -eq $me -and $_.status -eq 'doing' })
$answered = @()
foreach ($t in @($tasks | Where-Object { $_.claimedBy -eq $me -and $_.status -in @('waiting', 'blocked') })) {
    # 最後にこのファイルを書いたのが自分でなければ、利用者（か別の書き手）が回答・決定を書いた見込み
    $subject = (Invoke-Git $repo @('log', '-1', '--format=%s', '--', (Get-RelPath $repo $t.path))).Text.Trim()
    if ($subject -and -not $subject.StartsWith("[$me]")) { $answered += $t }
}
$ready = @($tasks | Where-Object { $_.status -eq 'ready' -and -not $_.claimedBy -and (Test-LoopAssignee $me $_.assignee) })
$inbox = Get-InboxSummary $cfg
$urgent = @($ready | Where-Object { $_.priority -eq 'urgent' }).Count + $inbox.Urgent
$summary = "doing=$($doing.Count) 回答あり=$($answered.Count) ready=$($ready.Count) 受付=$($inbox.Count) 緊急=$urgent"

$kind = ''
if ($doing.Count + $answered.Count + $ready.Count + $inbox.Count -gt 0) { $kind = 'work' }
elseif ($kick.idle) {
    $defs = @(Get-IdleDefinitions $cfg)
    $due = @($defs | Where-Object { $_.due })
    $idleSince = Get-HoursSince $hist.lastIdleAt
    $summary += " 手が空いた時の定義=$($defs.Count)（実施できる $($due.Count)）"
    if ($defs.Count -gt 0 -and $due.Count -eq 0) { Skip "やることが無い（$summary）$pullNote" }
    if (-not $Force -and $null -ne $idleSince -and $idleSince -lt [double]$kick.idleMinIntervalHours) {
        Skip ("通常のタスクは無く、手が空いたときの作業は {0:0.0} 時間前に行った（kick.idleMinIntervalHours = {1}）（{2}）" -f $idleSince, $kick.idleMinIntervalHours, $summary)
    }
    $kind = 'idle'
}
if (-not $kind) { Skip "やることが無い（$summary）$pullNote" }

if ($DryRun) {
    Write-LoopLog 'kick' "DryRun: $kind を起こす判断（$summary）$pullNote"
    Write-Output "KICK $kind（DryRun。起こさない）: $summary$pullNote"
    exit 0
}

# 起こす: 新しいウィンドウで kick-session.ps1（その中で claude を起動する）
$sessionId = [guid]::NewGuid().ToString()
$launcher = Join-Path $PSScriptRoot 'kick-session.ps1'
$shell = if ($arCfg.PSObject.Properties['shellPath'] -and $arCfg.shellPath -and (Test-Path -LiteralPath $arCfg.shellPath)) { [string]$arCfg.shellPath } else { (Get-Process -Id $PID).Path }
$psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$launcher`" -SessionId $sessionId -Kind $kind"
$wt = if ($arCfg.PSObject.Properties['terminalPath']) { [string]$arCfg.terminalPath } else { '' }
if (-not ($wt -and (Test-Path -LiteralPath $wt))) {
    $wtCmd = Get-Command wt.exe -ErrorAction SilentlyContinue
    $wt = if ($wtCmd) { $wtCmd.Source } else { '' }
}
try {
    if ($wt) { Start-Process -FilePath $wt -ArgumentList "-w new new-tab --title `"auto-loop $kind`" -d `"$repo`" `"$shell`" $psArgs" }   # ; は wt の区切りなので使わない
    else { Start-Process -FilePath $shell -ArgumentList $psArgs -WorkingDirectory $repo }
}
catch {
    Write-LoopLog 'kick' "起こせなかった: $($_.Exception.Message)"
    Write-Output "NG 起こせなかった: $($_.Exception.Message)"
    exit 0
}
$now = Get-NowIso
$hist.lastLaunchedAt = $now; $hist.lastKind = $kind
if ($kind -eq 'idle') { $hist.lastIdleAt = $now }
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force $stateDir | Out-Null }
[IO.File]::WriteAllText($histFile, ($hist | ConvertTo-Json), $utf8)
Write-LoopLog 'kick' "起こした: $kind session=$sessionId（$summary）$pullNote"
Write-Output "KICK ${kind}: session=$sessionId（$summary）$pullNote"
exit 0
