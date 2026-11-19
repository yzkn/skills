#requires -Version 7.0
<#
.SYNOPSIS
  起動時（ログオン時）・スリープ解除時に、やることがあれば新しいウィンドウで Claude Code のセッションを起こす。
.DESCRIPTION
  タスク AutoLoopKick（install.ps1 -EnableKick で登録）が起動する。判断は git とファイルだけで行い、利用枠（トークン）を使わない。
  起こすのは、次のすべてを満たすときだけ。見送ったときは、理由を logs/auto-loop.log に残す。
    1. config.json の kick.enabled が true
    2. auto-resume-global が導入済みで、停止中（disabled）でない
    3. 前に起こしたセッションが、手を動かしていない（プロセスが無いか、入力待ちなど。auto-resume-global が再開したセッションは 5 で見る）
    4. 上限の解除待ちでない（復帰タスク ClaudeAutoResumeGlobal-Wake が先の時刻に登録されていない）
    5. この PC で、手を動かしているセッションが無い。手が止まっているもの（claude が起動していない / 起動したが指示が無い /
       利用者の入力待ち / 上限の解除待ち / kick.busyMinutes 分より長く書かれていない）は数えない（Get-BusySessions）
    6. 前に起こしてから kick.minIntervalHours 時間が過ぎている（週の解除時刻の起動 -Trigger weekly では見ない）
    7. やることがある: 自分が担当の doing / 回答の届いた waiting・blocked / 自分に合う ready / 受付の未整理（work）。
       どれも無ければ、手が空いたときの作業（idle。kick.idle が true で、前の idle から kick.idleMinIntervalHours 時間が過ぎているとき）
  起こしたセッションは /auto-loop next を実行する（指令リポジトリの AGENTS.md「7. 着手の順」）。
  あわせて、kick.weeklyAtReset が true なら、週の上限の解除時刻（記録の resetsAt か kick.weeklyResetAt）を調べ、
  タスク AutoLoopKickWeekly の時刻が違っていれば登録し直す（1 の前に行う。DryRun では表示だけ）。
  判断のたびに、PC の状況を指令リポジトリの state/pcs/<agentId>.json に書く（kick.enabled のときだけ。中身が変わったときか
  kick.statusEveryMinutes 分ごと。このファイルだけをコミットし、ほかの変更が無いときだけ push する。ダッシュボードが読む）。
  終了コード: 0 = 起こした・見送った / 1 = 設定が読めない
.PARAMETER Trigger
  起動のきっかけ（ログに書く）。weekly（週の解除時刻）のときは 6 の間隔を見ない
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
    [switch]$SkipSystemChecks,
    [ValidateSet('', 'weekly')][string]$Trigger = ''
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

