<#
.SYNOPSIS
  自動再開のタスクを削除する。
  -RestoreWakeTimers で、スリープ解除タイマー (電源接続時) を install.ps1 -EnableWakeTimers の前の値に戻す。
  ~/.claude/settings.json に足したフック (StopFailure の sleep-on-limit.ps1) も外す。
  スクリプト・設定・ログ (このフォルダ) は残す。一時的に止めるだけなら、このフォルダに disabled という空ファイルを置く。
#>
param([switch]$RestoreWakeTimers, [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json'))
# 前の版の名前 (ClaudeAutoResume / ClaudeAutoResume-Wake) が残っていれば、それも消す
foreach ($name in @('ClaudeAutoResumeGlobal', 'ClaudeAutoResumeGlobal-Wake', 'ClaudeAutoResume', 'ClaudeAutoResume-Wake')) {
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "削除: $name"
    }
}
if ($RestoreWakeTimers) {
    $before = Join-Path $PSScriptRoot 'state\wake-timer-before.txt'
    # 記録が無ければ Windows の既定に近い「重要なスリープ解除タイマーのみ」(2) にする
    $value = if (Test-Path $before) { [int](Get-Content $before -Raw).Trim() } else { 2 }
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE $value
    powercfg /setactive SCHEME_CURRENT
    if (Test-Path $before) { Remove-Item -LiteralPath $before }
    Write-Host "スリープ解除タイマー (電源接続時) を元の値 ($value) に戻しました (0: 無効 / 1: 有効 / 2: 重要なスリープ解除タイマーのみ)"
}

# 上限で止まったらスリープするフックを外す (ほかのフックは残す)
if (Test-Path $SettingsPath) {
    $settings = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['StopFailure']) {
        $groups = @()
        foreach ($g in @($settings.hooks.StopFailure)) {
            $rest = @($g.hooks | Where-Object { $_.command -notlike '*sleep-on-limit.ps1*' })
            if ($rest.Count -gt 0) { $g.hooks = $rest; $groups += $g }
        }
        if ($groups.Count -gt 0) { $settings.hooks.StopFailure = $groups } else { $settings.hooks.PSObject.Properties.Remove('StopFailure') }
        [IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
        Write-Host "フック StopFailure (sleep-on-limit.ps1) を外しました: $SettingsPath"
    }
}
