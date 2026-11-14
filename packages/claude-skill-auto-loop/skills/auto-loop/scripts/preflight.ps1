#requires -Version 7.0
<#
.SYNOPSIS
  着手前の確認。認証・push 先の状態・本流のリモート・作業ツリーを、作業の最初に確かめる。
.DESCRIPTION
  1 行 1 項目で「OK / INFO / WARN / NG」を出す。NG があれば終了コード 1。
  何も変更しない（git fetch だけ行う）。認証の入力待ちでは止まらず、NG として直し方のコマンドを示す。
.EXAMPLE
  pwsh -NoProfile -File preflight.ps1                    # 道具・指令リポジトリだけ
  pwsh -NoProfile -File preflight.ps1 -Project my-app   # 案件のリポジトリも
#>
param(
    [string]$Project = '',
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force

$results = [Collections.Generic.List[object]]::new()
function Add-Result([string]$Level, [string]$Area, [string]$Message, [string]$Fix = '') {
    $results.Add([pscustomobject]@{ level = $Level; area = $Area; message = $Message; fix = $Fix })
}
function Invoke-Tool([string]$Exe, [string[]]$ToolArgs) {
    $ErrorActionPreference = 'Continue'   # 標準エラーの出力で例外にしない（pwsh 7.1 以前）
    $out = @(& $Exe @ToolArgs 2>&1 | ForEach-Object { "$_" })
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
}
function Test-Tool([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# --- 設定と道具 ---
$cfg = $null
try { $cfg = Get-LoopConfig; Add-Result 'OK' '設定' "agentId=$($cfg.agentId) 指令リポジトリ=$($cfg.controlRepoPath)" }
catch { Add-Result 'NG' '設定' $_.Exception.Message '/auto-loop setup を実行する' }
if (Test-Tool 'git') { Add-Result 'OK' '道具' ((Invoke-Tool 'git' @('--version')).Text) } else { Add-Result 'NG' '道具' 'git が無い' }

# --- 指令リポジトリ ---
if ($cfg) {
    $repo = [string]$cfg.controlRepoPath
    $remote = Get-ControlRemote $cfg
    if (-not $remote) { Add-Result 'WARN' '指令リポジトリ' 'リモートが無い（この PC だけで使う構成）。複数台・複数エージェントでは共有されない' }
    else {
        $branch = Get-ControlBranch $cfg
        $f = Invoke-Git $repo @('fetch', $remote)
        if ($f.Code -ne 0) {
            $hint = Get-GitFailureHint $repo $remote $f.Text
            Add-Result 'NG' '指令リポジトリ' "取得できない: $(($f.Text -split "`n")[-1])" $(if ($hint) { $hint } else { '認証と通信を確かめる' })
        }
        else {
            $p = Invoke-Git $repo @('push', '--dry-run', $remote, "HEAD:$branch")
            if ($p.Code -ne 0 -and $p.Text -notmatch 'non-fast-forward|fetch first') { Add-Result 'NG' '指令リポジトリ' "push できない: $($p.Text)" '権限（共同作業者）と認証を確かめる' }
            else { Add-Result 'OK' '指令リポジトリ' "取得・push 可（$remote/$branch）" }
        }
    }
    $dirty = @((Invoke-Git $repo @('status', '--porcelain')).Out | Where-Object { $_ }).Count
    if ($dirty) { Add-Result 'WARN' '指令リポジトリ' "未コミットの変更が $dirty 件" 'sync.ps1 で送る' }
}

# --- 案件のリポジトリ ---
$authCache = @{}
function Test-HostAuth([string]$HostName, [string]$Account) {
    $key = "$HostName|$Account"
    if ($authCache.ContainsKey($key)) { return $authCache[$key] }
    $ok = $false
    if ($HostName -match 'github') {
        if (-not (Test-Tool 'gh')) { Add-Result 'NG' "認証 $HostName" 'gh が無い' 'GitHub CLI を導入する' }
        else {
            $u = Invoke-Tool 'gh' @('api', 'user', '--hostname', $HostName, '--jq', '.login')
            if ($u.Code -ne 0) { Add-Result 'NG' "認証 $HostName" "gh の認証が無効: $(($u.Text -split "`n")[0])" "! gh auth login --hostname $HostName --web" }
            elseif ($Account -and $u.Text.Trim() -ne $Account) {
                $st = Invoke-Tool 'gh' @('auth', 'status', '--hostname', $HostName)
                if ($st.Text -match ('account\s+' + [regex]::Escape($Account) + '\b')) { Add-Result 'NG' "認証 $HostName" "有効なアカウントは $($u.Text.Trim())、必要なのは $Account" "gh auth switch --hostname $HostName --user $Account" }
                else { Add-Result 'NG' "認証 $HostName" "有効なアカウントは $($u.Text.Trim())、必要な $Account はログインしていない" "! gh auth login --hostname $HostName --web" }
            }
            else { Add-Result 'OK' "認証 $HostName" "gh: $($u.Text.Trim())"; $ok = $true }
        }
    }
    elseif ($HostName -match 'gitlab') {
        if (-not (Test-Tool 'glab')) { Add-Result 'NG' "認証 $HostName" 'glab が無い' 'GitLab CLI を導入する' }
        else {
            $u = Invoke-Tool 'glab' @('api', 'user', '--hostname', $HostName)
            $login = ''
            if ($u.Code -eq 0) { try { $login = [string]($u.Text | ConvertFrom-Json).username } catch { } }
            if (-not $login) { Add-Result 'NG' "認証 $HostName" "glab の認証が無効（トークンの失効など）: $(($u.Text -split "`n")[0])" "! glab auth login --hostname $HostName --web" }
            elseif ($Account -and $login -ne $Account) { Add-Result 'NG' "認証 $HostName" "有効なアカウントは $login、必要なのは $Account" "! glab auth login --hostname $HostName --web" }
            else { Add-Result 'OK' "認証 $HostName" "glab: $login"; $ok = $true }
        }
    }
    else { Add-Result 'INFO' "認証 $HostName" 'gh / glab の対象外。git の取得で確かめる'; $ok = $true }
    $authCache[$key] = $ok
    return $ok
}

function Test-RemoteProject($r) {
    if ($r.host -match 'github') {
        $a = Invoke-Tool 'gh' @('api', "repos/$($r.repo)", '--hostname', $r.host, '--jq', '[.permissions.push, .archived, .disabled] | @tsv')
        if ($a.Code -ne 0) { Add-Result 'NG' "push 先 $($r.key)" "$($r.repo) を読めない: $(($a.Text -split "`n")[0])"; return }
        $v = $a.Text.Trim() -split "`t"
        if ($v[1] -eq 'true' -or $v[2] -eq 'true') { Add-Result 'NG' "push 先 $($r.key)" "$($r.repo) はアーカイブ済み・無効" }
        elseif ($v[0] -ne 'true') { Add-Result 'WARN' "push 先 $($r.key)" "$($r.repo) に push 権限が無い（フォークから PR を出す構成か確かめる）" }
        else { Add-Result 'OK' "push 先 $($r.key)" "$($r.repo) に push 可" }
    }
    elseif ($r.host -match 'gitlab') {
        $a = Invoke-Tool 'glab' @('api', "projects/$([uri]::EscapeDataString($r.repo))", '--hostname', $r.host)
        $j = $null
        if ($a.Code -eq 0) { try { $j = $a.Text | ConvertFrom-Json } catch { } }
        if (-not $j) { Add-Result 'NG' "push 先 $($r.key)" "$($r.repo) を読めない: $(($a.Text -split "`n")[0])"; return }
        $names = $j.PSObject.Properties.Name
        $deletion = @('marked_for_deletion_on', 'marked_for_deletion_at') | Where-Object { $names -contains $_ -and $j.$_ } | Select-Object -First 1
        $level = 0
        if ($names -contains 'permissions' -and $j.permissions) {
            foreach ($k in @('project_access', 'group_access')) { if ($j.permissions.$k -and $j.permissions.$k.access_level -gt $level) { $level = [int]$j.permissions.$k.access_level } }
        }
        if ($deletion) { Add-Result 'NG' "push 先 $($r.key)" "$($r.repo) は削除予定（$($j.$deletion)）。本流が別の場所に移っていないか利用者に確かめる" }
        elseif ($names -contains 'archived' -and $j.archived) { Add-Result 'NG' "push 先 $($r.key)" "$($r.repo) はアーカイブ済み" }
        elseif ($level -lt 30) { Add-Result 'WARN' "push 先 $($r.key)" "$($r.repo) の権限が Developer 未満（access_level=$level）" }
        else { Add-Result 'OK' "push 先 $($r.key)" "$($r.repo) に push 可（access_level=$level）" }
    }
}

function Test-LocalRepo($r, [string]$Path) {
    $area = "作業コピー $($r.key)"
    if (-not $Path) { Add-Result 'WARN' $area "この PC での場所が未登録（config.json の repoPaths.`"$Project/$($r.key)`"）" 'clone の場所を利用者に確かめて登録する'; return }
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) { Add-Result 'NG' $area "git の作業コピーではない: $Path"; return }
    $url = Invoke-Git $Path @('remote', 'get-url', $r.remote)
    if ($url.Code -ne 0) { Add-Result 'NG' $area "リモート $($r.remote) が無い（あるのは: $(((Invoke-Git $Path @('remote')).Out) -join ', ')）"; return }
    $norm = ($url.Text.Trim() -replace '\.git$', '').ToLowerInvariant()
    if ($r.repo -and -not $norm.EndsWith($r.repo.ToLowerInvariant())) { Add-Result 'NG' $area "本流のリモート $($r.remote) が $($r.repo) を指していない: $($url.Text.Trim())"; return }
    $f = Invoke-Git $Path @('fetch', $r.remote)
    if ($f.Code -ne 0) {
        $hint = Get-GitFailureHint $Path $r.remote $f.Text
        Add-Result 'NG' $area "git fetch $($r.remote) に失敗: $(($f.Text -split "`n")[-1])" $(if ($hint) { $hint -replace '<アカウント>', $(if ($r.account) { $r.account } else { '<アカウント>' }) } else { '認証を確かめる' })
        return
    }
    $ref = "$($r.remote)/$($r.base)"
    if ((Invoke-Git $Path @('rev-parse', '--verify', '--quiet', $ref)).Code -ne 0) { Add-Result 'NG' $area "基準ブランチ $ref が無い"; return }
    Add-Result 'OK' $area "$Path  本流=$ref"
    $local = Invoke-Git $Path @('rev-list', '--count', "$($r.base)..$ref")
    if ($local.Code -eq 0 -and [int]$local.Text.Trim() -gt 0) { Add-Result 'WARN' $area "ローカルの $($r.base) は $ref より $($local.Text.Trim()) コミット遅れ" "作業ブランチは $ref から切る" }
    $cur = (Invoke-Git $Path @('rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()
    $dirty = @((Invoke-Git $Path @('status', '--porcelain')).Out | Where-Object { $_ }).Count
    if ($dirty) { Add-Result 'WARN' $area "未コミットの変更が $dirty 件（ブランチ $cur）。誰の変更か確かめてから進める" }
    # 作業ツリー: 止まったサブエージェントの置き土産が無いか
    $wt = (Invoke-Git $Path @('worktree', 'list', '--porcelain')).Out
    $paths = @($wt | Where-Object { $_ -like 'worktree *' } | ForEach-Object { $_.Substring(9) })
    $clean = 0; $missing = 0
    foreach ($w in ($paths | Select-Object -Skip 1)) {
        if (-not (Test-Path -LiteralPath $w)) { $missing++; continue }
        $wd = @((Invoke-Git $w @('status', '--porcelain')).Out | Where-Object { $_ }).Count
        $wb = (Invoke-Git $w @('rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()
        if ($wd) { Add-Result 'WARN' $area "作業ツリー $w（$wb）に未コミットの変更が $wd 件。止まった委任の続きなら「仕上げ」として引き継ぐ" }
        else { $clean++ }
    }
    # 変更の無い作業ツリーは 1 行にまとめる（数が多いと、ほかの結果が埋もれる）
    if ($clean) { Add-Result 'INFO' $area "変更の無い作業ツリーが $clean 本（一覧: git -C `"$Path`" worktree list）。不要なら片付けを利用者に提案する" }
    if ($missing) { Add-Result 'WARN' $area "フォルダが無いのに登録だけ残っている作業ツリーが $missing 本" "git -C `"$Path`" worktree prune（利用者に確かめてから）" }
}

if ($cfg -and $Project) {
    $pf = Join-Path $cfg.controlRepoPath "projects/$Project/project.md"
    if (-not (Test-Path -LiteralPath $pf)) { Add-Result 'NG' '案件' "projects/$Project/project.md が無い" }
    else {
        $repos = @(Get-ProjectRepos $pf)
        if ($repos.Count -eq 0) { Add-Result 'WARN' '案件' "$Project の「## リポジトリ」の表が空" }
        foreach ($r in $repos) {
            $authOk = $true
            if ($r.host) { $authOk = Test-HostAuth $r.host $r.account }
            if ($authOk -and $r.host -and $r.repo) { Test-RemoteProject $r }
            $key = "$Project/$($r.key)"
            $path = if ($cfg.repoPaths.PSObject.Properties.Name -contains $key) { [string]$cfg.repoPaths.$key } else { '' }
            Test-LocalRepo $r $path
        }
    }
}

# --- 自動再開との連携・利用枠 ---
$ar = Join-Path $HOME '.claude/auto-resume-global/config.json'
if (Test-Path -LiteralPath $ar) {
    $linked = (Read-LoopText $ar) -match 'auto-loop'
    if ($linked) { Add-Result 'OK' '自動再開' 'auto-resume-global の再開の指示に auto-loop の案内がある' }
    else { Add-Result 'INFO' '自動再開' 'auto-resume-global の再開の指示に auto-loop の案内が無い' 'install.ps1 -LinkAutoResume（利用者の了承を得てから）' }
}
else { Add-Result 'INFO' '自動再開' 'auto-resume-global は未導入（上限で止まったら手動で再開し、/auto-loop resume を実行する）' }
Add-Result 'INFO' '利用枠' "残りは機械的に取れない。並列の委任（上限 $(if ($cfg) { $cfg.maxParallel } else { '?' }) 本）を始める前に、利用者に /usage の残りを確かめる"

$ng = @($results | Where-Object level -eq 'NG').Count
$warn = @($results | Where-Object level -eq 'WARN').Count
Write-LoopLog 'preflight' "project='$Project' NG=$ng WARN=$warn : $((@($results | Where-Object level -in 'NG', 'WARN' | ForEach-Object { "$($_.level) $($_.area) $($_.message)" }) -join ' | '))"

if ($Json) { [pscustomobject]@{ ng = $ng; warn = $warn; results = $results } | ConvertTo-Json -Depth 4 }
else {
    foreach ($r in $results) {
        Write-Output ('{0,-4} {1}: {2}' -f $r.level, $r.area, $r.message)
        if ($r.fix) { Write-Output "       → $($r.fix)" }
    }
    Write-Output "結果: NG $ng 件 / WARN $warn 件"
}
if ($ng) { exit 1 } else { exit 0 }
