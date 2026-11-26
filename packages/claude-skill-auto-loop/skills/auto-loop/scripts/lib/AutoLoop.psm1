#requires -Version 7.0
# auto-loop の共通関数。指令リポジトリ（Markdown + git）を読み書きする
# 方針: 認証の入力待ちで止まらない / 何もしなかった理由もログに残す / 破壊的な git 操作をしない
Set-StrictMode -Version 3

$script:Utf8NoBom = [Text.UTF8Encoding]::new($false)
$script:LogAgent = ''
try { [Console]::OutputEncoding = $script:Utf8NoBom } catch { }

function Get-LoopHome {
    if ($env:AUTO_LOOP_HOME) { return $env:AUTO_LOOP_HOME }
    return (Join-Path $HOME '.claude/auto-loop')
}

function Get-LoopConfig {
    $path = Join-Path (Get-LoopHome) 'config.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "設定がありません: $path （/auto-loop setup、または scripts/install.ps1 を実行する）"
    }
    $c = [IO.File]::ReadAllText($path, $script:Utf8NoBom) | ConvertFrom-Json
    # 同じ PC の別エージェント（Copilot など）は、環境変数で ID を差し替える
    if ($env:AUTO_LOOP_AGENT_ID) { $c.agentId = $env:AUTO_LOOP_AGENT_ID }
    if (-not $c.agentId) { throw "config.json に agentId がありません: $path" }
    $script:LogAgent = [string]$c.agentId
    if (-not $c.controlRepoPath) { throw "config.json に controlRepoPath がありません: $path" }
    if (-not (Test-Path -LiteralPath (Join-Path $c.controlRepoPath 'projects'))) {
        throw "指令リポジトリが見つかりません（projects/ が無い）: $($c.controlRepoPath)"
    }
    foreach ($d in @(@('controlRemote', 'origin'), @('leaseHours', 24), @('maxParallel', 3))) {
        if (-not ($c.PSObject.Properties.Name -contains $d[0])) { $c | Add-Member -NotePropertyName $d[0] -NotePropertyValue $d[1] }
    }
    if (-not ($c.PSObject.Properties.Name -contains 'repoPaths') -or $null -eq $c.repoPaths) {
        $c | Add-Member -NotePropertyName repoPaths -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    return $c
}

function Get-NowIso { return (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') }

function Write-LoopLog {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Message)
    try {
        $dir = Join-Path (Get-LoopHome) 'logs'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        $agent = if ($script:LogAgent) { $script:LogAgent } else { '-' }
        $line = "{0} [{1}] [{2}] {3}`n" -f (Get-NowIso), $agent, $Source, ($Message -replace '\r?\n', ' / ')
        [IO.File]::AppendAllText((Join-Path $dir 'auto-loop.log'), $line, $script:Utf8NoBom)
    }
    catch { }
}

function Read-LoopText { param([string]$Path) return [IO.File]::ReadAllText($Path, $script:Utf8NoBom) }
function Write-LoopText { param([string]$Path, [string]$Text) [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom) }

$script:FrontMatterRx = [regex]::new('\A(﻿?---\r?\n)(.*?)(\r?\n---[ \t]*(?:\r?\n|\z))', 'Singleline')

# フロントマターは「キー: 値」の 1 行だけを扱う（入れ子・複数行は使わない）
function Get-FrontMatter {
    param([string]$Text)
    $h = [ordered]@{}
    $m = $script:FrontMatterRx.Match($Text)
    if (-not $m.Success) { return $h }
    foreach ($line in ($m.Groups[2].Value -split '\r?\n')) {
        if ($line -match '^([A-Za-z_][\w-]*):[ \t]*(.*)$') { $h[$Matches[1]] = $Matches[2].Trim().Trim('"') }
    }
    return $h
}

function Set-FrontMatterValue {
    param([string]$Text, [Parameter(Mandatory)][string]$Key, [AllowEmptyString()][string]$Value = '')
    $m = $script:FrontMatterRx.Match($Text)
    if (-not $m.Success) { throw 'フロントマター（先頭の --- で囲んだ部分）がありません' }
    $body = $m.Groups[2].Value
    $nl = if ($m.Groups[1].Value.EndsWith("`r`n")) { "`r`n" } else { "`n" }
    $line = if ($Value -eq '') { "${Key}:" } else { "${Key}: $Value" }
    $rx = [regex]::new('(?m)^' + [regex]::Escape($Key) + ':.*?(?=\r?$)')
    if ($rx.IsMatch($body)) { $body = $rx.Replace($body, $line.Replace('$', '$$'), 1) }
    else { $body = $body + $nl + $line }
    $g = $m.Groups[2]
    return $Text.Substring(0, $g.Index) + $body + $Text.Substring($g.Index + $g.Length)
}

# 末尾の「## ログ」に 1 行足す（ログは追記だけ。ひな形ではログが最後の節）
function Add-TaskLogLine {
    param([string]$Text, [string]$Agent, [string]$Message)
    $nl = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $t = $Text.TrimEnd("`r", "`n")
    if ($t -notmatch '(?m)^## ログ') { $t = $t + $nl + $nl + '## ログ' + $nl }
    return $t + $nl + ('- {0} [{1}] {2}' -f (Get-NowIso), $Agent, ($Message -replace '\r?\n', ' / ')) + $nl
}

function Invoke-Git {
    param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string[]]$GitArgs)
    $oldPrompt = $env:GIT_TERMINAL_PROMPT; $oldGcm = $env:GCM_INTERACTIVE
    # 認証の入力待ちで止めない（失敗として返す）
    $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
    # pwsh 7.1 以前は、Stop のままだと標準エラーの 1 行目で例外になる（git は進み具合を標準エラーに出す）
    $ErrorActionPreference = 'Continue'
    try {
        $out = @(& git -C $Repo -c core.quotepath=false @GitArgs 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    finally { $env:GIT_TERMINAL_PROMPT = $oldPrompt; $env:GCM_INTERACTIVE = $oldGcm }
    return [pscustomobject]@{ Code = $code; Out = $out; Text = ($out -join "`n") }
}

# git の失敗の文面から、直し方を 1 行で返す（分からなければ空）
function Get-GitFailureHint {
    param([string]$Repo, [string]$Remote, [string]$Text)
    if ($Text -notmatch 'Cannot prompt because user interactivity has been disabled|terminal prompts disabled|could not read Username') { return '' }
    $url = (Invoke-Git $Repo @('remote', 'get-url', $Remote)).Text.Trim()
    $origin = if ($url -match '^(https?://[^/]+)') { $Matches[1] } else { 'https://<ホスト>' }
    # Git Credential Manager に同じホストのアカウントが複数あると、選ぶ画面を出そうとして止まる
    return "資格情報の入力が要る状態（同じホストのアカウントが複数保存されている、または未保存）。この clone で使うアカウントを固定する: git -C `"$Repo`" config credential.$origin.username <アカウント>（未保存なら、一度対話で git fetch してログインする）"
}

function Get-ControlRemote {
    param($Config)
    $r = Invoke-Git $Config.controlRepoPath @('remote')
    if ($r.Out -contains $Config.controlRemote) { return [string]$Config.controlRemote }
    return ''   # リモート無し（1 台だけで試すとき）
}

function Get-ControlBranch {
    param($Config)
    return (Invoke-Git $Config.controlRepoPath @('rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()
}

function Test-RemoteBranch {
    param($Config, [string]$Remote, [string]$Branch)
    $r = Invoke-Git $Config.controlRepoPath @('ls-remote', '--heads', $Remote, $Branch)
    return [pscustomobject]@{ Ok = ($r.Code -eq 0); Exists = [bool]$r.Text.Trim(); Detail = $r.Text }
}

# 取り込みだけ（未コミットの変更は autostash で保つ）
function Update-ControlRepo {
    param($Config)
    # 同じ PC の別のセッションと、指令リポジトリの git の操作が重ならないようにする（20261120-no-parallel-sessions）
    $lock = Enter-ControlLock $Config
    try {
        $repo = $Config.controlRepoPath
        $remote = Get-ControlRemote $Config
        if (-not $remote) { return [pscustomobject]@{ Ok = $true; Reason = 'local-only'; Detail = '' } }
        $branch = Get-ControlBranch $Config
        $rb = Test-RemoteBranch $Config $remote $branch
        if (-not $rb.Ok) { return [pscustomobject]@{ Ok = $false; Reason = 'remote'; Detail = $rb.Detail } }
        if (-not $rb.Exists) { return [pscustomobject]@{ Ok = $true; Reason = 'remote-empty'; Detail = '' } }
        $r = Invoke-Git $repo @('pull', '--rebase', '--autostash', $remote, $branch)
        if ($r.Code -ne 0) {
            $conflict = $r.Text -match 'CONFLICT|could not apply'
            Invoke-Git $repo @('rebase', '--abort') | Out-Null
            return [pscustomobject]@{ Ok = $false; Reason = $(if ($conflict) { 'conflict' } else { 'pull' }); Detail = $r.Text }
        }
        return [pscustomobject]@{ Ok = $true; Reason = 'updated'; Detail = '' }
    }
    finally { Exit-ControlLock $lock }
}

# コミット（変更があれば）→ 取り込み → 送信。競合したら rebase を取り消して報告する（強制はしない）
function Sync-ControlRepo {
    param($Config, [Parameter(Mandatory)][string]$Message)
    # 同じ PC の別のセッションと、指令リポジトリの git の操作が重ならないようにする（20261120-no-parallel-sessions）
    $lock = Enter-ControlLock $Config
    try {
        $repo = $Config.controlRepoPath
        $committed = $false
        if ((Invoke-Git $repo @('status', '--porcelain')).Text.Trim()) {
            Invoke-Git $repo @('add', '-A') | Out-Null
            $r = Invoke-Git $repo @('commit', '-m', $Message)
            if ($r.Code -ne 0) { return [pscustomobject]@{ Ok = $false; Reason = 'commit'; Detail = $r.Text; Committed = $false; Pushed = $false } }
            $committed = $true
        }
        $remote = Get-ControlRemote $Config
        if (-not $remote) { return [pscustomobject]@{ Ok = $true; Reason = 'local-only'; Detail = ''; Committed = $committed; Pushed = $false } }
        $branch = Get-ControlBranch $Config
        $last = ''
        for ($i = 1; $i -le 3; $i++) {
            $rb = Test-RemoteBranch $Config $remote $branch
            if (-not $rb.Ok) { return [pscustomobject]@{ Ok = $false; Reason = 'remote'; Detail = $rb.Detail; Committed = $committed; Pushed = $false } }
            if ($rb.Exists) {
                $r = Invoke-Git $repo @('pull', '--rebase', $remote, $branch)
                if ($r.Code -ne 0) {
                    $conflict = $r.Text -match 'CONFLICT|could not apply'
                    Invoke-Git $repo @('rebase', '--abort') | Out-Null
                    return [pscustomobject]@{ Ok = $false; Reason = $(if ($conflict) { 'conflict' } else { 'pull' }); Detail = $r.Text; Committed = $committed; Pushed = $false }
                }
                $ahead = (Invoke-Git $repo @('rev-list', '--count', "$remote/$branch..HEAD")).Text.Trim()
                if ($ahead -eq '0') { return [pscustomobject]@{ Ok = $true; Reason = 'up-to-date'; Detail = ''; Committed = $committed; Pushed = $false } }
            }
            $r = Invoke-Git $repo @('push', $remote, "HEAD:$branch")
            if ($r.Code -eq 0) { return [pscustomobject]@{ Ok = $true; Reason = 'pushed'; Detail = ''; Committed = $committed; Pushed = $true } }
            $last = $r.Text
        }
        return [pscustomobject]@{ Ok = $false; Reason = 'push'; Detail = $last; Committed = $committed; Pushed = $false }
    }
    finally { Exit-ControlLock $lock }
}

function Find-TaskFile {
    param($Config, [Parameter(Mandatory)][string]$Task, [string]$Project = '')
    $root = Join-Path $Config.controlRepoPath 'projects'
    $dirs = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { -not $Project -or $_.Name -eq $Project })
    $hits = @()
    foreach ($d in $dirs) {
        foreach ($sub in @('tasks', 'archive')) {
            $p = Join-Path $d.FullName "$sub/$Task.md"
            if (Test-Path -LiteralPath $p) { $hits += (Get-Item -LiteralPath $p) }
        }
    }
    if ($hits.Count -eq 0) { throw "タスクが見つかりません: $Task" }
    if ($hits.Count -gt 1) { throw "同じ ID のタスクが複数あります（-Project を指定する）: $(($hits | ForEach-Object FullName) -join ', ')" }
    return $hits[0]
}

function Get-RelPath {
    param([string]$Root, [string]$Path)
    return [IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

function Get-LoopTasks {
    param($Config, [string]$Project = '', [switch]$IncludeArchive)
    $root = Join-Path $Config.controlRepoPath 'projects'
    $list = @()
    foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { -not $Project -or $_.Name -eq $Project })) {
        $subs = @('tasks'); if ($IncludeArchive) { $subs += 'archive' }
        foreach ($sub in $subs) {
            $dir = Join-Path $d.FullName $sub
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.md' -File | Where-Object { $_.Name -notmatch '^(_|README)' })) {
                $fm = Get-FrontMatter (Read-LoopText $f.FullName)
                $get = { param($k) if ($fm.Contains($k)) { [string]$fm[$k] } else { '' } }
                $list += [pscustomobject]@{
                    project   = $d.Name
                    id        = $f.BaseName
                    status    = $(if ($sub -eq 'archive' -and -not (& $get 'status')) { 'done' } elseif (& $get 'status') { & $get 'status' } else { '?' })
                    stage     = & $get 'stage'
                    priority  = & $get 'priority'
                    order     = & $get 'order'
                    created   = & $get 'created'
                    assignee  = & $get 'assignee'
                    claimedBy = & $get 'claimed_by'
                    heartbeat = & $get 'heartbeat_at'
                    updated   = & $get 'updated'
                    title     = & $get 'title'
                    archived  = ($sub -eq 'archive')
                    path      = $f.FullName
                }
            }
        }
    }
    return $list
}

function Get-AgeHours {
    param([string]$Iso)
    if (-not $Iso) { return $null }
    try { return [math]::Round(([datetimeoffset]::Now - [datetimeoffset]::Parse($Iso)).TotalHours, 1) } catch { return $null }
}

# project.md の「## リポジトリ」の表を読む（列の順: キー | ホスト | リポジトリ | アカウント | 本流リモート | 基準ブランチ）
function Get-ProjectRepos {
    param([Parameter(Mandatory)][string]$ProjectFile)
    $rows = @(); $in = $false; $seenTable = $false
    foreach ($line in (Read-LoopText $ProjectFile) -split '\r?\n') {
        if ($line -match '^##\s+リポジトリ') { $in = $true; continue }
        if (-not $in) { continue }
        if ($line -match '^##\s') { break }
        if ($line -notmatch '^\s*\|') { if ($seenTable) { break } else { continue } }
        $seenTable = $true
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim().Trim('`') })
        if ($cells.Count -lt 3) { continue }
        if ($cells[0] -match '^:?-{2,}' -or $cells[0] -in @('キー', 'key') -or -not $cells[0] -or $cells[0].StartsWith('<')) { continue }
        $cell = { param($i, $default) if ($cells.Count -gt $i -and $cells[$i] -and $cells[$i] -ne '-') { $cells[$i] } else { $default } }
        $rows += [pscustomobject]@{
            key     = $cells[0]
            host    = & $cell 1 ''
            repo    = & $cell 2 ''
            account = & $cell 3 ''
            remote  = & $cell 4 'origin'
            base    = & $cell 5 'main'
        }
    }
    return $rows
}

