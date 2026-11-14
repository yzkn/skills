#requires -Version 7.0
<#
.SYNOPSIS
  タスクの担当の主張（claim）・生存の印（heartbeat）・解放（release）・引き継ぎ（takeover）。
.DESCRIPTION
  指令リポジトリのタスクファイルのフロントマター（claimed_by など）を書き換え、push で確定する。
  先に push できたエージェントが担当になる。push が拒否されたら自分の変更を取り消して取り込み直し、判定し直す。
  終了コード: 0 = 成功 / 1 = 実行できなかった（通信・競合・未コミットの変更）/ 2 = 担当できない（他のエージェントが担当中など）
.EXAMPLE
  pwsh -NoProfile -File claim.ps1 claim 20261115-ui-unify
  pwsh -NoProfile -File claim.ps1 heartbeat 20261115-ui-unify -Note 'A〜B を実装。次は C'
  pwsh -NoProfile -File claim.ps1 heartbeat 20261115-ui-unify -Status waiting -Note 'E-2 の判断待ち'
  pwsh -NoProfile -File claim.ps1 release 20261115-ui-unify -Status done -Note 'MR 4 本をマージ'
#>
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('claim', 'heartbeat', 'release', 'takeover')][string]$Action,
    [Parameter(Mandatory, Position = 1)][string]$Task,
    [string]$Project = '',
    [ValidateSet('', 'ready', 'doing', 'waiting', 'blocked', 'done', 'dropped')][string]$Status = '',
    [string]$Note = '',
    [string]$Cwd = (Get-Location).Path,
    [switch]$IgnoreAssignee,
    [switch]$NoArchive
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

function Stop-With([int]$Code, [string]$Message) {
    Write-LoopLog 'claim' "$Action $Task -> exit $Code : $Message"
    Write-Output $Message
    exit $Code
}

try { $cfg = Get-LoopConfig } catch { Write-Output "NG $($_.Exception.Message)"; exit 1 }
$me = [string]$cfg.agentId
$repo = [string]$cfg.controlRepoPath
try { $file = Find-TaskFile $cfg $Task $Project } catch { Stop-With 1 "NG $($_.Exception.Message)" }
$rel = Get-RelPath $repo $file.FullName
$activeDir = Join-Path (Get-LoopHome) 'state/active'
$activeFile = Join-Path $activeDir "$Task.json"

function Test-Assignee([string]$Assignee) {
    if ($IgnoreAssignee -or -not $Assignee -or $Assignee -eq 'any') { return $true }
    # エージェント ID そのもの、または ID の一部（道具の名前 claude / copilot、PC の名前）
    return ($me -eq $Assignee) -or (($me -split '-') -contains $Assignee)
}

if ($Action -in @('claim', 'takeover')) {
    if ($rel -like '*/archive/*') { Stop-With 2 "NG $Task は保管済み（archive）" }
    $last = ''
    for ($try = 1; $try -le 3; $try++) {
        if ((Invoke-Git $repo @('status', '--porcelain', '--', $rel)).Text.Trim()) {
            Stop-With 1 "NG $rel に未コミットの変更がある。先に sync.ps1 で送ってから claim する"
        }
        $u = Update-ControlRepo $cfg
        if (-not $u.Ok) { Stop-With 1 "NG 指令リポジトリを取り込めない（$($u.Reason)）: $($u.Detail)" }
        if (-not (Test-Path -LiteralPath $file.FullName)) { Stop-With 2 "NG $Task は取り込み後に無くなった（移動・保管された）" }

        $text = Read-LoopText $file.FullName
        $fm = Get-FrontMatter $text
        $st = [string]$fm['status']; $owner = [string]$fm['claimed_by']
        if ($st -in @('done', 'dropped')) { Stop-With 2 "NG $Task は $st" }
        if ($st -eq 'draft') { Stop-With 2 "NG $Task は draft（人が書きかけ）。status を ready にしてもらう" }
        if (-not (Test-Assignee ([string]$fm['assignee']))) { Stop-With 2 "NG $Task の assignee は $($fm['assignee'])（自分は $me）" }
        if ($owner -and $owner -ne $me -and $Action -ne 'takeover') {
            $age = Get-AgeHours ([string]$fm['heartbeat_at'])
            $stale = if ($null -ne $age -and $age -gt $cfg.leaseHours) { "（最後の印から $age 時間。lease $($cfg.leaseHours) 時間を超過。引き継ぐには利用者の指示を得て takeover）" } else { "（最後の印から $age 時間）" }
            Stop-With 2 "NG $Task は $owner が担当中 $stale"
        }

        $now = Get-NowIso
        $msg = if ($owner -and $owner -ne $me) { "takeover（$owner から引き継ぎ）" } elseif ($owner -eq $me) { 'claim（継続）' } else { 'claim' }
        if ($Note) { $msg = "${msg}: $Note" }
        if ($owner -ne $me) { $text = Set-FrontMatterValue $text 'claimed_at' $now }
        $text = Set-FrontMatterValue $text 'claimed_by' $me
        $text = Set-FrontMatterValue $text 'heartbeat_at' $now
        $text = Set-FrontMatterValue $text 'status' 'doing'
        $text = Set-FrontMatterValue $text 'updated' $now
        $text = Add-TaskLogLine $text $me $msg
        Write-LoopText $file.FullName $text

        Invoke-Git $repo @('add', '--', $rel) | Out-Null
        $c = Invoke-Git $repo @('commit', '-m', "[$me] $Action $Task", '--', $rel)
        if ($c.Code -ne 0) { Stop-With 1 "NG コミットできない: $($c.Text)" }

        $remote = Get-ControlRemote $cfg
        $pushed = $true
        if ($remote) {
            $p = Invoke-Git $repo @('push', $remote, "HEAD:$(Get-ControlBranch $cfg)")
            if ($p.Code -ne 0) {
                # 先を越された（または通信の失敗）。自分の主張だけを取り消して、取り込みから判定し直す
                $last = $p.Text; $pushed = $false
                Invoke-Git $repo @('reset', '--soft', 'HEAD~1') | Out-Null
                Invoke-Git $repo @('restore', '--staged', '--worktree', '--', $rel) | Out-Null
                Write-LoopLog 'claim' "$Action ${Task}: push が拒否されたのでやり直す ($try/3)"
            }
        }
        if ($pushed) {
            New-Item -ItemType Directory -Force $activeDir | Out-Null
            $active = [ordered]@{ task = $Task; project = $file.Directory.Parent.Name; file = $rel; agentId = $me; cwd = $Cwd; claimedAt = $now }
            Write-LoopText $activeFile ($active | ConvertTo-Json)
            $where = if ($remote) { 'push 済み' } else { 'リモート無し（ローカルだけ）' }
            Stop-With 0 "OK $Task を $me が担当（$where）: $($file.FullName)"
        }
    }
    Stop-With 1 "NG 3 回試したが push できない: $last"
}

