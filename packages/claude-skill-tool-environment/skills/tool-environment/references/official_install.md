# Windows: 公式が推奨するインストール手順

| ツール | 公式推奨手順 | URL |
|---|---|---|
| Python | 公式インストーラ、または `py` ランチャー(python.orgのインストーラに同梱) | https://www.python.org/downloads/windows/ |
| Node.js | 公式インストーラ(LTS版を推奨) | https://nodejs.org/en/download |
| Git | 公式インストーラ(Git for Windows) | https://git-scm.com/download/win |
| Rust | `rustup-init.exe`（rustup 経由で rustc / cargo が入る。単体の rustc を直接入れない） | https://rustup.rs/ |
| PowerShell Core 7.x | MSI インストーラ（Windows PowerShell 5.x は OS 同梱で置き換わらない） | https://github.com/PowerShell/PowerShell/releases |

## 補足

- Pythonは「Add python.exe to PATH」オプションを有効にしてインストールすると、
  以降 `python`/`pip` がPATH経由で呼び出せるようになる。無効のままだと
  `py` ランチャー経由(`py -m pip` 等)での呼び出しが必要になる場合がある。
- 公式インストーラはGUIウィザード形式で対話的になりやすいため、
  自動化(サイレントインストール)が必要な場合は以下のオプションが使える:
  - Python: `python-3.12.4-amd64.exe /quiet InstallAllUsers=1 PrependPath=1`
  - Node.js: msiexecのサイレントオプション(`/quiet`)
  - これらが複雑/環境依存で扱いにくい場合は②のWingetに切り替える判断でよい。
  - Rust: `rustup-init.exe -y`（既定 toolchain は `stable-x86_64-pc-windows-msvc`）。
    **MSVC toolchain はリンク時に Visual Studio の C++ ビルドツールを要する**ため、
    未導入環境では別途その導入可否をユーザーに確認する。
- **rustup / PowerShell 7 のインストーラ取得は外部からのダウンロードにあたる。**
  実行前に取得元 URL と目的を提示して承認を得る（`.claude/rules/external-resources.md`）。
- インストール直後は `%USERPROFILE%\.cargo\bin` が既存シェルの PATH に反映されない。
  `references/typical_install_paths.md` の該当行に従いフルパスで呼び出す。
