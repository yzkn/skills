# resume-watch.ps1 — セッションリミット(429)解除後の自動再開: 制御 CLI
#
# 5 時間のセッションリミットに当たると、解除時刻はトランスクリプト .jsonl の
# quotaLimits.resetsAt にだけ記録される（平常時のレコードには存在しない。ADR-039 実測）。
# そのため「事前に時刻を知って待つ」ことはできず、429 が起きた瞬間に気づく常駐ウォッチャーが要る。
#
# 待機は 2 系統を併用する（ADR-039 と同じ「独立 2 系統」の考え方）:
#   W1 常駐ウォッチャー (_resume-watcher.ps1) が自前で解除時刻まで待つ
#   W2 Windows タスクスケジューラのワンショットタスクが解除時刻に起動する
# 二重発火は .resume/fired/<resetsAt>.lock（New-Item の排他生成）で防ぐ。
#
# 解除時刻に行うこと（出口）:
#   R2 通知のみ（既定） … OS 通知を出し .resume/pending.json を置く。次にユーザーが
#                          Claude Code を開くと SessionStart フックが続きを提示する
#   R1 無人 headless 再開（オプトイン） … claude -p --resume を detach 起動する
#
# 使い方:
#   resume-watch.ps1 start -SessionId <id> -TranscriptPath <path>   ウォッチャー起動（フックから）
#   resume-watch.ps1 status                                          状態表示
#   resume-watch.ps1 stop                                            ウォッチャー停止＋予約タスク削除
#   resume-watch.ps1 intent -Text "<再開時にやること>"               再開意図を明示的に記録
#   resume-watch.ps1 optin [-MaxRuns <n>] / optout                   R1 の有効化 / 無効化
#   resume-watch.ps1 claim                                           再開通知を回収済みにする
#   resume-watch.ps1 disable / enable                                機構全体の停止 / 再開
#   resume-watch.ps1 arm  -ResetsAt <epoch> -SessionId <id>          （内部）W2 タスク登録
#   resume-watch.ps1 fire -ResetsAt <epoch> -SessionId <id>          （内部）解除時刻の処理

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'status',
    [string]$SessionId,
    [string]$TranscriptPath,
    [string]$Text,
    [long]$ResetsAt = 0,
    [int]$MaxRuns = 1,
    [int]$MaxIdleMinutes = 90
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateRoot  = Join-Path $RepoRoot '.resume'
$WatcherDir = Join-Path $StateRoot 'watchers'
$FiredDir   = Join-Path $StateRoot 'fired'
$HeadlessDir= Join-Path $StateRoot 'headless'
$LogFile    = Join-Path $StateRoot 'watch.log'
$StateFile  = Join-Path $StateRoot 'state.json'
$IntentFile = Join-Path $StateRoot 'intent.md'
$PendingFile= Join-Path $StateRoot 'pending.json'
$OptInFile  = Join-Path $StateRoot 'optin.json'
$RunsFile   = Join-Path $StateRoot 'runs.json'
$DisableFile= Join-Path $StateRoot 'disabled'
$StopFile   = Join-Path $StateRoot 'stop'
$TaskPrefix = 'ClaudeCodeAutoResume_'
$MaxWatchers = 4

