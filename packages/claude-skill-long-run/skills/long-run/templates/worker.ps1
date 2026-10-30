# _worker.ps1 — detach されたワーカー本体。run.ps1 から隠しウィンドウで起動される。
# command.txt を実行し、stdout/stderr をログへ、完了時に exit.code（完了マーカー）を書く。
# 直接手動で実行しないこと。
$ErrorActionPreference = 'Continue'
$jobDir     = $PSScriptRoot
$cmdFile    = Join-Path $jobDir 'command.txt'
$stdoutLog  = Join-Path $jobDir 'stdout.log'
$stderrLog  = Join-Path $jobDir 'stderr.log'
$exitFile   = Join-Path $jobDir 'exit.code'
$statusFile = Join-Path $jobDir 'status.json'

$command = (Get-Content -Raw -LiteralPath $cmdFile).Trim()

# 実処理を現在のワーカープロセス内で実行し、終了コードを取得する。
# （子プロセスを挟まないため引用符のエスケープ問題を回避できる）
$code = 0
try {
  Invoke-Expression $command 1> $stdoutLog 2> $stderrLog
  $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
} catch {
  ($_ | Out-String) | Add-Content -LiteralPath $stderrLog
  $code = 1
}

# 完了状態を確定（exit.code は最後に書く＝完了判定の唯一の根拠）
$finishedAt = (Get-Date).ToString('o')
try { $prev = Get-Content -Raw -LiteralPath $statusFile | ConvertFrom-Json } catch { $prev = $null }
[ordered]@{
  state      = if ($code -eq 0) { 'succeeded' } else { 'failed' }
  processId  = if ($prev) { $prev.processId } else { $PID }
  startedAt  = if ($prev) { $prev.startedAt } else { $null }
  finishedAt = $finishedAt
  exitCode   = $code
  command    = $command
} | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8

Set-Content -LiteralPath $exitFile -Value ([string]$code) -Encoding ASCII
