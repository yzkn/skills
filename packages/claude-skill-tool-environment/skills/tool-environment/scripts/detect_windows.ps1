# detect_windows.ps1
# Windows環境のツール呼び出し方・格納パス・文字コードを検出し、
# tool-environment.json 相当の情報を標準出力に書き出す。
# 実際のJSON書き込みはこのスクリプトを呼び出す側(Claude Code)が行う。

$ErrorActionPreference = "SilentlyContinue"
# 出力を UTF-8 に統一する（既定の cp932 だと呼び出し側で日本語が文字化けする。
# 本スキル ステップ3「検出より先に UTF-8 へ強制統一」と同じ方針）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Output "## OS/Shell"
Write-Output "os=windows"
Write-Output "shell=powershell"
# このスクリプトを実行している PowerShell 自身
Write-Output "powershell_version=$($PSVersionTable.PSVersion)"
Write-Output "powershell_edition=$($PSVersionTable.PSEdition)"

# Windows PowerShell 5.x(PSEdition=Desktop)と PowerShell Core 6.x/7.x(PSEdition=Core)は
# 同居しうる別ランタイム。片方でしか動かない構文・エンコーディング既定があるため、
# 「PowerShell がある」ではなくエディション単位で有無・バージョン・実体パスを記録する。
Write-Output "## PowerShell Editions"
foreach ($ps in @(@("windows_powershell", "powershell"), @("powershell_core", "pwsh"))) {
    $key = $ps[0]; $exe = $ps[1]
    $resolved = Get-Command "$exe.exe" -ErrorAction SilentlyContinue
    if (-not $resolved) { $resolved = Get-Command $exe -ErrorAction SilentlyContinue }
    if ($resolved) {
        Write-Output "${key}_found=true"
        Write-Output "${key}_path=$($resolved.Source)"
        # 自プロセスの $PSVersionTable では実行中のエディションしか分からないため、
        # 実際に子プロセスとして起動して版数を取る（1 行に連結して受け取る）。
        # -Command に渡す文字列に " を含めない: ネイティブコマンド引数の受け渡しで
        # 二重引用符が剥がれ、子プロセス側が構文エラーになる（5.1 で実測）。
        # 区切りの | も [char]124 で生成し、パイプと解釈されないようにする。
        $info = & $resolved.Source -NoProfile -Command '@($PSVersionTable.PSVersion.ToString(), $PSVersionTable.PSEdition, $PSHOME) -join [char]124' 2>$null
        if ($info) {
            $parts = ($info | Select-Object -First 1).ToString().Split([char]124)
            Write-Output "${key}_version=$($parts[0])"
            Write-Output "${key}_edition=$($parts[1])"
            Write-Output "${key}_pshome=$($parts[2])"
        }
    } else {
        Write-Output "${key}_found=false"
    }
}

Write-Output "## Console Encoding"
Write-Output "chcp_raw=$(chcp)"
Write-Output "console_output_encoding=$([Console]::OutputEncoding.WebName)"

Write-Output "## UTF-8 Override Test"
try {
    $before = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output "utf8_override_works=true"
    [Console]::OutputEncoding = $before
} catch {
    Write-Output "utf8_override_works=false"
}

Write-Output "## Tool Resolution (Tier A: ランタイム・VCS)"
foreach ($cmd in @("python", "py", "pip", "pip3", "node", "npm", "npx", "git")) {
    $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($resolved) {
        Write-Output "$cmd`_found=true"
        Write-Output "$cmd`_path=$($resolved.Source)"
    } else {
        Write-Output "$cmd`_found=false"
    }
}

# references/tool_catalog.md の Tier B（利用実績のあるコマンド）
Write-Output "## Tool Resolution (Tier B: 利用実績のあるコマンド)"
foreach ($cmd in @("pandoc", "pdftotext", "gh", "gitleaks", "dotnet", "java", "javac", "mvn",
                   "pac", "docker", "podman", "volta", "winget", "jq", "cloc",
                   "unzip", "tar", "iconv", "pwsh", "markitdown")) {
    $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($resolved) {
        Write-Output "$cmd`_found=true"
        Write-Output "$cmd`_path=$($resolved.Source)"
    } else {
        Write-Output "$cmd`_found=false"
    }
}

