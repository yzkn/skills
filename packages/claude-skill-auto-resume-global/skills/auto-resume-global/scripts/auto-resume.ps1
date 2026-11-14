<#
.SYNOPSIS
  Claude Code の利用上限 (5 時間・週) で止まった対話セッションを見つけ、上限の解除後に続きから再開する。
.DESCRIPTION
  ~/.claude/projects/*/*.jsonl (全プロジェクトのセッション記録) を調べ、最後の会話の記録が
  利用上限の記録 (Test-LimitRecord。apiError = usage_limit_reached など) になっているセッションを「上限で停止中」とみなす。
  - まだ解除前なら、解除時刻 + 余裕 にスリープから復帰して実行するタスク (ClaudeAutoResume-Wake) を登録する
  - 解除時刻 + 余裕 を過ぎていれば、config.json の action に従う
      resume (既定): 新しいターミナルのウィンドウで claude --resume <id> --fork-session を起動する
                     (再開した claude が動いている間は、PC をスリープさせない。resume-session.ps1)
      wake         : keepAwakeMinutes の間 PC がスリープしないようにするだけ (keep-awake.ps1)。
                     Claude Code は上限の解除後に止まったターンを自分では続けないので、別の仕組み (/auto-resume など) が再開する場合だけに使う
  - 90 秒以内に再開の時刻になるもの・上限の記録が新しすぎて保留したものは、タスクを登録せず、このプロセスのまま待って調べ直す
    (最大 5 回・5 分。それでも残れば、2 分後の復帰タスクに任せる)
  また、自動で再開したセッションが PC の再起動 (Windows Update など) で作業の途中に終わっていれば、次の起動 (ログオン時) に
  もう一度再開する (resume-session.ps1 が置く state/running/<ID>.json が、OS の起動時刻より前のまま残っているもの)。
  動いている間は PC をスリープさせない (タイマーで起こされた PC は、無操作だと 2 分ほどでまた眠るため)。
  タスク スケジューラから 10 分ごと・ログオン時・スリープ復帰時に起動される (install.ps1。conhost.exe --headless で、ウィンドウを出さずに起動する)。
.PARAMETER DryRun
  何も起動・登録せず、見つけたセッションと判断だけを表示する。待って調べ直すこともしない。
.PARAMETER NoTask
  タスク (ClaudeAutoResume-Wake) の登録・削除をしない (試験用)。
.PARAMETER ProjectsDir
  セッション記録の置き場所 (試験用に差し替えられる)。既定は ~/.claude/projects
.PARAMETER StateDir
  状態の置き場所 (handled.json・running/)。試験用に差し替えられる。既定はこのフォルダの state
  再起動で中断したセッションの再開 (running/ の印) も、ここを見る。resume-session.ps1 は常にこのフォルダの state/running に書く
#>
param(
    [switch]$DryRun,
    [switch]$NoTask,
    [string]$ProjectsDir = (Join-Path $env:USERPROFILE '.claude\projects'),
    [string]$StateDir = (Join-Path $PSScriptRoot 'state')
)
$ErrorActionPreference = 'Stop'
$runStart = Get-Date
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

# 同時に 2 つ動かない。先の実行が終わるのを 120 秒まで待つ
# (スリープ復帰のイベントの起動と復帰タスクの起動は、ほぼ同時になる。すぐにやめると、先の実行が取りこぼしたときに後が無い)
# 試験で別の -StateDir を使うときは、別の名前にする (本物の巡回を待たせない)
$mutexName = 'Local\ClaudeAutoResume'
$stateFull = [IO.Path]::GetFullPath($StateDir).TrimEnd('\')
if ($stateFull -ne [IO.Path]::GetFullPath((Join-Path $Root 'state')).TrimEnd('\')) {
    $sha = [Security.Cryptography.SHA1]::Create()
    $hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stateFull.ToLowerInvariant())) | ForEach-Object { $_.ToString('x2') })
    $mutexName += '-' + $hash.Substring(0, 12)
}
$mutex = New-Object Threading.Mutex($false, $mutexName)
$owned = $false
try { $owned = $mutex.WaitOne([TimeSpan]::FromSeconds(120)) } catch [Threading.AbandonedMutexException] { $owned = $true }   # 先の実行が途中で終わった
if (-not $owned) { Write-Log 'skip: 別の実行が 120 秒たっても終わらない'; exit 0 }

# スリープさせない要求 (PowerCreateRequest / PowerSetRequest(PowerRequestSystemRequired))。
# 要求はプロセスが持つハンドルに付き、スレッドに依らない。念のため SetThreadExecutionState も使う。どちらも finally で解く
$powerType = @'
using System;
using System.Runtime.InteropServices;
namespace ClaudeAutoResume {
    public static class Power {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct REASON_CONTEXT {
            public uint Version;
            public uint Flags;
            [MarshalAs(UnmanagedType.LPWStr)] public string SimpleReasonString;
        }
        [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr PowerCreateRequest(ref REASON_CONTEXT context);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerSetRequest(IntPtr handle, int requestType);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerClearRequest(IntPtr handle, int requestType);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
        // PowerRequestSystemRequired (1) の要求を作って有効にする。できなければ IntPtr.Zero
        public static IntPtr Request(string reason) {
            REASON_CONTEXT c = new REASON_CONTEXT();
            c.Version = 0;   // POWER_REQUEST_CONTEXT_VERSION
            c.Flags = 1;     // POWER_REQUEST_CONTEXT_SIMPLE_STRING
            c.SimpleReasonString = reason;
            IntPtr h = PowerCreateRequest(ref c);
            if (h == IntPtr.Zero || h == new IntPtr(-1)) return IntPtr.Zero;
            if (!PowerSetRequest(h, 1)) { CloseHandle(h); return IntPtr.Zero; }
            return h;
        }
        public static void Release(IntPtr h) {
            if (h == IntPtr.Zero) return;
            PowerClearRequest(h, 1);
            CloseHandle(h);
        }
    }
}
'@
$powerHandle = [IntPtr]::Zero

try {
    $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $DryRun) {
        Add-Type -TypeDefinition $powerType
        $powerHandle = [ClaudeAutoResume.Power]::Request('Claude Code の自動再開 (auto-resume.ps1) が、上限で止まったセッションを調べて再開している')
        [ClaudeAutoResume.Power]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
        if ($powerHandle -eq [IntPtr]::Zero) { Write-Log '警告: スリープさせない要求 (PowerCreateRequest) を作れない' }
    }
    $debugLog = [bool]($cfg.PSObject.Properties['debugLog'] -and $cfg.debugLog)
    if ($debugLog) {
        # 起動元 (親・その親のプロセス)。分からなければ省く
        $from = ''
        try {
            $chain = @()
            $p = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
            for ($i = 0; $i -lt 2 -and $p; $i++) {
                $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)"
                if ($p) { $chain += "$($p.Name) $($p.ProcessId)" }
            }
            if ($chain.Count -gt 0) { $from = '、起動元 ' + ($chain -join ' ← ') }
        } catch { }
        Write-Log ("開始 (pid {0}{1})" -f $PID, $from)
    }
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
    $deferredAny = $false   # 保留・待って調べ直したものがあった (終わりのログを書く)

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

    # セッション記録の末尾から、最後の会話の記録 (user / assistant。サブエージェントを除く) を返す
    # -SkipSynthetic: 利用者の入力ではない user の記録 (サブエージェントの通知など) を飛ばす
    # まず末尾 4 MB。その中に会話の記録が無く (通知や巨大な記録だけで埋まっている)、記録がもっと大きければ、32 MB で 1 回だけ読み直す
    # 読んだ末尾は、権限モードの読み取り (Get-SessionPermissionMode) のために 1 つだけ覚えておく
    $script:tailPath = $null
    $script:tailText = $null
    function Get-LastTurn([string]$Path, [switch]$SkipSynthetic) {
        foreach ($max in 4MB, 32MB) {
            $tail = Read-SessionTail $Path $max
            $script:tailPath = $Path
            $script:tailText = $tail.Text
            $lines = $tail.Lines
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $line = $lines[$i]
                if (-not $line.StartsWith('{"parentUuid"')) { continue }   # 会話の記録だけ (api-request-blob などを除く)
                try { $r = $line | ConvertFrom-Json } catch { continue }
                if ($r.type -ne 'user' -and $r.type -ne 'assistant') { continue }
                if ($r.isSidechain) { continue }
                if ($SkipSynthetic -and (Test-SyntheticUser $r)) { continue }
                return $r
            }
            if ($tail.FromStart) { break }   # 記録の先頭まで読んだ
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

    # 末尾 (Get-LastTurn が読んだところ) にある最後の "permissionMode"。無ければ $null (呼び出し側が fallbackPermissionMode にする)
    function Get-SessionPermissionMode([string]$Path) {
        $text = if ($script:tailPath -eq $Path) { $script:tailText } else { (Read-SessionTail $Path).Text }
        $ms = [regex]::Matches($text, '"permissionMode":"([A-Za-z]+)"')
        if ($ms.Count -gt 0) { return $ms[$ms.Count - 1].Groups[1].Value }
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

    # 再開したウィンドウ (resume-session.ps1) が動いている印を置くまで、スリープさせないまま待つ (最大 90 秒)。
    # 印を置いたあとは、resume-session.ps1 が自分でスリープを抑止する。
    # 印の名前は分岐先の ID (forkSession が false なら再開元の ID)。resume-session.ps1 は常にこのフォルダの state/running に書く
    function Wait-ResumeMarker([string]$Id) {
        $path = Join-Path $Root "state\running\$Id.json"
        $limit = (Get-Date).AddSeconds(90)
        while (-not (Test-Path -LiteralPath $path)) {
            if ((Get-Date) -ge $limit) { Write-Log "警告: 再開したウィンドウの印が 90 秒たっても現れない ($Id)"; return }
            Start-Sleep -Milliseconds 500
        }
    }

    # 古い記録を捨てて保存 (再開したらすぐ保存する。待っている間に眠っても、同じセッションを 2 度再開しない)
    function Save-Handled {
        $keep = [ordered]@{}
        $since = (Get-Date).AddDays(-14)
        foreach ($k in $handled.Keys) { if ([datetime]$handled[$k].resumedAt -ge $since) { $keep[$k] = $handled[$k] } }
        [IO.File]::WriteAllText($HandledFile, ($keep | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
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
                if (Test-LimitRecord $lastTurn) { & $drop; continue }   # 上限で止まっていた: 下の巡回 (上限からの再開) に任せる
                $endTurn = $lastTurn.type -eq 'assistant' -and $lastTurn.message -and $lastTurn.message.stop_reason -eq 'end_turn'
                if ($endTurn) { & $drop; continue }       # 入力待ちだった (作業は終わっていた): 再開しない
            }
            $attempt = [int]$m.attempt + 1
            if ($attempt -gt $maxReboot + 1) { Write-Log "skip $($m.sessionId) : 再起動からの再開が $maxReboot 回を超えた"; & $drop; continue }
            Write-Log ("再起動後の再開 {0} (再開元 {1}、{2} に開始、起動 {3}) mode={4} cwd={5}" -f $m.sessionId, $resumeFrom, $started.ToString('MM/dd HH:mm'), $bootTime.ToString('MM/dd HH:mm'), $m.mode, $m.cwd)
            if ($DryRun) { $launched++; continue }
            $newId = Start-Resume $resumeFrom $m.cwd $m.mode $resumeFrom.Substring(0, 8) $reason $attempt
            $markerId = if ($cfg.forkSession) { $newId } else { $resumeFrom }
            if ($markerId -ne $mf.BaseName) { & $drop }   # 同じ名前なら、新しい resume-session.ps1 が書き直した印なので残す
            $launched++
            Wait-ResumeMarker $markerId
        }
    }

    # --- 上限で止まったセッション ---
    # 90 秒以内に再開の時刻になるもの・保留したもの (上限の記録が新しすぎる) は、タスクを登録せず、このプロセスのまま待って調べ直す。
    # 最大 5 回・5 分。それでも残れば、2 分後の復帰タスクに任せる (復帰タスクを消したまま終わらない)
    $scanStart = Get-Date
    $pass = 0
    while ($true) {
        $pass++
        $now = Get-Date
        $maxAge = $now.AddHours(-[double]$cfg.maxAgeHours)
        $nextWake = $null
        $recheckAt = $null
        $limitCount = 0
        $waitCount = 0
        $files = Get-ChildItem -Path $ProjectsDir -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.jsonl' -File } |
            Where-Object { $_.LastWriteTime -ge $maxAge }

        foreach ($f in $files) {
            # 上限の記録のあとにサブエージェントの通知が付いていても、利用者の入力とはみなさない
            $last = Get-LastTurn $f.FullName -SkipSynthetic
            if (-not (Test-LimitRecord $last)) { continue }
            if ($last.PSObject.Properties['entrypoint'] -and $last.entrypoint -ne 'cli') { continue }   # 対話セッションだけ (claude -p などは対象外)
            $limitCount++

            $sid = $last.sessionId
            $key = "$sid/$($last.uuid)"
            if ($handled.ContainsKey($key)) { continue }

            $cwd = Get-StartCwd $f.FullName
            if (-not $cwd -or -not (Test-Path -LiteralPath $cwd)) { Write-Log "skip $sid : 作業ディレクトリが無い ($cwd)"; continue }
            if (@($cfg.excludeCwd | Where-Object { $cwd -like $_ }).Count -gt 0) { continue }

            $resetsAt = $null
            $info = $null
            if ($last.PSObject.Properties['apiErrorParams'] -and $last.apiErrorParams -and $last.apiErrorParams.PSObject.Properties['rate_limit_info']) { $info = $last.apiErrorParams.rate_limit_info }
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
                $waitCount++
                if ($DryRun) { Write-Log ("待機 {0} ({1}) {2} の上限 → {3} に再開予定 [{4}]" -f $sid, $title, $kind, $due.ToString('MM/dd HH:mm'), $cwd) }
                if (($due - $now).TotalSeconds -le 90) {
                    # すぐに再開の時刻になる: タスクを登録せず、このまま待つ
                    Write-Log ("待つ {0} : {1} に再開の時刻になるので、このまま待って調べ直す" -f $sid, $due.ToString('HH:mm:ss'))
                    if (-not $recheckAt -or $due -lt $recheckAt) { $recheckAt = $due }
                } elseif (-not $nextWake -or $due -lt $nextWake) { $nextWake = $due }
                continue
            }
            # 上限の記録が書かれた直後 (60 秒未満) なら、少し待って調べ直す。
            # 最後の会話の記録が上限の記録なので、ターンの途中ではない (ファイルの更新時刻では判断しない。復帰直後の claude が書き足すことがある)
            $recordAt = ([datetime]$last.timestamp).ToLocalTime()
            $age = ($now - $recordAt).TotalSeconds
            if ($age -lt 60) {
                Write-Log ("保留 {0} : 上限の記録が新しい ({1} 秒前)" -f $sid, [math]::Floor([math]::Max(0, $age)))
                $waitCount++
                $at = $recordAt.AddSeconds(60)
                if (-not $recheckAt -or $at -lt $recheckAt) { $recheckAt = $at }
                continue
            }

            if ($cfg.action -eq 'wake') {   # action が無い (古い config.json) ときも resume
                # wake: 再開は別の仕組み (/auto-resume など) に任せる。Claude Code は上限の解除後に止まったターンを自分では続けないので、これだけでは進まない。
                # 解除時刻にスリープから起こされた PC が、無操作でまたすぐスリープしないよう、しばらく起こしておくだけ
                $awake = if ($cfg.keepAwakeMinutes) { [math]::Min(240, [math]::Max(1, [double]$cfg.keepAwakeMinutes)) } else { 20 }
                $until = $due.AddMinutes($awake)
                if ($now -lt $until) {
                    Write-Log ("起こしておく {0} ({1}) {2} の上限 (解除 {3}) → {4} まで [{5}]" -f $sid, $title, $kind, $resetsAt.ToString('MM/dd HH:mm'), $until.ToString('MM/dd HH:mm'), $cwd)
                    if (-not $keepAwakeUntil -or $until -gt $keepAwakeUntil) { $keepAwakeUntil = $until }
                } else {
                    Write-Log ("skip {0} : action が wake (再開しない)。起こしておく時刻 ({1}) も過ぎた" -f $sid, $until.ToString('MM/dd HH:mm'))
                }
                if (-not $DryRun) { $handled[$key] = [ordered]@{ resumedAt = $now.ToString('o'); cwd = $cwd; kind = $kind; mode = 'wake' } }
                continue
            }

            $mode = $cfg.permissionMode
            if ($mode -eq 'fromSession') { $mode = Get-SessionPermissionMode $f.FullName; if (-not $mode) { $mode = $cfg.fallbackPermissionMode } }

            Write-Log ("再開 {0} ({1}) {2} の上限 (解除 {3}) mode={4} cwd={5}" -f $sid, $title, $kind, $resetsAt.ToString('MM/dd HH:mm'), $mode, $cwd)
            if ($DryRun) { $launched++; continue }

            $newId = Start-Resume $sid $cwd $mode $title 'limit' 1
            $handled[$key] = [ordered]@{ resumedAt = (Get-Date).ToString('o'); cwd = $cwd; kind = $kind; mode = $mode; forkedTo = $newId }
            Save-Handled
            $launched++
            Wait-ResumeMarker $(if ($cfg.forkSession) { $newId } else { $sid })
        }

        if (-not $recheckAt) { break }
        $deferredAny = $true
        if ($DryRun) { Write-Host ("(DryRun) {0} まで待って調べ直す" -f $recheckAt.ToString('HH:mm:ss')); break }
        $waitUntil = $recheckAt.AddSeconds(2)
        if ($pass -ge 5 -or $waitUntil -gt $scanStart.AddMinutes(5)) {
            $fallback = (Get-Date).AddMinutes(2)
            if (-not $nextWake -or $fallback -lt $nextWake) { $nextWake = $fallback }
            Write-Log ("調べ直しが上限 ({0} 回目・{1} 秒) に達したので、{2} の復帰タスクに任せる" -f $pass, [math]::Round(((Get-Date) - $scanStart).TotalSeconds), $fallback.ToString('HH:mm:ss'))
            break
        }
        $ms = ($waitUntil - (Get-Date)).TotalMilliseconds
        if ($ms -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling($ms)) }
    }

    # wake: 一番遅い時刻まで、1 つのプロセスで PC を起こしておく
    if ($keepAwakeUntil) {
        $minutes = [math]::Ceiling(($keepAwakeUntil - (Get-Date)).TotalMinutes)
        if ($DryRun) {
            Write-Host ("(DryRun) {0} 分 ({1} まで) PC を起こしておく" -f $minutes, $keepAwakeUntil.ToString('MM/dd HH:mm'))
        } else {
            Start-Process -FilePath $cfg.shellPath -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Root 'keep-awake.ps1')`" -Minutes $minutes"
            Write-Log ("{0} 分 PC を起こしておく" -f $minutes)
        }
    }

    if (-not $DryRun) {
        Save-Handled

        # 次の解除時刻にスリープから復帰して起動する 1 回きりのタスク
        # (VBScript は Windows から外されていくので、conhost.exe --headless でウィンドウを出さずに起動する)
        $wakeName = 'ClaudeAutoResume-Wake'
        if ($NoTask) {
            if ($nextWake) { Write-Log ("NoTask: 次の解除時刻 {0} の復帰タスクは登録しない" -f $nextWake.ToString('MM/dd HH:mm:ss')) }
        } elseif ($nextWake) {
            $shell = if ($cfg.shellPath -and (Test-Path -LiteralPath $cfg.shellPath)) { $cfg.shellPath } else { 'powershell.exe' }
            $action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless `"$shell`" -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $Root 'auto-resume.ps1')`""
            $trigger = New-ScheduledTaskTrigger -Once -At $nextWake
            $settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
            Register-ScheduledTask -TaskName $wakeName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Claude Code の利用上限の解除時刻にスリープから復帰する (止まったセッションの再開は action に従う。auto-resume.ps1 が登録)' -Force | Out-Null
            Write-Log ("次の解除時刻 {0} に復帰タスクを登録" -f $nextWake.ToString('MM/dd HH:mm'))
        } elseif (Get-ScheduledTask -TaskName $wakeName -ErrorAction SilentlyContinue) {
            # 待っているセッションが 1 つも無いときだけ消す (保留・調べ直しの途中で残っていれば、上で nextWake が決まっている)
            Unregister-ScheduledTask -TaskName $wakeName -Confirm:$false
        }
    } elseif ($nextWake) {
        Write-Host ("(DryRun) 復帰タスクを {0} に登録する" -f $nextWake.ToString('MM/dd HH:mm'))
    }
    if ($DryRun -and -not $launched -and -not $nextWake -and -not $keepAwakeUntil -and -not $recheckAt) { Write-Host '上限で止まっているセッションはありません' }

    # 終わりのログ: debugLog のときは毎回。それ以外も、何か起動した・保留した・10 秒より長くかかったときは書く
    $elapsed = ((Get-Date) - $runStart).TotalSeconds
    if ($debugLog -or $launched -gt 0 -or $deferredAny -or $elapsed -gt 10) {
        Write-Log ("終了 (上限で停止 {0}、再開 {1}、待機 {2}、所要 {3} 秒)" -f $limitCount, $launched, $waitCount, [math]::Round($elapsed, 1))
    }
}
catch {
    Write-Log "エラー: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"
    throw
}
finally {
    if ($powerHandle -ne [IntPtr]::Zero) { [ClaudeAutoResume.Power]::Release($powerHandle) }
    if ('ClaudeAutoResume.Power' -as [type]) { [ClaudeAutoResume.Power]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null }   # スリープ抑止を解除
    $mutex.ReleaseMutex()
}
