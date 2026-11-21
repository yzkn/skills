#requires -Version 7.0
<#
.SYNOPSIS
  判断待ち・完了になったセッションを終わらせ、そのウィンドウ（Windows Terminal）を閉じる見張り。
.DESCRIPTION
  kick-session.ps1（自動起動のセッション）と kick.ps1（auto-resume-global が再開したセッション）が、ウィンドウを出さずに起動する。
  IntervalSeconds 秒ごとに、セッションの記録と指令リポジトリ（手元の clone）を読み、次のときに claude を終わらせる（Get-CloseDecision）。
    - 入力待ちが kick.settledCloseMinutes 分続き、このセッションが claim.ps1 で触れたタスクのどれも、まだ手に持っていない
      （判断待ち waiting・blocked・完了 done・dropped・解放 ready・別のエージェントやセッションに移った）。
      自動起動のセッションは、何も担当しなかったときも終わらせる。再開したセッションは、auto-loop のタスクに触れたものだけ
    - 自動起動のセッションだけ: 記録が kick.idleCloseMinutes 分のあいだ書かれない
  claude が終わると、起動したシェル（kick-session.ps1・resume-session.ps1）が後始末をして終わり、ウィンドウも閉じる。
  状態はタスクファイルにあるので、回答が届けば次の自動起動が続きを行う。
  シェルが終わったら（利用者が閉じた・claude が自分で終わった）、見張りも終わる。
  動いている間は state/close-watch/<SessionId>.json を置く（同じセッションに二重に付けない）。始めた・終えた・閉じた・入力待ちの間の見送りの理由をログに残す
.PARAMETER HostPid
  claude を起動したシェルの pid。この子プロセスの claude を終わらせる
.PARAMETER HostStartedAt
  シェルが動き始めた時刻（ISO 8601）。これより後に始まった同じ pid のプロセスは別物とみなす
.PARAMETER ParentSessionId
  再開元のセッション ID（--fork-session）。印がこの ID のままのタスクも、このセッションのものとみなす
.PARAMETER Once
  1 回だけ判断して終わる（試験用）。判断を CLOSE / KEEP で表示する
#>
param(
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][int]$HostPid,
    [ValidateSet('kick', 'resume')][string]$Source = 'kick',
    [string]$ParentSessionId = '',
    [string]$HostStartedAt = '',
    [int]$IntervalSeconds = 60,
    [switch]$Once
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force
try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$kick = Get-KickConfig $cfg
$sid8 = $SessionId.Substring(0, [math]::Min(8, $SessionId.Length))
$tag = "$Source session=$sid8 host=$HostPid"
$ids = @($SessionId); if ($ParentSessionId) { $ids += $ParentSessionId }

$watchDir = Join-Path (Get-LoopHome) 'state/close-watch'
$lockFile = Join-Path $watchDir "$SessionId.json"
if (-not $Once) {
    if (Test-CloseWatchRunning $SessionId) { Write-LoopLog 'close-watch' "見張りは既にある: $tag"; exit 0 }
    New-Item -ItemType Directory -Force $watchDir | Out-Null
    Write-LoopText $lockFile ([ordered]@{ pid = $PID; startedAt = (Get-NowIso); sessionId = $SessionId; hostPid = $HostPid; source = $Source } | ConvertTo-Json)
    Write-LoopLog 'close-watch' "見張りを始めた: $tag（判断待ち・完了 $($kick.settledCloseMinutes) 分$(if ($Source -eq 'kick') { "、書かれない $($kick.idleCloseMinutes) 分" })）"
}
$started = Get-Date
$paths = @('', '')
$last = ''
try {
    while ($true) {
        if (-not (Test-HostProcess $HostPid $HostStartedAt)) {
            if ($Once) { Write-Output 'END シェルが動いていない' } else { Write-LoopLog 'close-watch' "見張りを終えた: $tag（シェルが終わった）" }
            break
        }
        try {
            if (-not $paths[0]) { $paths[0] = Find-SessionTranscript $SessionId }
            if ($ParentSessionId -and -not $paths[1]) { $paths[1] = Find-SessionTranscript $ParentSessionId }
            $d = Get-CloseDecision -Config $cfg -Source $Source -SessionIds $ids -TranscriptPaths @($paths | Where-Object { $_ }) -WatchStartedAt $started
            if ($d.Close) {
                $killed = @(Stop-SessionHost $HostPid)
                $what = if ($killed.Count) { $killed -join ' ' } else { '（claude が見つからなかった）' }
                Write-LoopLog 'close-watch' "閉じた: $tag $($d.Reason)。終わらせた: $what"
                if ($Once) { Write-Output "CLOSE $($d.Reason)" }
                break
            }
            # 入力待ちの間の、見送りの理由の変化だけを残す（作業中の出入りは書かない。入力待ちの分数は除いて比べる）
            $note = if ($d.State -eq 'waiting-input') { $d.Reason -replace '（[0-9.]+ 分）', '' } else { '' }
            if ($note -and $note -ne $last -and -not $Once) { Write-LoopLog 'close-watch' "見送り: $tag $($d.Reason)" }
            $last = $note
            if ($Once) { Write-Output "KEEP $($d.Reason)" }
        }
        catch { Write-LoopLog 'close-watch' "判断できなかった: $tag $($_.Exception.Message)"; if ($Once) { Write-Output "NG $($_.Exception.Message)" } }
        if ($Once) { break }
        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    if (-not $Once -and (Test-Path -LiteralPath $lockFile)) { Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue }
}
exit 0