function Initialize-State {
    foreach ($d in @($StateRoot, $WatcherDir, $FiredDir, $HeadlessDir)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Write-Log([string]$Message) {
    try {
        Initialize-State
        $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $PID, $Message
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    } catch {}
}

function ConvertFrom-Epoch([long]$Epoch) {
    return [System.DateTimeOffset]::FromUnixTimeSeconds($Epoch).ToLocalTime().DateTime
}

# ファイル名に使う人間可読なタイムスタンプ（解除時刻をローカル時刻で yyyymmddhhmmss 表記）。
# W1 と W2 は同じ epoch を引数に受け取り、それぞれ fire の中でこの関数を通すため、
# 双方が同一のファイル名を導出する（排他マーカーの成立条件）。
function Format-Stamp([long]$Epoch) {
    return (ConvertFrom-Epoch $Epoch).ToString('yyyyMMddHHmmss')
}

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Write-Json([string]$Path, $Object) {
    $Object | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}

# 生存しているウォッチャーを返し、死んだ pid ファイルを掃除する
function Get-LiveWatcher {
    Initialize-State
    $live = @()
    foreach ($f in (Get-ChildItem -LiteralPath $WatcherDir -Filter '*.pid' -ErrorAction SilentlyContinue)) {
        $info = Read-Json $f.FullName
        $alive = $false
        if ($info -and $info.processId) {
            $p = Get-Process -Id $info.processId -ErrorAction SilentlyContinue
            # PID の使い回しを避けるため、プロセス名が powershell 系であることも確認する
            if ($p -and ($p.ProcessName -like 'powershell*' -or $p.ProcessName -like 'pwsh*')) { $alive = $true }
        }
        if ($alive) { $live += $info } else { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    }
    return $live
}

function Show-Notification([string]$Title, [string]$Body) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $icon = New-Object System.Windows.Forms.NotifyIcon
        $icon.Icon = [System.Drawing.SystemIcons]::Information
        $icon.Visible = $true
        $icon.BalloonTipTitle = $Title
        $icon.BalloonTipText = $Body
        $icon.ShowBalloonTip(20000)
        Start-Sleep -Seconds 10
        $icon.Visible = $false
        $icon.Dispose()
    } catch { Write-Log ("通知の表示に失敗: " + $_.Exception.Message) }
}

# ------------------------------------------------------------------ start

function Invoke-Start {
    Initialize-State
    if (Test-Path -LiteralPath $DisableFile) { Write-Host '自動再開は disable されています（resume-watch.ps1 enable で再開）。'; return }
    if ($env:CLAUDE_AUTO_RESUME -eq '1') { Write-Host '無人再開で起動したセッションのため、ウォッチャーは起動しません。'; return }
    if (-not $SessionId -or -not $TranscriptPath) { Write-Host 'SessionId と TranscriptPath が必要です。'; return }

    Remove-Item -LiteralPath $StopFile -Force -ErrorAction SilentlyContinue

    # 発火済み・期限切れの予約タスクが溜まらないよう、1 時間以上前の解除時刻のものを掃除する
    # （StartWhenAvailable で復帰後に実行されるはずの猶予を 1 時間見ている）。
    # タスク名の末尾はローカル時刻の yyyymmddhhmmss なので、日時として解釈して比較する。
    $threshold = (Get-Date).AddHours(-1)
    foreach ($task in @(Get-ScheduledTask -TaskName ($TaskPrefix + '*') -ErrorAction SilentlyContinue)) {
        if ($task.TaskName -notmatch ([regex]::Escape($TaskPrefix) + '(\d{14})$')) { continue }
        $at = Get-Date
        $parsed = [datetime]::TryParseExact($Matches[1], 'yyyyMMddHHmmss',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None, [ref]$at)
        if ($parsed -and $at -lt $threshold) {
            try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; Write-Log ('期限切れの予約タスクを削除: ' + $task.TaskName) } catch {}
        }
    }

    # @() で包む: PowerShell 5.1 では単一要素の戻り値がスカラーに展開され .Count が取れない
    $live = @(Get-LiveWatcher)
    foreach ($w in $live) {
        if ($w.sessionId -eq $SessionId) { Write-Host ('既に監視中です (PID={0})。' -f $w.processId); return }
    }
    if ($live.Count -ge $MaxWatchers) {
        Write-Log ('ウォッチャー数が上限 {0} に達しているため起動を見送りました。' -f $MaxWatchers)
        Write-Host ('ウォッチャーが {0} 本動作中のため起動を見送りました。' -f $live.Count); return
    }

    $worker = Join-Path $PSScriptRoot '_resume-watcher.ps1'
    if (-not (Test-Path -LiteralPath $worker)) { Write-Log '_resume-watcher.ps1 が見つかりません。'; return }

    $proc = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$worker`"",
                      '-SessionId', $SessionId, '-TranscriptPath', "`"$TranscriptPath`"",
                      '-MaxIdleMinutes', $MaxIdleMinutes `
        -WorkingDirectory $RepoRoot -WindowStyle Hidden -PassThru

    Write-Json (Join-Path $WatcherDir ($SessionId + '.pid')) ([ordered]@{
        sessionId      = $SessionId
        processId      = $proc.Id
        transcriptPath = $TranscriptPath
        startedAt      = (Get-Date).ToString('o')
    })
    Write-Log ('ウォッチャー起動 session={0} pid={1}' -f $SessionId, $proc.Id)
    Write-Host ('ウォッチャーを起動しました (PID={0})。' -f $proc.Id)
}

# ------------------------------------------------------------------ stop

function Invoke-Stop {
    Initialize-State
    New-Item -ItemType File -Path $StopFile -Force | Out-Null
    $n = 0
    foreach ($w in @(Get-LiveWatcher)) {
        try { Stop-Process -Id $w.processId -Force -ErrorAction Stop; $n++ } catch {}
        Remove-Item -LiteralPath (Join-Path $WatcherDir ($w.sessionId + '.pid')) -Force -ErrorAction SilentlyContinue
    }
    $t = 0
    foreach ($task in (Get-ScheduledTask -TaskName ($TaskPrefix + '*') -ErrorAction SilentlyContinue)) {
        try { Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop; $t++ } catch {}
    }
    Remove-Item -LiteralPath $StopFile -Force -ErrorAction SilentlyContinue
    Write-Log ('stop: ウォッチャー {0} 本・予約タスク {1} 件を停止' -f $n, $t)
    Write-Host ('ウォッチャー {0} 本、予約タスク {1} 件を停止しました。' -f $n, $t)
}

# ------------------------------------------------------------------ arm（W2 = タスクスケジューラ登録）

function Invoke-Arm {
    Initialize-State
    if ($ResetsAt -le 0) { Write-Host 'ResetsAt が必要です。'; return }
    $at = ConvertFrom-Epoch $ResetsAt
    if ($at -le (Get-Date)) { Write-Log 'arm: 解除時刻が過去のため登録しません。'; return }

    $taskName = $TaskPrefix + (Format-Stamp $ResetsAt)
    $self = Join-Path $PSScriptRoot 'resume-watch.ps1'
    $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" fire -ResetsAt {1} -SessionId {2}' -f $self, $ResetsAt, $SessionId
    try {
        $action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine -WorkingDirectory $RepoRoot
        $trigger  = New-ScheduledTaskTrigger -Once -At $at
        # StartWhenAvailable: スリープ等で時刻を過ぎていた場合、復帰後に実行する
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::FromHours(2))
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
        Write-Log ('arm: タスク {0} を {1} に登録' -f $taskName, $at.ToString('yyyy-MM-dd HH:mm:ss'))
        Write-Host ('予約しました: {0} ({1})' -f $taskName, $at)
    } catch {
        # 登録できなくても W1（常駐ウォッチャーの自前待機）が残るため fail-open で続行する
        Write-Log ('arm: タスク登録に失敗（W1 のみで継続）: ' + $_.Exception.Message)
        Write-Host ('タスク登録に失敗しました（常駐ウォッチャー側の待機は継続します）: ' + $_.Exception.Message)
    }
}

# ------------------------------------------------------------------ fire（解除時刻の処理）

function Invoke-Fire {
    Initialize-State
    if ($ResetsAt -le 0) { Write-Host 'ResetsAt が必要です。'; return }

    # W1 と W2 の二重発火を防ぐ（New-Item は既存ファイルがあると失敗する）
    $stamp = Format-Stamp $ResetsAt
    $lock = Join-Path $FiredDir ($stamp + '.lock')
    try { New-Item -ItemType File -Path $lock -ErrorAction Stop | Out-Null }
    catch { Write-Log ('fire: 解除時刻 {0} は発火済みのためスキップ' -f $stamp); return }

    # タスクが早発したときのための保険
    while ((Get-Date) -lt (ConvertFrom-Epoch $ResetsAt)) { Start-Sleep -Seconds 20 }

    $state  = Read-Json $StateFile
    $sid    = if ($SessionId) { $SessionId } elseif ($state) { $state.sessionId } else { '' }
    $intent = ''
    if (Test-Path -LiteralPath $IntentFile) { try { $intent = (Get-Content -Raw -LiteralPath $IntentFile -Encoding UTF8).Trim() } catch {} }
    $limitType = if ($state -and $state.rateLimitType) { $state.rateLimitType } else { 'unknown' }

    Write-Json $PendingFile ([ordered]@{
        sessionId     = $sid
        resetsAt      = $ResetsAt
        resetsAtLocal = (ConvertFrom-Epoch $ResetsAt).ToString('yyyy-MM-dd HH:mm:ss')
        rateLimitType = $limitType
        firedAt       = (Get-Date).ToString('o')
        intent        = $intent
        headless      = $false
    })
    Write-Log ('fire: 解除時刻 {0} type={1} session={2}' -f $stamp, $limitType, $sid)

    # ---- R1: 無人 headless 再開（オプトインのときだけ）
    $optIn = Read-Json $OptInFile
    $doHeadless = $false
    $reason = ''
    if (-not $optIn -or -not $optIn.enabled) { $reason = '未オプトイン' }
    elseif ($limitType -ne 'five_hour') { $reason = ('rateLimitType={0} のため通知のみ' -f $limitType) }
    elseif (-not $sid) { $reason = 'セッション ID 不明' }
    else {
        $runs = Read-Json $RunsFile
        $count = 0
        if ($runs -and $runs.windowStart -and ((Get-Date) - [datetime]$runs.windowStart).TotalHours -lt 24) { $count = [int]$runs.count }
        $max = if ($optIn.maxRuns) { [int]$optIn.maxRuns } else { 1 }
        if ($count -ge $max) { $reason = ('24 時間あたりの上限 {0} 回に到達' -f $max) }
        else { $doHeadless = $true }
    }

    if ($doHeadless) {
        $ok = Start-HeadlessResume -SessionIdToResume $sid -Intent $intent
        if ($ok) {
            $runs = Read-Json $RunsFile
            $windowStart = if ($runs -and $runs.windowStart -and ((Get-Date) - [datetime]$runs.windowStart).TotalHours -lt 24) { [datetime]$runs.windowStart } else { Get-Date }
            $count = if ($runs -and $runs.windowStart -and ((Get-Date) - [datetime]$runs.windowStart).TotalHours -lt 24) { [int]$runs.count } else { 0 }
            Write-Json $RunsFile ([ordered]@{ windowStart = $windowStart.ToString('o'); count = ($count + 1) })
            $p = Read-Json $PendingFile
            $p.headless = $true
            Write-Json $PendingFile $p
        }
    } else {
        Write-Log ('fire: headless 再開は行わない（{0}）' -f $reason)
    }

    # 通知は 10 秒ほど表示を保持するため、予約タスクの後始末を先に済ませる
    $taskName = $TaskPrefix + $stamp
    try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop } catch {}

    Show-Notification 'Claude Code: リミット解除' ('セッションリミットが解除されました（' + (ConvertFrom-Epoch $ResetsAt).ToString('HH:mm') + '）。Claude Code を開くと中断した作業の続きを提示します。')
    Write-Host '再開通知を作成しました。'
}

function Start-HeadlessResume([string]$SessionIdToResume, [string]$Intent) {
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) { Write-Log 'headless: claude コマンドが見つからないため中止'; return $false }

    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $out   = Join-Path $HeadlessDir ($stamp + '_stdout.log')
    $err   = Join-Path $HeadlessDir ($stamp + '_stderr.log')
    $pf    = Join-Path $HeadlessDir ($stamp + '_prompt.txt')
    $rf    = Join-Path $HeadlessDir ($stamp + '_run.ps1')

    $prompt = @"
セッションリミット（429）で中断した作業を、解除後に自動再開しています。これは無人セッションです。

中断前の指示:
$Intent

次の制約を守ってください。
- 承認が必要な操作（コミット・本番変更・ツール導入など）には進まず、何が必要かを出力して停止する
- 【絶対禁止】の操作は行わない（git push・証跡ファイルの編集など）
- 作業の結論と、次にユーザーが判断すべき点を最後に箇条書きでまとめる
"@
    Set-Content -LiteralPath $pf -Value $prompt -Encoding UTF8

    # 引用符・改行のエスケープを避けるため、実行用スクリプトを生成して detach 起動する
    $runner = @"
`$env:CLAUDE_AUTO_RESUME = '1'
Set-Location -LiteralPath '$RepoRoot'
Get-Content -Raw -LiteralPath '$pf' | & '$($claude.Source)' -p --resume '$SessionIdToResume' 1>'$out' 2>'$err'
"@
    Set-Content -LiteralPath $rf -Value $runner -Encoding UTF8

    try {
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$rf`"" `
            -WorkingDirectory $RepoRoot -WindowStyle Hidden -PassThru
        Write-Log ('headless: claude -p --resume {0} を起動 pid={1} log={2}' -f $SessionIdToResume, $proc.Id, $out)
        return $true
    } catch {
        Write-Log ('headless: 起動に失敗: ' + $_.Exception.Message)
        return $false
    }
}

