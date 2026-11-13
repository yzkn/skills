---
name: tool-environment
description: "外部コマンドを実行する前に必ず確認する。呼び出し方・格納パス・文字コード・未導入時の導入手順をキャッシュから解決する。「pip が見つからない」「pandoc が無い」「文字化けする」でも参照。"
---

# Tool Environment (環境認識・自動インストール補助スキル)

外部コマンドを呼び出す際の「呼び出し方の揺れ」「格納パスの違い」「文字コードの違い」
を吸収し、同じ調査を毎回繰り返さないようにするためのスキル。

**管理対象は言語の実行環境自体に限らない。** 言語のライブラリが提供する CLI
(markitdown 等)・文書変換ツール(pandoc / pdftotext)・開発 CLI(gh / gitleaks / jq)・
プラットフォーム CLI(pac / docker / volta)まで含めて 1 つのキャッシュで扱う。
検出対象と導入手段の一覧は `references/tool_catalog.md`(ティア A〜D)を参照する。

## 全体フロー

```
1. キャッシュ確認
   ├─ ある → そのまま使用(再検出しない)
   └─ ない/古い → 2へ

2. 環境検出(scripts/detect_*)
   └─ 結果をキャッシュファイルに書き込む

3. 実行時、文字コードは「検出」より先に「強制統一」を試みる
   （コンソール出力の文字化けはこちら。**ファイル自体の文字コード・改行コード・BOM は
     `python .claude/scripts/check-encoding.py <パス>` で検査する** → `.claude/docs/text-encoding.md`）

4. 必要なツールが見つからない場合のみ、インストール優先順位ロジックへ
   ① 公式推奨手順 → ② パッケージマネージャ → ③ 手動対応(ユーザー誘導)
```

## ステップ1: キャッシュ確認

以下の2ファイルを確認する。**存在し、かつ古くなければ、絶対に再検出しない。**

- `~/.claude/tool-environment.json` — マシン単位(OS/シェル/文字コード/インストール済みツールの絶対パス等)
- `<project>/.claude/tool-environment.json` — プロジェクト単位(venv、プロジェクト固有のpython呼び出し等)

キャッシュのJSONスキーマは `references/cache_schema.md` を参照。

### キャッシュを無効化(再検出)すべき条件

- ユーザーが明示的に「環境が変わった」「再検出して」等と言った場合
- 直前のステップでツールを新規インストールした直後(そのツールのエントリのみ更新)
- `detected_at` から30日以上経過している場合
- venv/仮想環境の切り替えを検知した場合(プロジェクト単位キャッシュのみ)

キャッシュが有効な場合、記録されている `invocation`(呼び出し文字列)と
`resolved_path`(絶対パス)をそのまま使ってツールを実行する。存在確認や
`--version` の試し打ちなどは行わない。

## ステップ2: 環境検出(キャッシュが無い場合のみ)

OSを判定し、対応するスクリプトを実行する。

- Windows → `scripts/detect_windows.ps1`
- macOS/Linux → `scripts/detect_unix.sh`

これらのスクリプトは以下を出力する:
- `references/tool_catalog.md` の Tier A(ランタイム・VCS)と Tier B(利用実績のあるコマンド:
  markitdown / pandoc / pdftotext / gh / gitleaks / dotnet / java / mvn / pac / docker / podman /
  volta / winget / jq / cloc / unzip / tar / iconv)の呼び出し可否と解決済み絶対パス
- Tier C の Python パッケージ(docling / openpyxl / python-docx / python-pptx / reportlab)の import 可否
- OS種別・シェル種別
- **PowerShell のエディション別の情報**(`windows_powershell_*` / `powershell_core_*`: 有無・版数・`PSEdition`・実体パス)
- **Rust ツールチェーン**(`rustc` / `cargo` / `rustup` の有無・パス・`in_path`、`cargo_bin_dir`、アクティブ toolchain)
- (Unix系のみ)利用可能なパッケージマネージャ(brew/apt/dnf/pacman)
- (Windowsのみ)コンソールの既定文字コード(code page)

**ランタイムはエディション・ツールチェーン単位で記録する**(「あるかないか」だけでは不足する 2 例):

