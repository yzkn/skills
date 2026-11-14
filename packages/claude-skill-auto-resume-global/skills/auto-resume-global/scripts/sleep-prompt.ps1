<#
.SYNOPSIS
  利用上限で止まったセッションの記録を確かめ、解除時刻にスリープから起こすタスクを用意してから、
  確認 (既定 120 秒) のうえ Windows をスリープする。sleep-on-limit.ps1 (StopFailure フック) が起動する。
.DESCRIPTION
  1. セッション記録の最後の会話が「apiError = usage_limit_reached」になるのを待つ (一時的な 429 ならスリープしない)
  2. 解除まで sleepMinMinutes (既定 15 分) 未満ならスリープしない
  3. auto-resume.ps1 を実行して、解除時刻 + 余裕 に復帰するタスク ClaudeAutoResume-Wake を登録する
  4. 確認の画面を出す。「今すぐスリープ」か、応答が無いまま時間が過ぎたらスリープする。「キャンセル」で何もしない
     (復帰タスクが無い・スリープ解除タイマーが無効・バッテリ駆動中なら、画面にその旨を出す)
  同時に 1 つだけ (複数のセッションが同時に上限に当たっても、確認は 1 つ)。
.PARAMETER TranscriptPath
  セッション記録 (~/.claude/projects/<プロジェクト>/<セッション ID>.jsonl)
.PARAMETER Seconds
  確認の秒数。0 なら config.json の sleepPromptSeconds (既定 120)
.PARAMETER DryRun
  タスクの登録もスリープもせず、判断をログに書くだけ
.PARAMETER SimulateClick
  試験用: 確認の画面を出してすぐに、そのボタン (sleep / cancel) を押す