# 起動時・スリープ解除時の自動起動（kick.ps1）の設定。config.json の kick に無い項目は既定で補う
function Get-KickConfig {
    param($Config)
    $k = [ordered]@{
        enabled              = $false   # install.ps1 -EnableKick で true
        minIntervalHours     = 0.5      # 前に起こしてから、次に起こすまでの最短の時間
        idle                 = $true    # 通常のタスクが無いとき、手が空いたときの作業のために起こすか
        idleMinIntervalHours = 24       # 手が空いたときの作業のために起こす間隔
        busyMinutes          = 15       # 作業中のセッション（入力待ちでないもの）の記録がこの分の内に書かれていれば、起こさない（0 なら見ない）
        idleCloseMinutes     = 60       # 起こしたセッションの記録がこの分のあいだ書かれなければ、終わらせる（0 なら終わらせない）
        longToolMinutes      = 240      # ツールを呼び出し中（結果がまだ無い。試験・ビルドなどの長い実行）のセッションは、この分までは動いているとみなす（busyMinutes・idleCloseMinutes を超えても。0 なら busyMinutes だけで見る）
        keepOpenSkills       = @('long-run')   # このスキルを使ったセッションは、見張り（close-watch.ps1）が終わらせない
        keepOpenPhrases      = @('終了しないで', '終了させないで', '終わらせないで', '閉じないで', 'keep open', 'keep-open', 'do not close', "don't close")   # 利用者がこう書いたセッションは、見張りが終わらせない
        settledCloseMinutes  = 5        # 入力待ちがこの分続き、担当したタスクが判断待ち・完了などになったら、セッションとウィンドウを終わらせる（0 なら終わらせない。close-watch.ps1）
        settledCloseResumed  = $true    # auto-resume-global が再開したセッションも、上と同じ条件で終わらせる（auto-loop のタスクに触れたものだけ）
        intervalMinutes      = 0        # この分ごとにも kick.ps1 を起動する（0 なら使わない。15・30 など）。起こすかどうかは同じ判断
        pollMinutes          = 3        # この分ごとに、ダッシュボードの即時実行の印（state/kick/<ID>.json）を見に行く（kick-poll.ps1。タスク AutoLoopKickPoll。0 なら見ない）
        weeklyAtReset        = $true    # 週の上限の解除時刻（の 6 分後）に、毎週 PC を起こして kick.ps1 を起動する（タスク AutoLoopKickWeekly）
        weeklyResetAt        = ''       # 週の解除の曜日・時刻を手で決める（例 'Thu 08:00'）。空なら、セッションの記録の週の上限の resetsAt から取る
        statusEveryMinutes   = 60       # PC の状況（指令リポジトリの state/pcs/<ID>.json）を、中身が変わらなくてもこの分ごとに書き直す（0 なら書かない）
        permissionMode       = 'auto'   # 起こすセッションの権限モード
        remoteControl        = $true    # --remote-control つきで起こす
        prompt               = ''       # 最初に送る指示。空なら既定（/auto-loop next）
    }
    if ($Config.PSObject.Properties.Name -contains 'kick' -and $Config.kick) {
        foreach ($p in $Config.kick.PSObject.Properties) { if ($k.Contains($p.Name) -and $null -ne $p.Value) { $k[$p.Name] = $p.Value } }
    }
    return [pscustomobject]$k
}

# Claude Code のセッションの記録（~/.claude/projects/<プロジェクト>/<ID>.jsonl）の末尾 MaxBytes バイトを行に分けて返す。
# 末尾に巨大な行があっても速いよう、バイト単位で読む（auto-resume-global の Read-SessionTail と同じ考え方）。途中から読んだときは最初の行を捨てる
function Read-SessionTailLines {
    param([string]$Path, [long]$MaxBytes = 4MB)
    $fs = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        $start = [math]::Max([long]0, $fs.Length - $MaxBytes)
        [void]$fs.Seek($start, [IO.SeekOrigin]::Begin)
        $buf = [byte[]]::new([int]($fs.Length - $start))
        $n = 0
        while ($n -lt $buf.Length) { $k = $fs.Read($buf, $n, $buf.Length - $n); if ($k -le 0) { break }; $n += $k }
    }
    finally { $fs.Dispose() }
    [string[]]$lines = [Text.Encoding]::UTF8.GetString($buf, 0, $n).Split([char]"`n")
    if ($start -gt 0 -and $lines.Length -gt 0) { $lines = @($lines | Select-Object -Skip 1) }
    return , $lines
}

# 記録の時刻（ConvertFrom-Json が DateTime に変えたもの・ISO 8601 の文字列）を、この PC の時刻にする。読めなければ $null
function ConvertTo-LocalTime {
    param($Value)
    try {
        if ($Value -is [datetime]) { return $(if ($Value.Kind -eq [DateTimeKind]::Utc) { $Value.ToLocalTime() } else { $Value }) }
        if ($Value -is [datetimeoffset]) { return $Value.LocalDateTime }
        return [datetimeoffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture).LocalDateTime
    }
    catch { return $null }
}

# セッションが「手を動かしているか」を、最後の会話の記録から判定する（kick.ps1 の 1 台 1 セッションの数え方。依頼 20261119-autoresume-fix-idle-dashboard）。
#   empty         会話の記録が無い（起動したが何も指示されていない）
#   limit         最後が利用上限の記録（解除待ち。kick.ps1 は復帰タスクで別に見る）
#   waiting-input 最後が assistant の応答で、ツールの呼び出しが無い（利用者の入力待ち）
#   working       最後が user の入力・ツールの結果、またはツールを呼び出し中で、BusyMinutes 分の内に記録（サブエージェントの記録を含む）が書かれた
#   stale         working の形だが、BusyMinutes 分より長く書かれていない（権限の確認待ち・異常終了など。長いツールの実行もここに入りうる）
# 利用者の入力ではない user の記録（サブエージェントの通知・isMeta など）と、サブエージェント側の記録（isSidechain）は飛ばす。
# 記録の形は Claude Code の内部形式（2026-11 時点）。版が変わったら実物に合わせて直す
# LastWrite は、本体の記録の最後の時刻つきの行（timestamp）の時刻と、サブエージェントの記録の更新時刻の遅いほう。
# 本体のファイルの更新時刻は使わない。開いているセッションは、同じ PC で別のセッションが起動するたびに、時刻の無いメタデータの行
# （last-prompt・ai-title・bridge-session など）を書き足すので、手が止まっていても更新時刻が新しくなる（2026-11-21 に実物で確かめた）。
# 時刻つきの行が無い記録（古い形・試験）は、ファイルの更新時刻を使う
function Get-SessionActivity {
    param([string]$Path, [double]$BusyMinutes = 15, [double]$LongToolMinutes = 0)
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) { return [pscustomobject]@{ State = 'empty'; LastWrite = $null; Path = $Path; PendingTool = $false } }
    $subWrite = $null
    $sub = Join-Path $item.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($item.Name))
    if (Test-Path -LiteralPath $sub) {
        $s = Get-ChildItem -LiteralPath $sub -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($s) { $subWrite = $s.LastWriteTime }
    }
    $state = 'empty'
    $stamp = $null
    $pending = $false   # 最後が assistant のツールの呼び出しで、結果がまだ無い（ツールの実行中・権限の確認待ち）
    $lines = Read-SessionTailLines $Path
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $l = $lines[$i].TrimEnd("`r")
        if (-not $l.StartsWith('{')) { continue }
        try { $r = $l | ConvertFrom-Json } catch { continue }
        if (-not $stamp -and $r.PSObject.Properties['timestamp'] -and $r.timestamp) { $stamp = ConvertTo-LocalTime $r.timestamp }
        if ($r.type -notin @('user', 'assistant')) { continue }
        if ($r.PSObject.Properties['isSidechain'] -and $r.isSidechain) { continue }
        if ($r.type -eq 'user') {
            if ($r.PSObject.Properties['isMeta'] -and $r.isMeta) { continue }
            if ($r.PSObject.Properties['origin'] -and $r.origin -and $r.origin.PSObject.Properties['kind'] -and $r.origin.kind -ne 'human') { continue }
            $c = if ($r.message) { $r.message.content } else { $null }
            if ($c -is [string] -and $c -match '^\s*<(task-notification|system-reminder)>') { continue }
            $state = 'working'; break
        }
        # assistant
        if (($r.PSObject.Properties['apiError'] -and $r.apiError -in @('usage_limit_reached', 'model_requires_usage_credits')) -or
            ($r.PSObject.Properties['error'] -and $r.error -eq 'rate_limit')) { $state = 'limit'; break }
        $content = @(if ($r.message -and $r.message.PSObject.Properties['content']) { $r.message.content })
        $tool = @($content | Where-Object { $_ -and $_.PSObject.Properties['type'] -and $_.type -eq 'tool_use' })
        $state = if ($tool.Count -gt 0) { 'working' } else { 'waiting-input' }
        $pending = $tool.Count -gt 0
        break
    }
    $lastWrite = if ($stamp) { $stamp } else { $item.LastWriteTime }
    if ($subWrite -and $subWrite -gt $lastWrite) { $lastWrite = $subWrite }
    # ツールの実行中は LongToolMinutes まで待つ（試験などの長い実行を、止まっているとみなさない。権限の確認待ちもここに入る）
    $limitMin = if ($pending -and $LongToolMinutes -gt $BusyMinutes) { $LongToolMinutes } else { $BusyMinutes }
    if ($state -eq 'working' -and ((Get-Date) - $lastWrite).TotalMinutes -gt $limitMin) { $state = 'stale' }
    return [pscustomobject]@{ State = $state; LastWrite = $lastWrite; Path = $Path; PendingTool = $pending }
}

