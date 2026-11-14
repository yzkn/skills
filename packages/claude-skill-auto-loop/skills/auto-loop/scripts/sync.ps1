#requires -Version 7.0
<#
.SYNOPSIS
  指令リポジトリの同期。変更があればコミットし、取り込んで（pull --rebase）送る（push）。
.DESCRIPTION
  -PullOnly なら取り込みだけ。競合したら rebase を取り消して報告する（強制の上書きはしない）。
  終了コード: 0 = 成功 / 1 = 失敗（理由を 1 行で出す）
.EXAMPLE
  pwsh -NoProfile -File sync.ps1 -PullOnly
  pwsh -NoProfile -File sync.ps1 -Message 'intake: my-app に 2 件起票'
#>
param(
    [string]$Message = '',
    [switch]$PullOnly
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }

if ($PullOnly) {
    $r = Update-ControlRepo $cfg
    Write-LoopLog 'sync' "pull-only -> $($r.Ok) $($r.Reason)"
    if ($r.Ok) { Write-Output "OK 取り込み（$($r.Reason)）"; exit 0 }
    Write-Output "NG 取り込めない（$($r.Reason)）: $($r.Detail)"; exit 1
}

if (-not $Message) { $Message = 'update' }
$r = Sync-ControlRepo $cfg "[$($cfg.agentId)] $Message"
Write-LoopLog 'sync' "sync '$Message' -> $($r.Ok) $($r.Reason)"
if ($r.Ok) { Write-Output "OK 同期（$($r.Reason)。コミット: $($r.Committed)、push: $($r.Pushed)）"; exit 0 }
$hint = switch ($r.Reason) {
    'conflict' { '同じ箇所を別のエージェントか利用者が書き換えている。git status と差分を見て、相手の内容を残す形で手で直す（強制の上書きはしない）' }
    'push' { '認証か権限を確かめる（preflight.ps1）' }
    'remote' { 'リモートに届かない。通信と認証を確かめる（preflight.ps1）' }
    default { '' }
}
$authHint = Get-GitFailureHint $cfg.controlRepoPath (Get-ControlRemote $cfg) $r.Detail
if ($authHint) { $hint = $authHint }
Write-Output "NG 同期できない（$($r.Reason)）: $($r.Detail)"
if ($hint) { Write-Output "   → $hint" }
exit 1