# ------------------------------------------------------------------ その他

function Invoke-Intent {
    Initialize-State
    if (-not $Text) { Write-Host '-Text が必要です。'; return }
    Set-Content -LiteralPath $IntentFile -Value $Text -Encoding UTF8
    Write-Log '再開意図を明示的に記録'
    Write-Host '再開意図を記録しました。'
}

function Invoke-OptIn {
    Initialize-State
    Write-Json $OptInFile ([ordered]@{ enabled = $true; maxRuns = $MaxRuns; updatedAt = (Get-Date).ToString('o') })
    Write-Host ('無人 headless 再開を有効化しました（24 時間あたり最大 {0} 回）。' -f $MaxRuns)
}

function Invoke-OptOut {
    Initialize-State
    Write-Json $OptInFile ([ordered]@{ enabled = $false; maxRuns = $MaxRuns; updatedAt = (Get-Date).ToString('o') })
    Write-Host '無人 headless 再開を無効化しました（解除時は通知のみ）。'
}

function Invoke-Claim {
    if (Test-Path -LiteralPath $PendingFile) {
        Remove-Item -LiteralPath $PendingFile -Force
        Remove-Item -LiteralPath $IntentFile -Force -ErrorAction SilentlyContinue
        Write-Log 'claim: 再開通知を回収済みにした'
        Write-Host '再開通知を回収済みにしました。'
    } else {
        Write-Host '未回収の再開通知はありません。'
    }
}

