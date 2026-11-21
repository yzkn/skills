#requires -Version 7.0
<#
.SYNOPSIS
  指令リポジトリの全案件の状態を短くまとめる（タスクファイルの全文は読まない）。
.EXAMPLE
  pwsh -NoProfile -File status.ps1                 # 全案件（先に取り込む）
  pwsh -NoProfile -File status.ps1 -Mine -NoPull   # 自分が担当中のものだけ
  pwsh -NoProfile -File status.ps1 -Project my-app -All -Json
#>
param(
    [string]$Project = '',
    [switch]$Mine,
    [switch]$All,      # done / dropped / 保管済みも出す
    [switch]$NoPull,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$me = [string]$cfg.agentId

$pull = $null
if (-not $NoPull) { $pull = Update-ControlRepo $cfg }

$tasks = @(Get-LoopTasks $cfg -Project $Project -IncludeArchive:$All)
if (-not $All) { $tasks = @($tasks | Where-Object { $_.status -notin @('done', 'dropped') }) }
if ($Mine) { $tasks = @($tasks | Where-Object { $_.claimedBy -eq $me }) }

$order = @{ waiting = 0; blocked = 1; doing = 2; ready = 3; draft = 4; done = 5; dropped = 6 }
$rows = foreach ($t in $tasks) {
    $age = Get-AgeHours $t.heartbeat
    $flag = ''
    if ($t.claimedBy -and $t.status -eq 'doing' -and $null -ne $age -and $age -gt $cfg.leaseHours) { $flag = 'stale' }
    if ($t.claimedBy -eq $me) { $flag = (@($flag, 'mine') | Where-Object { $_ }) -join ',' }
    [pscustomobject]@{
        project = $t.project; id = $t.id; status = $t.status; stage = $t.stage; priority = $t.priority; order = $t.order
        assignee = $t.assignee; claimedBy = $t.claimedBy; ageHours = $age; flag = $flag; title = $t.title
        created = $t.created
        sort = $(if ($order.ContainsKey($t.status)) { $order[$t.status] } else { 9 })
        prio = Get-PriorityRank $t.priority
        ord = Get-OrderKey $t.order
    }
}
# 状態ごとに、優先度の高い順 → order（利用者が並べた順。無いものは後ろ）→ 古い順（着手の順の目安。AGENTS.md「7. 着手の順」）
$rows = @($rows | Sort-Object sort, prio, ord, created, project, id)

# 受付（inbox.md）の未整理の件数: 「## 」見出し（書き方の例と「手が空いた時に実行するタスク」の節を除く。Get-InboxSummary）
$inboxSummary = Get-InboxSummary $cfg
$inbox = $inboxSummary.Count
$idle = @(Get-IdleDefinitions $cfg)

# 進行中の印（新旧の名前。同じ案件・同じタスクは 1 つにまとめる。20261121-task-id-collision）
$active = @(Get-ActiveMarks)
# 印のセッションの状態（20261120-no-parallel-sessions）。otherSessionLive が true のタスクは、同じ PC の別のセッションが手を動かしているので、再開の候補にしない
$session = Get-CurrentSession
foreach ($m in $active) {
    $sid = if ($m.PSObject.Properties['sessionId']) { [string]$m.sessionId } else { '' }
    $mine = [bool]($session -and $sid -and $sid -eq $session.SessionId)
    $live = if ($sid -and -not $mine) { Test-SessionLive $m } else { $null }
    $m | Add-Member -NotePropertyName thisSession -NotePropertyValue $mine -Force
    $m | Add-Member -NotePropertyName otherSessionLive -NotePropertyValue ([bool]($live -and $live.Live)) -Force
    $m | Add-Member -NotePropertyName sessionState -NotePropertyValue $(if ($mine) { 'this' } elseif ($live) { $live.Reason } else { 'no-session' }) -Force
}

if ($Json) {
    [pscustomobject]@{
        agentId = $me; controlRepo = $cfg.controlRepoPath; pulled = $(if ($pull) { $pull.Reason } else { 'skipped' })
        inbox = $inbox; inboxUrgent = $inboxSummary.Urgent; tasks = @($rows | Select-Object * -ExcludeProperty sort, prio); idle = $idle; active = $active
    } | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output "エージェント: $me   指令リポジトリ: $($cfg.controlRepoPath)"
if ($pull -and -not $pull.Ok) { Write-Output "WARN 取り込めなかった（$($pull.Reason)）。手元の版で表示する: $($pull.Detail)" }
Write-Output "受付（inbox.md）の未整理: $inbox 件$(if ($inboxSummary.Urgent) { "（うち 緊急 $($inboxSummary.Urgent) 件）" })"
if ($rows.Count -eq 0) { Write-Output '該当するタスクは無い' }
else {
    $rows | Format-Table -AutoSize -Wrap @{ n = '案件'; e = { $_.project } }, @{ n = 'ID'; e = { $_.id } }, @{ n = '状態'; e = { $_.status } },
    @{ n = '段階'; e = { $_.stage } }, @{ n = '優先'; e = { $_.priority } }, @{ n = '担当'; e = { $_.claimedBy } }, @{ n = '印から(h)'; e = { $_.ageHours } },
    @{ n = '印'; e = { $_.flag } }, @{ n = '件名'; e = { $_.title } } | Out-String -Width 200 | ForEach-Object { $_.TrimEnd() }
    $urgent = @($rows | Where-Object { $_.priority -eq 'urgent' -and $_.status -in @('ready', 'doing', 'waiting', 'blocked') })
    if ($urgent.Count) { Write-Output "緊急（priority: urgent）: $($urgent.Count) 件。担当中のタスクを区切りで中断して、先に行う" }
    $need = @($rows | Where-Object { $_.status -in @('waiting', 'blocked') })
    if ($need.Count) { Write-Output "人の対応が要る: $($need.Count) 件（waiting = 判断・承認待ち / blocked = 外部の要因）" }
    $stale = @($rows | Where-Object { $_.flag -match 'stale' })
    if ($stale.Count) { Write-Output "stale: $($stale.Count) 件（印が $($cfg.leaseHours) 時間より古い。引き継ぎは利用者の指示を得てから）" }
}
if ($idle.Count) {
    $due = @($idle | Where-Object { $_.due })
    Write-Output "手が空いた時に実行するタスク（inbox.md）: 定義 $($idle.Count) 件、うち実施できる $($due.Count) 件"
}
if ($active.Count) {
    Write-Output 'この PC で進行中の印（state/active）:'
    foreach ($a in $active) {
        $who = if ($a.thisSession) { '  ← このセッション' } elseif ($a.otherSessionLive) { "  ← 別のセッションが作業中（$($a.sessionState)）" } else { '' }
        Write-Output "  $($a.project)/$($a.task)  cwd=$($a.cwd)$who"
    }
}
Write-LoopLog 'status' "tasks=$($rows.Count) inbox=$inbox"