# この PC で「手を動かしている」セッションを数える。BusyMinutes 分の内に書かれた記録（本体かサブエージェント）だけを読む。
# 戻り値の Working が 1 件以上なら、ほかのセッションが動いている。Idle は数えなかったもの（入力待ちなど）の内訳
function Get-BusySessions {
    param([string]$ProjectsDir, [double]$BusyMinutes = 15, [string[]]$ExcludeSessionIds = @(), [double]$LongToolMinutes = 0)
    $working = @(); $idle = @()
    if (-not (Test-Path -LiteralPath $ProjectsDir)) { return [pscustomobject]@{ Working = $working; Idle = $idle } }
    $cutoff = (Get-Date).AddMinutes(-[math]::Max($BusyMinutes, $LongToolMinutes))
    $seen = @{}
    foreach ($d in @(Get-ChildItem -LiteralPath $ProjectsDir -Directory -ErrorAction SilentlyContinue)) {
        foreach ($f in @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $cutoff })) {
            # サブエージェントの記録（<ID>/subagents/....jsonl）なら、本体の <ID>.jsonl を見る
            $main = $f.FullName
            $rel = $f.FullName.Substring($d.FullName.Length).TrimStart('\', '/')
            $first = ($rel -split '[\\/]')[0]
            if ($rel -ne $f.Name) { $main = Join-Path $d.FullName "$first.jsonl" }
            $sid = [IO.Path]::GetFileNameWithoutExtension($main)
            if ($seen.ContainsKey($main) -or $sid -in $ExcludeSessionIds) { continue }
            $seen[$main] = $true
            $a = Get-SessionActivity -Path $main -BusyMinutes $BusyMinutes -LongToolMinutes $LongToolMinutes
            $row = [pscustomobject]@{ SessionId = $sid; Project = $d.Name; State = $a.State; LastWrite = $a.LastWrite }
            if ($a.State -eq 'working') { $working += $row } else { $idle += $row }
        }
    }
    return [pscustomobject]@{ Working = $working; Idle = $idle }
}

# 記録の timestamp（ローカル時刻）。無い・読めなければ $null
function Get-RecordTime {
    param($Record)
    if (-not ($Record.PSObject.Properties['timestamp'] -and $Record.timestamp)) { return $null }
    try { return ([datetimeoffset]::Parse([string]$Record.timestamp)).LocalDateTime } catch { return $null }
}

# セッションの記録の 1 行が利用上限の記録か（auto-resume-global の Test-LimitRecord と同じ判定）。上限なら次を、違えば $null を返す。
#   apiError が usage_limit_reached / model_requires_usage_credits、または error が rate_limit で解除時刻のあるもの（無いものは一時的な 429）
#   ResetAt: 解除時刻（ローカル。記録に無ければ $null）/ Kind: rateLimitType（無ければ apiError）/ At: 記録の timestamp（無ければ $null）
function Get-LimitRecordInfo {
    param($Record)
    if (-not $Record -or $Record.type -ne 'assistant') { return $null }
    $byApi = [bool]($Record.PSObject.Properties['apiError'] -and $Record.apiError -in @('usage_limit_reached', 'model_requires_usage_credits'))
    $byRate = [bool]($Record.PSObject.Properties['error'] -and $Record.error -eq 'rate_limit')
    if (-not ($byApi -or $byRate)) { return $null }
    $infos = @()
    if ($Record.PSObject.Properties['apiErrorParams'] -and $Record.apiErrorParams -and $Record.apiErrorParams.PSObject.Properties['rate_limit_info']) { $infos += $Record.apiErrorParams.rate_limit_info }
    if ($Record.PSObject.Properties['quotaLimits'] -and $Record.quotaLimits) { $infos += $Record.quotaLimits }
    $info = @($infos | Where-Object { $_ -and $_.PSObject.Properties['resetsAt'] -and $_.resetsAt } | Select-Object -First 1)
    if (-not $byApi -and $info.Count -eq 0) { return $null }
    $reset = $null; $kind = ''
    if ($info.Count -gt 0) {
        try { $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$info[0].resetsAt).LocalDateTime } catch { }
        if ($info[0].PSObject.Properties['rateLimitType']) { $kind = [string]$info[0].rateLimitType }
    }
    if (-not $kind) { $kind = if ($byApi) { [string]$Record.apiError } else { 'rate_limit' } }
    return [pscustomobject]@{ ResetAt = $reset; Kind = $kind; At = (Get-RecordTime $Record) }
}

# セッションの記録から「まだ解除されていない利用上限」を探す（kick.ps1 の 4.。依頼 20261119-kick-limit-from-records）。
# 復帰タスク（auto-resume-global）が無くても、上限で止まっているときに起こさないために使う。
#   1. LookbackHours 時間の内に書かれた記録（本体・サブエージェント）のうち、resetsAt を含むものだけを読み、上限の記録を探す
#   2. resetsAt + MarginMinutes が Now より先のものを候補にする（resetsAt の無い上限は、解除時刻が分からないので使わない）
#   3. 上限はアカウント単位なので、どの記録でも、上限の記録より後に普通の assistant の応答があれば、解除済みとみなして捨てる
#      （上限のあとに利用者が入力しただけ・また上限、なら解除されていない）
#   4. 残ったうち、解除時刻が最も遅いものを返す（ResetAt・Kind・At・SessionId・Project）。無ければ $null
# 記録の形は Claude Code の内部形式（2026-11 時点）。版が変わったら実物に合わせて直す
function Find-PendingLimit {
    param([string]$ProjectsDir, [double]$LookbackHours = 170, [double]$MarginMinutes = 3, [datetime]$Now = (Get-Date))
    if (-not (Test-Path -LiteralPath $ProjectsDir)) { return $null }
    $rootDir = (Get-Item -LiteralPath $ProjectsDir).FullName
    $files = @(Get-ChildItem -LiteralPath $rootDir -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $Now.AddHours(-$LookbackHours) })
    if ($files.Count -eq 0) { return $null }
    # 末尾（Read-SessionTailLines の 4MB）だけを読み、行は -like / -match でまとめて絞る
    # （ファイル全体の Select-String・1 行ずつの比較は、この PC の 1 週間分 440MB で 5〜7 秒かかった）
    $cands = @()
    foreach ($f in $files) {
        $hits = @(@((Read-SessionTailLines $f.FullName) -like '*"resetsAt"*') -match '"(apiError|error)"\s*:\s*"(usage_limit_reached|model_requires_usage_credits|rate_limit)"')
        if ($hits.Count -eq 0) { continue }
        $path = $f.FullName
        $parts = @($path.Substring($rootDir.Length).TrimStart('\', '/') -split '[\\/]')
        $sid = if ($parts.Count -ge 3) { $parts[1] } else { [IO.Path]::GetFileNameWithoutExtension($path) }   # サブエージェントの記録なら本体の ID
        foreach ($l in $hits) {
            $l = $l.TrimEnd("`r")
            if (-not $l.StartsWith('{')) { continue }
            try { $r = $l | ConvertFrom-Json } catch { continue }
            $li = Get-LimitRecordInfo $r
            if (-not $li -or -not $li.ResetAt -or $li.ResetAt.AddMinutes($MarginMinutes) -le $Now) { continue }
            $cands += [pscustomobject]@{ ResetAt = $li.ResetAt; Kind = $li.Kind; At = $li.At; SessionId = $sid; Project = $parts[0] }
        }
    }
    if ($cands.Count -eq 0) { return $null }
    # 3. 上限の記録より後の普通の応答。最も早い上限の記録より後に書かれたファイルだけを、末尾から読む
    $known = @($cands | Where-Object { $_.At } | ForEach-Object { $_.At })
    $lastOk = $null
    if ($known.Count -gt 0) {
        $earliest = ($known | Measure-Object -Minimum).Minimum
        foreach ($f in @($files | Where-Object { $_.LastWriteTime -gt $earliest })) {
            $lines = @((Read-SessionTailLines $f.FullName) -like '*"assistant"*')
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $l = $lines[$i].TrimEnd("`r")
                if (-not $l.StartsWith('{')) { continue }
                try { $r = $l | ConvertFrom-Json } catch { continue }
                if ($r.type -ne 'assistant') { continue }
                if (($r.PSObject.Properties['apiError'] -and $r.apiError) -or ($r.PSObject.Properties['error'] -and $r.error) -or ($r.PSObject.Properties['isApiErrorMessage'] -and $r.isApiErrorMessage)) { continue }
                $t = Get-RecordTime $r
                if ($t) { if (-not $lastOk -or $t -gt $lastOk) { $lastOk = $t }; break }   # このファイルの最後の普通の応答だけを見ればよい
            }
        }
    }
    $pending = @($cands | Where-Object { -not ($lastOk -and $_.At -and $lastOk -gt $_.At) })
    if ($pending.Count -eq 0) { return $null }
    return ($pending | Sort-Object ResetAt -Descending | Select-Object -First 1)
}

# セッションの記録から、週の上限（rateLimitType が seven_day で始まる）の解除時刻を探す。Since より後に書かれた記録だけを読む。
# 見つかった中で最も遅い解除時刻（ローカル時刻）を返す。無ければ $null。記録の形は Claude Code の内部形式（2026-11 時点）
function Find-WeeklyResetFromTranscripts {
    param([string]$ProjectsDir, [datetime]$Since)
    if (-not (Test-Path -LiteralPath $ProjectsDir)) { return $null }
    $files = @(Get-ChildItem -LiteralPath $ProjectsDir -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $Since })
    if ($files.Count -eq 0) { return $null }
    $latest = $null
    foreach ($m in @($files | Select-String -Pattern '\{[^{}]*"rateLimitType"\s*:\s*"seven_day[^"]*"[^{}]*\}' -AllMatches -ErrorAction SilentlyContinue)) {
        foreach ($x in $m.Matches) {
            $r = [regex]::Match($x.Value, '"resetsAt"\s*:\s*(\d+)')
            if (-not $r.Success) { continue }
            $t = [DateTimeOffset]::FromUnixTimeSeconds([long]$r.Groups[1].Value).LocalDateTime
            if (-not $latest -or $t -gt $latest) { $latest = $t }
        }
    }
    return $latest
}

