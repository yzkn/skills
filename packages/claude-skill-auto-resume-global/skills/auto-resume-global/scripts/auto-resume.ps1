<#
.SYNOPSIS
  Claude Code の利用上限 (5 時間・週) で止まった対話セッションを見つけ、上限の解除後に続きから再開する。
.DESCRIPTION
  ~/.claude/projects/*/*.jsonl (全プロジェクトのセッション記録) を調べ、最後の会話の記録が
  「apiError = usage_limit_reached」のアシスタント記録になっているセッションを「上限で停止中」とみなす。
  - まだ解除前なら、解除時刻 + 余裕 にスリープから復帰して実行するタスク (ClaudeAutoResume-Wake) を登録する
  - 解除時刻 + 余裕 を過ぎていれば、config.json の action に従う
      resume (既定): 新しいターミナルのウィンドウで claude --resume <id> --fork-session を起動する
                     (再開した claude が動いている間は、PC をスリープさせない。resume-session.ps1)
      wake         : keepAwakeMinutes の間 PC がスリープしないようにするだけ (keep-awake.ps1)。
                     Claude Code は上限の解除後に止まったターンを自分では続けないので、別の仕組み (/auto-resume など) が再開する場合だけに使う
  また、自動で再開したセッションが PC の再起動 (Windows Update など) で作業の途中に終わっていれば、次の起動 (ログオン時) に
  もう一度再開する (resume-session.ps1 が置く state/running/<ID>.json が、OS の起動時刻より前のまま残っているもの)。
  タスク スケジューラから 10 分ごと・ログオン時・スリープ復帰時に起動される (install.ps1)。
.PARAMETER DryRun
  何も起動・登録せず、見つけたセッションと判断だけを表示する。
.PARAMETER ProjectsDir
  セッション記録の置き場所 (試験用に差し替えられる)。既定は ~/.claude/projects
.PARAMETER StateDir
  状態の置き場所 (handled.json・running/)。試験用に差し替えられる。既定はこのフォルダの state
  再起動で中断したセッションの再開 (running/ の印) も、ここを見る。resume-session.ps1 は常にこのフォルダの state/running に書く
#>
param(
    [switch]$DryRun,
    [string]$ProjectsDir = (Join-Path $env:USERPROFILE '.claude\projects'),
    [string]$StateDir = (Join-Path $PSScriptRoot 'state')
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'config.json'
$LogDir = Join-Path $Root 'logs'
foreach ($d in @($StateDir, $LogDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }
$LogFile = Join-Path $LogDir 'auto-resume.log'
$HandledFile = Join-Path $StateDir 'handled.json'

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message
    if ($DryRun) { Write-Host $line; return }
    if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 1MB) { Move-Item $LogFile "$LogFile.old" -Force }
    [IO.File]::AppendAllText($LogFile, $line + "`r`n", (New-Object Text.UTF8Encoding $false))
}

# 一時停止スイッチ: このフォルダに disabled というファイルがあれば何もしない
if (Test-Path (Join-Path $Root 'disabled')) { if ($DryRun) { Write-Host 'disabled ファイルがあるため停止中' }; exit 0 }

# 同時に 2 つ動かない
$mutex = New-Object Threading.Mutex($false, 'Local\ClaudeAutoResume')
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
    $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $handled = @{}
    if (Test-Path $HandledFile) {
        $obj = Get-Content $HandledFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $obj.PSObject.Properties) { $handled[$p.Name] = $p.Value }
    }
    $now = Get-Date
    $maxAge = $now.AddHours(-[double]$cfg.maxAgeHours)
    $nextWake = $null
    $keepAwakeUntil = $null
    $launched = 0

    # 利用者の入力ではない user の記録か (Claude Code が自分で差し込むもの)。
    # 例: バックグラウンドのサブエージェントが終わった・失敗したときの通知 (<task-notification>。origin.kind = task-notification)、
    #     isMeta の記録 (<system-reminder> など)。
    # サブエージェントを動かしている間に上限に当たると、上限の記録の「あと」にこれらが付く (2026-11-13 に実物で確認)。
    function Test-SyntheticUser($Record) {
        if ($Record.type -ne 'user') { return $false }
        if ($Record.PSObject.Properties['isMeta'] -and $Record.isMeta) { return $true }
        if ($Record.PSObject.Properties['origin'] -and $Record.origin -and $Record.origin.PSObject.Properties['kind']) {
            return ($Record.origin.kind -ne 'human')
        }
        if ($Record.PSObject.Properties['promptSource'] -and $Record.promptSource -eq 'system') { return $true }
        # origin の無い版の記録: 文面で見分ける
        $content = if ($Record.message) { $Record.message.content } else { $null }
        if ($content -is [string] -and $content -match '^\s*<(task-notification|system-reminder)>') { return $true }
        return $false
    }

    # セッション記録の末尾から、最後の会話の記録 (user / assistant。サブエージェントを除く) を返す
    # -SkipSynthetic: 利用者の入力ではない user の記録 (サブエージェントの通知など) を飛ばす
    function Get-LastTurn([string]$Path, [switch]$SkipSynthetic) {
        # まず末尾 80 行。サブエージェントが多く、上限の記録のあとの通知だけで埋まっていたら、400 行まで広げる
        # (記録には巨大な行もあるので、いつも 400 行を読むと巡回が遅くなる)
        foreach ($count in 80, 400) {
            $tail = @(Get-Content -LiteralPath $Path -Tail $count -Encoding UTF8)   # 1 行だけのときも配列にする
            for ($i = $tail.Count - 1; $i -ge 0; $i--) {
                $line = $tail[$i]
                if (-not $line.StartsWith('{"parentUuid"')) { continue }   # 会話の記録だけ (api-request-blob などを除く)
                try { $r = $line | ConvertFrom-Json } catch { continue }
                if ($r.type -ne 'user' -and $r.type -ne 'assistant') { continue }
                if ($r.isSidechain) { continue }
                if ($SkipSynthetic -and (Test-SyntheticUser $r)) { continue }
                return $r
            }
            if ($tail.Count -lt $count) { break }   # 記録の先頭まで読んだ
        }
        return $null
    }

    # セッションを始めたディレクトリ (claude --resume <id> はそのプロジェクトの中で探すため)
    function Get-StartCwd([string]$Path) {
        foreach ($line in (Get-Content -LiteralPath $Path -TotalCount 200 -Encoding UTF8)) {
            if ($line -match '"cwd":"((?:[^"\\]|\\.)*)"') { return ($Matches[1] -replace '\\\\', '\') }
        }
        return $null
    }

    function Get-SessionPermissionMode([string]$Path) {
        $m = Select-String -LiteralPath $Path -Pattern '"permissionMode":"([A-Za-z]+)"' -AllMatches | Select-Object -Last 1
        if ($m) { return $m.Matches[$m.Matches.Count - 1].Groups[1].Value }
        return $null
    }

    # 新しいウィンドウで resume-session.ps1 を起動する。分岐先のセッション ID を決めて渡す (再起動で中断したときに追えるように)
    function Start-Resume([string]$Sid, [string]$Cwd, [string]$Mode, [string]$Title, [string]$Reason, [int]$Attempt) {
        $newId = [guid]::NewGuid().ToString()
        $launcher = Join-Path $Root 'resume-session.ps1'
        $shell = $cfg.shellPath
        $psArgs = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$launcher`" -SessionId $Sid -Cwd `"$Cwd`" -Mode $Mode -NewSessionId $newId -Reason $Reason -Attempt $Attempt"
        # Windows Terminal の場所は版ごとに変わる (WindowsApps\Microsoft.WindowsTerminal_<版>\wt.exe)。無ければ探し直す
        $wt = $cfg.terminalPath
        if (-not ($wt -and (Test-Path $wt))) {
            $wtCmd = Get-Command wt.exe -ErrorAction SilentlyContinue
            $wt = if ($wtCmd) { $wtCmd.Source } else { $null }
        }
        $label = if ($Reason -eq 'reboot') { 'Claude 再起動後の再開' } else { 'Claude 再開' }
        if ($wt) {
            # Windows Terminal の新しいウィンドウで開く (; は wt の区切りなので使わない)
            Start-Process -FilePath $wt -ArgumentList "-w new new-tab --title `"$label $Title`" -d `"$Cwd`" `"$shell`" $psArgs"
        } else {
            Start-Process -FilePath $shell -ArgumentList $psArgs -WorkingDirectory $Cwd
        }
        return $newId
    }

    function Find-SessionFile([string]$Sid) {
        Get-ChildItem -Path $ProjectsDir -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "$Sid.jsonl" } |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }

    # --- 再起動 (Windows Update など) で中断した、自動で再開したセッション ---
    # resume-session.ps1 は動いている間 state/running/<ID>.json を置き、claude が終われば消す。
    # 印が残っていて、印を置いた後に OS が起動したなら、claude は再起動で強制終了された。
    # そのときの最後の会話の記録がターンの途中 (ツールの結果・ツールの呼び出し・未回答の入力) なら、もう一度再開する。
    $runDir = Join-Path $StateDir 'running'
    if (Test-Path $runDir) {
        $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $maxReboot = if ($cfg.PSObject.Properties['maxRebootResumes']) { [int]$cfg.maxRebootResumes } else { 3 }
        foreach ($mf in (Get-ChildItem -LiteralPath $runDir -Filter '*.json' -File)) {
            try { $m = Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Remove-Item -LiteralPath $mf.FullName -Force; continue }
            $started = [datetime]$m.startedAt
            if ($started -ge $bootTime) {
                # この起動のあとに始まった: 動いていれば何もしない。プロセスが無ければ利用者が閉じたもの (再起動ではない)
                $p = Get-Process -Id ([int]$m.pid) -ErrorAction SilentlyContinue
                if ($p -and $p.StartTime -le $started.AddMinutes(1)) { continue }
                if (-not $DryRun) { Remove-Item -LiteralPath $mf.FullName -Force }
                continue
            }
            # 再起動で中断した
            $drop = { if (-not $DryRun) { Remove-Item -LiteralPath $mf.FullName -Force } }
            if ($started -lt $maxAge) { & $drop; continue }
            if (-not (Test-Path -LiteralPath $m.cwd)) { Write-Log "skip $($m.sessionId) : 作業ディレクトリが無い ($($m.cwd))"; & $drop; continue }
            $path = Find-SessionFile $m.sessionId
            $resumeFrom = $m.sessionId
            $reason = 'reboot'
            if (-not $path) {
                # 分岐先の記録が無い (claude が書き始める前に再起動した): 元のセッションから、元の理由でやり直す
                # (元の記録も無いと、claude --resume は見つからないまま入力待ちになるので、やめる)
                if (-not (Find-SessionFile $m.parentSessionId)) { Write-Log "skip $($m.sessionId) : 分岐先も再開元 ($($m.parentSessionId)) の記録も無い"; & $drop; continue }
                $resumeFrom = $m.parentSessionId; $reason = $m.reason
            } else {
                $lastTurn = Get-LastTurn $path
                if (-not $lastTurn) { & $drop; continue }
                $isLimitTurn = $lastTurn.type -eq 'assistant' -and $lastTurn.PSObject.Properties['apiError'] -and $lastTurn.apiError
                if ($isLimitTurn) { & $drop; continue }   # 上限で止まっていた: 下の巡回 (上限からの再開) に任せる
                $endTurn = $lastTurn.type -eq 'assistant' -and $lastTurn.message -and $lastTurn.message.stop_reason -eq 'end_turn'
                if ($endTurn) { & $drop; continue }       # 入力待ちだった (作業は終わっていた): 再開しない
            }
            $attempt = [int]$m.attempt + 1
            if ($attempt -gt $maxReboot + 1) { Write-Log "skip $($m.sessionId) : 再起動からの再開が $maxReboot 回を超えた"; & $drop; continue }
            Write-Log ("再起動後の再開 {0} (再開元 {1}、{2} に開始、起動 {3}) mode={4} cwd={5}" -f $m.sessionId, $resumeFrom, $started.ToString('MM/dd HH:mm'), $bootTime.ToString('MM/dd HH:mm'), $m.mode, $m.cwd)
            if ($DryRun) { $launched++; continue }
            Start-Resume $resumeFrom $m.cwd $m.mode $resumeFrom.Substring(0, 8) $reason $attempt | Out-Null
            & $drop
            $launched++
            Start-Sleep -Seconds 2
        }
    }

    $files = Get-ChildItem -Path $ProjectsDir -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.jsonl' -File } |
        Where-Object { $_.LastWriteTime -ge $maxAge }

    foreach ($f in $files) {
        # 上限の記録のあとにサブエージェントの通知が付いていても、利用者の入力とはみなさない
        $last = Get-LastTurn $f.FullName -SkipSynthetic
        if (-not $last) { continue }
        if ($last.type -ne 'assistant') { continue }
        $isLimit = ($last.PSObject.Properties['apiError'] -and $last.apiError -eq 'usage_limit_reached') -or
                   ($last.PSObject.Properties['error'] -and $last.error -eq 'rate_limit' -and $last.PSObject.Properties['apiErrorParams'])
        if (-not $isLimit) { continue }
        if ($last.PSObject.Properties['entrypoint'] -and $last.entrypoint -ne 'cli') { continue }   # 対話セッションだけ (claude -p などは対象外)

        $sid = $last.sessionId
        $key = "$sid/$($last.uuid)"
        if ($handled.ContainsKey($key)) { continue }

        $cwd = Get-StartCwd $f.FullName
        if (-not $cwd -or -not (Test-Path -LiteralPath $cwd)) { Write-Log "skip $sid : 作業ディレクトリが無い ($cwd)"; continue }
        if (@($cfg.excludeCwd | Where-Object { $cwd -like $_ }).Count -gt 0) { continue }

        $resetsAt = $null
        $info = $null
        if ($last.PSObject.Properties['apiErrorParams'] -and $last.apiErrorParams.PSObject.Properties['rate_limit_info']) { $info = $last.apiErrorParams.rate_limit_info }
        elseif ($last.PSObject.Properties['quotaLimits']) { $info = $last.quotaLimits }
        if ($info -and $info.PSObject.Properties['resetsAt'] -and $info.resetsAt) {
            $resetsAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$info.resetsAt).LocalDateTime
        } else {
            # 解除時刻が記録に無いときは、止まった時刻から一定時間後に試す (まだ上限なら、再開したセッションがまた止まり、次の解除時刻が記録される)
            $resetsAt = ([datetime]$last.timestamp).ToLocalTime().AddMinutes([double]$cfg.fallbackWaitMinutes)
        }
        $kind = if ($info -and $info.PSObject.Properties['rateLimitType']) { $info.rateLimitType } else { 'unknown' }
        $due = $resetsAt.AddMinutes([double]$cfg.marginMinutes)
        $title = if ($last.PSObject.Properties['slug']) { $last.slug } else { $sid.Substring(0, 8) }

        if ($now -lt $due) {
            if ($DryRun) { Write-Log ("待機 {0} ({1}) {2} の上限 → {3} に再開予定 [{4}]" -f $sid, $title, $kind, $due.ToString('MM/dd HH:mm'), $cwd) }
            if (-not $nextWake -or $due -lt $nextWake) { $nextWake = $due }
            continue
        }
        # 書き込み中 (直前まで動いていた) なら次の回に回す
        if ($f.LastWriteTime -gt $now.AddMinutes(-1)) { continue }

        if ($cfg.action -eq 'wake') {   # action が無い (古い config.json) ときも resume
            # wake: 再開は別の仕組み (/auto-resume など) に任せる。Claude Code は上限の解除後に止まったターンを自分では続けないので、これだけでは進まない。
            # 解除時刻にスリープから起こされた PC が、無操作でまたすぐスリープしないよう、しばらく起こしておくだけ
            $awake = if ($cfg.keepAwakeMinutes) { [math]::Min(240, [math]::Max(1, [double]$cfg.keepAwakeMinutes)) } else { 20 }
            $until = $due.AddMinutes($awake)
            if ($now -lt $until) {
                Write-Log ("起こしておく {0} ({1}) {2} の上限 (解除 {3}) → {4} まで [{5}]" -f $sid, $title, $kind, $resetsAt.ToString('MM/dd HH:mm'), $until.ToString('MM/dd HH:mm'), $cwd)
                if (-not $keepAwakeUntil -or $until -gt $keepAwakeUntil) { $keepAwakeUntil = $until }
            }
            if (-not $DryRun) { $handled[$key] = [ordered]@{ resumedAt = $now.ToString('o'); cwd = $cwd; kind = $kind; mode = 'wake' } }
            continue
        }

        $mode = $cfg.permissionMode
        if ($mode -eq 'fromSession') { $mode = Get-SessionPermissionMode $f.FullName; if (-not $mode) { $mode = $cfg.fallbackPermissionMode } }

        Write-Log ("再開 {0} ({1}) {2} の上限 (解除 {3}) mode={4} cwd={5}" -f $sid, $title, $kind, $resetsAt.ToString('MM/dd HH:mm'), $mode, $cwd)
        if ($DryRun) { $launched++; continue }

        $newId = Start-Resume $sid $cwd $mode $title 'limit' 1
        $handled[$key] = [ordered]@{ resumedAt = $now.ToString('o'); cwd = $cwd; kind = $kind; mode = $mode; forkedTo = $newId }
        $launched++
        Start-Sleep -Seconds 2
    }

    # wake: 一番遅い時刻まで、1 つのプロセスで PC を起こしておく
    if ($keepAwakeUntil) {
        $minutes = [math]::Ceiling(($keepAwakeUntil - $now).TotalMinutes)
        if ($DryRun) {
            Write-Host ("(DryRun) {0} 分 ({1} まで) PC を起こしておく" -f $minutes, $keepAwakeUntil.ToString('MM/dd HH:mm'))
        } else {
            Start-Process -FilePath $cfg.shellPath -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Root 'keep-awake.ps1')`" -Minutes $minutes"
            Write-Log ("{0} 分 PC を起こしておく" -f $minutes)
        }
    }

    if (-not $DryRun) {
        # 古い記録を捨てて保存
        $keep = [ordered]@{}
        foreach ($k in $handled.Keys) { if ([datetime]$handled[$k].resumedAt -ge $now.AddDays(-14)) { $keep[$k] = $handled[$k] } }
        [IO.File]::WriteAllText($HandledFile, ($keep | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))

        # 次の解除時刻にスリープから復帰して起動する 1 回きりのタスク
        $wakeName = 'ClaudeAutoResume-Wake'
        if ($nextWake) {
            $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$(Join-Path $Root 'run-hidden.vbs')`""
            $trigger = New-ScheduledTaskTrigger -Once -At $nextWake
            $settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
            Register-ScheduledTask -TaskName $wakeName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Claude Code の利用上限の解除時刻にスリープから復帰する (止まったセッションの再開は action に従う。auto-resume.ps1 が登録)' -Force | Out-Null
            Write-Log ("次の解除時刻 {0} に復帰タスクを登録" -f $nextWake.ToString('MM/dd HH:mm'))
        } elseif (Get-ScheduledTask -TaskName $wakeName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $wakeName -Confirm:$false
        }
    } elseif ($nextWake) {
        Write-Host ("(DryRun) 復帰タスクを {0} に登録する" -f $nextWake.ToString('MM/dd HH:mm'))
    }
    if ($DryRun -and -not $launched -and -not $nextWake -and -not $keepAwakeUntil) { Write-Host '上限で止まっているセッションはありません' }
}
catch {
    Write-Log "エラー: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"
    throw
}
finally {
    $mutex.ReleaseMutex()
}
