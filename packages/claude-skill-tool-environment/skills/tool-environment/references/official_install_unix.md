# Mac/Linux: 公式が推奨するインストール手順

| ツール | 公式推奨手順 | URL |
|---|---|---|
| Python | pyenv、または公式インストーラ(macOS) | https://www.python.org/downloads/ |
| Node.js | 公式インストーラ、または nvm | https://nodejs.org/en/download |
| Git | Xcode Command Line Tools(macOS)/ 公式手順(Linux) | https://git-scm.com/downloads |
| Homebrew | 公式インストールスクリプト | https://brew.sh |
| Rust | rustup（公式スクリプト。単体の rustc をディストリのパッケージで入れない） | https://rustup.rs/ |
| PowerShell Core | 公式パッケージ / Homebrew cask（Unix に Windows PowerShell 5.x は無い） | https://learn.microsoft.com/powershell/scripting/install/installing-powershell |

## 補足

- macOSでは `xcode-select --install` でGitを含む基本的な開発ツールが入る。
  これは対話的なGUIダイアログを伴うため、自動化には不向き。その場合は
  Homebrew経由(②)に切り替える。
- Homebrew自体が未インストールの場合、以下の公式スクリプトで導入する
  (①相当の扱い。実行前に必ずユーザーへ確認する):

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

- rustup の公式スクリプト（`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`）も
  外部からのダウンロードと実行を伴う。**取得元と目的を提示して承認を得てから実行する**
  （`.claude/rules/external-resources.md`）。導入後 `~/.cargo/bin` は既存シェルの PATH に
  反映されないため、`~/.cargo/env` を読み込むかフルパスで呼び出す。
- pyenv/nvmはバージョン管理を伴うため、プロジェクトごとに異なるバージョンを
  使い分けたい場合はこちらを優先する判断も可。ただし初回導入の手間が
  Homebrew単体より大きいため、単に「動けばよい」ケースでは②のパッケージ
  マネージャの方が手早い。
