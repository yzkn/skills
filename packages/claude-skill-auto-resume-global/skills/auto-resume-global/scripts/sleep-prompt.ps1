<#
.SYNOPSIS
  利用上限で止まったセッションの記録を確かめ、解除時刻にスリープから起こすタスクを用意してから、
  確認 (既定 120 秒) のうえ Windows をスリープする。sleep-on-limit.ps1 (StopFailure フック) が起動する。
.DESCRIPTION
  1. セッション記録の最後の会話が利用上限の記録 (Test-LimitRecord。auto-resume.ps1 と同じ判定) になるのを待つ (一時的な 429 ならスリープしない)
  2. 解除まで sleepMinMinutes (既定 15 分) 未満ならスリープしない
  3. auto-resume.ps1 を実行して、解除時刻 + 余裕 に復帰するタスク ClaudeAutoResumeGlobal-Wake を登録する
  4. 確認の画面を出す。「今すぐスリープ」か、応答が無いまま時間が過ぎたらスリープする。「キャンセル」で何もしない
     (復帰タスクが無い・スリープ解除タイマーが無効・バッテリ駆動中・gh / glab の認証が切れているなら、画面にその旨を出す)
     解除まで sleepMaxHours (既定 12 時間) より長ければ、時間が過ぎてもスリープしない (「今すぐスリープ」ならスリープする)
  同時に 1 つだけ (複数のセッションが同時に上限に当たっても、確認は 1 つ)。
.PARAMETER TranscriptPath
  セッション記録 (~/.claude/projects/<プロジェクト>/<セッション ID>.jsonl)
.PARAMETER Seconds
  確認の秒数。0 なら config.json の sleepPromptSeconds (既定 120)
.PARAMETER DryRun
  タスクの登録もスリープもせず、判断をログに書くだけ
.PARAMETER SimulateClick
  試験用: 確認の画面を出してすぐに、そのボタン (sleep / cancel) を押す
.PARAMETER CheckAuthOnly
  gh / glab の認証だけを確かめて表示し、終わる (確認の画面は出さない。-TranscriptPath は要らない)