#>
param(
    [Parameter(Mandatory)][string]$TranscriptPath,
    [int]$Seconds = 0,
    [int]$WaitRecordSeconds = 20,
    [switch]$DryRun,
    [ValidateSet('', 'sleep', 'cancel')][string]$SimulateClick = ''
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$LogDir = Join-Path $Root 'logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = Join-Path $LogDir 'auto-resume.log'
function Write-Log([string]$Message) {
    $line = '{0} [sleep] {1}{2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message, $(if ($DryRun) { ' (DryRun)' } else { '' })
    [IO.File]::AppendAllText($LogFile, $line + "`r`n", (New-Object Text.UTF8Encoding $false))
    if ($DryRun) { Write-Host $line }
}

$mutex = New-Object Threading.Mutex($false, 'Local\ClaudeSleepOnLimit')
if (-not $mutex.WaitOne(0)) { exit 0 }   # 別のセッションの確認がもう出ている
try {
    $cfg = Get-Content (Join-Path $Root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Seconds -le 0) { $Seconds = if ($cfg.PSObject.Properties['sleepPromptSeconds']) { [int]$cfg.sleepPromptSeconds } else { 120 } }
    $minMinutes = if ($cfg.PSObject.Properties['sleepMinMinutes']) { [double]$cfg.sleepMinMinutes } else { 15 }

    # 1. 利用上限の記録 (最後の会話の記録。auto-resume.ps1 と同じ判定)
    # 利用者の入力ではない user の記録か (サブエージェントの通知 <task-notification>、isMeta の記録など)。
    # サブエージェントを動かしている間に上限に当たると、上限の記録の「あと」にこれらが付く。auto-resume.ps1 の Test-SyntheticUser と同じ判定
    $isSynthetic = {
        param($r)
        if ($r.type -ne 'user') { return $false }
        if ($r.PSObject.Properties['isMeta'] -and $r.isMeta) { return $true }
        if ($r.PSObject.Properties['origin'] -and $r.origin -and $r.origin.PSObject.Properties['kind']) { return ($r.origin.kind -ne 'human') }
        if ($r.PSObject.Properties['promptSource'] -and $r.promptSource -eq 'system') { return $true }
        $content = if ($r.message) { $r.message.content } else { $null }
        return ($content -is [string] -and $content -match '^\s*<(task-notification|system-reminder)>')
    }
    $getLimit = {
        if (-not (Test-Path -LiteralPath $TranscriptPath)) { return $null }
        # まず末尾 80 行。上限の記録のあとの通知だけで埋まっていたら、400 行まで広げる (auto-resume.ps1 の Get-LastTurn と同じ)
        foreach ($count in 80, 400) {
            $tail = @(Get-Content -LiteralPath $TranscriptPath -Tail $count -Encoding UTF8)
            for ($i = $tail.Count - 1; $i -ge 0; $i--) {
                if (-not $tail[$i].StartsWith('{"parentUuid"')) { continue }
                try { $r = $tail[$i] | ConvertFrom-Json } catch { continue }
                if (($r.type -ne 'user' -and $r.type -ne 'assistant') -or $r.isSidechain) { continue }
                if (& $isSynthetic $r) { continue }
                if ($r.type -eq 'assistant' -and $r.PSObject.Properties['apiError'] -and $r.apiError -eq 'usage_limit_reached') { return $r }
                return $null
            }
            if ($tail.Count -lt $count) { break }
        }
        return $null
    }
    $deadline = (Get-Date).AddSeconds($WaitRecordSeconds)
    $rec = & $getLimit
    while (-not $rec -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500; $rec = & $getLimit }
    if (-not $rec) { Write-Log "スリープしない: 利用上限の記録が無い (一時的な 429 など) $TranscriptPath"; exit 0 }

    $resetsAt = $null
    $kind = 'unknown'
    if ($rec.PSObject.Properties['apiErrorParams'] -and $rec.apiErrorParams.PSObject.Properties['rate_limit_info']) {
        $info = $rec.apiErrorParams.rate_limit_info
        if ($info.PSObject.Properties['resetsAt'] -and $info.resetsAt) { $resetsAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$info.resetsAt).LocalDateTime }
        if ($info.PSObject.Properties['rateLimitType']) { $kind = $info.rateLimitType }
    }
    # 2. 解除が近ければスリープしない
    if ($resetsAt -and ($resetsAt - (Get-Date)).TotalMinutes -lt $minMinutes) {
        Write-Log ("スリープしない: 解除 ({0}) まで {1} 分未満" -f $resetsAt.ToString('MM/dd HH:mm'), $minMinutes)
        exit 0
    }

    # 3. 解除時刻に復帰するタスク (auto-resume.ps1 が登録する)
    if (-not $DryRun) {
        & $cfg.shellPath -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'auto-resume.ps1') | Out-Null
    }
    $warnings = @()
    $wakeTask = Get-ScheduledTask -TaskName 'ClaudeAutoResume-Wake' -ErrorAction SilentlyContinue
    $wakeAt = if ($wakeTask) { (Get-ScheduledTaskInfo -TaskName 'ClaudeAutoResume-Wake').NextRunTime } else { $null }
    if (-not $wakeAt) { $warnings += '解除時刻に復帰するタスクがありません。自動では復帰しません。' }
    $rtc = @(powercfg /query SCHEME_CURRENT SUB_SLEEP RTCWAKE | Select-String -Pattern '0x[0-9a-fA-F]{8}\s*$' | ForEach-Object { [Convert]::ToInt32($_.Matches[0].Value.Trim(), 16) })
    if ($rtc.Count -ge 2 -and $rtc[-2] -ne 1) { $warnings += 'スリープ解除タイマー (電源接続時) が「有効」ではありません (install.ps1 -EnableWakeTimers)。' }
    if ($cfg.action -eq 'wake') { $warnings += 'action が wake のため、復帰しても再開しません (install.ps1 -Action resume)。' }
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($battery -and $battery.BatteryStatus -eq 1) { $warnings += 'バッテリ駆動中です。バッテリ駆動時のスリープ解除タイマーの設定によっては復帰しません。' }

    # 4. 確認
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $resetText = if ($resetsAt) { $resetsAt.ToString('MM/dd HH:mm') } else { '不明' }
    $wakeText = if ($wakeAt) { $wakeAt.ToString('MM/dd HH:mm') } else { 'なし' }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Claude Code: 利用上限に達しました'
    $form.Width = 520; $form.Height = 300
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false; $form.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label
    $label.Left = 16; $label.Top = 14; $label.Width = 480; $label.Height = 170
    $label.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10)
    $form.Controls.Add($label)
    $btnSleep = New-Object System.Windows.Forms.Button
    $btnSleep.Text = '今すぐスリープ'; $btnSleep.Left = 210; $btnSleep.Top = 200; $btnSleep.Width = 130; $btnSleep.Height = 34
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'キャンセル'; $btnCancel.Left = 350; $btnCancel.Top = 200; $btnCancel.Width = 130; $btnCancel.Height = 34
    $form.Controls.Add($btnSleep); $form.Controls.Add($btnCancel)
    $form.AcceptButton = $btnSleep; $form.CancelButton = $btnCancel
    $script:result = 'cancel'   # 閉じるボタン (×) もキャンセル
    $script:left = $Seconds
    $render = {
        $lines = @("$kind の利用上限に達しました (解除 $resetText)。", "解除時刻に復帰するタスク: $wakeText", '')
        $lines += $warnings | ForEach-Object { "※ $_" }
        $lines += @('', "$($script:left) 秒後に Windows をスリープします。キャンセルするとスリープしません。")
        $label.Text = $lines -join "`r`n"
    }
    & $render
    $btnSleep.Add_Click({ $script:result = 'sleep'; $form.Close() })
    $btnCancel.Add_Click({ $script:result = 'cancel'; $form.Close() })
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        $script:left--
        if ($script:left -le 0) { $script:result = 'timeout'; $timer.Stop(); $form.Close() } else { & $render }
    })
    $form.Add_Shown({
        $form.Activate()
        $timer.Start()
        if ($SimulateClick -eq 'sleep') { $btnSleep.PerformClick() } elseif ($SimulateClick -eq 'cancel') { $btnCancel.PerformClick() }
    })
    [void]$form.ShowDialog()
    $timer.Dispose(); $form.Dispose()

    if ($script:result -eq 'cancel') { Write-Log "キャンセル: スリープしない ($kind、解除 $resetText)"; exit 0 }
    Write-Log ("スリープする ({0}: {1}、解除 {2}、復帰タスク {3}){4}" -f $script:result, $kind, $resetText, $wakeText, $(if ($warnings) { ' 注意: ' + ($warnings -join ' ') } else { '' }))
    if (-not $DryRun) {
        # Suspend (スリープ)。第 3 引数 false でスリープ解除のイベント (復帰タスク) を有効のままにする
        [void][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false)
    }
}
catch {
    Write-Log "エラー: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"
}
finally {
    $mutex.ReleaseMutex()
}
