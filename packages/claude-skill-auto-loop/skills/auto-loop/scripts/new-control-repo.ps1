#requires -Version 7.0
<#
.SYNOPSIS
  指令・状態管理用のリポジトリを、ひな形（assets/control-repo）から手元に作る。
.DESCRIPTION
  空のフォルダにひな形を写し、git init と最初のコミットまでを行う。GitHub には触れない。
  リモートの作成と push は利用者が行う（最後にコマンドを示す）。指令には案件の内情が入るので、非公開にする。
.EXAMPLE
  pwsh -NoProfile -File new-control-repo.ps1 -Path C:\Users\me\Documents\GitHub\loop-control
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Branch = 'main'
)
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets/control-repo'
if (-not (Test-Path -LiteralPath $src)) { Write-Output "NG ひな形が無い: $src"; exit 1 }
$Path = [IO.Path]::GetFullPath($Path)
if ((Test-Path -LiteralPath $Path) -and @(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) { Write-Output "NG 空ではない: $Path"; exit 1 }

New-Item -ItemType Directory -Force $Path | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $Path -Recurse -Force
# 先頭がドットのファイルも写す
Get-ChildItem -LiteralPath $src -Force | Where-Object { $_.Name.StartsWith('.') } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Path -Recurse -Force }

& git -C $Path init -q -b $Branch
& git -C $Path add -A
& git -C $Path commit -q -m 'auto-loop: 指令リポジトリのひな形'
if ($LASTEXITCODE -ne 0) { Write-Output 'NG 最初のコミットに失敗（git の user.name / user.email を確かめる）'; exit 1 }

$name = Split-Path -Leaf $Path
Write-Output "OK 指令リポジトリを作った: $Path"
Write-Output '次の手順（利用者が行う）:'
Write-Output "  1. リモートを非公開で作って送る:  gh repo create $name --private --source `"$Path`" --remote origin --push"
Write-Output '  2. ほかの PC・アカウントのエージェントを、共同作業者（書き込み可）として招く'
Write-Output "  3. この PC に登録する:  pwsh -NoProfile -File `"$(Join-Path $PSScriptRoot 'install.ps1')`" -ControlRepoPath `"$Path`""
