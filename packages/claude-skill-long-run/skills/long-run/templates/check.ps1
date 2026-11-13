# check.ps1 — ジョブ状態を確認する（副作用なし・冪等・別セッションからでも実行可）
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$jobDir     = $PSScriptRoot
$statusFile = Join-Path $jobDir 'status.json'
$exitFile   = Join-Path $jobDir 'exit.code'
$stdoutLog  = Join-Path $jobDir 'stdout.log'
$stderrLog  = Join-Path $jobDir 'stderr.log'

if (-not (Test-Path $statusFile)) {
  Write-Host "未起動です。run.ps1 を実行してください。"
  exit 0
}
$st = Get-Content -Raw -LiteralPath $statusFile | ConvertFrom-Json

Write-Host "==== ジョブ状態 ===="
Write-Host "コマンド : $($st.command)"
Write-Host "開始     : $($st.startedAt)"

if (Test-Path $exitFile) {
  $code = (Get-Content -Raw -LiteralPath $exitFile).Trim()
  if ($code -eq '0') { Write-Host "状態     : 完了（成功） 終了コード=0" }
  else               { Write-Host "状態     : 完了（失敗） 終了コード=$code" }
  if ($st.finishedAt) { Write-Host "完了     : $($st.finishedAt)" }
} elseif ($st.processId -and (Get-Process -Id $st.processId -ErrorAction SilentlyContinue)) {
  try { $elapsed = [int]((Get-Date) - [datetime]$st.startedAt).TotalMinutes } catch { $elapsed = '?' }
  Write-Host "状態     : 実行中（PID=$($st.processId)・経過 約 $elapsed 分）"
} else {
  Write-Host "状態     : 中断/異常終了（プロセスが存在せず完了マーカーもありません）"
  Write-Host "           stderr.log を確認してください。"
}

Write-Host ""
Write-Host "---- stdout.log (末尾20行) ----"
if (Test-Path $stdoutLog) { Get-Content -LiteralPath $stdoutLog -Tail 20 } else { Write-Host "(なし)" }
Write-Host "---- stderr.log (末尾20行) ----"
if (Test-Path $stderrLog) { Get-Content -LiteralPath $stderrLog -Tail 20 } else { Write-Host "(なし)" }