function Show-Status {
    Initialize-State
    Write-Host ('自動再開: ' + $(if (Test-Path -LiteralPath $DisableFile) { '無効 (disabled)' } else { '有効' }))
    $live = @(Get-LiveWatcher)
    Write-Host ('稼働中のウォッチャー: {0} 本' -f $live.Count)
    foreach ($w in $live) { Write-Host ('  - pid={0} session={1} 開始={2}' -f $w.processId, $w.sessionId, $w.startedAt) }

    $optIn = Read-Json $OptInFile
    if ($optIn -and $optIn.enabled) { Write-Host ('無人 headless 再開: 有効（上限 {0} 回/24h）' -f $optIn.maxRuns) }
    else { Write-Host '無人 headless 再開: 無効（解除時は通知のみ）' }

    $runs = Read-Json $RunsFile
    if ($runs) { Write-Host ('  直近 24h の無人再開回数: {0}（起点 {1}）' -f $runs.count, $runs.windowStart) }

    $state = Read-Json $StateFile
    if ($state) { Write-Host ('最後に検出した 429: {0} 解除={1} type={2}' -f $state.detectedAt, $state.resetsAtLocal, $state.rateLimitType) }
    else { Write-Host '429 の検出履歴はありません。' }

    $tasks = @(Get-ScheduledTask -TaskName ($TaskPrefix + '*') -ErrorAction SilentlyContinue)
    Write-Host ('予約中のタスク: {0} 件' -f $tasks.Count)
    foreach ($t in $tasks) { Write-Host ('  - ' + $t.TaskName) }

    $pending = Read-Json $PendingFile
    if ($pending) { Write-Host ('★未回収の再開通知あり: 解除={0} headless={1}' -f $pending.resetsAtLocal, $pending.headless) }

    if (Test-Path -LiteralPath $IntentFile) { Write-Host ('再開意図: ' + $IntentFile) }
}

switch ($Command.ToLower()) {
    'start'   { Invoke-Start }
    'stop'    { Invoke-Stop }
    'arm'     { Invoke-Arm }
    'fire'    { Invoke-Fire }
    'intent'  { Invoke-Intent }
    'optin'   { Invoke-OptIn }
    'optout'  { Invoke-OptOut }
    'claim'   { Invoke-Claim }
    'disable' { Initialize-State; New-Item -ItemType File -Path $DisableFile -Force | Out-Null; Invoke-Stop; Write-Host '自動再開を無効化しました。' }
    'enable'  { Initialize-State; Remove-Item -LiteralPath $DisableFile -Force -ErrorAction SilentlyContinue; Write-Host '自動再開を有効化しました（次のセッション開始時にウォッチャーが起動します）。' }
    'status'  { Show-Status }
    default   { Write-Host ('不明なコマンド: ' + $Command); Show-Status }
}