# PC の状況（指令リポジトリの state/pcs/<ID>.json）。kick.enabled のときだけ、DryRun では書かない
$script:pcStatus = @{ trigger = $(if ($Trigger) { $Trigger } else { 'logon-wake-interval' }); intervalMinutes = [int]$kick.intervalMinutes }
function Save-PcStatus([string]$Decision, [string]$Reason) {
    if ($DryRun -or -not $kick.enabled) { return }
    # 手元のパス・フォルダ名（利用者名を含む）は書かない
    $public = $Reason -replace '[A-Za-z]:[\\/][^\s、）)]*', '<パス>' -replace '\b[A-Za-z]--[^\s、）)]+', '<プロジェクト>'
    $script:pcStatus.decision = $Decision
    $script:pcStatus.reason = $public
    $script:pcStatus.kickEnabled = [bool]$kick.enabled
    $r = Write-PcStatus -Config $cfg -Status $script:pcStatus -EveryMinutes ([double]$kick.statusEveryMinutes)
    if ($r -like 'failed*' -or $r -like 'written-local*') { Write-LoopLog 'kick' "PC の状況: $r" }
}
function Skip([string]$Reason) {
    Write-LoopLog 'kick' "見送り$(if ($DryRun) { '（DryRun）' }): $Reason"
    Write-Output "SKIP $Reason"
    Save-PcStatus 'skip' $Reason
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

# 0. 週の解除時刻のタスクを合わせる（有効なときだけ。失敗しても判断は続ける）
if ($kick.weeklyAtReset -and ($kick.enabled -or $DryRun)) {
    try {
        $wr = Resolve-WeeklyReset -Kick $kick -ProjectsDir $projects -NoSave:$DryRun
        if ($wr.ResetAt) {
            $at = Get-NextWeeklySlot -ResetAt $wr.ResetAt
            $atIso = $at.ToString('yyyy-MM-ddTHH:mm:sszzz')
            $script:pcStatus.weeklyResetAt = $wr.ResetAt.ToString('yyyy-MM-ddTHH:mm:sszzz')
            $script:pcStatus.weeklyNextAt = $atIso
            $registered = $false
            if ($IsWindows -and -not $SkipSystemChecks) { $registered = [bool](Get-ScheduledTask -TaskName 'AutoLoopKickWeekly' -ErrorAction SilentlyContinue) }
            # 曜日・時刻（7 日刻み）が同じなら登録し直さない
            $same = $false
            if ($wr.TaskAt) { try { $same = (([math]::Round(([datetimeoffset]::Parse($wr.TaskAt).LocalDateTime - $at).TotalMinutes) % 10080) -eq 0) } catch { } }
            if ($DryRun) { Write-Output "INFO 週の解除時刻: $($wr.ResetAt.ToString('ddd MM/dd HH:mm'))（$($wr.Source)）→ 次の起動 $($at.ToString('ddd MM/dd HH:mm'))$(if ($registered -and $same) { '（登録済み）' } else { '（登録し直す対象）' })" }
            elseif ($IsWindows -and -not $SkipSystemChecks -and -not ($registered -and $same)) {
                $shellPath = (Get-Process -Id $PID).Path
                $xml = New-KickTaskXml -Kind weekly -KickScript $PSCommandPath -Shell $shellPath -User "$env:USERDOMAIN\$env:USERNAME" -WeeklyAt $at
                Register-ScheduledTask -TaskName 'AutoLoopKickWeekly' -Xml $xml -Force | Out-Null
                Set-WeeklyTaskAt $atIso
                Write-LoopLog 'kick' "週の解除時刻のタスク AutoLoopKickWeekly を登録した（毎週 $($at.DayOfWeek) $($at.ToString('HH:mm'))、次 $($at.ToString('MM/dd HH:mm'))。$($wr.Source)）"
            }
        }
        elseif ($DryRun) { Write-Output 'INFO 週の解除時刻: 分からない（週の上限の記録が無い。kick.weeklyResetAt で手で決められる）' }
    }
    catch { Write-LoopLog 'kick' "週の解除時刻のタスクを合わせられなかった: $($_.Exception.Message)" }
}

# 1. 有効か
if ($Trigger) { Write-LoopLog 'kick' "起動のきっかけ: $Trigger" }
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
        if ($run -and (Test-Pid $run.pid ([string]$run.startedAt))) {
            # 動いていても、手が止まっている（入力待ちなど）なら数えない。そのウィンドウは kick-session.ps1 の見張りが終わらせる
            $runState = 'working'
            $runLog = @()
            if ($run.sessionId -and (Test-Path -LiteralPath $projects)) { $runLog = @(Get-ChildItem -LiteralPath $projects -Recurse -File -Filter "$($run.sessionId).jsonl" -ErrorAction SilentlyContinue | Select-Object -First 1) }
            if ($runLog.Count -gt 0) { $runState = (Get-SessionActivity -Path $runLog[0].FullName -BusyMinutes ([double]$kick.busyMinutes)).State }
            if ($runState -eq 'working') { Skip "前に起こしたセッションが動いている（pid $($run.pid)、$($run.startedAt) から）" }
            Write-LoopLog 'kick' "前に起こしたセッションは手が止まっている（$runState、pid $($run.pid)）。数えない"
        }
        elseif (-not $DryRun) { Remove-Item -LiteralPath $runFile -Force -ErrorAction SilentlyContinue }   # 印だけが残っている（再起動など）
    }

    # 4. 上限の解除待ち（いま起こしても、すぐ上限で止まる）
    if ($IsWindows) {
        try {
            $info = Get-ScheduledTaskInfo -TaskName 'ClaudeAutoResumeGlobal-Wake' -ErrorAction Stop
            if ($info.NextRunTime) { $script:pcStatus.nextWakeAt = $info.NextRunTime.ToString('yyyy-MM-ddTHH:mm:sszzz') }
            if ($info.NextRunTime -and $info.NextRunTime -gt (Get-Date)) { Skip "上限の解除待ち（復帰タスクが $($info.NextRunTime.ToString('MM/dd HH:mm')) に登録されている）" }
        }
        catch { }
    }
}