# Rust は rustup 管理が既定で、実体は %USERPROFILE%\.cargo\bin(CARGO_HOME 指定時はその配下)。
# インストーラが PATH を更新していても既存セッションに反映されていないことがあるため、
# PATH で見つからない場合はこのディレクトリを直接探索し、in_path=false として記録する。
Write-Output "## Rust Toolchain"
$cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE ".cargo" }
$cargoBin = Join-Path $cargoHome "bin"
$rustPaths = @{}
foreach ($cmd in @("rustc", "cargo", "rustup")) {
    $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($resolved) {
        Write-Output "${cmd}_found=true"
        Write-Output "${cmd}_path=$($resolved.Source)"
        Write-Output "${cmd}_in_path=true"
        $rustPaths[$cmd] = $resolved.Source
    } else {
        $candidate = Join-Path $cargoBin "$cmd.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Write-Output "${cmd}_found=true"
            Write-Output "${cmd}_path=$candidate"
            # PATH 未反映。呼び出しは必ずフルパスで行う（SKILL.md ステップ5と同じ扱い）
            Write-Output "${cmd}_in_path=false"
            $rustPaths[$cmd] = $candidate
        } else {
            Write-Output "${cmd}_found=false"
        }
    }
}
Write-Output "cargo_bin_dir=$cargoBin"
if ($rustPaths.ContainsKey("rustc"))  { Write-Output "rustc_version=$(& $rustPaths['rustc'] --version 2>$null)" }
if ($rustPaths.ContainsKey("cargo"))  { Write-Output "cargo_version=$(& $rustPaths['cargo'] --version 2>$null)" }
if ($rustPaths.ContainsKey("rustup")) {
    Write-Output "rustup_version=$(& $rustPaths['rustup'] --version 2>$null | Select-Object -First 1)"
    Write-Output "rustup_home=$(if ($env:RUSTUP_HOME) { $env:RUSTUP_HOME } else { Join-Path $env:USERPROFILE '.rustup' })"
    # host target triple（例: stable-x86_64-pc-windows-msvc）。msvc は VS の C++ ビルドツールに依存する
    Write-Output "rustup_active_toolchain=$(& $rustPaths['rustup'] show active-toolchain 2>$null | Select-Object -First 1)"
}

# Windows では PowerShell と Git Bash で PATH が異なる。Claude Code の Bash ツールは Git Bash で
# 動くため、PowerShell で未検出のコマンドを Git Bash 側でも一括再確認する（取りこぼし防止）。
Write-Output "## Git Bash Fallback Resolution"
# 実装方針: bash に -c でスクリプトを渡すと Git Bash（MSYS）側が引数を再解釈して
# ${var} が壊れるため、シェルを起動せず Git 同梱ディレクトリを直接探索する。
# 拡張子なしのスクリプト（例: usr/bin/core_perl/piconv）も拾えるように両方を試す。
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    # git.exe は Git\cmd\ にも Git\mingw64\bin\ にも置かれるため、固定の階層数で親を辿らず、
    # usr\bin を持つ祖先ディレクトリ（= Git のインストールルート）を探す。
    $gitRoot = $null
    $probe = Split-Path $gitCmd.Source -Parent
    for ($i = 0; $i -lt 4 -and $probe; $i++) {
        if (Test-Path (Join-Path $probe "usr\bin")) { $gitRoot = $probe; break }
        $probe = Split-Path $probe -Parent
    }
    if (-not $gitRoot) { $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent }
    $bashDirs = @("usr\bin", "usr\local\bin", "mingw64\bin",
                  "usr\bin\core_perl", "usr\bin\vendor_perl") |
                ForEach-Object { Join-Path $gitRoot $_ } | Where-Object { Test-Path $_ }
    Write-Output "git_root=$gitRoot"
    Write-Output "bash_search_dirs=$($bashDirs -join ';')"

    $missing = @()
    foreach ($cmd in @("pandoc", "pdftotext", "gh", "gitleaks", "dotnet", "java", "mvn", "pac",
                       "docker", "podman", "jq", "cloc", "unzip", "tar", "iconv", "piconv",
                       "markitdown", "python", "node", "npm", "git")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { $missing += $cmd }
    }
    if ($missing.Count -eq 0) {
        Write-Output "bash_recheck_targets=none"
    }
    foreach ($cmd in $missing) {
        $hit = $null
        foreach ($dir in $bashDirs) {
            foreach ($name in @("$cmd.exe", $cmd)) {
                $candidate = Join-Path $dir $name
                if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and -not $hit) { $hit = $candidate }
            }
        }
        if ($hit) {
            Write-Output "${cmd}_found_in_bash=true"
            Write-Output "${cmd}_bash_path=$hit"
        } else {
            Write-Output "${cmd}_found_in_bash=false"
        }
    }
} else {
    Write-Output "git_not_available=true"
}