# セッションの記録から、直近の上限の窓（5 時間・週）を集める（ダッシュボードの帯。20261121-dashboard-improve）。
# rateLimitType が five_hour → 'five_hour'、seven_day で始まる（seven_day_overage_included など）→ 'seven_day'。種類と解除時刻ごとに 1 件にまとめ、
# 解除時刻が Since より後のものを、解除時刻の古い順に最大 Max 件返す。startsAt は解除時刻から窓の長さを引いた推定（窓の始まりは記録に無い）。
# hit は、その窓で上限に当たった（status が rejected の）記録があったか。Since（FilesSince があればそれ）より後に書かれた記録だけを読む
function Find-LimitWindows {
    param([string]$ProjectsDir, [datetime]$Since, [int]$Max = 30, [Nullable[datetime]]$FilesSince = $null)
    if (-not $ProjectsDir -or -not (Test-Path -LiteralPath $ProjectsDir)) { return @() }
    $fs = if ($null -ne $FilesSince -and $FilesSince -gt $Since) { $FilesSince } else { $Since }
    $files = @(Get-ChildItem -LiteralPath $ProjectsDir -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $fs })
    if ($files.Count -eq 0) { return @() }
    $sinceUnix = ([DateTimeOffset]$Since).ToUnixTimeSeconds()
    $byKey = @{}
    foreach ($m in @($files | Select-String -Pattern '\{[^{}]*"rateLimitType"\s*:\s*"(five_hour|seven_day)[^"]*"[^{}]*\}' -AllMatches -ErrorAction SilentlyContinue)) {
        foreach ($x in $m.Matches) {
            $r = [regex]::Match($x.Value, '"resetsAt"\s*:\s*(\d+)')
            if (-not $r.Success) { continue }
            $reset = [long]$r.Groups[1].Value
            if ($reset -le $sinceUnix) { continue }
            $kind = if ($x.Groups[1].Value -eq 'five_hour') { 'five_hour' } else { 'seven_day' }
            $hit = $x.Value -match '"status"\s*:\s*"rejected"'
            $key = "$kind/$reset"
            if ($byKey.ContainsKey($key)) { if ($hit) { $byKey[$key].Hit = $true } }
            else { $byKey[$key] = @{ Kind = $kind; Reset = $reset; Hit = $hit } }
        }
    }
    $fmt = 'yyyy-MM-ddTHH:mm:sszzz'
    return @($byKey.Values | Sort-Object { $_.Reset }, { $_.Kind } | Select-Object -Last $Max | ForEach-Object {
            $resetAt = [DateTimeOffset]::FromUnixTimeSeconds($_.Reset).ToLocalTime()
            $len = if ($_.Kind -eq 'five_hour') { [TimeSpan]::FromHours(5) } else { [TimeSpan]::FromDays(7) }
            [ordered]@{ kind = $_.Kind; startsAt = $resetAt.Subtract($len).ToString($fmt); resetsAt = $resetAt.ToString($fmt); hit = [bool]$_.Hit }
        })
}

# 上限の窓を、前回の結果（state/kick-limits.json）に、前回から書かれた記録の分だけを足して返す（記録の全部を毎回読むと数十秒かかるため）。
# 解除時刻が Days 日より前のものは捨てる。NoSave なら結果を保存しない（DryRun）
function Update-LimitWindows {
    param([string]$ProjectsDir, [int]$Days = 7, [switch]$NoSave)
    $file = Join-Path (Get-LoopHome) 'state/kick-limits.json'
    $now = [datetime]::Now
    $since = $now.AddDays(-$Days)
    $prev = @(); $filesSince = $null
    if (Test-Path -LiteralPath $file) {
        try {
            $c = Read-LoopText $file | ConvertFrom-Json
            $filesSince = [datetimeoffset]::Parse([string]$c.scannedAt).LocalDateTime.AddMinutes(-5)   # 書き込みの途中だった記録を取りこぼさないよう、少し重ねる
            $prev = @($c.windows | Where-Object { $_ } | ForEach-Object { [ordered]@{ kind = [string]$_.kind; startsAt = [string]$_.startsAt; resetsAt = [string]$_.resetsAt; hit = [bool]$_.hit } })
        }
        catch { $prev = @(); $filesSince = $null }
    }
    $new = @(Find-LimitWindows -ProjectsDir $ProjectsDir -Since $since -FilesSince $filesSince)
    $byKey = [ordered]@{}
    foreach ($w in @($prev + $new)) {
        try { if ([datetimeoffset]::Parse($w.resetsAt).LocalDateTime -le $since) { continue } } catch { continue }
        $key = "$($w.kind)/$([datetimeoffset]::Parse($w.resetsAt).ToUnixTimeSeconds())"
        if ($byKey.Contains($key)) { if ($w.hit) { $byKey[$key].hit = $true } } else { $byKey[$key] = $w }
    }
    $list = @($byKey.Values | Sort-Object { [datetimeoffset]::Parse($_.resetsAt) }, { $_.kind } | Select-Object -Last 30)
    if (-not $NoSave) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $file) | Out-Null
        Write-LoopText $file ((@{ scannedAt = $now.ToString('yyyy-MM-ddTHH:mm:sszzz'); windows = $list } | ConvertTo-Json -Depth 4) + "`n")
    }
    return $list
}
# 'Thu 08:00' のような書き方を、直近の過去のその曜日・時刻（DateTime）にする。読めなければ $null
function ConvertFrom-WeeklyText {
    param([string]$Text, [datetime]$Now = (Get-Date))
    $days = @{ sun = 0; mon = 1; tue = 2; wed = 3; thu = 4; fri = 5; sat = 6; '日' = 0; '月' = 1; '火' = 2; '水' = 3; '木' = 4; '金' = 5; '土' = 6 }
    $m = [regex]::Match($Text.Trim().ToLowerInvariant(), '^(sun|mon|tue|wed|thu|fri|sat|日|月|火|水|木|金|土)\S*\s+(\d{1,2}):(\d{2})$')
    if (-not $m.Success) { return $null }
    $dow = $days[$m.Groups[1].Value]
    $t = $Now.Date.AddHours([int]$m.Groups[2].Value).AddMinutes([int]$m.Groups[3].Value)
    $diff = ([int]$t.DayOfWeek - $dow + 7) % 7
    $t = $t.AddDays(-$diff)
    if ($t -gt $Now) { $t = $t.AddDays(-7) }
    return $t
}

# 解除時刻（過去でも未来でもよい）から、Now 以降で最初の「解除時刻 + OffsetMinutes」を、7 日刻みで求める
function Get-NextWeeklySlot {
    param([datetime]$ResetAt, [int]$OffsetMinutes = 6, [datetime]$Now = (Get-Date))
    $t = $ResetAt.AddMinutes($OffsetMinutes)
    while ($t -le $Now) { $t = $t.AddDays(7) }
    while ($t.AddDays(-7) -gt $Now) { $t = $t.AddDays(-7) }
    return $t
}

# 自動起動のタスク（タスク スケジューラ）の XML。
#   Kind 'main'  : AutoLoopKick。ログオン時・スリープ復帰時の 3 分後。IntervalMinutes > 0 なら、その分ごとにも
#   Kind 'weekly': AutoLoopKickWeekly。WeeklyAt の曜日・時刻に毎週。PC を起こす（WakeToRun）
#   Kind 'poll'  : AutoLoopKickPoll。IntervalMinutes 分ごとに kick-poll.ps1（KickScript に渡す）。PC は起こさない
function New-KickTaskXml {
    param([ValidateSet('main', 'weekly', 'poll')][string]$Kind, [string]$KickScript, [string]$Shell, [string]$User, [int]$IntervalMinutes = 0, [datetime]$WeeklyAt)
    $esc = { param($s) [Security.SecurityElement]::Escape([string]$s) }
    $trigger = if ($Kind -eq 'weekly') { 'weekly' } else { '' }
    $argsText = "--headless `"$Shell`" -NoProfile -ExecutionPolicy Bypass -File `"$KickScript`"$(if ($trigger) { " -Trigger $trigger" })"
    $u = & $esc $User
    $triggers = ''
    $desc = ''
    $wake = 'false'
    if ($Kind -eq 'main') {
        $desc = "auto-loop: 起動時・スリープ解除時$(if ($IntervalMinutes -gt 0) { "と $IntervalMinutes 分ごと" })に、やることがあれば Claude Code のセッションを起こす ($KickScript)"
        $triggers = @"
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$u</UserId>
      <Delay>PT3M</Delay>
    </LogonTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT3M</Delay>
    </EventTrigger>
"@
        if ($IntervalMinutes -gt 0) {
            $start = (Get-Date).AddMinutes($IntervalMinutes).ToString('yyyy-MM-ddTHH:mm:00')
            $triggers += @"
    <TimeTrigger>
      <Repetition>
        <Interval>PT$($IntervalMinutes)M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$start</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
"@
        }
    }
    elseif ($Kind -eq 'poll') {
        $desc = "auto-loop: $IntervalMinutes 分ごとに、ダッシュボードの即時実行の印を見に行く ($KickScript)"
        $start = (Get-Date).AddMinutes(1).ToString('yyyy-MM-ddTHH:mm:00')
        $triggers = @"
    <TimeTrigger>
      <Repetition>
        <Interval>PT$([math]::Max(1, $IntervalMinutes))M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$start</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
"@
    }
    else {
        $desc = "auto-loop: 週の上限の解除時刻（の 6 分後）に毎週 PC を起こし、やることがあれば Claude Code のセッションを起こす ($KickScript)"
        $wake = 'true'
        $triggers = @"
    <CalendarTrigger>
      <StartBoundary>$($WeeklyAt.ToString('yyyy-MM-ddTHH:mm:00'))</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByWeek>
        <DaysOfWeek><$($WeeklyAt.DayOfWeek) /></DaysOfWeek>
        <WeeksInterval>1</WeeksInterval>
      </ScheduleByWeek>
    </CalendarTrigger>
"@
    }
    return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$(& $esc $desc)</Description>
  </RegistrationInfo>
  <Triggers>
$triggers  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$u</UserId>
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
    <WakeToRun>$wake</WakeToRun>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>conhost.exe</Command>
      <Arguments>$(& $esc $argsText)</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

# 週の解除時刻を決める（kick.weeklyResetAt があればそれ、無ければ記録から）。結果は state/kick-weekly.json に残し、
# 次からは前に調べた時刻より後に書かれた記録だけを読む（初回は 14 日分）。戻り値: ResetAt（$null なら不明）・Source
function Resolve-WeeklyReset {
    param($Kick, [string]$ProjectsDir, [switch]$NoSave)
    $file = Join-Path (Get-LoopHome) 'state/kick-weekly.json'
    $st = [ordered]@{ resetAt = ''; source = ''; scannedAt = ''; taskAt = '' }
    if (Test-Path -LiteralPath $file) {
        try { $o = [IO.File]::ReadAllText($file, $script:Utf8NoBom) | ConvertFrom-Json; foreach ($p in $o.PSObject.Properties) { if ($st.Contains($p.Name)) { $st[$p.Name] = [string]$p.Value } } } catch { }
    }
    $now = Get-Date
    $reset = $null; $source = ''
    if ([string]$Kick.weeklyResetAt) {
        $reset = ConvertFrom-WeeklyText ([string]$Kick.weeklyResetAt) $now
        $source = "設定 kick.weeklyResetAt = $($Kick.weeklyResetAt)"
    }
    else {
        $since = $now.AddDays(-14)
        if ($st.scannedAt) { try { $since = [datetimeoffset]::Parse($st.scannedAt).LocalDateTime.AddMinutes(-1) } catch { } }
        $found = Find-WeeklyResetFromTranscripts -ProjectsDir $ProjectsDir -Since $since
        $prev = $null
        if ($st.resetAt) { try { $prev = [datetimeoffset]::Parse($st.resetAt).LocalDateTime } catch { } }
        $reset = if ($found -and (-not $prev -or $found -gt $prev)) { $found } else { $prev }
        $source = 'セッションの記録の週の上限（resetsAt）'
        $st.scannedAt = Get-NowIso
    }
    if ($reset) { $st.resetAt = $reset.ToString('yyyy-MM-ddTHH:mm:sszzz'); $st.source = $source }
    if (-not $NoSave) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $file) | Out-Null
        Write-LoopText $file (([pscustomobject]$st) | ConvertTo-Json)
    }
    return [pscustomobject]@{ ResetAt = $reset; Source = $source; TaskAt = $st.taskAt; StateFile = $file }
}