- **PowerShell**: Windows PowerShell 5.x(`powershell.exe` / `PSEdition=Desktop` / Windows 同梱)と
  PowerShell Core 6.x・7.x(`pwsh.exe` / `PSEdition=Core` / 別途導入)は同居しうる別ランタイム。
  `??`・`ForEach-Object -Parallel`・`ConvertFrom-Json -AsHashtable` 等は 7.x 専用で、`-Encoding utf8` の
  BOM 有無も異なる。フック(`.claude/hooks/*.ps1`)や検証スクリプトの互換性判断に直結する
- **Rust**: 実体は `%USERPROFILE%\.cargo\bin`(Unix は `~/.cargo/bin`)。**PATH で見つからないことをもって
  「未導入」と判断しない**。検出スクリプトはこのディレクトリを直接探索し、見つかった場合は
  `<cmd>_in_path=false` として記録する(呼び出しはフルパス。ステップ5 と同じ扱い)。
  `rustup show` のアクティブ toolchain と host target triple も記録する

いずれも根拠と本端末の実測値は `references/tool_catalog.md`「PowerShell はエディションを区別する」
「Rust の扱い」を参照。

Tier D(az / aws / gcloud / kubectl / terraform / soffice)は既定では検出しない。要求が発生した
時点で個別に確認する。

**Windows では PowerShell と Git Bash の PATH が異なる**(Claude Code の Bash ツールは Git Bash)。
`detect_windows.ps1` は PowerShell で未検出のコマンドを Git のインストールルート配下
(`usr\bin`・`mingw64\bin`・`usr\bin\core_perl` 等)から直接探索して補い、`<cmd>_found_in_bash` /
`<cmd>_bash_path` として出力する。詳細は `references/tool_catalog.md`「Windows: PowerShell と
Git Bash で PATH が違う」を参照。

### Windows で WSL が有効な場合は WSL 上のコマンドも候補にする

**Windows 側に未導入でも、WSL のディストリビューションに同じコマンドが入っていることがある。**
「未導入だから使えない」と結論する前に WSL 側を確認し、使えるならインストールを提案せずに
そのまま利用する(docker に限らず、jq・iconv・各種ビルドツール等すべてに適用する)。

1. `wsl.exe -l -q` で有効なディストリビューションを列挙する(出力は UTF-16。`tr -d '\000'` 等で除去)
2. `wsl.exe -d <distro> -- which <cmd>` で存在を確認する(`command -v` はシェル組み込みのため
   `wsl -- ` から直接は呼べない)
3. 使う場合は `wsl.exe -d <distro> -- <cmd> <引数>` の形で呼び、キャッシュの `wsl` セクションに
   distro 名と `invocation` を記録する

**判断と注意点:**

- **Windows 側にあるものを優先する**。パス変換・I/O 性能・改行の差異が絡まないため。WSL 側は
  「Windows 側に無い」または「Linux でしか動かない」場合の選択肢
- **パス変換が必要**: Windows のパスは WSL では `/mnt/c/...`。`wsl.exe -d <distro> -- wslpath -a '<Windowsパス>'`
  で変換する。リポジトリ内のファイルを渡す処理では変換漏れが典型的な失敗要因
- **Git Bash から `wsl.exe` を呼ぶときは 3 点に注意**（いずれも実測で確認済み。詳細と回避策は
  `references/tool_catalog.md`「Git Bash から `wsl.exe` を呼ぶときの 3 つの落とし穴」）:
  Windows パスはスラッシュ区切りで渡す / `/mnt/...` を渡すときは `MSYS_NO_PATHCONV=1` を付ける /
  `bash -lc '<スクリプト>'` は引数が壊れるため 1 コマンド 1 呼び出しに分解する
- 大量ファイルを `/mnt/c` 越しに扱うと遅い。重い処理は対象を WSL 側にコピーするか、Windows 側の
  ツールを使う
- 環境変数・認証情報は WSL に自動では引き継がれない(`WSLENV` 未設定時)
- 出力は UTF-8。Windows 側の cp932 とは別系統として扱う
- **ディストリビューション内へのインストールは `sudo` を伴うため、実行前に必ず承認を得る**
  (パッケージ名は `references/package_manager_ids.md` の Linux 列)
- **製品が管理する VM 用ディストリビューション(`podman-machine-default`・`docker-desktop` 等)を
  作業用に使わない・ツールを入れない**。製品の再作成で消える前提の領域であり、ユーザーの作業環境ではない

