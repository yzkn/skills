#requires -Version 7.0
<#
.SYNOPSIS
  auto-loop をこの PC に導入する（スキルの写しと、実行時のフォルダ・設定の用意）。何度実行しても安全。
.DESCRIPTION
  - スキル: <SkillsDir>/auto-loop/ （既定 ~/.claude/skills/auto-loop/）
  - 実行時のファイル: ~/.claude/auto-loop/ （config.json・state/active/・logs/・work/）
  - -LinkAutoResume: auto-resume-global の再開の指示に「/auto-loop resume（担当中のタスクが無ければ /auto-loop next）を実行する」案内を足す（控えを取る。前の版の案内は置き換える）
  - -EnableKick: 起動時（ログオン時）・スリープ解除時に kick.ps1 を起動するタスク AutoLoopKick を登録し、config.json の kick.enabled を true にする
    （やることがあるときだけ、新しいウィンドウでセッションを起こす。Windows 専用。auto-resume-global が導入済みのときだけ動く）
    -KickIntervalMinutes <分>: その分ごとにも kick.ps1 を起動する（kick.intervalMinutes。0 で止める。省くと設定のまま）
    週の上限の解除時刻が分かれば（kick.weeklyAtReset が true のとき）、その 6 分後に毎週 PC を起こして kick.ps1 を起動するタスク
    AutoLoopKickWeekly も登録する。解除時刻が変わったら kick.ps1 が登録し直す
  - -DisableKick: タスク AutoLoopKick・AutoLoopKickWeekly を消し、kick.enabled を false にする
  スキル・フォルダ・ログの名前は、すべて配布名 auto-loop にそろえてある。
.EXAMPLE
  pwsh -NoProfile -File install.ps1 -AgentId pc1-claude-main -ControlRepoPath C:\Users\me\Documents\GitHub\loop-control
#>
param(
    [string]$AgentId = '',
    [string]$ControlRepoPath = '',
    [string]$SkillsDir = (Join-Path $HOME '.claude/skills'),
    [switch]$NoCopy,
    [switch]$LinkAutoResume,
    [switch]$EnableKick,
    [switch]$DisableKick,
    [int]$KickIntervalMinutes = -1
)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$loopHome = if ($env:AUTO_LOOP_HOME) { $env:AUTO_LOOP_HOME } else { Join-Path $HOME '.claude/auto-loop' }
$arHome = if ($env:AUTO_LOOP_AUTO_RESUME_HOME) { $env:AUTO_LOOP_AUTO_RESUME_HOME } else { Join-Path $HOME '.claude/auto-resume-global' }
$src = Split-Path -Parent $PSScriptRoot           # skills/auto-loop
$dest = Join-Path $SkillsDir 'auto-loop'