# Windows 側で未検出のコマンドは WSL 側に入っていることがある（docker に限らない）。
# 使う場合は `wsl.exe -d <distro> -- <cmd>` 形式。which は外部コマンドなのでシェルを介さず呼べる
# （command -v はシェル組み込みのため wsl -- からは呼べない）。
Write-Output "## WSL Detection"
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wsl) {
    # -l -q の出力は UTF-16。NUL 混入を除去してから扱う
    $distros = (& wsl.exe -l -q 2>$null) -replace "`0", "" |
               Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
    if ($distros) {
        Write-Output "wsl_available=true"
        Write-Output "wsl_distros=$($distros -join ',')"
        # 製品が管理する VM 用ディストリビューションは作業用に使わない
        $managed = $distros | Where-Object { $_ -match '^(podman-machine|docker-desktop)' }
        $usable  = $distros | Where-Object { $_ -notmatch '^(podman-machine|docker-desktop)' }
        if ($managed) { Write-Output "wsl_managed_distros=$($managed -join ',')" }
        Write-Output "wsl_usable_distros=$($usable -join ',')"

        foreach ($distro in $usable) {
            foreach ($cmd in $missing) {
                $p = (& wsl.exe -d $distro -- which $cmd 2>$null | Select-Object -First 1)
                if ($p) { Write-Output "wsl_${distro}_${cmd}=$($p.Trim())" }
            }
        }
    } else {
        Write-Output "wsl_available=false（ディストリビューション未導入）"
    }
} else {
    Write-Output "wsl_available=false"
}

# Tier C: CLI を持たない Python パッケージ（import 名で確認する。配布名とは異なる場合がある）
Write-Output "## Python Packages (Tier C)"
$pyCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" }
         elseif (Get-Command py -ErrorAction SilentlyContinue) { "py" } else { $null }
if ($pyCmd) {
    foreach ($pkg in @(@("markitdown", "markitdown"), @("docling", "docling"),
                       @("openpyxl", "openpyxl"), @("python-docx", "docx"),
                       @("python-pptx", "pptx"), @("reportlab", "reportlab"),
                       @("pymupdf", "fitz"))) {
        $dist = $pkg[0]; $import = $pkg[1]
        # 文字化け回避のため PYTHONUTF8=1 を付けて実行する
        $env:PYTHONUTF8 = "1"
        & $pyCmd -c "import $import" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "pypkg_${dist}=true"
        } else {
            Write-Output "pypkg_${dist}=false"
        }
    }
    # markitdown はモジュール実行が可能かも記録する（Windows では CLI が PATH に載らないことがある）
    & $pyCmd -m markitdown --help 2>$null | Out-Null
    Write-Output "markitdown_module_runnable=$($LASTEXITCODE -eq 0)"
} else {
    Write-Output "python_not_available=true"
}

# .NET グローバルツール（pac 等）の格納先。PATH 未反映時はここを直接叩く
Write-Output "## .NET Global Tools"
$dotnetTools = Join-Path $env:USERPROFILE ".dotnet\tools"
if (Test-Path $dotnetTools) {
    Write-Output "dotnet_tools_dir=$dotnetTools"
    Get-ChildItem $dotnetTools -Filter *.exe -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "dotnet_tool_entry=$($_.Name)"
    }
}

Write-Output "## Python Launcher Details"
$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    Write-Output "has_py_launcher=true"
    Write-Output "py_versions_raw=$(py -0p 2>&1 | Out-String)"
} else {
    Write-Output "has_py_launcher=false"
}

Write-Output "## Winget Availability"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Output "winget_available=true"
} else {
    Write-Output "winget_available=false"
}

Write-Output "## Winget Links Directory (post-install symlinks)"
$wingetLinks = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
if (Test-Path $wingetLinks) {
    Write-Output "winget_links_dir=$wingetLinks"
    Get-ChildItem $wingetLinks -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "winget_link_entry=$($_.Name)"
    }
}
