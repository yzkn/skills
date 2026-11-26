#requires -Version 7.0
<#
.SYNOPSIS
  Claude Code のステータスラインに挟み、利用率（5 時間・週）を state/usage.json に書き出す。表示は元のコマンドに任せる。
.DESCRIPTION
  install.ps1 -CaptureUsage が ~/.claude/settings.json の statusLine.command をこのスクリプトに置き換え、元のコマンドを
  ~/.claude/auto-loop/config.json の usage.statusLineCommand に控える（-NoCaptureUsage で戻す）。
    1. 標準入力の JSON（Claude Code が渡す）の rate_limits.five_hour / seven_day の used_percentage（0〜100）と resets_at（epoch 秒）を、
       state/usage.json（capturedAt・fiveHour・sevenDay の usedPercentage・resetsAt）に書く。rate_limits は Pro・Max の契約で、
       セッションの最初の応答のあとだけ出る。無ければ書かない（前の値を残す）
    2. usage.statusLineCommand があれば、同じ JSON を渡して呼び、その出力をそのまま返す（無ければ何も表示しない）
  kick.ps1 が、この値を PC の状況（state/pcs/<ID>.json の usage）に載せ、ダッシュボードが PC の表に出す。
  失敗しても、表示（2）は続ける。利用枠（トークン）を使わない。
.EXAMPLE
  （ステータスラインとして）pwsh -NoProfile -File statusline-usage.ps1
#>
param()
$ErrorActionPreference = 'Continue'
$utf8 = [Text.UTF8Encoding]::new($false)
try { [Console]::InputEncoding = $utf8; [Console]::OutputEncoding = $utf8 } catch { }
$OutputEncoding = $utf8
$raw = [Console]::In.ReadToEnd()

try {
    Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force
    $snap = ConvertTo-UsageSnapshot ($raw | ConvertFrom-Json)
    if ($snap) { Save-UsageSnapshot $snap }
}
catch { }

$inner = ''
try {
    $cfgFile = Join-Path $(if ($env:AUTO_LOOP_HOME) { $env:AUTO_LOOP_HOME } else { Join-Path $HOME '.claude/auto-loop' }) 'config.json'
    $c = [IO.File]::ReadAllText($cfgFile, $utf8) | ConvertFrom-Json
    if ($c.PSObject.Properties.Name -contains 'usage' -and $c.usage -and $c.usage.statusLineCommand) { $inner = [string]$c.usage.statusLineCommand }
}
catch { }
if (-not $inner -or $inner -match 'statusline-usage\.ps1') { exit 0 }   # 自分自身を呼び返さない
if ($IsWindows) { $raw | & cmd.exe /d /s /c $inner }
else { $raw | & sh -c $inner }
exit $LASTEXITCODE
