#requires -Version 7.0
<#
.SYNOPSIS
  auto-loop をこの PC に導入する（スキルの写しと、実行時のフォルダ・設定の用意）。何度実行しても安全。
.DESCRIPTION
  - スキル: <SkillsDir>/auto-loop/ （既定 ~/.claude/skills/auto-loop/）
  - 実行時のファイル: ~/.claude/auto-loop/ （config.json・state/active/・logs/・work/）
  - -LinkAutoResume: auto-resume-global の再開の指示に「/auto-loop resume を実行する」案内を足す（控えを取る）
  スキル・フォルダ・ログの名前は、すべて配布名 auto-loop にそろえてある。
.EXAMPLE
  pwsh -NoProfile -File install.ps1 -AgentId pc1-claude-main -ControlRepoPath C:\Users\me\Documents\GitHub\loop-control
#>
param(
    [string]$AgentId = '',
    [string]$ControlRepoPath = '',
    [string]$SkillsDir = (Join-Path $HOME '.claude/skills'),
    [switch]$NoCopy,
    [switch]$LinkAutoResume
)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$loopHome = if ($env:AUTO_LOOP_HOME) { $env:AUTO_LOOP_HOME } else { Join-Path $HOME '.claude/auto-loop' }
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
[IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 5), $utf8)
Write-Output "設定: $cfgPath"
Write-Output "  agentId         = $($cfg['agentId'])"
Write-Output "  controlRepoPath = $($cfg['controlRepoPath'])"
if (-not $cfg['controlRepoPath']) { Write-Output '  → 指令リポジトリが未設定。new-control-repo.ps1 で作るか clone して、-ControlRepoPath を付けてもう一度実行する' }
elseif (-not (Test-Path -LiteralPath (Join-Path $cfg['controlRepoPath'] 'projects'))) { Write-Output '  → 指令リポジトリが見つからない（projects/ が無い）。場所を確かめる' }

# 4. auto-resume-global との連携（頼まれたときだけ）
if ($LinkAutoResume) {
    $ar = Join-Path $HOME '.claude/auto-resume-global/config.json'
    if (-not (Test-Path -LiteralPath $ar)) { Write-Output "自動再開: auto-resume-global の設定が無い（$ar）。何もしない" }
    else {
        $raw = [IO.File]::ReadAllText($ar, $utf8)
        if ($raw -match 'auto-loop') { Write-Output '自動再開: 案内は入っている。何もしない' }
        else {
            $backup = Join-Path $loopHome ('state/auto-resume-global.config.{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
            [IO.File]::WriteAllText($backup, $raw, $utf8)
            $add = ' auto-loop で管理している作業（~/.claude/auto-loop/state/active/ に印がある）なら、続ける前に /auto-loop resume を実行し、指令リポジトリの状態ファイルを読んで前提を確かめ直してください。'
            $j = $raw | ConvertFrom-Json
            foreach ($k in @('resumePrompt', 'rebootResumePrompt')) { if ($j.PSObject.Properties.Name -contains $k -and $j.$k) { $j.$k = ([string]$j.$k).TrimEnd() + $add } }
            [IO.File]::WriteAllText($ar, ($j | ConvertTo-Json -Depth 8), $utf8)
            Write-Output "自動再開: 再開の指示に案内を足した（控え: $backup）"
        }
    }
}
Write-Output '完了。次は preflight.ps1 で確かめる'
