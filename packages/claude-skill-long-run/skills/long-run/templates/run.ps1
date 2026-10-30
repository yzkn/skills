# run.ps1 — 長時間ジョブを OS に detach して起動する（セッションリミット耐性）
# このスクリプトはジョブディレクトリ内で自己完結し、Claude Code / リポジトリのパスに依存しない。
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$jobDir     = $PSScriptRoot
$cmdFile    = Join-Path $jobDir 'command.txt'
$statusFile = Join-Path $jobDir 'status.json'
$exitFile   = Join-Path $jobDir 'exit.code'
$worker     = Join-Path $jobDir '_worker.ps1'

if (-not (Test-Path $cmdFile)) { throw "command.txt が見つかりません: $cmdFile" }

# 二重起動ガード（実行中なら何もしない）
if (Test-Path $statusFile) {
  try { $st = Get-Content -Raw -LiteralPath $statusFile | ConvertFrom-Json } catch { $st = $null }
  if ($st -and $st.state -eq 'running' -and $st.processId -and (Get-Process -Id $st.processId -ErrorAction SilentlyContinue)) {
    Write-Host "既に実行中です (PID=$($st.processId))。状態は check.ps1 で確認してください。"
    exit 0
  }
}

# 前回の完了マーカーを掃除
Remove-Item -LiteralPath $exitFile -ErrorAction SilentlyContinue

$startedAt = (Get-Date).ToString('o')

# ワーカーを親から切り離して隠しウィンドウで起動（Claude Code / ターミナルを閉じても継続）
$proc = Start-Process -FilePath 'powershell.exe' `
  -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$worker`"" `
  -WindowStyle Hidden -PassThru

[ordered]@{
  state     = 'running'
  processId = $proc.Id
  startedAt = $startedAt
  command   = (Get-Content -Raw -LiteralPath $cmdFile).Trim()
} | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8

Write-Host "起動しました。PID=$($proc.Id) 開始=$startedAt"
Write-Host "確認: powershell -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $jobDir 'check.ps1')`""