# 1. スキルの写し
if (-not $NoCopy) {
    if ([IO.Path]::GetFullPath($src).TrimEnd('\', '/') -ieq [IO.Path]::GetFullPath($dest).TrimEnd('\', '/')) { Write-Output "スキル: 導入先から実行しているので写さない（$dest）" }
    else {
        New-Item -ItemType Directory -Force $dest | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
        Write-Output "スキル: $dest に写した"
    }
}

# 2. 実行時のフォルダ
foreach ($d in @('state/active', 'logs', 'work')) { New-Item -ItemType Directory -Force (Join-Path $loopHome $d) | Out-Null }

# 3. 設定（あるものは残し、足りない項目だけ足す）
$cfgPath = Join-Path $loopHome 'config.json'
$cfg = [ordered]@{}
if (Test-Path -LiteralPath $cfgPath) {
    $old = [IO.File]::ReadAllText($cfgPath, $utf8) | ConvertFrom-Json
    foreach ($p in $old.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
}
$defaults = [ordered]@{
    agentId         = ('{0}-claude' -f [Environment]::MachineName.ToLowerInvariant())
    controlRepoPath = ''
    controlRemote   = 'origin'
    leaseHours      = 24
    maxParallel     = 3
    repoPaths       = [ordered]@{}
}
foreach ($k in $defaults.Keys) { if (-not $cfg.Contains($k)) { $cfg[$k] = $defaults[$k] } }
if ($AgentId) { $cfg['agentId'] = $AgentId }
if ($ControlRepoPath) { $cfg['controlRepoPath'] = [IO.Path]::GetFullPath($ControlRepoPath) }
# 自動起動（kick.ps1）の設定は、頼まれたときに足す（既定の値は lib/AutoLoop.psm1 の Get-KickConfig と同じ）
if ($EnableKick -or $DisableKick) {
    $k = [ordered]@{}
    if ($cfg.Contains('kick') -and $cfg['kick']) { foreach ($p in $cfg['kick'].PSObject.Properties) { $k[$p.Name] = $p.Value } }
    $kickDefaults = [ordered]@{ enabled = $false; minIntervalHours = 4; idle = $true; idleMinIntervalHours = 24; busyMinutes = 15; idleCloseMinutes = 60; intervalMinutes = 0; weeklyAtReset = $true; weeklyResetAt = ''; statusEveryMinutes = 60; permissionMode = 'auto'; remoteControl = $true; prompt = '' }
    foreach ($n in $kickDefaults.Keys) { if (-not $k.Contains($n)) { $k[$n] = $kickDefaults[$n] } }
    $k['enabled'] = [bool]$EnableKick
    if ($KickIntervalMinutes -ge 0) { $k['intervalMinutes'] = $KickIntervalMinutes }
    $cfg['kick'] = $k
}
[IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 5), $utf8)
Write-Output "設定: $cfgPath"
Write-Output "  agentId         = $($cfg['agentId'])"
Write-Output "  controlRepoPath = $($cfg['controlRepoPath'])"
if (-not $cfg['controlRepoPath']) { Write-Output '  → 指令リポジトリが未設定。new-control-repo.ps1 で作るか clone して、-ControlRepoPath を付けてもう一度実行する' }
elseif (-not (Test-Path -LiteralPath (Join-Path $cfg['controlRepoPath'] 'projects'))) { Write-Output '  → 指令リポジトリが見つからない（projects/ が無い）。場所を確かめる' }

# 4. auto-resume-global との連携（頼まれたときだけ）
if ($LinkAutoResume) {
    $ar = Join-Path $arHome 'config.json'
    if (-not (Test-Path -LiteralPath $ar)) { Write-Output "自動再開: auto-resume-global の設定が無い（$ar）。何もしない" }
    else {
        $raw = [IO.File]::ReadAllText($ar, $utf8)
        if ($raw -match '/auto-loop next') { Write-Output '自動再開: 案内は入っている。何もしない' }
        else {
            $backup = Join-Path $loopHome ('state/auto-resume-global.config.{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
            [IO.File]::WriteAllText($backup, $raw, $utf8)
            # 前の版の案内（resume だけ）が入っていれば、置き換える
            $oldAdd = 'auto-loop で管理している作業（~/.claude/auto-loop/state/active/ に印がある）なら、続ける前に /auto-loop resume を実行し、指令リポジトリの状態ファイルを読んで前提を確かめ直してください。'
            $add = 'auto-loop で管理している作業（~/.claude/auto-loop/state/active/ に印がある）なら、続ける前に /auto-loop resume を実行し、指令リポジトリの状態ファイルを読んで前提を確かめ直してください。緊急（priority: urgent）のタスクや、受付の「優先: 緊急」の件があれば、指令リポジトリの AGENTS.md「7. 着手の順」に従って先に行ってください。担当中のタスクが無い・終わったときは、/auto-loop next を実行して次にやることを決めてください。'
            $j = $raw | ConvertFrom-Json
            foreach ($k in @('resumePrompt', 'rebootResumePrompt')) {
                if (-not ($j.PSObject.Properties.Name -contains $k -and $j.$k)) { continue }
                $v = [string]$j.$k
                if ($v.Contains($oldAdd)) { $j.$k = $v.Replace($oldAdd, $add) } else { $j.$k = $v.TrimEnd() + ' ' + $add }
            }
            [IO.File]::WriteAllText($ar, ($j | ConvertTo-Json -Depth 8), $utf8)
            Write-Output "自動再開: 再開の指示に案内を足した（控え: $backup）"
        }
    }
}

# 5. 起動時・スリープ解除時の自動起動（頼まれたときだけ。タスクスケジューラに登録する）
if ($EnableKick -or $DisableKick) {
    $kickTask = 'AutoLoopKick'
    $weeklyTask = 'AutoLoopKickWeekly'
    if (-not $IsWindows) { Write-Output '自動起動: Windows 専用。タスクは登録しない' }
    elseif ($DisableKick) {
        foreach ($tn in @($kickTask, $weeklyTask)) {
            if (Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $tn -Confirm:$false
                Write-Output "自動起動: タスク $tn を消した（kick.enabled = false）"
            }
            else { Write-Output "自動起動: タスク $tn は無い（kick.enabled = false）" }
        }
    }
    else {
        Import-Module (Join-Path $src 'scripts/lib/AutoLoop.psm1') -Force
        $kc = Get-KickConfig ([pscustomobject]@{ kick = [pscustomobject]$cfg['kick'] })
        $kickScript = Join-Path $(if (Test-Path -LiteralPath (Join-Path $dest 'scripts/kick.ps1')) { $dest } else { $src }) 'scripts/kick.ps1'
        $taskShell = (Get-Process -Id $PID).Path
        $user = "$env:USERDOMAIN\$env:USERNAME"
        # conhost.exe --headless <シェル> ...: ウィンドウを出さずに起動する。
        # 遅れ（3 分）は、auto-resume-global の巡回（ログオン・復帰の 1 分後）が先に再開を済ませるのを待つため
        $xml = New-KickTaskXml -Kind main -KickScript $kickScript -Shell $taskShell -User $user -IntervalMinutes ([int]$kc.intervalMinutes)
        Register-ScheduledTask -TaskName $kickTask -Xml $xml -Force | Out-Null
        Write-Output "自動起動: タスク $kickTask を登録した（ログオン時・スリープ復帰時の 3 分後$(if ([int]$kc.intervalMinutes -gt 0) { "、$($kc.intervalMinutes) 分ごと" })に $kickScript）"
        if ([int]$kc.intervalMinutes -gt 0 -and [double]$kc.minIntervalHours * 60 -gt [int]$kc.intervalMinutes) {
            Write-Output "  → 注意: kick.minIntervalHours（$($kc.minIntervalHours) 時間）の内は、起こしたあとに続けて起こさない。間隔の起動を生かすなら、config.json の kick.minIntervalHours を小さくする（例 0.5）"
        }
        # 週の上限の解除時刻（の 6 分後）に毎週
        if ($kc.weeklyAtReset) {
            $projects = if ($env:AUTO_LOOP_CLAUDE_PROJECTS) { $env:AUTO_LOOP_CLAUDE_PROJECTS } else { Join-Path $HOME '.claude/projects' }
            $wr = Resolve-WeeklyReset -Kick $kc -ProjectsDir $projects
            if ($wr.ResetAt) {
                $at = Get-NextWeeklySlot -ResetAt $wr.ResetAt
                Register-ScheduledTask -TaskName $weeklyTask -Xml (New-KickTaskXml -Kind weekly -KickScript $kickScript -Shell $taskShell -User $user -WeeklyAt $at) -Force | Out-Null
                Set-WeeklyTaskAt $at.ToString('yyyy-MM-ddTHH:mm:sszzz')
                Write-Output "自動起動: タスク $weeklyTask を登録した（毎週 $($at.DayOfWeek) $($at.ToString('HH:mm'))、次は $($at.ToString('MM/dd HH:mm'))。PC を起こす。解除時刻の出どころ: $($wr.Source)）"
            }
            else { Write-Output "自動起動: 週の上限の解除時刻が分からないので、$weeklyTask は登録しない（週の上限に当たると、kick.ps1 が登録する。手で決めるなら kick.weeklyResetAt = 'Thu 08:00' など）" }
        }
        elseif (Get-ScheduledTask -TaskName $weeklyTask -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $weeklyTask -Confirm:$false
            Write-Output "自動起動: kick.weeklyAtReset が false なので、タスク $weeklyTask を消した"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $arHome 'config.json'))) { Write-Output '  → auto-resume-global が導入されていない。導入されるまで、kick.ps1 は何もしない（見送りの理由はログに残る）' }
        Write-Output '  → 判断だけを見る: kick.ps1 -DryRun　止める: install.ps1 -NoCopy -DisableKick'
    }
}
Write-Output '完了。次は preflight.ps1 で確かめる'
