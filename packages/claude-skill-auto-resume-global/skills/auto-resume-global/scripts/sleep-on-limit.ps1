<#
.SYNOPSIS
  Claude Code の StopFailure フック (matcher: rate_limit) から呼ばれる。利用上限で止まったら、確認のうえ Windows をスリープする。
.DESCRIPTION
  Claude Code を待たせないよう、確認 (sleep-prompt.ps1) を別のプロセスで起動して、すぐに終わる。
  一時的な 429 (利用上限でないもの) でも error は rate_limit になるため、利用上限かどうかは sleep-prompt.ps1 がセッション記録で確かめる。
  標準入力: フックの JSON ({ session_id, transcript_path, cwd, hook_event_name, error, error_details, last_assistant_message })
  config.json の sleepOnLimit が true のときだけ動く (install.ps1 -EnableSleepOnLimit)。disabled ファイルがあれば何もしない。
#>
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
try {
    if (Test-Path (Join-Path $Root 'disabled')) { exit 0 }
    $cfg = Get-Content (Join-Path $Root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not ($cfg.PSObject.Properties['sleepOnLimit'] -and $cfg.sleepOnLimit)) { exit 0 }
    $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if ($hook.error -ne 'rate_limit' -or -not $hook.transcript_path) { exit 0 }
    $quote = { param($s) if ($s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s } }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden',
        '-File', (Join-Path $Root 'sleep-prompt.ps1'), '-TranscriptPath', $hook.transcript_path) | ForEach-Object { & $quote $_ }
    Start-Process -FilePath $cfg.shellPath -ArgumentList $argList -WindowStyle Hidden
}
catch {
    # フックの失敗で Claude Code を妨げない (StopFailure の終了コードは無視されるが、念のため 0 で終わる)
}
exit 0