#>
param(
    [string]$TranscriptPath,
    [int]$Seconds = 0,
    [int]$WaitRecordSeconds = 20,
    [switch]$DryRun,
    [ValidateSet('', 'sleep', 'cancel')][string]$SimulateClick = '',
    [switch]$CheckAuthOnly
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

# 無人で再開したセッションが使いそうなコマンドラインのログインを確かめ、切れているものの注意の文を返す。
# gh / glab が PATH にあるときだけ。それぞれ 10 秒で打ち切る (打ち切りは注意にしない)。判定は終了コードだけで、出力は読み捨てる (トークンを表示しない)
function Get-AuthWarnings {
    $checks = @(
        @{ Name = 'gh'; Arguments = 'auth status'; Text = 'GitHub (gh) の認証が切れています。再開後の push / PR が止まります (gh auth login)' },
        @{ Name = 'glab'; Arguments = 'auth status'; Text = 'GitLab (glab) の認証が切れています。再開後の push / MR が止まります (glab auth login --hostname gitlab.com --web)' }
    )
    $result = @()
    foreach ($c in $checks) {
        $cmd = Get-Command $c.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { continue }
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $cmd.Source
        $psi.Arguments = $c.Arguments
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        try { $p = [Diagnostics.Process]::Start($psi) } catch { continue }
        try {
            $p.StandardInput.Close()
            $null = $p.StandardOutput.ReadToEndAsync()   # 詰まらないように読み捨てる
            $null = $p.StandardError.ReadToEndAsync()
            if (-not $p.WaitForExit(10000)) {
                # 時間切れ: 注意にしない。子プロセスごと止める (Kill(true) の無い .NET Framework (PowerShell 5.1) では本体だけ)
                try { $p.Kill($true) } catch { try { $p.Kill() } catch { } }
                continue
            }
            $p.WaitForExit()
            if ($p.ExitCode -ne 0) { $result += $c.Text }
        } finally { $p.Dispose() }
    }
    return $result
}

if ($CheckAuthOnly) {
    $auth = @(Get-AuthWarnings)
    if ($auth.Count -gt 0) { $auth | ForEach-Object { Write-Output "※ $_" } } else { Write-Output '認証は有効です' }
    exit 0
}
if (-not $TranscriptPath) { throw '-TranscriptPath を指定してください' }

$mutex = New-Object Threading.Mutex($false, 'Local\ClaudeAutoResumeGlobal-Sleep')
if (-not $mutex.WaitOne(0)) { exit 0 }   # 別のセッションの確認がもう出ている
try {
    $cfg = Get-Content (Join-Path $Root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Seconds -le 0) { $Seconds = if ($cfg.PSObject.Properties['sleepPromptSeconds']) { [int]$cfg.sleepPromptSeconds } else { 120 } }
    $minMinutes = if ($cfg.PSObject.Properties['sleepMinMinutes']) { [double]$cfg.sleepMinMinutes } else { 15 }
    $maxHours = if ($cfg.PSObject.Properties['sleepMaxHours']) { [double]$cfg.sleepMaxHours } else { 12 }

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

    # 利用上限の記録か (auto-resume.ps1 と sleep-prompt.ps1 で同じ判定)。
    # - apiError が usage_limit_reached (5 時間・週の上限) か model_requires_usage_credits (モデルごとの上限。2026-11-14 に実物で確認)
    # - または error が rate_limit で、解除時刻 (resetsAt) が apiErrorParams.rate_limit_info か quotaLimits にある
    #   (解除時刻の無い rate_limit は、一時的な 429 とみなす)
    function Test-LimitRecord($Record) {
        if (-not $Record -or $Record.type -ne 'assistant') { return $false }
        if ($Record.PSObject.Properties['apiError'] -and $Record.apiError -in @('usage_limit_reached', 'model_requires_usage_credits')) { return $true }
        if (-not ($Record.PSObject.Properties['error'] -and $Record.error -eq 'rate_limit')) { return $false }
        $infos = @()
        if ($Record.PSObject.Properties['apiErrorParams'] -and $Record.apiErrorParams -and $Record.apiErrorParams.PSObject.Properties['rate_limit_info']) { $infos += $Record.apiErrorParams.rate_limit_info }
        if ($Record.PSObject.Properties['quotaLimits'] -and $Record.quotaLimits) { $infos += $Record.quotaLimits }
        foreach ($info in $infos) { if ($info -and $info.PSObject.Properties['resetsAt'] -and $info.resetsAt) { return $true } }
        return $false
    }

    # セッション記録の末尾 MaxBytes バイトを読み、行に分けて返す (auto-resume.ps1 と sleep-prompt.ps1 で同じもの)。
    # Get-Content -Tail は、末尾に巨大な行 (30 万文字を超えるもの) があると 30 秒以上かかる (2026-11-14 に実測) ため、バイト単位で直接読む。
    # 読み始めがファイルの途中なら、最初の行は切れているので捨てる。FromStart: ファイルの先頭から読んだ (これ以上さかのぼれない)
    function Read-SessionTail([string]$Path, [long]$MaxBytes = 4MB) {
        $fs = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try {
            $start = [math]::Max([long]0, $fs.Length - $MaxBytes)
            [void]$fs.Seek($start, [IO.SeekOrigin]::Begin)
            $buf = [byte[]]::new([int]($fs.Length - $start))
            $n = 0
            while ($n -lt $buf.Length) {
                $k = $fs.Read($buf, $n, $buf.Length - $n)
                if ($k -le 0) { break }
                $n += $k
            }
        } finally { $fs.Dispose() }
        $text = [Text.Encoding]::UTF8.GetString($buf, 0, $n)
        [string[]]$lines = $text.Split([char]"`n")
        for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i].EndsWith("`r")) { $lines[$i] = $lines[$i].Substring(0, $lines[$i].Length - 1) } }
        if ($start -gt 0) { if ($lines.Length -gt 1) { $lines = $lines[1..($lines.Length - 1)] } else { $lines = @() } }
        return [pscustomobject]@{ Lines = $lines; Text = $text; FromStart = ($start -eq 0) }
    }

    $getLimit = {
        if (-not (Test-Path -LiteralPath $TranscriptPath)) { return $null }
        # まず末尾 4 MB。その中に会話の記録が無く、記録がもっと大きければ 32 MB で読み直す (auto-resume.ps1 の Get-LastTurn と同じ)
        foreach ($max in 4MB, 32MB) {
            $tail = Read-SessionTail $TranscriptPath $max
            $lines = $tail.Lines
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                if (-not $lines[$i].StartsWith('{"parentUuid"')) { continue }
                try { $r = $lines[$i] | ConvertFrom-Json } catch { continue }
                if (($r.type -ne 'user' -and $r.type -ne 'assistant') -or $r.isSidechain) { continue }
                if (& $isSynthetic $r) { continue }
                if (Test-LimitRecord $r) { return $r }
                return $null
            }
            if ($tail.FromStart) { break }
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
    # 解除まで sleepMaxHours より長ければ (週の上限など)、応答が無くてもスリープしない。何日も眠らせたままにしない
    $hoursLeft = if ($resetsAt) { ($resetsAt - (Get-Date)).TotalHours } else { $null }
    $noAutoSleep = ($null -ne $hoursLeft) -and $hoursLeft -gt $maxHours
    $hoursText = if ($null -ne $hoursLeft) { [math]::Round($hoursLeft, 1) } else { '' }

    # 3. 解除時刻に復帰するタスク (auto-resume.ps1 が登録する)
    if (-not $DryRun) {
        & $cfg.shellPath -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'auto-resume.ps1') | Out-Null
    }
    $warnings = @()
    $wakeTask = Get-ScheduledTask -TaskName 'ClaudeAutoResumeGlobal-Wake' -ErrorAction SilentlyContinue
    $wakeAt = if ($wakeTask) { (Get-ScheduledTaskInfo -TaskName 'ClaudeAutoResumeGlobal-Wake').NextRunTime } else { $null }
    if (-not $wakeAt) { $warnings += '解除時刻に復帰するタスクがありません。自動では復帰しません。' }
    $rtc = @(powercfg /query SCHEME_CURRENT SUB_SLEEP RTCWAKE | Select-String -Pattern '0x[0-9a-fA-F]{8}\s*$' | ForEach-Object { [Convert]::ToInt32($_.Matches[0].Value.Trim(), 16) })
    if ($rtc.Count -ge 2 -and $rtc[-2] -ne 1) { $warnings += 'スリープ解除タイマー (電源接続時) が「有効」ではありません (install.ps1 -EnableWakeTimers)。' }
    if ($cfg.action -eq 'wake') { $warnings += 'action が wake のため、復帰しても再開しません (install.ps1 -Action resume)。' }
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($battery -and $battery.BatteryStatus -eq 1) { $warnings += 'バッテリ駆動中です。バッテリ駆動時のスリープ解除タイマーの設定によっては復帰しません。' }
    # 再開したセッションが push などで止まらないよう、gh / glab の認証を確かめる
    $warnings += @(Get-AuthWarnings)
    $note = if ($warnings) { ' 注意: ' + ($warnings -join ' ') } else { '' }

    # 4. 確認
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $resetText = if ($resetsAt) { $resetsAt.ToString('MM/dd HH:mm') } else { '不明' }
    $wakeText = if ($wakeAt) { $wakeAt.ToString('MM/dd HH:mm') } else { 'なし' }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Claude Code: 利用上限に達しました'
    $form.Width = 520; $form.Height = 360
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false; $form.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label
    $label.Left = 16; $label.Top = 14; $label.Width = 480; $label.Height = 230
    $label.Font = New-Object System.Drawing.Font('Yu Gothic UI', 10)
    $form.Controls.Add($label)
    $btnSleep = New-Object System.Windows.Forms.Button
    $btnSleep.Text = '今すぐスリープ'; $btnSleep.Left = 210; $btnSleep.Top = 260; $btnSleep.Width = 130; $btnSleep.Height = 34
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'キャンセル'; $btnCancel.Left = 350; $btnCancel.Top = 260; $btnCancel.Width = 130; $btnCancel.Height = 34
    $form.Controls.Add($btnSleep); $form.Controls.Add($btnCancel)
    $form.AcceptButton = $btnSleep; $form.CancelButton = $btnCancel
    $script:result = 'cancel'   # 閉じるボタン (×) もキャンセル
    $script:left = $Seconds
    $render = {
        $lines = @("$kind の利用上限に達しました (解除 $resetText)。", "解除時刻に復帰するタスク: $wakeText", '')
        $lines += $warnings | ForEach-Object { "※ $_" }
        if ($noAutoSleep) {
            $lines += @('', "解除まで $hoursText 時間あるため (sleepMaxHours $maxHours 時間を超える)、$($script:left) 秒たってもスリープしません。スリープするなら「今すぐスリープ」を押してください。")
        } else {
            $lines += @('', "$($script:left) 秒後に Windows をスリープします。キャンセルするとスリープしません。")
        }
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

    if ($script:result -eq 'cancel') { Write-Log "キャンセル: スリープしない ($kind、解除 $resetText)$note"; exit 0 }
    if ($script:result -eq 'timeout' -and $noAutoSleep) {
        Write-Log ("スリープしない: 解除まで {0} 時間 (sleepMaxHours {1} 時間を超える) ({2}、解除 {3}、復帰タスク {4}){5}" -f $hoursText, $maxHours, $kind, $resetText, $wakeText, $note)
        exit 0
    }
    Write-Log ("スリープする ({0}: {1}、解除 {2}、復帰タスク {3}){4}" -f $script:result, $kind, $resetText, $wakeText, $note)
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
