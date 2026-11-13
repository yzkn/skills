# Mac/Linux: パッケージマネージャ別パッケージ名対応表

| ツール | Homebrew (brew) | apt | dnf | pacman |
|---|---|---|---|---|
| Python | `python@3.12` | `python3` | `python3` | `python` |
| pip | (pythonに同梱) | `python3-pip` | `python3-pip` | `python-pip` |
| Node.js | `node` | `nodejs` | `nodejs` | `nodejs` |
| npm | (nodeに同梱) | `npm` | `npm`(nodejsに同梱の場合あり) | `npm` |
| Git | `git` | `git` | `git` | `git` |
| pandoc | `pandoc` | `pandoc` | `pandoc` | `pandoc` |
| pdftotext | `poppler` | `poppler-utils` | `poppler-utils` | `poppler` |
| GitHub CLI | `gh` | `gh` | `gh` | `github-cli` |
| gitleaks | `gitleaks` | (公式バイナリ配布を使う) | `gitleaks` | `gitleaks` |
| jq | `jq` | `jq` | `jq` | `jq` |
| rtk | `rtk` | (README に記載なし。Homebrew を使う) | 同左 | 同左 |
| cloc | `cloc` | `cloc` | `cloc` | `cloc` |
| .NET SDK | `dotnet-sdk`(cask) | `dotnet-sdk-<ver>` | `dotnet-sdk-<ver>` | `dotnet-sdk` |
| JDK | `openjdk` | `default-jdk` | `java-<ver>-openjdk-devel` | `jdk-openjdk` |
| Maven | `maven` | `maven` | `maven` | `maven` |
| Volta | `volta` | (公式スクリプト `curl`※ を使う) | 同左 | `volta` |
| Rust (rustup) | `rustup`（`rust` ではなく rustup を入れる） | `rustup`（無ければ公式スクリプト `curl`※） | `rustup` | `rustup` |
| PowerShell Core | `powershell`(cask) | Microsoft リポジトリ追加後 `powershell` | `powershell` | `powershell-bin`(AUR) |

- markitdown / docling / openpyxl / python-docx / python-pptx / reportlab は **pip 管理**（`python3 -m pip install <名前>`）。OS のパッケージマネージャでは配布されていない
- anydoc は **npm のグローバルインストール**（`npm install -g @firecrawl/anydoc`。Node 20 以上）。**スコープ付きの完全なパッケージ名で指定する**（スコープなしの `anydoc` は無関係な同名パッケージ）。Volta 管理下ではシムが `~/AppData/Local/Volta/bin/anydoc` に作られる
- pac（Power Platform CLI）は **.NET グローバルツール**（`dotnet tool install --global Microsoft.PowerApps.CLI.Tool`）
- Rust は **ディストリビューションの `rust` / `rustc` パッケージではなく `rustup` を使う**（toolchain / target を切り替えられなくなるため）。導入先は `~/.cargo/bin`（PATH 未反映のことがある）、toolchain 実体は `~/.rustup/toolchains/<toolchain>/bin`
- ※ 公式インストールスクリプトの取得は外部通信にあたる。実行前に送信先・目的をユーザーに提示して承認を得ること（`.claude/rules/external-resources.md`）

## インストールコマンド例

```bash
# macOS (Homebrew)
brew install python@3.12

# Debian/Ubuntu
sudo apt update && sudo apt install -y python3 python3-pip

# RHEL/Fedora
sudo dnf install -y python3 python3-pip

# Arch
sudo pacman -S python python-pip
```

## 補足

- `sudo` を伴うコマンドは特に、実行前の承認を必ず取ること。
- ディストリビューションによってパッケージ名やバージョンが異なる場合がある。
  上記はあくまで代表例であり、`apt search <キーワード>` 等での事前確認が
  望ましい。