出力結果を `~/.claude/tool-environment.json` および必要なら
`<project>/.claude/tool-environment.json` に書き込む。書き込み後、
検出結果を簡潔な表でユーザーに提示し、誤りがあれば訂正してもらう。

## ステップ3: 文字コードの扱い

**方針: 検出して分岐するより、まず強制的にUTF-8へ統一することを優先する。**

- Windows:
  - コマンド実行前に `chcp 65001` を試す、またはPowerShellなら
    `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` を設定
  - Pythonを呼ぶ場合は環境変数 `PYTHONUTF8=1`(または `PYTHONIOENCODING=utf-8`)
    を付与して実行し、code pageに関係なく出力をUTF-8として扱わせる
- Mac/Linux:
  - 通常はUTF-8が既定だが、`LANG`/`LC_ALL` が `C` や未設定の場合のみ
    `LANG=en_US.UTF-8` 等を明示して実行する

上記の強制統一を試みても文字化けが解消しない場合に限り、実際のcode page
(例: `cp932`)を検出し、キャッシュの `default_console_encoding` に記録して
以降はそれに応じたデコード処理を行う。

## ステップ4: ツール未検出時のインストール優先順位

検出の結果、必要なツールが存在しない場合の対応順位。
**いずれの段階でも、実行前に「何をどうインストールするか」を一度ユーザーに
提示し、承認を得てから実行すること。無断でインストーラやパッケージマネージャ
を実行しない。**

### ① 公式が推奨する手順(最優先)

- Windows: `references/official_install.md` を参照
- Mac/Linux: `references/official_install_unix.md` を参照

### ② パッケージマネージャ

①で確認できない、または①の手順が対話的すぎて自動化に適さない場合に使う。

- Windows: Winget(`winget install --id <PackageId> -e --source winget`)
  - パッケージIDは `references/winget_ids.md` を参照
- macOS: Homebrew(`brew install <formula>`)
  - Homebrew自体が未インストールの場合は、公式インストールスクリプト
    (https://brew.sh)導入も①相当として扱い、ユーザー確認の上で実行する
- Linux: ディストリビューションに応じて切り替える
  - Debian/Ubuntu系 → `apt`
  - RHEL/Fedora系 → `dnf`(旧: `yum`)
  - Arch系 → `pacman`
  - どれが使えるかは検出時にキャッシュ済みの `package_manager` を使う
  - パッケージ名対応は `references/package_manager_ids.md` を参照

### ③ 手動対応(フォールバック)

①②のいずれでも解決しない場合、自動インストールは行わず、手動インストールが
必要である旨と公式ダウンロードページのURLをユーザーに提示して処理を終了する。

## ステップ5: インストール後のパス解決とキャッシュ更新

- インストール直後は同一シェルセッション内でPATHが反映されない場合がある。
  その場合は `references/typical_install_paths.md` を参照し、典型的な
  格納先を直接探索して、見つかったバイナリをフルパスで呼び出す
  (PATH更新やシェル再起動を待たない)。
- インストール完了後、必ず以下をキャッシュに書き戻す:
  - `resolved_path`(絶対パス)
  - `install_method`(`official_installer` / `winget` / `homebrew` /
    `apt` / `dnf` / `pacman` / `manual` のいずれか)
  - `in_path`(フルパス指定なしでPATH経由のまま呼べるか)
- `in_path: false` で記録された項目は、次回セッション開始時に一度だけ
  PATH反映を確認し、反映されていれば `invocation` を簡略コマンドに戻して
  `in_path: true` に更新する。

## 参照ファイル一覧

- `references/tool_catalog.md` — **管理対象コマンドのカタログ**（ティア別の検出範囲・呼び出し方・存在確認・導入手段）
- `references/cache_schema.md` — キャッシュJSONのフォーマット定義
- `references/official_install.md` — Windows向け公式インストール手順
- `references/official_install_unix.md` — Mac/Linux向け公式インストール手順
- `references/winget_ids.md` — WingetパッケージID一覧
- `references/package_manager_ids.md` — brew/apt/dnf/pacmanのパッケージ名対応表
- `references/typical_install_paths.md` — インストール方法別の典型的な格納先一覧