# heartbeat / release: 自分の主張が生きていることを、リモートの版でも確かめる
$remote = Get-ControlRemote $cfg
if ($remote) {
    $branch = Get-ControlBranch $cfg
    $f = Invoke-Git $repo @('fetch', $remote, $branch)
    if ($f.Code -ne 0) { Stop-With 1 "NG 指令リポジトリを取得できない: $($f.Text)" }
    $show = Invoke-Git $repo @('show', "$remote/${branch}:$rel")
    if ($show.Code -eq 0) {
        $rfm = Get-FrontMatter $show.Text
        if ([string]$rfm['claimed_by'] -ne $me) {
            # この PC の「進行中の印」も外す（再開のときに、失った担当を続けないように）
            if (Test-Path -LiteralPath $activeFile) { Remove-Item -LiteralPath $activeFile -Force }
            Stop-With 2 "NG $Task の担当はリモートでは「$($rfm['claimed_by'])」（自分は $me）。主張が失われている。作業を止めて利用者に報告する"
        }
    }
}
$text = Read-LoopText $file.FullName
$fm = Get-FrontMatter $text
if ([string]$fm['claimed_by'] -ne $me) { Stop-With 2 "NG $Task の担当は「$($fm['claimed_by'])」（自分は $me）" }
$now = Get-NowIso

if ($Action -eq 'heartbeat') {
    if ($Status -and $Status -notin @('doing', 'waiting', 'blocked')) { Stop-With 1 'NG heartbeat の -Status は doing / waiting / blocked' }
    $text = Set-FrontMatterValue $text 'heartbeat_at' $now
    $text = Set-FrontMatterValue $text 'updated' $now
    if ($Status) { $text = Set-FrontMatterValue $text 'status' $Status }
    if ($Note -or $Status) { $text = Add-TaskLogLine $text $me ("checkpoint" + $(if ($Status) { "（$Status）" }) + $(if ($Note) { ": $Note" })) }
    Write-LoopText $file.FullName $text
    $s = Sync-ControlRepo $cfg "[$me] checkpoint $Task$(if ($Note) { ": $Note" })"
    if (-not $s.Ok) { Stop-With 1 "NG 状態は手元に書いたが送れていない（$($s.Reason)）: $($s.Detail)" }
    Stop-With 0 "OK $Task の状態を記録（$($s.Reason)）"
}

if ($Action -eq 'release') {
    $to = if ($Status) { $Status } else { 'ready' }
    if ($to -notin @('ready', 'done', 'dropped')) { Stop-With 1 'NG release の -Status は ready / done / dropped（判断待ちは heartbeat -Status waiting で担当を保つ）' }
    $text = Set-FrontMatterValue $text 'claimed_by' ''
    $text = Set-FrontMatterValue $text 'claimed_at' ''
    $text = Set-FrontMatterValue $text 'heartbeat_at' ''
    $text = Set-FrontMatterValue $text 'status' $to
    $text = Set-FrontMatterValue $text 'updated' $now
    $text = Add-TaskLogLine $text $me ("release（$to）" + $(if ($Note) { ": $Note" }))
    Write-LoopText $file.FullName $text
    if ($to -in @('done', 'dropped') -and -not $NoArchive) {
        $archive = Join-Path $file.Directory.Parent.FullName 'archive'
        New-Item -ItemType Directory -Force $archive | Out-Null
        $dest = Get-RelPath $repo (Join-Path $archive $file.Name)
        $mv = Invoke-Git $repo @('mv', '--', $rel, $dest)
        if ($mv.Code -ne 0) { Write-LoopLog 'claim' "保管へ移せない: $($mv.Text)" }
    }
    $s = Sync-ControlRepo $cfg "[$me] release $Task ($to)$(if ($Note) { ": $Note" })"
    if (Test-Path -LiteralPath $activeFile) { Remove-Item -LiteralPath $activeFile -Force }
    if (-not $s.Ok) { Stop-With 1 "NG 解放を手元に書いたが送れていない（$($s.Reason)）: $($s.Detail)" }
    Stop-With 0 "OK $Task を解放（$to、$($s.Reason)）"
}
