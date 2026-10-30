# インストール方法別の典型的な格納先

インストール直後にPATHが未反映の場合や、複数バージョンが共存する場合に、
「どこに入りやすいか」を逆引きするための一覧。

## Windows

| インストール方法 | 典型的な格納先 |
|---|---|
| 公式インストーラ(Python) | `%LOCALAPPDATA%\Programs\Python\Python3XX\` |
| 公式インストーラ(Node.js) | `C:\Program Files\nodejs\` |
| 公式インストーラ(Git) | `C:\Program Files\Git\` |
| Winget(共通) | 実体は各アプリの既定先に入るが、`%LOCALAPPDATA%\Microsoft\WinGet\Links\` にシムリンクが作成されユーザーPATHに自動追加される |
| Microsoft Store / アプリ実行エイリアス(Python) | `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`（シム。実体は別の場所） |
| pip(ユーザーインストールの CLI) | `%APPDATA%\Python\Python3XX\Scripts\`（PATH 未追加のことが多い。`python -m <モジュール>` での実行を優先する） |
| pip(仮想環境) | `<venv>\Scripts\`（`python.exe` / `pip.exe` / パッケージ由来の CLI が同居） |
| .NET グローバルツール(pac 等) | `%USERPROFILE%\.dotnet\tools\` |
| Volta(Node のバージョン管理) | シムは `C:\Program Files\Volta\`、実体は `%LOCALAPPDATA%\Volta\tools\image\node\<version>\` |
| poppler(pdftotext) | winget 導入時は WinGet Links 経由。手動展開時は `<展開先>\poppler-<version>\Library\bin\` |
| rustup(rustc / cargo) | シムは `%USERPROFILE%\.cargo\bin\`（`CARGO_HOME` 指定時はその配下）、toolchain 実体は `%USERPROFILE%\.rustup\toolchains\<toolchain>\bin\`。**PATH 未登録のまま残ることがあるため、未検出でも必ずここを確認する** |
| PowerShell Core 7.x | `C:\Program Files\PowerShell\7\pwsh.exe`（Windows PowerShell 5.x の `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` とは別物・同居する） |

## macOS

| インストール方法 | 典型的な格納先 |
|---|---|
| Homebrew (Apple Silicon) | `/opt/homebrew/bin/` |
| Homebrew (Intel) | `/usr/local/bin/` |
| pyenv | `~/.pyenv/versions/<version>/bin/` |
| nvm | `~/.nvm/versions/node/<version>/bin/` |
| 公式インストーラ | `/usr/local/bin/` または `/Library/Frameworks/Python.framework/Versions/<version>/bin/` |
| Xcode Command Line Tools (git) | `/usr/bin/git` |

## Linux

| インストール方法 | 典型的な格納先 |
|---|---|
| apt/dnf/pacman(共通) | `/usr/bin/` |
| ソースビルド/手動 | `/usr/local/bin/` |
| pyenv | `~/.pyenv/versions/<version>/bin/` |
| nvm | `~/.nvm/versions/node/<version>/bin/` |

## 共通（Unix 系）

| インストール方法 | 典型的な格納先 |
|---|---|
| pip(ユーザーインストールの CLI) | `~/.local/bin/`（PATH 未追加のことがある。`python3 -m <モジュール>` を優先） |
| pip(仮想環境) | `<venv>/bin/` |
| .NET グローバルツール(pac 等) | `~/.dotnet/tools/` |
| Volta | `~/.volta/bin/` |
| rustup(rustc / cargo) | シムは `~/.cargo/bin/`（`CARGO_HOME` 指定時はその配下）、toolchain 実体は `~/.rustup/toolchains/<toolchain>/bin/` |
| PowerShell Core(pwsh) | Homebrew: `/opt/homebrew/bin/pwsh`、Linux パッケージ: `/usr/bin/pwsh`（Unix に Windows PowerShell 5.x は存在しない） |

## 探索の使い方

キャッシュに `resolved_path` が無い、またはインストール直後でPATHが
未反映と思われる場合、上記の該当パスを直接チェックする(例:
Windowsなら `Test-Path`、Unixなら `[ -x path ]`)。見つかったら
そのフルパスで即座にツールを呼び出し、後で `resolved_path` として
キャッシュに書き戻す。
