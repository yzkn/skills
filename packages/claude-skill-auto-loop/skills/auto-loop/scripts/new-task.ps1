#requires -Version 7.0
<#
.SYNOPSIS
  タスクファイルを、指令リポジトリの templates/task.md から作る（コミットはしない）。
.DESCRIPTION
  ID は「日付-スラグ」（例 20261115-ui-unify）。連番を使わないので、複数のエージェントが同時に起票しても重ならない。
  作ったあと、本文（依頼の原文・目的と完了条件・計画）を埋めて sync.ps1 で送る。
.EXAMPLE
  pwsh -NoProfile -File new-task.ps1 -Project my-app -Title '動的 UI の不統一を洗い出す' -Slug ui-audit -Stage propose -Source direct
#>
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Title,
    [string]$Slug = '',
    [ValidateSet('propose', 'implement', 'merge')][string]$Stage = 'propose',
    [ValidateSet('low', 'normal', 'high')][string]$Priority = 'normal',
    [ValidateSet('inbox', 'direct', 'file')][string]$Source = 'direct',
    [string]$Assignee = 'any',
    [string]$Request = '',
    [string]$RequestFile = ''
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$repo = [string]$cfg.controlRepoPath
$projDir = Join-Path $repo "projects/$Project"
if (-not (Test-Path -LiteralPath (Join-Path $projDir 'project.md'))) {
    Write-Output "NG 案件がありません: projects/$Project/project.md（templates/project.md を写して作る）"; exit 1
}
$template = Join-Path $repo 'templates/task.md'
if (-not (Test-Path -LiteralPath $template)) { Write-Output "NG ひな形がありません: $template"; exit 1 }

if (-not $Slug) { $Slug = (($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')) }
$Slug = (($Slug.ToLowerInvariant() -replace '[^a-z0-9-]+', '-').Trim('-'))
if (-not $Slug) { $Slug = 'task' }
if ($Slug.Length -gt 40) { $Slug = $Slug.Substring(0, 40).Trim('-') }

$base = '{0}-{1}' -f (Get-Date).ToString('yyyyMMdd'), $Slug
$id = $base; $n = 2
while ((Test-Path -LiteralPath (Join-Path $projDir "tasks/$id.md")) -or (Test-Path -LiteralPath (Join-Path $projDir "archive/$id.md"))) { $id = "$base-$n"; $n++ }

if ($RequestFile) { $Request = Read-LoopText $RequestFile }
if (-not $Request) { $Request = '（依頼の原文をここに写す）' }
$now = Get-NowIso
$text = Read-LoopText $template
$map = [ordered]@{ '{{id}}' = $id; '{{title}}' = ($Title -replace '\r?\n', ' '); '{{project}}' = $Project; '{{stage}}' = $Stage
    '{{priority}}' = $Priority; '{{source}}' = $Source; '{{assignee}}' = $Assignee; '{{now}}' = $now; '{{agent}}' = [string]$cfg.agentId; '{{request}}' = $Request.Trim()
}
foreach ($k in $map.Keys) { $text = $text.Replace($k, [string]$map[$k]) }

New-Item -ItemType Directory -Force (Join-Path $projDir 'tasks') | Out-Null
$path = Join-Path $projDir "tasks/$id.md"
Write-LoopText $path $text
Write-LoopLog 'new-task' "$Project/$id ($Stage, $Source)"
Write-Output "OK $id"
Write-Output $path