# PC の状況を、指令リポジトリの state/pcs/<agentId>.json に書く（ダッシュボードが読む）。
# 中身（updatedAt を除く）が前と同じで、前に書いてから EveryMinutes 分たっていなければ、何もしない。
# このファイルだけをコミットし（ほかのセッションの書きかけを巻き込まない）、作業ツリーにほかの変更が無いときだけ push する。
# 認証情報・パス・セッションの中身は書かない。戻り値: 'written-pushed' / 'written-local' / 'unchanged' / 'off' / 'failed: …'
function Write-PcStatus {
    param($Config, [hashtable]$Status, [double]$EveryMinutes = 60)
    if ($EveryMinutes -le 0) { return 'off' }
    $repo = [string]$Config.controlRepoPath
    if (-not $repo -or -not (Test-Path -LiteralPath $repo)) { return 'failed: 指令リポジトリが無い' }
    $id = [string]$Config.agentId
    $rel = "state/pcs/$id.json"
    $file = Join-Path $repo $rel
    $now = Get-NowIso
    $body = [ordered]@{ agentId = $id; pc = [Environment]::MachineName; updatedAt = $now }
    foreach ($k in ($Status.Keys | Sort-Object)) { $body[$k] = $Status[$k] }
    # 比べるときはキーを並べ替える（PowerShell 7.1 の ConvertFrom-Json -AsHashtable は順序を保たない）
    $canon = $null
    $canon = {
        param($v)
        if ($v -is [System.Collections.IDictionary]) {
            $o = [ordered]@{}
            foreach ($k in (@($v.Keys) | Sort-Object)) { if ($k -ne 'updatedAt') { $o[$k] = & $canon $v[$k] } }
            return $o
        }
        if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { return , @($v | ForEach-Object { & $canon $_ }) }
        return $v
    }
    $prevAt = $null; $same = $false
    if (Test-Path -LiteralPath $file) {
        try {
            $old = [IO.File]::ReadAllText($file, $script:Utf8NoBom) | ConvertFrom-Json -AsHashtable
            $prevAt = [datetimeoffset]::Parse([string]$old['updatedAt'])
            $newH = ([pscustomobject]$body | ConvertTo-Json -Depth 5) | ConvertFrom-Json -AsHashtable   # 型をそろえる（JSON を往復）
            $same = (((& $canon $old) | ConvertTo-Json -Depth 6 -Compress) -eq ((& $canon $newH) | ConvertTo-Json -Depth 6 -Compress))
        }
        catch { }
    }
    if ($same -and $prevAt -and ([datetimeoffset]::Now - $prevAt).TotalMinutes -lt $EveryMinutes) { return 'unchanged' }
    try {
        New-Item -ItemType Directory -Force (Split-Path -Parent $file) | Out-Null
        Write-LoopText $file ((([pscustomobject]$body) | ConvertTo-Json -Depth 5) + "`n")
        Invoke-Git $repo @('add', '--', $rel) | Out-Null
        $c = Invoke-Git $repo @('commit', '-m', "[$id] pc-status", '--', $rel)
        if ($c.Code -ne 0) { return "failed: commit $($c.Text.Trim())" }
        # ほかの変更（別のセッションの書きかけ）があれば push しない。次の同期（sync.ps1・claim.ps1）で一緒に送られる
        if ((Invoke-Git $repo @('status', '--porcelain')).Text.Trim()) { return 'written-local' }
        $r = Sync-ControlRepo $Config -Message "[$id] pc-status"
        if ($r.Ok) { return 'written-pushed' } else { return "written-local（push できなかった: $($r.Reason)）" }
    }
    catch { return "failed: $($_.Exception.Message)" }
}

# 即時実行の印（ダッシュボードが指令リポジトリの state/kick/<agentId>.json に書く）。無い・読めなければ $null
function Read-KickRequest {
    param($Config)
    $file = Join-Path ([string]$Config.controlRepoPath) "state/kick/$([string]$Config.agentId).json"
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try { $j = [IO.File]::ReadAllText($file, $script:Utf8NoBom) | ConvertFrom-Json } catch { $j = $null }
    $get = { param($n) if ($j -and $j.PSObject.Properties[$n]) { [string]$j.$n } else { '' } }
    # ConvertFrom-Json は日時の形の文字列を日時に変える。ISO の形に戻す
    $at = if ($j -and $j.PSObject.Properties['requestedAt'] -and $j.requestedAt -is [datetime]) { ([datetimeoffset]$j.requestedAt).ToString('yyyy-MM-ddTHH:mm:sszzz') } else { & $get 'requestedAt' }
    return [pscustomobject]@{ requestedAt = $at; by = (& $get 'by'); task = (& $get 'task'); path = $file }
}

# 即時実行の印を消す（このファイルだけをコミットし、作業ツリーにほかの変更が無いときだけ push する。Write-PcStatus と同じ考え方）。
# 戻り値: 'removed-pushed' / 'removed-local…' / 'absent' / 'failed: …'
function Remove-KickRequest {
    param($Config, [string]$Note = '')
    $repo = [string]$Config.controlRepoPath
    $id = [string]$Config.agentId
    $rel = "state/kick/$id.json"
    if (-not (Test-Path -LiteralPath (Join-Path $repo $rel))) { return 'absent' }
    $lock = Enter-ControlLock $Config
    try {
        $tracked = (Invoke-Git $repo @('ls-files', '--', $rel)).Text.Trim()
        if (-not $tracked) { Remove-Item -LiteralPath (Join-Path $repo $rel) -Force; return 'removed-local（コミットされていない印）' }
        $rm = Invoke-Git $repo @('rm', '-q', '--', $rel)
        if ($rm.Code -ne 0) { return "failed: rm $($rm.Text.Trim())" }
        $msg = "[$id] kick-request$(if ($Note) { ": $Note" })"
        $c = Invoke-Git $repo @('commit', '-m', $msg, '--', $rel)
        if ($c.Code -ne 0) { return "failed: commit $($c.Text.Trim())" }
    }
    finally { Exit-ControlLock $lock }
    if ((Invoke-Git $repo @('status', '--porcelain')).Text.Trim()) { return 'removed-local' }
    $r = Sync-ControlRepo $Config -Message "[$id] kick-request"
    if ($r.Ok) { return 'removed-pushed' } else { return "removed-local（push できなかった: $($r.Reason)）" }
}

# 即時実行の依頼を、担当すべきエージェントに回す（エスカレーション）。自分の印（state/kick/<自分>.json）を消し、
# 回し先の印（state/kick/<To>.json）を書く。1 コミットで、作業ツリーにほかの変更が無いときだけ push する。
# 回し先にすでに印があれば、そちらを残して自分の印だけを消す（上書きしない）。escalatedFrom に回した元を残す（回し直さないため）
# 戻り値: 'escalated-pushed' / 'escalated-local…' / 'exists-removed…' / 'failed: …'
function Move-KickRequest {
    param($Config, $Request, [string]$To)
    $repo = [string]$Config.controlRepoPath
    $id = [string]$Config.agentId
    if ($To -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $To -eq $id) { return "failed: 回し先の ID が使えない（$To）" }
    $rel = "state/kick/$id.json"
    $toRel = "state/kick/$To.json"
    $toPath = Join-Path $repo $toRel
    if (Test-Path -LiteralPath $toPath) {
        $r = Remove-KickRequest -Config $Config -Note "$To にすでに依頼があるので、回さずに消した"
        return "exists-$r"
    }
    $lock = Enter-ControlLock $Config
    try {
        $body = [ordered]@{ requestedAt = [string]$Request.requestedAt; by = [string]$Request.by; task = [string]$Request.task; escalatedFrom = $id; escalatedAt = (Get-NowIso) }
        New-Item -ItemType Directory -Force (Split-Path -Parent $toPath) | Out-Null
        Write-LoopText $toPath (([pscustomobject]$body | ConvertTo-Json) + "`n")
        $add = Invoke-Git $repo @('add', '--', $toRel)
        if ($add.Code -ne 0) { return "failed: add $($add.Text.Trim())" }
        $paths = @($toRel)
        if ((Invoke-Git $repo @('ls-files', '--', $rel)).Text.Trim()) {
            $rm = Invoke-Git $repo @('rm', '-q', '--', $rel)
            if ($rm.Code -ne 0) { return "failed: rm $($rm.Text.Trim())" }
            $paths += $rel
        }
        elseif (Test-Path -LiteralPath (Join-Path $repo $rel)) { Remove-Item -LiteralPath (Join-Path $repo $rel) -Force }
        $c = Invoke-Git $repo (@('commit', '-m', "[$id] kick-request: $($Request.task) を $To に回した（エスカレーション）", '--') + $paths)
        if ($c.Code -ne 0) { return "failed: commit $($c.Text.Trim())" }
    }
    finally { Exit-ControlLock $lock }
    if ((Invoke-Git $repo @('status', '--porcelain')).Text.Trim()) { return 'escalated-local' }
    $r = Sync-ControlRepo $Config -Message "[$id] kick-request"
    if ($r.Ok) { return 'escalated-pushed' } else { return "escalated-local（push できなかった: $($r.Reason)）" }
}

# 即時実行で指定されたタスクを、自分が担当できないとき、回し先のエージェントの ID を返す（回せなければ ''）。
#   担当（claimed_by）がほかのエージェント → その ID
#   担当が無く、assignee が自分に合わず、エージェントの ID の形（<PC>-<道具>…。ハイフンを含む）→ assignee
#   道具の名前（claude など）・any・自分に合う・完了などは回さない
function Get-KickEscalationTarget {
    param([string]$Me, $Task)
    if (-not $Task -or $Task.status -in @('done', 'dropped', 'draft')) { return '' }
    if ($Task.claimedBy) { return $(if ($Task.claimedBy -ne $Me) { [string]$Task.claimedBy } else { '' }) }
    $a = [string]$Task.assignee
    if (-not $a -or (Test-LoopAssignee $Me $a)) { return '' }
    if ($a -match '^[A-Za-z0-9][A-Za-z0-9._]*-[A-Za-z0-9._-]+$') { return $a }
    return ''
}

# 週次のタスクの登録時刻を state/kick-weekly.json に書く
function Set-WeeklyTaskAt {
    param([string]$Iso)
    $file = Join-Path (Get-LoopHome) 'state/kick-weekly.json'
    $o = [ordered]@{ resetAt = ''; source = ''; scannedAt = ''; taskAt = '' }
    if (Test-Path -LiteralPath $file) { try { $j = [IO.File]::ReadAllText($file, $script:Utf8NoBom) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { if ($o.Contains($p.Name)) { $o[$p.Name] = [string]$p.Value } } } catch { } }
    $o.taskAt = $Iso
    Write-LoopText $file (([pscustomobject]$o) | ConvertTo-Json)
}

