# Windows: Wingetパッケージ ID一覧

## 言語ランタイム・VCS（Tier A）

| ツール | Winget ID | インストールコマンド例 |
|---|---|---|
| Python 3.12 | `Python.Python.3.12` | `winget install --id Python.Python.3.12 -e --source winget` |
| Node.js LTS | `OpenJS.NodeJS.LTS` | `winget install --id OpenJS.NodeJS.LTS -e --source winget` |
| Git | `Git.Git` | `winget install --id Git.Git -e --source winget` |
| Rust（rustup 経由で rustc / cargo を導入） | `Rustlang.Rustup` | `winget install --id Rustlang.Rustup -e --source winget` |
| PowerShell Core 7.x | `Microsoft.PowerShell` | `winget install --id Microsoft.PowerShell -e --source winget` |

- **Rust は rustup 以外の経路（`Rustlang.Rust.MSVC` 等）で入れない**。toolchain / target の切替ができなくなる。導入後は `rustup show` でアクティブ toolchain を確認し、キャッシュの `rust.active_toolchain` に記録する
- MSVC toolchain（既定）は**リンクに Visual Studio の C++ ビルドツールを要する**。未導入の環境では `Microsoft.VisualStudio.2022.BuildTools`（ワークロード `Microsoft.VisualStudio.Workload.VCTools`）の追加が別途必要になる。**サイズが大きいため、導入は必ず事前に承認を得る**
- Windows PowerShell 5.x は OS 同梱で winget からは導入・更新しない（5.1 で凍結）。7.x を入れても 5.x は置き換わらず同居する

## ライブラリ由来 CLI・文書変換・開発 CLI（Tier B）

| ツール | 導入方法 | コマンド例 |
|---|---|---|
| anydoc | **npm グローバル**（winget では配布されていない） | `npm install -g @firecrawl/anydoc` |
| markitdown | **pip**（winget では配布されていない） | `python -m pip install markitdown` |
| pandoc | winget: `JohnMacFarlane.Pandoc` | `winget install --id JohnMacFarlane.Pandoc -e --source winget` |
| pdftotext（poppler） | winget: `oschwartz10612.Poppler` | `winget install --id oschwartz10612.Poppler -e --source winget` |
| GitHub CLI | winget: `GitHub.cli` | `winget install --id GitHub.cli -e --source winget` |
| gitleaks | winget: `Gitleaks.Gitleaks` | `winget install --id Gitleaks.Gitleaks -e --source winget` |
| jq | winget: `jqlang.jq` | `winget install --id jqlang.jq -e --source winget` |
| rtk | winget: `rtk-ai.rtk`（winget のマニフェストは GitHub の最新リリースより遅れることがある。2026-10-13 時点で v0.50.0） | `winget install --id rtk-ai.rtk -e --source winget`。導入後は Claude Code を再起動しないと PATH に載らない |
| Volta | winget: `Volta.Volta` | `winget install --id Volta.Volta -e --source winget` |
| .NET SDK | winget: `Microsoft.DotNet.SDK.<major>` | `winget install --id Microsoft.DotNet.SDK.8 -e --source winget` |
| pac（Power Platform CLI） | **.NET グローバルツール** | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| Python パッケージ全般（docling / openpyxl / python-docx / python-pptx / reportlab） | pip | `python -m pip install <パッケージ名>` |

**ID は必ず `winget search <キーワード>` で実在を確認してから実行する**（この表は補助であり、
ID は変更・移管されることがある）。表にないツールや ID が一致しない場合も同様に検索で確認する。

## 補足

- `-e`(`--exact`)を付けて曖昧一致を避けること。
- インストール後は同一シェルセッション内でPATHが反映されないことが多い。
  `references/typical_install_paths.md` の
  `%LOCALAPPDATA%\Microsoft\WinGet\Links\` を確認し、必要ならフルパスで
  即座に呼び出す。
- Wingetパッケージの検索: `winget search <キーワード>` で正確なIDを確認できる。
  一覧の情報が古い/一致しない場合はこのコマンドで再確認すること。
