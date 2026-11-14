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

Export-ModuleMember -Function *