# 優先度の順（小さいほど先）。urgent（緊急）・solo（単独）は利用者が指定したときだけ使う。書いていない・知らない値は normal と同じ
function Get-PriorityRank {
    param([string]$Priority)
    switch ($Priority) { 'urgent' { return 0 } 'solo' { return 1 } 'high' { return 2 } 'low' { return 4 } default { return 3 } }
}

# 名簿（roster.md）の「AI のアカウント」: エージェントの ID → アカウントの呼び名。
# 空・例（<...>）のままの行は、道具が Claude（道具の列か ID の区切りに claude）なら既定の Claude のアカウント（'claude'）とみなす
# （利用枠は Claude のアカウント単位で共通なので、別の PC でも区別しない。使い分けるときだけ列に書く）。それ以外は載せない
function Get-RosterAccounts {
    param($Cfg)
    $map = @{}
    $path = Join-Path ([string]$Cfg.controlRepoPath) 'roster.md'
    if (-not (Test-Path -LiteralPath $path)) { return $map }
    $cols = $null
    foreach ($l in [IO.File]::ReadAllLines($path, $script:Utf8NoBom)) {
        if ($l -notmatch '^\s*\|') { $cols = $null; continue }
        $cells = @(($l.Trim().Trim('|')) -split '\|' | ForEach-Object { $_.Trim() })
        if (-not $cols) {
            if ($cells -contains 'ID') { $cols = @{ id = [array]::IndexOf($cells, 'ID'); acct = [array]::IndexOf($cells, 'AI のアカウント'); tool = [array]::IndexOf($cells, '道具') } }
            continue
        }
        if ($cells[0] -match '^-+$' -or $cols.id -ge $cells.Count) { continue }
        $id = $cells[$cols.id].Trim('`')
        if (-not $id -or $id -match '^<.*>$') { continue }
        $acct = if ($cols.acct -ge 0 -and $cols.acct -lt $cells.Count) { $cells[$cols.acct].Trim('`') } else { '' }
        $tool = if ($cols.tool -ge 0 -and $cols.tool -lt $cells.Count) { $cells[$cols.tool] } else { '' }
        if ($acct -and $acct -notmatch '^<.*>$') { $map[$id] = $acct }
        elseif (Test-ClaudeAgent $id $tool) { $map[$id] = 'claude' }
    }
    return $map
}

# Claude のエージェントか（道具の列に Claude、または ID の区切りに claude）
function Test-ClaudeAgent {
    param([string]$Id, [string]$Tool = '')
    return ($Tool -match '(?i)claude') -or ((($Id -split '-') | ForEach-Object { $_.ToLowerInvariant() }) -contains 'claude')
}

# エージェントのアカウント: 名簿に書いてあればそれ。名簿に無い Claude のエージェントは既定の 'claude'。分からなければ空
function Get-AgentAccount {
    param([hashtable]$Map, [string]$Id)
    if (-not $Id) { return '' }
    if ($Map.ContainsKey($Id)) { return $Map[$Id] }
    if (Test-ClaudeAgent $Id) { return 'claude' }
    return ''
}

# 同じ Claude アカウントで着手中の緊急・単独のタスク（AGENTS.md 7.3）: priority が urgent / solo で status が doing、
# 担当が自分か、アカウント（Get-AgentAccount）が自分と同じエージェント。アカウントが分からなければ自分の担当だけ
function Get-ExclusiveTasks {
    param($Cfg, $Tasks, [string]$Me)
    $acct = Get-RosterAccounts $Cfg
    $mine = Get-AgentAccount $acct $Me
    return @($Tasks | Where-Object {
            $_.priority -in @('urgent', 'solo') -and $_.status -eq 'doing' -and $_.claimedBy -and
            ($_.claimedBy -eq $Me -or ($mine -and (Get-AgentAccount $acct $_.claimedBy) -eq $mine))
        })
}

