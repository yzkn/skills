<#
.SYNOPSIS
  Claude Code の利用上限 (5 時間・週) からの自動再開を、この PC 全体 (全プロジェクト) に設定する。何度実行してもよい。
.DESCRIPTION
  1. このスクリプトと同じフォルダのスクリプト一式を、インストール先 (既定 ~/.claude/auto-resume) にコピーする
     (スキルの置き場所に依存せず動くようにするため。スキルを削除・移動しても自動再開は止まらない)
  2. インストール先に config.json を作る (既にあれば設定は残し、claude・pwsh・wt の場所だけ更新する)
  3. タスク ClaudeAutoResume を登録する: 一定間隔 (既定 10 分) / ログオン時 / スリープからの復帰時
     (解除時刻にスリープから起こすタスク ClaudeAutoResume-Wake は、auto-resume.ps1 が上限を見つけたときに登録する)
  4. -EnableWakeTimers で、電源接続時のスリープ解除タイマーを「有効」にする (解除時刻にスリープから復帰できるように)
  5. -Action resume|wake で、解除後の動作 (config.json の action) を切り替える。既定は resume (新しいウィンドウで再開する)
     (wake は PC を起こしておくだけ。Claude Code は上限の解除後に止まったターンを自分では続けないので、別の仕組みが再開する場合だけに使う)
  6. -EnableSleepOnLimit で、利用上限で止まったら確認 (既定 120 秒) のうえ Windows をスリープするフックを、
     ~/.claude/settings.json の StopFailure (matcher: rate_limit) に足す (-DisableSleepOnLimit で外す)
  管理者権限は不要。
.EXAMPLE
  pwsh -File install.ps1 -EnableWakeTimers
  pwsh -File install.ps1 -EnableWakeTimers -EnableSleepOnLimit
#>
param(
    [string]$InstallDir = (Join-Path $env:USERPROFILE '.claude\auto-resume'),
    [int]$IntervalMinutes = 10,
    [switch]$EnableWakeTimers,
    [ValidateSet('resume', 'wake')][string]$Action,
    [switch]$EnableSleepOnLimit,
    [switch]$DisableSleepOnLimit,
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json')
)
$ErrorActionPreference = 'Stop'

# 1. スクリプト一式をインストール先へ (インストール先から実行したときはそのまま)
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
$src = (Resolve-Path $PSScriptRoot).Path
$dst = (Resolve-Path $InstallDir).Path
if ($src -ne $dst) {
    foreach ($f in @('auto-resume.ps1', 'resume-session.ps1', 'keep-awake.ps1', 'sleep-on-limit.ps1', 'sleep-prompt.ps1', 'run-hidden.vbs', 'install.ps1', 'uninstall.ps1')) {
        Copy-Item -LiteralPath (Join-Path $src $f) -Destination (Join-Path $dst $f) -Force
    }
    Write-Host "スクリプトをコピーしました: $dst"
}
$Root = $dst
$ConfigPath = Join-Path $Root 'config.json'

# 2. 設定
$claude = (Get-Command claude -ErrorAction Stop).Source
$pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$shell = if (Test-Path $pwsh) { $pwsh } else { (Get-Command powershell.exe).Source }
# Windows Terminal は、版を含まない実行エイリアス (%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe) を優先する
# (WindowsApps\Microsoft.WindowsTerminal_<版>\wt.exe は、Terminal の更新で無くなる)
$wtAlias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
$wtCmd = Get-Command wt.exe -ErrorAction SilentlyContinue
$wt = if (Test-Path $wtAlias) { $wtAlias } elseif ($wtCmd) { $wtCmd.Source } else { $null }