# 5. ほかのセッションが手を動かしている（共倒れを防ぐ。AGENTS.md 7.3）。手が止まっているものは数えない
$idleNote = ''
if ($kick.busyMinutes -gt 0) {
    # claude のプロセスが 1 つも無ければ、記録を読むまでもなく動いていない（試験では飛ばす）
    $anyClaude = $true
    if (-not $SkipSystemChecks) { $anyClaude = [bool](Get-Process -Name 'claude' -ErrorAction SilentlyContinue | Select-Object -First 1) }
    if ($anyClaude) {
        $busy = Get-BusySessions -ProjectsDir $projects -BusyMinutes ([double]$kick.busyMinutes)
        $counts = [ordered]@{ working = $busy.Working.Count; 'waiting-input' = 0; limit = 0; empty = 0; stale = 0 }
        foreach ($g in @($busy.Idle | Group-Object State)) { $counts[$g.Name] = $g.Count }
        $script:pcStatus.sessions = $counts
        if ($busy.Working.Count -gt 0) {
            $w = $busy.Working[0]
            Skip "ほかのセッションが動いている（$($w.Project) の $($w.SessionId.Substring(0, [math]::Min(8, $w.SessionId.Length)))、$($kick.busyMinutes) 分の内に作業の記録がある。ほか $($busy.Working.Count - 1) 件）"
        }
        if ($busy.Idle.Count -gt 0) {
            $idleNote = "。手が止まっているセッション $($busy.Idle.Count) 件は数えない（" + (($busy.Idle | Group-Object State | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ') + '）'
        }
    }
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
$script:pcStatus.lastLaunchedAt = $hist.lastLaunchedAt; $script:pcStatus.lastKind = $hist.lastKind
$since = Get-HoursSince $hist.lastLaunchedAt
if (-not $Force -and $Trigger -ne 'weekly' -and $null -ne $since -and $since -lt [double]$kick.minIntervalHours) {
    Skip ("前に起こしてから {0:0.0} 時間（kick.minIntervalHours = {1}）" -f $since, $kick.minIntervalHours)
}

# 7. やることがあるか
$pull = Update-ControlRepo $cfg
$pullNote = if ($pull.Ok) { '' } else { "。指令リポジトリを取り込めなかった（$($pull.Reason)）ので手元の版で判断" }
$pullNote += $idleNote
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
    Save-PcStatus 'error' "起こせなかった: $($_.Exception.Message)"
    exit 0
}
$now = Get-NowIso
$hist.lastLaunchedAt = $now; $hist.lastKind = $kind
if ($kind -eq 'idle') { $hist.lastIdleAt = $now }
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force $stateDir | Out-Null }
[IO.File]::WriteAllText($histFile, ($hist | ConvertTo-Json), $utf8)
Write-LoopLog 'kick' "起こした: $kind session=$sessionId（$summary）$pullNote"
Write-Output "KICK ${kind}: session=$sessionId（$summary）$pullNote"
$script:pcStatus.lastLaunchedAt = $now; $script:pcStatus.lastKind = $kind
Save-PcStatus "kick-$kind" "起こした（$summary）"
exit 0
