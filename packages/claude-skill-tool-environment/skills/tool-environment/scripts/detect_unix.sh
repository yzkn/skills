#!/usr/bin/env bash
# detect_unix.sh
# Mac/Linux環境のツール呼び出し方・格納パス・文字コード・パッケージマネージャを
# 検出し、tool-environment.json 相当の情報を標準出力に書き出す。
# 実際のJSON書き込みはこのスクリプトを呼び出す側(Claude Code)が行う。

echo "## OS/Shell"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "os=macos"
else
  echo "os=linux"
fi
echo "shell=$(basename "$SHELL")"

echo "## Encoding"
echo "lang=${LANG:-unset}"
echo "lc_all=${LC_ALL:-unset}"

echo "## Tool Resolution (Tier A)"
for cmd in python3 python pip3 pip node npm npx git; do
  path=$(command -v "$cmd" 2>/dev/null)
  if [ -n "$path" ]; then
    echo "${cmd}_found=true"
    echo "${cmd}_path=${path}"
  else
    echo "${cmd}_found=false"
  fi
done

# references/tool_catalog.md の Tier B（利用実績のあるコマンド）
echo "## Tool Resolution (Tier B)"
for cmd in pandoc pdftotext gh gitleaks dotnet java javac mvn pac docker podman \
           volta jq cloc unzip tar iconv pwsh markitdown; do
  path=$(command -v "$cmd" 2>/dev/null)
  if [ -n "$path" ]; then
    echo "${cmd}_found=true"
    echo "${cmd}_path=${path}"
  else
    echo "${cmd}_found=false"
  fi
done

# PowerShell はエディション（Desktop / Core）を区別して記録する。
# Unix に入るのは PowerShell Core（pwsh）のみで、Windows PowerShell 5.x は存在しない。
echo "## PowerShell Editions"
echo "windows_powershell_found=false"
if command -v pwsh >/dev/null 2>&1; then
  echo "powershell_core_found=true"
  echo "powershell_core_path=$(command -v pwsh)"
  echo "powershell_core_version=$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)"
  echo "powershell_core_edition=$(pwsh -NoProfile -Command '$PSVersionTable.PSEdition' 2>/dev/null)"
else
  echo "powershell_core_found=false"
fi

# Rust は rustup 管理が既定で、実体は ${CARGO_HOME:-~/.cargo}/bin。インストーラが更新した PATH が
# 既存セッションに反映されていないことがあるため、未検出時はこのディレクトリを直接探索する。
echo "## Rust Toolchain"
CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
resolve_rust() {
  command -v "$1" 2>/dev/null || { [ -x "${CARGO_BIN}/$1" ] && echo "${CARGO_BIN}/$1"; }
}
for cmd in rustc cargo rustup; do
  if path=$(command -v "$cmd" 2>/dev/null); then
    echo "${cmd}_found=true"; echo "${cmd}_path=${path}"; echo "${cmd}_in_path=true"
  elif [ -x "${CARGO_BIN}/${cmd}" ]; then
    # PATH 未反映。呼び出しは必ずフルパスで行う（SKILL.md ステップ5と同じ扱い）
    echo "${cmd}_found=true"; echo "${cmd}_path=${CARGO_BIN}/${cmd}"; echo "${cmd}_in_path=false"
  else
    echo "${cmd}_found=false"
  fi
done
echo "cargo_bin_dir=${CARGO_BIN}"
RUSTC=$(resolve_rust rustc)
[ -n "$RUSTC" ] && echo "rustc_version=$("$RUSTC" --version 2>/dev/null)"
CARGO=$(resolve_rust cargo)
[ -n "$CARGO" ] && echo "cargo_version=$("$CARGO" --version 2>/dev/null)"
RUSTUP=$(resolve_rust rustup)
if [ -n "$RUSTUP" ]; then
  echo "rustup_version=$("$RUSTUP" --version 2>/dev/null | head -1)"
  echo "rustup_home=${RUSTUP_HOME:-$HOME/.rustup}"
  # host target triple（例: stable-x86_64-unknown-linux-gnu）
  echo "rustup_active_toolchain=$("$RUSTUP" show active-toolchain 2>/dev/null | head -1)"
fi

# Tier C: CLI を持たない Python パッケージ（import 名で確認。配布名と異なる場合がある）
echo "## Python Packages (Tier C)"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -n "$PY" ]; then
  for pair in "markitdown:markitdown" "docling:docling" "openpyxl:openpyxl" \
              "python-docx:docx" "python-pptx:pptx" "reportlab:reportlab"; do
    dist=${pair%%:*}
    imp=${pair##*:}
    if PYTHONUTF8=1 "$PY" -c "import ${imp}" >/dev/null 2>&1; then
      echo "pypkg_${dist}=true"
    else
      echo "pypkg_${dist}=false"
    fi
  done
  if PYTHONUTF8=1 "$PY" -m markitdown --help >/dev/null 2>&1; then
    echo "markitdown_module_runnable=true"
  else
    echo "markitdown_module_runnable=false"
  fi
else
  echo "python_not_available=true"
fi

# .NET グローバルツール（pac 等）。PATH 未反映時はここを直接叩く
echo "## .NET Global Tools"
if [ -d "$HOME/.dotnet/tools" ]; then
  echo "dotnet_tools_dir=$HOME/.dotnet/tools"
  ls -1 "$HOME/.dotnet/tools" 2>/dev/null | while read -r e; do echo "dotnet_tool_entry=${e}"; done
fi

echo "## Package Manager Detection"
for pm in brew apt dnf yum pacman; do
  if command -v "$pm" >/dev/null 2>&1; then
    echo "package_manager=${pm}"
    break
  fi
done

echo "## Homebrew Prefix (if present)"
if command -v brew >/dev/null 2>&1; then
  echo "brew_prefix=$(brew --prefix 2>/dev/null)"
fi

echo "## Version Manager Detection"
if [ -d "$HOME/.pyenv" ]; then
  echo "pyenv_present=true"
  echo "pyenv_versions_dir=$HOME/.pyenv/versions"
fi
if [ -d "$HOME/.nvm" ]; then
  echo "nvm_present=true"
  echo "nvm_versions_dir=$HOME/.nvm/versions/node"
fi
