# long-run.ps1 — 長時間ジョブのスキャフォールド生成エンジン（/long-run スキル）
# セッションリミットに強い detach 実行ジョブを .jobs/<id>/ に生成する。
#   create: ジョブディレクトリを生成（-Start で即起動。-Intent で完了後にやることを残す）
#   list  : 既存ジョブの状態一覧（完了済みで未報告のものに ★未回収 を付す）
#   claim : 結果をユーザーへ報告し終えたジョブを回収済みにする（collected マーカーを作る）
#
# collected マーカーは SessionStart フック（.claude/hooks/job-resume-check.ps1）が参照し、
# 「完了しているが未報告」のジョブがある場合だけ再開を促す。報告前に claim してはならない。
[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('create','list','claim')][string]$Action = 'create',
  [string]$Name = 'job',
  [string]$Command,
  [string]$Root = '.jobs',
  [string]$Id,
  [string]$Intent,
  [switch]$All,
  [switch]$Start
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$scriptDir = $PSScriptRoot
$tplDir = Join-Path $scriptDir '..\skills\long-run\templates'

function Set-BomFile {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function New-LongRunJob {
  param([string]$Name, [string]$Command, [string]$Root, [string]$Intent, [switch]$Start)
  if ([string]::IsNullOrWhiteSpace($Command)) {
    throw '-Command は必須です（例: -Command "npm run build"）'
  }
  $safe = ($Name -replace '[^\w\-]', '_'); if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'job' }
  $id = '{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $safe
  $jobDir = Join-Path $Root $id
  New-Item -ItemType Directory -Force -Path $jobDir | Out-Null

  Set-BomFile (Join-Path $jobDir 'command.txt') $Command
  Copy-Item (Join-Path $tplDir 'run.ps1')    (Join-Path $jobDir 'run.ps1')     -Force
  Copy-Item (Join-Path $tplDir 'worker.ps1') (Join-Path $jobDir '_worker.ps1') -Force
  Copy-Item (Join-Path $tplDir 'check.ps1')  (Join-Path $jobDir 'check.ps1')   -Force

  # テンプレートは BOM なし UTF-8。PowerShell 5.1 の Get-Content は既定で ANSI(cp932) として
  # 読むため、-Encoding UTF8 を明示しないと日本語が文字化けする。
  $readme = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $tplDir 'README.win.md')).Replace('{{ID}}', $id).Replace('{{COMMAND}}', $Command)
  Set-BomFile (Join-Path $jobDir 'README.md') $readme

  # 再開意図: 会話履歴を持たない新しいセッションで開き直したときに読ませる
  if ([string]::IsNullOrWhiteSpace($Intent)) {
    $Intent = '（未記入）このジョブの完了後に何をすべきかが記録されていません。README.md と stdout.log を読み、何を依頼されていたかをユーザーに確認してください。'
  }
  $checkCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File {0}/{1}/check.ps1' -f $Root, $id
  $claimCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/long-run.ps1 claim -Id {0}' -f $id
  $intentDoc = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $tplDir 'resume-intent.md')).Replace('{{ID}}', $id).Replace('{{INTENT}}', $Intent).Replace('{{COMMAND}}', $Command).Replace('{{CHECK}}', $checkCmd).Replace('{{CLAIM}}', $claimCmd)
  Set-BomFile (Join-Path $jobDir 'resume-intent.md') $intentDoc

  Write-Host "ジョブを作成しました: $jobDir"
  if ($Start) {
    & (Join-Path $jobDir 'run.ps1')
  } else {
    Write-Host ('起動: powershell -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $jobDir 'run.ps1'))
  }
}

function Get-LongRunJobs {
  param([string]$Root)
  $dirs = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue
  if (-not $dirs) { Write-Host "ジョブはありません ($Root)"; return }
  foreach ($d in $dirs) {
    $ef = Join-Path $d.FullName 'exit.code'
    $sf = Join-Path $d.FullName 'status.json'
    $cf = Join-Path $d.FullName 'collected'
    $state = '未起動'
    if (Test-Path $ef) {
      $state = '完了(code={0})' -f (Get-Content -Raw -LiteralPath $ef).Trim()
    } elseif (Test-Path $sf) {
      try { $st = Get-Content -Raw -LiteralPath $sf | ConvertFrom-Json } catch { $st = $null }
      if ($st -and $st.processId -and (Get-Process -Id $st.processId -ErrorAction SilentlyContinue)) { $state = '実行中' } else { $state = '停止' }
    }
    $mark = ''
    if ((Test-Path $ef) -and (-not (Test-Path $cf))) { $mark = '  ★未回収' }
    Write-Host ('{0}  [{1}]{2}' -f $d.Name, $state, $mark)
  }
}

function Set-LongRunClaimed {
  param([string]$Root, [string]$Id, [switch]$All)
  if (-not (Test-Path -LiteralPath $Root)) { Write-Host "ジョブはありません ($Root)"; return }
  if ($All) {
    $targets = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue)
  } elseif ([string]::IsNullOrWhiteSpace($Id)) {
    throw '-Id <ジョブID> か -All を指定してください'
  } else {
    $d = Join-Path $Root $Id
    if (-not (Test-Path -LiteralPath $d)) { throw ('ジョブが見つかりません: {0}' -f $d) }
    $targets = @(Get-Item -LiteralPath $d)
  }
  $n = 0
  foreach ($t in $targets) {
    $ef = Join-Path $t.FullName 'exit.code'
    $cf = Join-Path $t.FullName 'collected'
    # 未完了のジョブを回収済みにすると、完了後に再開通知が出なくなるため保護する
    if (-not (Test-Path -LiteralPath $ef)) {
      Write-Host ('スキップ（未完了。exit.code がありません）: {0}' -f $t.Name)
      continue
    }
    if (Test-Path -LiteralPath $cf) { continue }
    Set-BomFile $cf ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' 回収済み（結果をユーザーへ報告済み）')
    Write-Host ('回収済みにしました: {0}' -f $t.Name)
    $n++
  }
  if ($n -eq 0) { Write-Host '対象はありませんでした（すべて回収済み）' }
}

switch ($Action) {
  'create' { New-LongRunJob -Name $Name -Command $Command -Root $Root -Intent $Intent -Start:$Start }
  'list'   { Get-LongRunJobs -Root $Root }
  'claim'  { Set-LongRunClaimed -Root $Root -Id $Id -All:$All }
}
