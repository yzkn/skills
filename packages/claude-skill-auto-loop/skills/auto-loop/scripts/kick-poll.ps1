#requires -Version 7.0
<#
.SYNOPSIS
  ダッシュボードの即時実行の印（指令リポジトリの state/kick/<agentId>.json）を見に行き、あれば kick.ps1 -Trigger now を呼ぶ。
.DESCRIPTION
  タスク AutoLoopKickPoll（install.ps1 -EnableKick で登録。kick.pollMinutes 分ごと。既定 3 分）が起動する。利用枠（トークン）を使わない。
    1. kick.enabled が true で、kick.pollMinutes が 0 より大きい（-DryRun では見ない）
    1b. 利用率（ステータスラインが書いた state/usage.json）の % か解除時刻が、PC の状況（state/pcs/<agentId>.json の usage）と違えば、
       usage だけを書き換えて push する（Update-PcUsage。kick.ps1 の判断を待たずに、ダッシュボードに今の値を届ける）
    2. git ls-remote で指令リポジトリの先頭のコミットを見る（軽い）。前に見たものと同じで、手元に印も無ければ、何もせずに終わる（ログも書かない）
    3. 変わっていれば取り込む（作業ツリーに書きかけがあっても autostash で保つ。Update-ControlRepo）
    4. 自分宛ての印があれば、kick.ps1 -Trigger now を別のプロセスで呼ぶ。印を消すか残すかは kick.ps1 が決める
       （起こした・起こせない理由が続くものは消す。ほかのセッションが動いている・上限の解除待ちは残して、次の見回りでやり直す）
  遅れは、最大で kick.pollMinutes 分 + セッションの起動の数十秒。
  終了コード: 0 = 何もしなかった・呼んだ / 1 = 設定が読めない
.PARAMETER DryRun
  判断だけを表示する（取り込みはする。kick.ps1 も -DryRun で呼ぶ。見た先頭のコミットは記録しない）
.PARAMETER SkipSystemChecks
  kick.ps1 に渡す（試験用）
.EXAMPLE
  pwsh -NoProfile -File kick-poll.ps1 -DryRun
#>
param(
    [switch]$DryRun,
    [switch]$SkipSystemChecks
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$kick = Get-KickConfig $cfg
if (-not $DryRun -and (-not $kick.enabled -or [double]$kick.pollMinutes -le 0)) { exit 0 }

$utf8 = [Text.UTF8Encoding]::new($false)
$stateFile = Join-Path (Get-LoopHome) 'state/kick-poll.json'
$repo = [string]$cfg.controlRepoPath
$reqFile = Join-Path $repo "state/kick/$([string]$cfg.agentId).json"

# 2. 先頭のコミットが変わったか
$last = ''
if (Test-Path -LiteralPath $stateFile) { try { $last = [string]([IO.File]::ReadAllText($stateFile, $utf8) | ConvertFrom-Json).head } catch { } }
$head = ''
$remote = Get-ControlRemote $cfg
if ($remote) {
    $branch = Get-ControlBranch $cfg
    $ls = Invoke-Git $repo @('ls-remote', $remote, "refs/heads/$branch")
    if ($ls.Code -eq 0 -and $ls.Text.Trim()) { $head = ($ls.Text.Trim() -split '\s+')[0] }
    elseif ($ls.Code -ne 0) { Write-LoopLog 'kick-poll' "指令リポジトリの先頭を見られなかった: $($ls.Text.Trim())" }
}
$changed = [bool]($head -and $head -ne $last)

# 1b. 利用率を PC の状況に反映する（先頭が変わっていなくても。変わったときだけ書く）
$ur = Update-PcUsage $cfg -NoWrite:$DryRun
if ($DryRun) { Write-Output "INFO 利用率: $ur" }
elseif ($ur -like 'written-local*' -or $ur -like 'failed*') { Write-LoopLog 'kick-poll' "利用率を PC の状況に反映: $ur" }

if (-not $changed -and -not (Test-Path -LiteralPath $reqFile)) {
    if ($DryRun) { Write-Output "SKIP 指令リポジトリの先頭は前と同じ（$(if ($head) { $head.Substring(0, 7) } else { '不明' })）で、即時実行の印も無い" }
    exit 0
}

# 3. 取り込む
if ($changed) {
    $u = Update-ControlRepo $cfg
    if (-not $u.Ok) { Write-LoopLog 'kick-poll' "取り込めなかった（$($u.Reason)）。手元の版で判断する" }
    elseif (-not $DryRun) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $stateFile) | Out-Null
        [IO.File]::WriteAllText($stateFile, ([ordered]@{ head = $head; checkedAt = (Get-NowIso) } | ConvertTo-Json), $utf8)
    }
}

# 4. 自分宛ての印
if (-not (Test-Path -LiteralPath $reqFile)) {
    if ($DryRun) { Write-Output 'SKIP 即時実行の印が無い（取り込み済み）' }
    exit 0
}
$kickArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'kick.ps1'), '-Trigger', 'now')
if ($DryRun) { $kickArgs += '-DryRun' }
if ($SkipSystemChecks) { $kickArgs += '-SkipSystemChecks' }
$shell = (Get-Process -Id $PID).Path
$out = & $shell @kickArgs 2>&1 | ForEach-Object { "$_" }
$text = ($out -join "`n").Trim()
Write-LoopLog 'kick-poll' "即時実行の印を見つけて kick.ps1 -Trigger now を呼んだ: $(($text -split "`n")[-1])"
Write-Output $text
exit 0