# 同じ優先度の中の順（order。小さいほど先）。書いていない・数でない値は、いちばん後ろ（そのあとは古い順）
function Get-OrderKey {
    param([string]$Order)
    $v = 0.0
    if ($Order -and $Order.Trim() -match '^-?\d+(\.\d+)?$' -and [double]::TryParse($Order.Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { return $v }
    return [double]::MaxValue
}

# assignee が自分に合うか（any・自分の ID・自分の道具の名前）
function Test-LoopAssignee {
    param([string]$Me, [string]$Assignee)
    if (-not $Assignee -or $Assignee -eq 'any') { return $true }
    return ($Me -eq $Assignee) -or (($Me -split '-') -contains $Assignee)
}

# 受付（inbox.md）の未整理の件: 「## 」見出し 1 つが 1 件。書く場所は問わない（冒頭の案内の下でも、末尾の目印の下でもよい）。
# 数えないもの: コードの囲み（```）の中（書き方の例）、「## 手が空いた時に実行するタスク」の節（次の「## 」まで）。
# Urgent は、そのうち「優先: 緊急」と書かれた件数
function Get-InboxSummary {
    param($Config)
    $count = 0; $urgent = 0
    $file = Join-Path $Config.controlRepoPath 'inbox.md'
    if (Test-Path -LiteralPath $file) {
        $fence = $false; $inItem = $false
        foreach ($l in (Read-LoopText $file) -split '\r?\n') {
            if ($l -match '^\s*```') { $fence = -not $fence; continue }
            if ($fence) { continue }
            if ($l -match '^##\s+\S') {
                $inItem = -not ($l -match '^##\s+手が空いた時に実行するタスク')
                if ($inItem) { $count++ }
                continue
            }
            if ($inItem -and $l -match '^優先[:：]\s*(緊急|urgent)') { $urgent++ }
        }
    }
    return [pscustomobject]@{ Count = $count; Urgent = $urgent }
}

# 「間隔:」の書き方を日数にする（毎回 = 0、省略・読めないときは 1 = 毎日。2026-11 に週 1 回から変えた）
function ConvertTo-IntervalDays {
    param([string]$Text)
    $t = ($Text -replace '\s', '')
    if (-not $t) { return 1 }
    if ($t -match '毎回') { return 0 }
    if ($t -match '毎日') { return 1 }
    if ($t -match '毎週') { return 7 }
    if ($t -match '毎月') { return 30 }
    if ($t -match '^(\d+)日') { return [int]$Matches[1] }
    if ($t -match '日(\d+)回') { return 1 }
    if ($t -match '週(\d+)回') { return [math]::Max(1, [int][math]::Floor(7 / [math]::Max(1, [int]$Matches[1]))) }
    if ($t -match '月(\d+)回') { return [math]::Max(1, [int][math]::Floor(30 / [math]::Max(1, [int]$Matches[1]))) }
    return 1
}

# inbox.md の「## 手が空いた時に実行するタスク」の定義（### <案件>: <件名>）を読む。
# コードの囲み（```）の中と、見出しが「（停止）」で始まるものは読まない。due = 間隔の内に実施していない
function Get-IdleDefinitions {
    param($Config)
    $defs = @()
    $file = Join-Path $Config.controlRepoPath 'inbox.md'
    if (-not (Test-Path -LiteralPath $file)) { return $defs }
    $in = $false; $fence = $false; $cur = $null
    foreach ($l in (Read-LoopText $file) -split '\r?\n') {
        if ($l -match '^\s*```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        if ($l -match '^##\s+手が空いた時に実行するタスク') { $in = $true; continue }
        if (-not $in) { continue }
        if ($l -match '^##\s' -or $l -match '<!--\s*ここから下に追記') { break }
        if ($l -match '^###\s+(.+?)\s*$') {
            if ($cur) { $defs += $cur }
            $cur = $null
            $head = $Matches[1]
            if ($head -match '^[（(]停止[）)]') { continue }
            $project = ''; $title = $head
            if ($head -match '^([^:：]+)[:：]\s*(.+)$') { $project = $Matches[1].Trim(); $title = $Matches[2].Trim() }
            $cur = [pscustomobject]@{ project = $project; title = $title; stage = 'propose'; interval = ''; intervalDays = 1; last = ''; due = $true }
            continue
        }
        if (-not $cur) { continue }
        if ($l -match '^段階[:：]\s*(.*)$') { $cur.stage = $(if ($Matches[1] -match '実装|implement') { 'implement' } else { 'propose' }) }
        elseif ($l -match '^間隔[:：]\s*(.*)$') { $cur.interval = $Matches[1].Trim(); $cur.intervalDays = ConvertTo-IntervalDays $Matches[1] }
        elseif ($l -match '^最終実施[:：]\s*(.*)$') { $cur.last = $Matches[1].Trim() }
    }
    if ($cur) { $defs += $cur }
    foreach ($d in $defs) {
        if ($d.last -match '(\d{4})-(\d{2})-(\d{2})') {
            try {
                $date = [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
                $d.due = (((Get-Date).Date - $date).TotalDays -ge $d.intervalDays)
            }
            catch { $d.due = $true }
        }
    }
    return $defs
}

# --- 同じ PC の複数のセッション（20261120-no-parallel-sessions） ---
# 担当はエージェント ID 単位なので、同じ PC・同じ ID の 2 つのセッション（上限からの再開と自動起動など）は、どちらも「自分の担当」とみなしてしまう。
# 進行中の印（state/active/<案件>--<タスク ID>.json）に担当したセッションを書き、別のセッションが生きて手を動かしている間は、claim / heartbeat / release を通さない。

# 進行中の印のファイル。別の案件に同じタスク ID があっても取り合わないよう、名前に案件を入れる（20261121-task-id-collision）。
# Legacy は古い版の名前（state/active/<タスク ID>.json）。中身の project が同じときだけ、同じタスクの印として読む
function Get-ActiveMarkPath {
    param([Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Task, [switch]$Legacy)
    $dir = Join-Path (Get-LoopHome) 'state/active'
    if ($Legacy) { return (Join-Path $dir "$Task.json") }
    return (Join-Path $dir "$Project--$Task.json")
}

# この PC の進行中の印をすべて読む。新旧の名前で同じ案件・同じタスクの印が 2 つあれば、新しい名前の方を採る
function Get-ActiveMarks {
    $dir = Join-Path (Get-LoopHome) 'state/active'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $byKey = [ordered]@{}
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' | Sort-Object { $_.BaseName -notlike '*--*' }, Name)) {
        try { $m = Read-LoopText $f.FullName | ConvertFrom-Json } catch { continue }
        if (-not $m) { continue }
        $key = "$([string]$m.project)/$([string]$m.task)"
        if (-not $byKey.Contains($key)) { $byKey[$key] = $m }
    }
    return @($byKey.Values)
}

# Claude Code のセッションの記録のフォルダ（試験では AUTO_LOOP_CLAUDE_PROJECTS で差し替える）
function Get-ClaudeProjectsDir {
    if ($env:AUTO_LOOP_CLAUDE_PROJECTS) { return $env:AUTO_LOOP_CLAUDE_PROJECTS }
    return (Join-Path $HOME '.claude/projects')
}

# いまのセッション。Claude Code は子のシェルに CLAUDE_CODE_SESSION_ID・CLAUDE_PID を渡す（2026-11 時点、Windows で確認）。
# 無い（Claude Code 以外の道具・手で実行）なら $null を返し、セッションの判定はしない（エージェント ID 単位のまま）
function Get-CurrentSession {
    $sid = [string]$env:CLAUDE_CODE_SESSION_ID
    if (-not $sid) { return $null }
    $procId = 0; $start = ''
    if ([int]::TryParse([string]$env:CLAUDE_PID, [ref]$procId) -and $procId -gt 0) {
        try { $start = (Get-Process -Id $procId -ErrorAction Stop).StartTime.ToString('o') } catch { $start = '' }
    }
    return [pscustomobject]@{ SessionId = $sid; Pid = $procId; ProcessStart = $start }
}

# 印のセッションが「生きて手を動かしている」か。戻り値の Live が true なら、ほかのセッションは担当を続けられない。
#   プロセスが終わっている（pid が無い・開始時刻が違う = 番号の使い回し）→ 手放した
#   記録の状態（Get-SessionActivity）が limit（上限の解除待ち）・waiting-input（入力待ち）・empty → 手放した
#   working・stale（長いツールの実行・権限の確認待ちもありうる）→ 生きている
#   記録が見つからない（プロセスは生きている）→ 確かめられないので、生きているとみなす（二重に進めるより安全）
function Test-SessionLive {
    param($Mark, [double]$BusyMinutes = 15, [string]$ProjectsDir = (Get-ClaudeProjectsDir))
    $sid = if ($Mark -and $Mark.PSObject.Properties['sessionId']) { [string]$Mark.sessionId } else { '' }
    if (-not $sid) { return [pscustomobject]@{ Live = $false; Reason = 'no-session'; SessionId = '' } }
    $procId = if ($Mark.PSObject.Properties['pid']) { [int]$Mark.pid } else { 0 }
    if ($procId -gt 0) {
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        # 終わったプロセスでも、ほかのプロセスがハンドルを持っている間は番号で見つかる（HasExited で見分ける）
        $exited = $false; if ($p) { try { $exited = $p.HasExited } catch { } }
        if (-not $p -or $exited) { return [pscustomobject]@{ Live = $false; Reason = 'process-ended'; SessionId = $sid } }
        $want = if ($Mark.PSObject.Properties['processStart']) { [string]$Mark.processStart } else { '' }
        if ($want) {
            try {
                if ([math]::Abs(($p.StartTime - [datetime]::Parse($want, $null, 'RoundtripKind')).TotalSeconds) -gt 2) { return [pscustomobject]@{ Live = $false; Reason = 'process-ended'; SessionId = $sid } }
            }
            catch { }
        }
    }
    $log = $null
    if (Test-Path -LiteralPath $ProjectsDir) {
        foreach ($d in @(Get-ChildItem -LiteralPath $ProjectsDir -Directory -ErrorAction SilentlyContinue)) {
            $f = Join-Path $d.FullName "$sid.jsonl"
            if (Test-Path -LiteralPath $f) { $log = $f; break }
        }
    }
    if (-not $log) {
        if ($procId -gt 0) { return [pscustomobject]@{ Live = $true; Reason = 'no-transcript'; SessionId = $sid } }
        return [pscustomobject]@{ Live = $false; Reason = 'no-transcript'; SessionId = $sid }
    }
    $state = (Get-SessionActivity -Path $log -BusyMinutes $BusyMinutes).State
    return [pscustomobject]@{ Live = ($state -in @('working', 'stale')); Reason = $state; SessionId = $sid }
}

# ---- 判断待ち・完了になったセッションを終わらせる見張り（close-watch.ps1。2026-11-21） ----

# JSON から読んだ時刻を ISO 8601 の文字列にする。PowerShell 7 の ConvertFrom-Json は ISO 8601 の文字列を DateTime に変えるので、
# そのまま [string] にすると「11/21/2026 07:33:41」（空白を含み、カルチャによっては読めない）になる
function ConvertTo-IsoTime {
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToString('o') }
    if ($Value -is [datetimeoffset]) { return $Value.ToString('o') }
    return [string]$Value
}

# 指定の pid のプロセスが動いていて、StartedAt（ISO 8601 か DateTime。空なら見ない）より前から動いているか（pid の使い回しを取り違えない）
function Test-HostProcess {
    param([int]$ProcessId, $StartedAt = '')
    if ($ProcessId -le 0) { return $false }
    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    try { if ($p.HasExited) { return $false } } catch { }
    $at = ConvertTo-IsoTime $StartedAt
    if (-not $at) { return $true }
    try { return ($p.StartTime -le [datetimeoffset]::Parse($at, [Globalization.CultureInfo]::InvariantCulture).LocalDateTime.AddMinutes(1)) } catch { return $true }
}

# セッションの記録（本体の .jsonl）の場所。無ければ空
function Find-SessionTranscript {
    param([string]$SessionId, [string]$ProjectsDir = (Get-ClaudeProjectsDir))
    if (-not $SessionId -or -not (Test-Path -LiteralPath $ProjectsDir)) { return '' }
    foreach ($d in @(Get-ChildItem -LiteralPath $ProjectsDir -Directory -ErrorAction SilentlyContinue)) {
        $f = Join-Path $d.FullName "$SessionId.jsonl"
        if (Test-Path -LiteralPath $f) { return $f }
    }
    return ''
}

# セッションが claim.ps1 で触れたタスクの ID（担当の主張・印・解放・引き継ぎ）。ツールの呼び出し（tool_use）の行だけを見る
# （読み込んだ手順書の例や、応答の文中に書いた ID は拾わない）
function Get-SessionTaskRefs {
    param([string[]]$Paths)
    $ids = [Collections.Generic.List[string]]::new()
    $re = 'claim\.ps1(?:\\"|"|'')?\s+(?:claim|heartbeat|release|takeover)\s+(?:\\"|"|'')?(\d{8}-[A-Za-z0-9][A-Za-z0-9._-]*)'
    foreach ($p in @($Paths)) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        foreach ($l in (Read-SessionTailLines $p -MaxBytes 256MB)) {
            if ($l.IndexOf('claim.ps1') -lt 0 -or $l.IndexOf('"tool_use"') -lt 0) { continue }
            foreach ($m in [regex]::Matches($l, $re)) { $id = $m.Groups[1].Value; if (-not $ids.Contains($id)) { $ids.Add($id) } }
        }
    }
    return $ids.ToArray()
}

# TaskIds のうち、このセッション（SessionIds のどれか）がまだ手に持っているもの（自分が担当で、状態が判断待ち・完了などでない）。
# 進行中の印が別のセッションのものなら、そのセッションのものとして数えない。読めなければ $null（終わらせない側に倒す）
function Get-HeldTasks {
    param($Config, [string[]]$TaskIds, [string[]]$SessionIds)
    $me = [string]$Config.agentId
    $settled = @('waiting', 'review', 'blocked', 'done', 'dropped', 'ready')
    try { $all = @(Get-LoopTasks $Config); $marks = @(Get-ActiveMarks) } catch { return $null }
    $held = @(); $seen = @()
    foreach ($id in @($TaskIds)) {
        # 別の案件に同じ ID があれば、どれも見る（記録の claim.ps1 の呼び出しからは、案件まで分からないことがある）
        $ts = @($all | Where-Object { $_.id -eq $id })
        if ($ts.Count -eq 0) { $seen += "$id=保管済み"; continue }
        foreach ($t in $ts) {
            $seen += $(if ($ts.Count -gt 1) { "$($t.project)/$id=$($t.status)" } else { "$id=$($t.status)" })
            if ($t.claimedBy -ne $me -or $t.status -in $settled) { continue }
            $owner = ''
            $m = @($marks | Where-Object { [string]$_.project -eq $t.project -and [string]$_.task -eq $id }) | Select-Object -First 1
            if ($m -and $m.PSObject.Properties['sessionId'] -and $m.sessionId) { $owner = [string]$m.sessionId }
            if ($owner -and $owner -notin @($SessionIds)) { continue }   # 同じ PC の別のセッションが持っている
            $held += $t
        }
    }
    return [pscustomobject]@{ Held = $held; Summary = ($seen -join ' ') }
}

# セッションを終わらせてはいけない理由（無ければ ''）。セッションの記録（本体。再開元も）から探す:
#   Skills のスキルを使った（Skill の呼び出しの input.skill。「プラグイン:名前」の名前の部分でも合わせる。/<スキル> と打った記録も）
#   利用者が Phrases のどれかを書いた（利用者の入力だけ。ツールの結果・自動の通知・サブエージェントは見ない。大文字・小文字は区別しない）
# 記録の形は Claude Code の内部形式（2026-11 時点）
function Get-KeepOpenReason {
    param([string[]]$Paths, [string[]]$Skills = @('long-run'), [string[]]$Phrases = @())
    $skillSet = @($Skills | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $phraseSet = @($Phrases | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() })
    if (-not $skillSet.Count -and -not $phraseSet.Count) { return '' }
    $nameOf = { param($n) $x = ([string]$n).ToLowerInvariant().TrimStart('/'); if ($x.Contains(':')) { $x = $x.Substring($x.LastIndexOf(':') + 1) }; $x }
    foreach ($p in @($Paths)) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        foreach ($l in (Read-SessionTailLines $p -MaxBytes 64MB)) {
            if (-not $l.StartsWith('{')) { continue }
            $isTool = $l.IndexOf('"tool_use"') -ge 0 -and $l.IndexOf('"Skill"') -ge 0
            $isUser = $l.IndexOf('"type":"user"') -ge 0
            if (-not $isTool -and -not $isUser) { continue }
            try { $r = $l | ConvertFrom-Json } catch { continue }
            if ($r.PSObject.Properties['isSidechain'] -and $r.isSidechain) { continue }
            $content = if ($r.message -and $r.message.PSObject.Properties['content']) { $r.message.content } else { $null }
            if ($r.type -eq 'assistant' -and $skillSet.Count) {
                foreach ($c in @($content)) {
                    if ($c -and $c.PSObject.Properties['type'] -and $c.type -eq 'tool_use' -and $c.name -eq 'Skill' -and $c.input -and $c.input.PSObject.Properties['skill']) {
                        $n = & $nameOf $c.input.skill
                        if ($n -in $skillSet) { return "スキル $($c.input.skill) を使った" }
                    }
                }
            }
            elseif ($r.type -eq 'user') {
                if ($r.PSObject.Properties['isMeta'] -and $r.isMeta) { continue }
                if ($r.PSObject.Properties['origin'] -and $r.origin -and $r.origin.PSObject.Properties['kind'] -and $r.origin.kind -ne 'human') { continue }
                $text = if ($content -is [string]) { $content } else { (@($content) | Where-Object { $_ -and $_.PSObject.Properties['type'] -and $_.type -eq 'text' } | ForEach-Object { [string]$_.text }) -join "`n" }
                if (-not $text -or $text -match '^\s*<(task-notification|system-reminder|local-command-stdout)>') { continue }
                $low = $text.ToLowerInvariant()
                foreach ($m in [regex]::Matches($low, '<command-name>/?([^<\s]+)</command-name>')) {
                    if ((& $nameOf $m.Groups[1].Value) -in $skillSet) { return "スキル $($m.Groups[1].Value) を使った" }
                }
                foreach ($ph in $phraseSet) { if ($low.Contains($ph)) { return "利用者が「$ph」と書いた" } }
            }
        }
    }
    return ''
}

# 見張りの 1 回分の判断。戻り値の Close が true なら終わらせる。Note は見送りの理由・状態（ログ用）
#   kick（自動起動のセッション）: 記録が idleCloseMinutes 分のあいだ書かれない、
#                                 または入力待ちが settledCloseMinutes 分続き、手に持っているタスクが無い（何も担当しなかったときも含む）
#   resume（auto-resume-global が再開したセッション）: 入力待ちが settledCloseMinutes 分続き、claim.ps1 で触れたタスクがあって、
#                                 そのどれも手に持っていない（auto-loop のタスクに触れていないセッションは終わらせない）
function Get-CloseDecision {
    param($Config, [ValidateSet('kick', 'resume')][string]$Source, [string[]]$SessionIds, [string[]]$TranscriptPaths,
        [datetime]$WatchStartedAt, [datetime]$Now = (Get-Date))
    $kick = Get-KickConfig $Config
    $main = if (@($TranscriptPaths).Count) { [string]@($TranscriptPaths)[0] } else { '' }
    $state = 'empty'; $lastWrite = $WatchStartedAt; $pending = $false
    if ($main -and (Test-Path -LiteralPath $main)) {
        $a = Get-SessionActivity -Path $main -BusyMinutes ([double]$kick.busyMinutes) -LongToolMinutes ([double]$kick.longToolMinutes)
        $state = $a.State; if ($a.LastWrite) { $lastWrite = $a.LastWrite }
        $pending = [bool]$a.PendingTool
    }
    $quiet = ($Now - $lastWrite).TotalMinutes
    $idle = ($Now - $(if ($lastWrite -gt $WatchStartedAt) { $lastWrite } else { $WatchStartedAt })).TotalMinutes
    $r = { param($Close, $Reason) [pscustomobject]@{ Close = [bool]$Close; Reason = $Reason; State = $state } }
    # long-run などのスキルを使った・利用者が「終了しないで」と書いたセッションは、終わらせない
    $keep = Get-KeepOpenReason -Paths $TranscriptPaths -Skills @($kick.keepOpenSkills) -Phrases @($kick.keepOpenPhrases)
    if ($keep) { return (& $r $false "keep-open（$keep。状態 $state）") }
    # ツールの実行中（試験などの長い実行）は、longToolMinutes までは「書かれない」で終わらせない
    if ($pending -and [double]$kick.longToolMinutes -gt 0 -and $quiet -lt [double]$kick.longToolMinutes) {
        return (& $r $false ('tool-running（ツールの実行中 {0:0} 分。longToolMinutes = {1}）' -f $quiet, $kick.longToolMinutes))
    }
    if ($Source -eq 'kick' -and [double]$kick.idleCloseMinutes -gt 0 -and $idle -ge [double]$kick.idleCloseMinutes) {
        return (& $r $true "idle-close（記録が $($kick.idleCloseMinutes) 分のあいだ書かれなかった。状態 $state）")
    }
    if ([double]$kick.settledCloseMinutes -le 0 -or ($Source -eq 'resume' -and -not $kick.settledCloseResumed)) { return (& $r $false "$state（判断待ち・完了で終わらせない設定）") }
    if ($state -ne 'waiting-input') { return (& $r $false $state) }
    if ($quiet -lt [double]$kick.settledCloseMinutes) { return (& $r $false ('waiting-input（{0:0.0} 分）' -f $quiet)) }
    $refs = @(Get-SessionTaskRefs $TranscriptPaths)
    if ($Source -eq 'resume' -and $refs.Count -eq 0) { return (& $r $false 'waiting-input（auto-loop のタスクに触れていない）') }
    $h = Get-HeldTasks -Config $Config -TaskIds $refs -SessionIds $SessionIds
    if ($null -eq $h) { return (& $r $false 'waiting-input（タスクの状態を読めない）') }
    if (@($h.Held).Count -gt 0) { return (& $r $false "waiting-input（担当中: $((@($h.Held) | ForEach-Object { "$($_.id)=$($_.status)" }) -join ' ')）") }
    $what = if ($refs.Count) { $h.Summary } else { '担当したタスクは無い' }
    return (& $r $true ("settled-close（入力待ち {0:0} 分、{1}）" -f $quiet, $what))
}

# HostPid（claude を起動したシェル）の子プロセスのうち、claude（とその子）を終わらせる。
# シェル・conhost（見張り自身や、裏で動かしているもの）は残す。シェルは claude が終わると後始末をして閉じ、ウィンドウも閉じる
function Stop-SessionHost {
    param([int]$HostPid)
    # taskkill は、子の一部を終わらせられないと（すでに終わりかけているものなど）標準エラーに書いて 0 以外で終わる。
    # ErrorActionPreference = Stop のままだと例外になり、終わらせたのに「閉じた」を記録できない（2026-11-21 に本番で 2 件）
    $ErrorActionPreference = 'Continue'
    $done = @()
    foreach ($k in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$HostPid" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('conhost.exe', 'pwsh.exe', 'powershell.exe') -and $_.ProcessId -ne $PID })) {
        $null = & taskkill.exe /PID $k.ProcessId /T /F 2>&1
        $left = Get-Process -Id $k.ProcessId -ErrorAction SilentlyContinue
        $done += "$($k.Name)/$($k.ProcessId)$(if ($left -and -not $left.HasExited) { '（終わらせられなかった）' })"
    }
    return $done
}

# 見張りの印（state/close-watch/<ID>.json）。見張りが動いていれば true
function Test-CloseWatchRunning {
    param([string]$SessionId)
    $f = Join-Path (Get-LoopHome) "state/close-watch/$SessionId.json"
    if (-not (Test-Path -LiteralPath $f)) { return $false }
    try { $m = Read-LoopText $f | ConvertFrom-Json } catch { return $false }
    return (Test-HostProcess ([int]$m.pid) $m.startedAt)
}

# 見張り（close-watch.ps1）を、ウィンドウを出さずに別のプロセスで起動する
function Start-CloseWatch {
    param([Parameter(Mandatory)][string]$SessionId, [Parameter(Mandatory)][int]$HostPid, [ValidateSet('kick', 'resume')][string]$Source = 'kick',
        [string]$ParentSessionId = '', [string]$HostStartedAt = '', [int]$IntervalSeconds = 60)
    $script = Join-Path (Split-Path -Parent $PSScriptRoot) 'close-watch.ps1'
    $shell = (Get-Process -Id $PID).Path
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -SessionId $SessionId -HostPid $HostPid -Source $Source -IntervalSeconds $IntervalSeconds"
    if ($ParentSessionId) { $a += " -ParentSessionId `"$ParentSessionId`"" }
    if ($HostStartedAt) { $a += " -HostStartedAt `"$(ConvertTo-IsoTime $HostStartedAt)`"" }
    $conhost = if ($IsWindows) { Join-Path $env:SystemRoot 'System32\conhost.exe' } else { '' }
    if ($conhost -and (Test-Path -LiteralPath $conhost)) { return (Start-Process -FilePath $conhost -ArgumentList "--headless `"$shell`" $a" -WindowStyle Hidden -PassThru) }
    return (Start-Process -FilePath $shell -ArgumentList $a -PassThru)
}

# auto-resume-global が再開して、いま動いているセッション（state/running/<ID>.json の印。pid は再開のシェル）
function Get-ResumedSessions {
    param([string]$AutoResumeHome)
    $dir = Join-Path $AutoResumeHome 'state/running'
    $list = @()
    if (-not (Test-Path -LiteralPath $dir)) { return $list }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        try { $m = [IO.File]::ReadAllText($f.FullName, $script:Utf8NoBom) | ConvertFrom-Json } catch { continue }
        $sid = if ($m.PSObject.Properties['sessionId']) { [string]$m.sessionId } else { '' }
        $procId = if ($m.PSObject.Properties['pid']) { [int]$m.pid } else { 0 }
        $at = if ($m.PSObject.Properties['startedAt']) { ConvertTo-IsoTime $m.startedAt } else { '' }
        if (-not $sid -or -not (Test-HostProcess $procId $at)) { continue }
        $list += [pscustomobject]@{
            SessionId = $sid; Pid = $procId; StartedAt = $at
            ParentSessionId = $(if ($m.PSObject.Properties['parentSessionId']) { [string]$m.parentSessionId } else { '' })
        }
    }
    return $list
}

# 指令リポジトリごとの、PC の中の排他（名前付きミューテックス）。同じスレッドなら入れ子にできる。
# 取れなければ（TimeoutSeconds 秒）例外。前の持ち主が異常終了していたら（AbandonedMutexException）、そのまま取ったものとして使う
function Enter-ControlLock {
    param($Config, [int]$TimeoutSeconds = 180)
    $path = [IO.Path]::GetFullPath([string]$Config.controlRepoPath).TrimEnd('\', '/').ToLowerInvariant()
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($path))).Substring(0, 16)
    $m = [Threading.Mutex]::new($false, "Local\auto-loop-control-$hash")
    $got = $false
    try { $got = $m.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds)) }
    catch [Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) { $m.Dispose(); throw "指令リポジトリの排他を $TimeoutSeconds 秒で取れない（同じ PC の別のセッションが git の操作中）" }
    return $m
}

function Exit-ControlLock {
    param($Lock)
    if (-not $Lock) { return }
    try { $Lock.ReleaseMutex() } catch { }
    $Lock.Dispose()
}

# ---- 利用率（5 時間・週）。Claude Code のステータスラインに渡る JSON の rate_limits（Pro・Max の契約で、最初の応答のあとだけ出る）から ----
# statusline-usage.ps1 が state/usage.json に書き、kick.ps1 が PC の状況（usage）に載せる。ダッシュボードが PC の表に出す
function Get-UsageFile { return (Join-Path (Get-LoopHome) 'state/usage.json') }

function ConvertTo-UsageSnapshot {
    param($StatusJson, [datetime]$Now = (Get-Date))
    if (-not $StatusJson -or -not ($StatusJson.PSObject.Properties.Name -contains 'rate_limits') -or -not $StatusJson.rate_limits) { return $null }
    $rl = $StatusJson.rate_limits
    $snap = [ordered]@{ capturedAt = $Now.ToString('yyyy-MM-ddTHH:mm:sszzz') }
    foreach ($pair in @(@('five_hour', 'fiveHour'), @('seven_day', 'sevenDay'))) {
        $w = if ($rl.PSObject.Properties.Name -contains $pair[0]) { $rl.($pair[0]) } else { $null }
        if (-not $w) { continue }
        $o = [ordered]@{}
        if ($w.PSObject.Properties.Name -contains 'used_percentage' -and $null -ne $w.used_percentage) {
            try { $o.usedPercentage = [math]::Round([double]$w.used_percentage, 1) } catch { }
        }
        if ($w.PSObject.Properties.Name -contains 'resets_at' -and $w.resets_at) {
            try { $o.resetsAt = [DateTimeOffset]::FromUnixTimeSeconds([long][double]$w.resets_at).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz') } catch { }
        }
        if ($o.Count -gt 0) { $snap[$pair[1]] = $o }
    }
    if ($snap.Count -le 1) { return $null }
    return $snap
}

function Save-UsageSnapshot {
    param([Parameter(Mandatory)]$Snapshot, [string]$Path = (Get-UsageFile))
    New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null
    # 書きかけを読まれないよう、一時ファイルに書いてから置き換える（複数のセッションが同時に書いても壊れない）
    $tmp = "$Path.$PID.tmp"
    [IO.File]::WriteAllText($tmp, ((([pscustomobject]$Snapshot) | ConvertTo-Json -Depth 4) + "`n"), $script:Utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

# 前回の値を読む。値は書いた時点のもの（capturedAt）。解除時刻を過ぎた窓も残す（ダッシュボードが「解除済み」と出す）
function Read-UsageSnapshot {
    param([string]$Path = (Get-UsageFile))
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { $j = [IO.File]::ReadAllText($Path, $script:Utf8NoBom) | ConvertFrom-Json } catch { return $null }
    if (-not $j -or -not $j.capturedAt) { return $null }
    $o = [ordered]@{ capturedAt = [string]$j.capturedAt }
    foreach ($k in @('fiveHour', 'sevenDay')) {
        if (-not ($j.PSObject.Properties.Name -contains $k) -or -not $j.$k) { continue }
        $w = [ordered]@{}
        if ($j.$k.PSObject.Properties.Name -contains 'usedPercentage' -and $null -ne $j.$k.usedPercentage) { $w.usedPercentage = [double]$j.$k.usedPercentage }
        if ($j.$k.PSObject.Properties.Name -contains 'resetsAt' -and $j.$k.resetsAt) { $w.resetsAt = [string]$j.$k.resetsAt }
        if ($w.Count -gt 0) { $o[$k] = $w }
    }
    if ($o.Count -le 1) { return $null }
    return $o
}

Export-ModuleMember -Function *