$defaults = [ordered]@{
    claudePath             = $claude
    shellPath              = $shell
    terminalPath           = $wt               # Windows Terminal。無ければ PowerShell のウィンドウで開く
    action                 = 'resume'          # 解除後の動作。resume: 新しいウィンドウで再開する / wake: PC を起こしておくだけ (再開はしない)
    keepAwakeMinutes       = 20                # wake のとき、解除時刻 + marginMinutes からこの分だけ PC をスリープさせない
    sleepOnLimit           = $false            # 上限で止まったら確認のうえスリープする (StopFailure フック。-EnableSleepOnLimit で true)
    sleepPromptSeconds     = 120               # スリープするまでの確認の秒数 (応答が無ければスリープ)
    sleepMinMinutes        = 15                # 解除までこの分より短ければスリープしない
    permissionMode         = 'fromSession'     # 止まったセッションの権限モードを引き継ぐ。固定するなら auto / acceptEdits / manual など
    fallbackPermissionMode = 'manual'          # セッションの記録にモードが無いとき (操作の許可を求めた時点で入力待ちになる)
    forkSession            = $true             # 新しいセッション ID に分けて再開する (止まったときのウィンドウと二重に書き込まない)
    marginMinutes          = 3                 # 解除時刻からこの分だけ待ってから再開する
    fallbackWaitMinutes    = 60                # 記録に解除時刻が無いときの待ち時間
    maxAgeHours            = 192               # これより前に止まったセッションは再開しない (週の上限 7 日 + 余裕)
    excludeCwd             = @()               # 再開しない作業ディレクトリ (ワイルドカード可。例: "C:\\work\\secret*")
    resumePrompt           = '利用上限で中断していました。上限が解除されたので、中断する直前の作業を、中断したところから続けてください。最初に、中断時点で何をしていたかを 1〜2 文で述べてから再開してください。'
    rebootResumePrompt     = 'PC の再起動 (Windows Update など) で、作業の途中で中断していました。中断する直前の作業を、中断したところから続けてください。最初に、中断時点で何をしていたかを 1〜2 文で述べてから再開してください。'
    maxRebootResumes       = 3                 # 自動で再開したセッションが再起動で中断したとき、続けて再開し直す回数の上限
}
if (Test-Path $ConfigPath) {
    $cur = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($k in @($defaults.Keys)) {
        if ($cur.PSObject.Properties[$k] -and $k -notin @('claudePath', 'shellPath', 'terminalPath')) { $defaults[$k] = $cur.$k }
    }
}
if ($Action) { $defaults.action = $Action }
if ($defaults.action -eq 'wake') {
    Write-Warning ("action が wake です。解除時刻に PC を起こしておくだけで、止まったセッションは再開しません (" + 'Claude Code は上限の解除後に止まったターンを自分では続けない' + ")。再開させるには: install.ps1 -Action resume")
}
if ($EnableSleepOnLimit) { $defaults.sleepOnLimit = $true }
if ($DisableSleepOnLimit) { $defaults.sleepOnLimit = $false }
[IO.File]::WriteAllText($ConfigPath, ($defaults | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
Write-Host "config.json: $ConfigPath"

# 3. タスク (時刻・ログオン・スリープ復帰のイベントの 3 つのきっかけ)
$user = "$env:USERDOMAIN\$env:USERNAME"
$vbs = Join-Path $Root 'run-hidden.vbs'
$start = (Get-Date).AddMinutes(1).ToString('yyyy-MM-ddTHH:mm:ss')
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Claude Code の利用上限 (5 時間・週) で止まった対話セッションを見つけ、解除時刻にスリープから起こす (action=resume なら解除後に再開する) ($Root)</Description>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <Repetition><Interval>PT${IntervalMinutes}M</Interval><StopAtDurationEnd>false</StopAtDurationEnd></Repetition>
      <StartBoundary>$start</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$user</UserId>
      <Delay>PT1M</Delay>
    </LogonTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT1M</Delay>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$user</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"$vbs"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName 'ClaudeAutoResume' -Xml $xml -Force | Out-Null
Write-Host "タスク ClaudeAutoResume を登録しました ($IntervalMinutes 分ごと・ログオン時・スリープ復帰時)"

# 4. スリープ解除タイマー (電源接続時のみ)
if ($EnableWakeTimers) {
    # 元の値を覚えておく (uninstall.ps1 -RestoreWakeTimers で戻す)。表示の言語に依存しないよう、16 進の値だけを読む
    $stateDir = Join-Path $Root 'state'
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }
    $before = Join-Path $stateDir 'wake-timer-before.txt'
    if (-not (Test-Path $before)) {
        $values = @(powercfg /query SCHEME_CURRENT SUB_SLEEP RTCWAKE | Select-String -Pattern '0x[0-9a-fA-F]{8}\s*$' | ForEach-Object { $_.Matches[0].Value.Trim() })
        if ($values.Count -ge 2) { [IO.File]::WriteAllText($before, [Convert]::ToInt32($values[-2], 16).ToString()) }   # 最後の 2 つが AC・DC の現在値
    }
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 1
    powercfg /setactive SCHEME_CURRENT
    Write-Host 'スリープ解除タイマー (電源接続時) を「有効」にしました。戻すには: uninstall.ps1 -RestoreWakeTimers'
}

# 5. 上限で止まったらスリープするフック (~/.claude/settings.json の StopFailure)
if ($EnableSleepOnLimit -or $DisableSleepOnLimit) {
    $settings = if (Test-Path $SettingsPath) { Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (Test-Path $SettingsPath) {
        $stateDir = Join-Path $Root 'state'
        if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }
        Copy-Item -LiteralPath $SettingsPath -Destination (Join-Path $stateDir 'settings.json.bak') -Force   # 書き換える前の控え
    }
    if (-not $settings.PSObject.Properties['hooks']) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    # 前に足したもの (sleep-on-limit.ps1 を呼ぶもの) を外してから足す (何度実行しても 1 つ)
    $groups = @()
    if ($settings.hooks.PSObject.Properties['StopFailure']) {
        foreach ($g in @($settings.hooks.StopFailure)) {
            $rest = @($g.hooks | Where-Object { $_.command -notlike '*sleep-on-limit.ps1*' })
            if ($rest.Count -gt 0) { $g.hooks = $rest; $groups += $g }
        }
    }
    if ($EnableSleepOnLimit) {
        $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}"' -f $shell, (Join-Path $Root 'sleep-on-limit.ps1')
        $groups += [pscustomobject]@{ matcher = 'rate_limit'; hooks = @([pscustomobject]@{ type = 'command'; command = $command; timeout = 30 }) }
    }
    if ($groups.Count -gt 0) { $settings.hooks | Add-Member -NotePropertyName StopFailure -NotePropertyValue $groups -Force }
    elseif ($settings.hooks.PSObject.Properties['StopFailure']) { $settings.hooks.PSObject.Properties.Remove('StopFailure') }
    $dir = Split-Path $SettingsPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
    if ($EnableSleepOnLimit) { Write-Host "フック StopFailure (rate_limit) を足しました: $SettingsPath (利用上限で止まったら $($defaults.sleepPromptSeconds) 秒の確認のあとスリープ)" }
    else { Write-Host "フック StopFailure (sleep-on-limit.ps1) を外しました: $SettingsPath" }
}
