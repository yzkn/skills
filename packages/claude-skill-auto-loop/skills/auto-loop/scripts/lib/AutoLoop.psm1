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

# コミット（変更があれば）→ 取り込み → 送信。競合したら rebase を取り消して報告する（強制はしない）
function Sync-ControlRepo {
    param($Config, [Parameter(Mandatory)][string]$Message)
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
        minIntervalHours     = 4        # 前に起こしてから、次に起こすまでの最短の時間
        idle                 = $true    # 通常のタスクが無いとき、手が空いたときの作業のために起こすか
        idleMinIntervalHours = 24       # 手が空いたときの作業のために起こす間隔
        busyMinutes          = 15       # 作業中のセッション（入力待ちでないもの）の記録がこの分の内に書かれていれば、起こさない（0 なら見ない）
        idleCloseMinutes     = 60       # 起こしたセッションの記録がこの分のあいだ書かれなければ、終わらせる（0 なら終わらせない）
        intervalMinutes      = 0        # この分ごとにも kick.ps1 を起動する（0 なら使わない。15・30 など）。起こすかどうかは同じ判断
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

# セッションが「手を動かしているか」を、最後の会話の記録から判定する（kick.ps1 の 1 台 1 セッションの数え方。依頼 20261119-autoresume-fix-idle-dashboard）。
#   empty         会話の記録が無い（起動したが何も指示されていない）
#   limit         最後が利用上限の記録（解除待ち。kick.ps1 は復帰タスクで別に見る）
#   waiting-input 最後が assistant の応答で、ツールの呼び出しが無い（利用者の入力待ち）
#   working       最後が user の入力・ツールの結果、またはツールを呼び出し中で、BusyMinutes 分の内に記録（サブエージェントの記録を含む）が書かれた
#   stale         working の形だが、BusyMinutes 分より長く書かれていない（権限の確認待ち・異常終了など。長いツールの実行もここに入りうる）
# 利用者の入力ではない user の記録（サブエージェントの通知・isMeta など）と、サブエージェント側の記録（isSidechain）は飛ばす。
# 記録の形は Claude Code の内部形式（2026-11 時点）。版が変わったら実物に合わせて直す
function Get-SessionActivity {
    param([string]$Path, [double]$BusyMinutes = 15)
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) { return [pscustomobject]@{ State = 'empty'; LastWrite = $null; Path = $Path } }
    $lastWrite = $item.LastWriteTime
    $sub = Join-Path $item.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($item.Name))
    if (Test-Path -LiteralPath $sub) {
        $s = Get-ChildItem -LiteralPath $sub -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($s -and $s.LastWriteTime -gt $lastWrite) { $lastWrite = $s.LastWriteTime }
    }
    $state = 'empty'
    $lines = Read-SessionTailLines $Path
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $l = $lines[$i].TrimEnd("`r")
        if (-not $l.StartsWith('{')) { continue }
        try { $r = $l | ConvertFrom-Json } catch { continue }
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
        break
    }
    if ($state -eq 'working' -and ((Get-Date) - $lastWrite).TotalMinutes -gt $BusyMinutes) { $state = 'stale' }
    return [pscustomobject]@{ State = $state; LastWrite = $lastWrite; Path = $Path }
}

# この PC で「手を動かしている」セッションを数える。BusyMinutes 分の内に書かれた記録（本体かサブエージェント）だけを読む。
# 戻り値の Working が 1 件以上なら、ほかのセッションが動いている。Idle は数えなかったもの（入力待ちなど）の内訳
function Get-BusySessions {
    param([string]$ProjectsDir, [double]$BusyMinutes = 15, [string[]]$ExcludeSessionIds = @())
    $working = @(); $idle = @()
    if (-not (Test-Path -LiteralPath $ProjectsDir)) { return [pscustomobject]@{ Working = $working; Idle = $idle } }
    $cutoff = (Get-Date).AddMinutes(-$BusyMinutes)
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
            $a = Get-SessionActivity -Path $main -BusyMinutes $BusyMinutes
            $row = [pscustomobject]@{ SessionId = $sid; Project = $d.Name; State = $a.State; LastWrite = $a.LastWrite }
            if ($a.State -eq 'working') { $working += $row } else { $idle += $row }
        }
    }
    return [pscustomobject]@{ Working = $working; Idle = $idle }
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
function New-KickTaskXml {
    param([ValidateSet('main', 'weekly')][string]$Kind, [string]$KickScript, [string]$Shell, [string]$User, [int]$IntervalMinutes = 0, [datetime]$WeeklyAt)
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

# 週次のタスクの登録時刻を state/kick-weekly.json に書く
function Set-WeeklyTaskAt {
    param([string]$Iso)
    $file = Join-Path (Get-LoopHome) 'state/kick-weekly.json'
    $o = [ordered]@{ resetAt = ''; source = ''; scannedAt = ''; taskAt = '' }
    if (Test-Path -LiteralPath $file) { try { $j = [IO.File]::ReadAllText($file, $script:Utf8NoBom) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { if ($o.Contains($p.Name)) { $o[$p.Name] = [string]$p.Value } } } catch { } }
    $o.taskAt = $Iso
    Write-LoopText $file (([pscustomobject]$o) | ConvertTo-Json)
}

# 優先度の順（小さいほど先）。urgent は利用者が指定したときだけ使う。書いていない・知らない値は normal と同じ
function Get-PriorityRank {
    param([string]$Priority)
    switch ($Priority) { 'urgent' { return 0 } 'high' { return 1 } 'low' { return 3 } default { return 2 } }
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

# 「間隔:」の書き方を日数にする（毎回 = 0、省略・読めないときは 7）
function ConvertTo-IntervalDays {
    param([string]$Text)
    $t = ($Text -replace '\s', '')
    if (-not $t) { return 7 }
    if ($t -match '毎回') { return 0 }
    if ($t -match '毎日') { return 1 }
    if ($t -match '毎週') { return 7 }
    if ($t -match '毎月') { return 30 }
    if ($t -match '^(\d+)日') { return [int]$Matches[1] }
    if ($t -match '日(\d+)回') { return 1 }
    if ($t -match '週(\d+)回') { return [math]::Max(1, [int][math]::Floor(7 / [math]::Max(1, [int]$Matches[1]))) }
    if ($t -match '月(\d+)回') { return [math]::Max(1, [int][math]::Floor(30 / [math]::Max(1, [int]$Matches[1]))) }
    return 7
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
            $cur = [pscustomobject]@{ project = $project; title = $title; stage = 'propose'; interval = ''; intervalDays = 7; last = ''; due = $true }
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

Export-ModuleMember -Function *
