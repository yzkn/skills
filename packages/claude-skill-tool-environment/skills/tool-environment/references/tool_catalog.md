# 管理対象ツールのカタログ

このスキルが検出・キャッシュ・導入案内の対象とするコマンドの索引。
**言語ランタイムだけでなく、各言語のライブラリが提供する CLI（markitdown 等）・
文書変換ツール（pandoc / pdftotext）・クラウド/プラットフォーム CLI も対象とする。**

ティアは検出の既定範囲を表す。Tier A / B / C は既定で検出し、Tier D は必要になった時点で個別に確認する。

## Tier A: 言語ランタイム・VCS（毎セッション使う）

| ツール | 種別 | 呼び出し | 存在確認 | 導入 | 主な用途 |
|---|---|---|---|---|---|
| python | ランタイム | `python` / `py -3` | `python --version` / `py -0p` | 公式インストーラ / winget | スクリプト実行全般 |
| pip | パッケージ管理 | `python -m pip` | `python -m pip --version` | Python に同梱 | Python パッケージ導入 |
| node | ランタイム | `node` | `node --version` | 公式 / volta | Node レンダラー・各種 CLI |
| npm / npx | パッケージ管理 | `npm` / `npx` | `npm --version` | node に同梱 | 依存導入・単発実行 |
| git | VCS | `git` | `git --version` | 公式 / winget | バージョン管理 |

## Tier B: Claude Code 経由での利用実績があるコマンド

`~/.claude/settings.json` の許可履歴から抽出した実績ベースの一覧（2026-07-27 時点）。

| ツール | 種別 | 呼び出し | 存在確認 | 導入 | 主な用途 |
|---|---|---|---|---|---|
| anydoc | npm 由来 CLI（Node バインディング / Rust 実装） | `anydoc <file>` | `anydoc --version` | **`npm install -g @firecrawl/anydoc`**（Node 20 以上。npx での都度実行はしない） | Office / PDF / ODF / RTF / EPUB → Markdown 変換の**一次エンジン**（`read_document.py`）。**スコープなしの `anydoc` は同名の別パッケージなので入れない**。OCR は非対応で、`--ocr hosted` は文書を外部 API へ送るため使用禁止 |
| markitdown | Python ライブラリ由来 CLI | **`python -m markitdown`**（Windows では CLI が PATH に載らないことがある） | `python -c "import markitdown"` | `pip install markitdown` | Office / PDF → Markdown 変換（anydoc のフォールバック） |
| anytomd | cargo 由来 CLI（Rust 実装） | `anytomd <file>`（`~/.cargo/bin` が PATH 未登録なら `~/.cargo/bin/anytomd`） | `anytomd --version` | **`cargo install anytomd --locked --no-default-features`**（Rust 1.89 以上。配布バイナリは無い） | Office → Markdown 変換の**クロスチェック**（`verify_conversion.py` の検証エンジン・`read_document.py --force-engine anytomd`）。PDF は非対応。`--gemini` は画像を外部 API へ送るため使用禁止 |
| pandoc | ネイティブ CLI | `pandoc` | `pandoc --version` | winget / brew | Markdown ↔ docx / pptx 変換、**変換結果の検証** |
| pdftotext | ネイティブ CLI（poppler） | `pdftotext` | `pdftotext -v` | winget / brew | PDF テキスト抽出、**PDF 変換の検証** |
| gh | ネイティブ CLI | `gh` | `gh --version` | winget / brew | GitHub の issue / PR / release 参照 |
| gitleaks | ネイティブ CLI | `gitleaks` | `gitleaks version` | winget / brew | pre-commit フックでの機密情報検知 |
| rtk | ネイティブ CLI（Rust） | `rtk <コマンド>` | `rtk --version` と `rtk gain`（crates.io の同名の別物と見分ける） | winget（`rtk-ai.rtk`）/ brew（`rtk`）。**`cargo install rtk` は別物が入る** | Bash 出力の圧縮によるトークン削減（任意）。Claude Code への組み込み（`rtk init -g`）は、リスクを提示して導入前にユーザーへ確認する |
| dotnet | SDK / ランタイム | `dotnet` | `dotnet --version` | winget / 公式 | .NET プロジェクトのビルド・テスト |
| java / javac | ランタイム / コンパイラ | `java` / `javac` | `java -version` | winget / brew | JDBC ドライバ等の検証 |
| mvn | ビルドツール | `mvn` | `mvn -v` | brew / 手動 | Java 依存の取得・ビルド |
| pac | .NET グローバルツール | `pac` | `pac help` | `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` | Power Platform（ソリューション・環境操作） |
| podman | コンテナ | `podman` | `podman --version` | 公式 / winget | コンテナ実行・検証 |
| docker | コンテナ | **`podman` に読み替える**（Docker CLI は導入しない） | — | — | 読み替え表と差異は下記「docker の扱い」 |
| docker-compose | Compose | `docker-compose` | `docker-compose version` | Podman Desktop 同梱 | compose ファイルの実行（Docker API 互換経由） |
| volta | バージョン管理 | `volta` | `volta --version` | winget / 公式 | Node / npm のバージョン切替 |
| winget | パッケージ管理 | `winget` | `winget --version` | Windows 同梱 | ツール導入（Windows） |
| jq | ネイティブ CLI | `jq`（Windows 未導入時は `wsl.exe -d Ubuntu -- jq`） | `jq --version` | winget / brew / apt | JSON 整形・抽出 |
| cloc | ネイティブ CLI | `cloc` | `cloc --version` | winget / brew | コード行数計測 |
| unzip / tar | アーカイブ | `unzip` / `tar` | `unzip -v` / `tar --version` | OS 同梱 | OOXML の展開・配布物の確認 |
| piconv | 文字コード変換（Perl 同梱） | `piconv` | `piconv -h` | Git for Windows / Perl に同梱 | エンコーディング変換（`iconv` の代替。`piconv -f cp932 -t utf-8 <file>`） |
| iconv | 文字コード変換 | `wsl.exe -d Ubuntu -- iconv`（Windows 側には無い） | `iconv --version` | WSL に既定で導入済み / brew | **Git for Windows には同梱されない**（`libiconv-2.dll` はあるが CLI はない）。WSL 経由・`piconv`・Python のいずれでも代替できる |
| powershell（Windows PowerShell 5.x） | シェル | `powershell -NoProfile` | `$PSVersionTable.PSVersion` と `.PSEdition`（= `Desktop`） | Windows 同梱（個別に更新されない） | フック・PowerShell スクリプト実行。**Core と別ランタイムとして扱う**（下記「PowerShell はエディションを区別する」） |
| pwsh（PowerShell Core 6.x / 7.x） | シェル | `pwsh -NoProfile` | `$PSVersionTable.PSVersion` と `.PSEdition`（= `Core`） | winget（`Microsoft.PowerShell`）/ 公式 | 同上。5.x で動かない構文を使う場合はこちらを明示的に呼ぶ |
| rustc / cargo | ランタイム / ビルドツール | `rustc` / `cargo`（PATH 未登録時は `%USERPROFILE%\.cargo\bin\cargo.exe`） | `rustc --version` / `cargo --version` | rustup（公式 `rustup-init` / winget `Rustlang.Rustup`） | Rust のビルド・テスト |
| rustup | ツールチェーン管理 | `rustup`（同上のフルパス） | `rustup show`（アクティブ toolchain と host target triple） | 同上 | toolchain / target の切替。MSVC toolchain は VS の C++ ビルドツールに依存（下記「Rust の扱い」） |

## Tier C: CLI を持たない Python パッケージ（import で確認）

| パッケージ | import 名 | 存在確認 | 導入 | 主な用途 |
|---|---|---|---|---|
| docling | `docling` | `python -c "import docling"` | `pip install docling` | 高忠実な文書変換（anydoc → markitdown の最終フォールバック）。**OCR を行えるのはこれだけ** |
| openpyxl | `openpyxl` | `python -c "import openpyxl"` | `pip install openpyxl` | xlsx 読み書き・**xlsx 変換の検証** |
| python-docx | `docx` | `python -c "import docx"` | `pip install python-docx` | docx 生成 |
| python-pptx | `pptx` | `python -c "import pptx"` | `pip install python-pptx` | pptx 生成・**pptx 変換の検証** |
| reportlab | `reportlab` | `python -c "import reportlab"` | `pip install reportlab` | PDF 生成（テスト用サンプル作成等） |
| PyMuPDF | `fitz` | `python -c "import fitz"` | `pip install pymupdf` | PDF のページ描画・領域クリップ。`.claude/scripts/pdf/extract_figures.py`（図表の画像切り出し）が使う。**配布名 `pymupdf` と import 名 `fitz` が異なる** |

## Tier D: 必要時のみ確認（未導入が既定）

`az` / `aws` / `gcloud` / `kubectl` / `terraform` / `soffice`（LibreOffice）。
いずれも要求が発生した時点で存在確認し、未導入ならインストール優先順位のロジックに従う。
**これらは本番環境を操作しうるため、実行前の承認をより厳格に扱う**（`.claude/rules/environment-safety.md`）。

## Windows: PowerShell と Git Bash で PATH が違う

Claude Code の Bash ツールは **Git Bash** で動くため、PowerShell の PATH で見つからないコマンドが Git Bash 側では使えることがある（逆もある）。`scripts/detect_windows.ps1` は PowerShell で未検出のコマンドについて、Git のインストールルート配下（`usr\bin`・`mingw64\bin`・`usr\bin\core_perl`・`usr\bin\vendor_perl`）を直接探索して補う。

- 検出結果は `<cmd>_found_in_bash` / `<cmd>_bash_path` として出力される
- **bash に `-c` でスクリプトを渡す方式は使わない**。Git Bash（MSYS）側が引数を再解釈して `${var}` が壊れるため、ディレクトリ探索で判定している
- Git 同梱で使えるもの（本端末の実測）: `unzip` / `tar` / `pdftotext` / `piconv` / `awk` / `sed` / `grep`

## PowerShell はエディションを区別する（Desktop / Core）

**「PowerShell がある」だけの記録では不十分。** Windows PowerShell 5.x と PowerShell Core 6.x / 7.x は同居する別ランタイムであり、片方でしか動かないスクリプトがある。`scripts/detect_windows.ps1` は両方を個別に起動して `windows_powershell_*` / `powershell_core_*` として出力する。

| | Windows PowerShell 5.x | PowerShell Core 6.x / 7.x |
|---|---|---|
| 実行ファイル | `powershell.exe` | `pwsh.exe` |
| `$PSVersionTable.PSEdition` | `Desktop` | `Core` |
| `$PSHOME`（既定） | `C:\Windows\System32\WindowsPowerShell\v1.0` | `C:\Program Files\PowerShell\7` |
| 導入 | Windows 同梱（5.1 で凍結） | winget / 公式インストーラで別途導入 |

**5.x で動かない代表例**（Core を明示的に呼ぶ必要がある）: `??` / `??=` 演算子、`ForEach-Object -Parallel`、`ConvertFrom-Json -AsHashtable`、三項演算子 `? :`、`Test-Json`。

**文字コードの差異**（`.claude/rules/safe-file-ops.md`・本スキル ステップ 3 と併せて判断する）:

- 5.x の `-Encoding utf8` は **BOM 付き UTF-8**。BOM なしにするには `[System.IO.File]::WriteAllText()` か `-Encoding utf8NoBOM`（7.x のみ）を使う
- 5.x のリダイレクト・パイプの既定はシステムロケール（日本語環境では CP932）寄り。7.x は既定 UTF-8
- どちらのエディションでも、実行時は `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` を先に設定する方針は変わらない

**本端末の実測（2026-08-03）**: Windows PowerShell **5.1.26100.8655**（Desktop）と PowerShell **7.6.1**（Core）が同居。フック（`.claude/hooks/*.ps1`）は Claude Code が起動する側のエディションで動くため、**7.x 専用構文を書かない**のが安全側。

## Rust の扱い（rustup 管理・PATH 未登録に注意）

Rust は `rustup` で導入するのが既定で、実体は `%USERPROFILE%\.cargo\bin`（Unix は `~/.cargo/bin`、`CARGO_HOME` 指定時はその配下）に入る。**インストーラが PATH を更新していても、既存のシェルセッションや Claude Code の Bash ツールに反映されていないことがある。**

- `rustc` / `cargo` / `rustup` が PATH で見つからないときに **「未導入」と即断しない**。`%USERPROFILE%\.cargo\bin\<cmd>.exe` の存在を直接確認する（`scripts/detect_windows.ps1` の `## Rust Toolchain` が自動で行い、`<cmd>_in_path=false` として記録する）
- `in_path=false` の場合はフルパスで呼ぶ（`references/typical_install_paths.md`・本スキル ステップ 5 と同じ扱い）
- 記録する値: `rustc --version` / `cargo --version` / `rustup show`（アクティブ toolchain と **host target triple**）/ `rustup home` / `cargo_bin_in_path`
- **MSVC toolchain（`*-pc-windows-msvc`）はリンカを Visual Studio の C++ ビルドツールに依存する**。`cargo build` がコンパイル後のリンク段階だけで失敗する場合はこれを疑う（`vswhere.exe -products * -property displayName` で VS の導入を確認できる）
- GNU toolchain（`*-pc-windows-gnu`）へ切り替える場合は `rustup toolchain install stable-x86_64-pc-windows-gnu`。**toolchain / target の追加はダウンロードを伴うため、実行前に承認を得る**

**本端末の実測（2026-08-03）**: rustup 1.29.0 / rustc 1.97.1 / cargo 1.97.1、アクティブ toolchain は `stable-x86_64-pc-windows-msvc`（既定・唯一）、`rustup home` は `C:\Users\<user>\.rustup`。**`~/.cargo/bin` は PATH に載っていない**ため、Bash ツール・PowerShell のいずれからもフルパス指定で呼ぶ必要がある。最小プロジェクトの `cargo build` は成功（VS Enterprise 2026 が導入済みでリンカは解決される）。

## Windows: WSL 上のコマンドも候補にする

Windows 側に未導入でも、WSL のディストリビューションに入っていれば `wsl.exe -d <distro> -- <cmd>` で使える。**「Windows 側に無い＝未導入」と結論する前に WSL 側を確認する**（docker に限らずすべてのコマンドに適用）。

| 手順 | コマンド |
|---|---|
| ディストリビューションの列挙 | `wsl.exe -l -q`（出力は UTF-16。`tr -d '\000'` で除去する） |
| コマンドの存在確認 | `wsl.exe -d <distro> -- which <cmd>`（`command -v` はシェル組み込みのため直接呼べない） |
| 実行 | `wsl.exe -d <distro> -- <cmd> <引数>` |
| Windows パスの変換 | `wsl.exe -d <distro> -- wslpath -a '<Windowsパス>'` → `/mnt/c/...` |

### Git Bash から `wsl.exe` を呼ぶときの 3 つの落とし穴（いずれも実測済み）

| 症状 | 原因 | 回避策 |
|---|---|---|
| `wslpath -a 'c:\Users\...'` が `c:Users...` になる | バックスラッシュがシェル経由で失われる | **Windows パスはスラッシュ区切りで渡す**（`'c:/Users/...'`） |
| `/mnt/c/...` が `C:/Program Files/Git/mnt/c/...` に化ける | Git Bash（MSYS）の POSIX パス自動変換 | **`MSYS_NO_PATHCONV=1` を付けて呼ぶ**（例: `MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu -- head -1 "$P"`） |
| `wsl.exe -d X -- bash -lc '<スクリプト>'` の変数が空になる | MSYS 側の引数再解釈 | **複雑なスクリプトを渡さない**。`wsl.exe -d X -- <cmd> <args>` の 1 コマンド 1 呼び出しに分解し、結果を次の呼び出しへ渡す |

- **Windows 側にあるものを優先**（パス変換・I/O 性能・改行差異を避けられる）。WSL 側は Windows に無い場合や Linux 専用ツールの場合の選択肢
- `/mnt/c` 越しの大量ファイル処理は遅い。重い処理は WSL 側にコピーするか Windows 側ツールを使う
- 環境変数・認証情報は自動では引き継がれない（`WSLENV` 未設定時）。出力は UTF-8
- **ディストリビューションへのインストールは `sudo` を伴うため実行前に承認を得る**
- **製品管理用のディストリビューション（`podman-machine-default`・`docker-desktop` 等）は作業用に使わない**。製品側の再作成で消える領域

## docker の扱い（2026-07-27 調査）

**Podman Desktop 1.28.3 による Docker API 互換は有効に機能している。不足しているのは `docker` という名前のクライアント CLI だけ。**

| 確認項目 | 結果 |
|---|---|
| `\\.\pipe\docker_engine`（Docker API 互換エンドポイント） | **存在する**（全 433 本のパイプ中に `docker_engine` と `podman-machine-default`） |
| `docker-compose` | **使える**（`%LOCALAPPDATA%\Microsoft\WindowsApps\docker-compose.exe` v5.3.1）。`DOCKER_HOST` 未設定でも `docker-compose ls` が成功（Docker クライアントの既定が `npipe:////./pipe/docker_engine`） |
| `podman` | 5.8.5。docker と概ね同じサブコマンド体系で代替できる |
| `docker` / `docker.exe` | **未インストール**。WindowsApps・winget パッケージ・Podman Desktop 同梱・chocolatey・scoop・`~/.docker/bin`・WSL Ubuntu・podman machine のいずれにも無い |
| PowerShell プロファイル・Bash の alias | なし。`DOCKER_HOST`（User / Machine）も未設定 |

### 運用方針: `docker` は `podman` に読み替える

**Docker CLI は導入せず、`docker` コマンドの指示・手順書・記事の内容はすべて `podman` に読み替えて実行する**（この端末の方針）。Docker Desktop が入っている環境ではこの読み替えは不要なので、環境ごとに判断する。

| 元のコマンド | 読み替え後 |
|---|---|
| `docker run` / `ps` / `images` / `build` / `pull` / `push` / `logs` / `exec` / `rm` / `rmi` / `inspect` / `stop` / `start` | `podman <同じサブコマンド>`（引数もほぼ同一） |
| `docker compose <sub>` / `docker-compose <sub>` | `docker-compose <sub>`（Podman Desktop 同梱・追加設定不要）または `podman compose <sub>` |
| `docker system prune` | `podman system prune` |
| Docker API を直接利用するツール | `DOCKER_HOST=npipe:////./pipe/docker_engine`（互換エンドポイントに接続） |

**読み替え時に注意する差異**

- **イメージ名は完全修飾で書く**（`docker.io/library/nginx:latest`）。podman は短縮名の解決先をレジストリ設定に依存し、Docker のように暗黙で Docker Hub を前提にしない
- **rootless が既定**。権限・ポート・ボリュームの扱いで docker と挙動が異なる場合がある。失敗したらエラーメッセージを確認し、`sudo` で回避しようとしない
- **Windows のパスは `podman machine`（WSL 上の VM）から見える必要がある**。ボリュームマウントは共有されているパスかを確認する
- `docker-compose` は Docker API 互換エンドポイント経由で動作するため、compose ファイルはそのまま使える

### 機械的な検知（`permissions.deny`）と既知の副作用

読み替え漏れを機械的に止めるため、`~/.claude/settings.json`（ユーザーグローバル）の `permissions.deny` に以下 7 パターンを登録している。deny は allow より優先されるため、承認ダイアログでも通せない。

```
Bash(docker)            Bash(docker *)          Bash(docker.exe *)
Bash(wsl* -- docker)    Bash(wsl* -- docker*)
Bash(wsl* docker)       Bash(wsl* docker *)
```

WSL 経由（`wsl.exe -d <distro> -- docker ps`、および `--` を省略した `wsl.exe -d <distro> docker ps`）も対象。Windows 側の deny だけでは WSL 内の docker CLI を塞げないため。

| 影響を受けないもの | 理由 |
|---|---|
| `docker-compose` | `docker` の直後が `-` でありパターンに一致しない |
| `podman` / WSL 経由の他コマンド（`wsl.exe -d Ubuntu -- which jq` 等） | パターン外。実測で通過を確認済み |

**【副作用】`Bash(wsl* docker)` は「コマンド末尾が ` docker`」に一致するため、`wsl.exe -d Ubuntu -- grep docker` のような調査コマンドもブロックされる。** 読み替えの徹底を優先した結果であり、deny は承認でも解除できない。回避するには次のいずれかを取る。

- 引数を引用符で囲む（`wsl.exe -d Ubuntu -- grep 'docker'`）か、末尾に別の引数を置く
- Windows 側のコマンドで代替する（`grep docker <file>` 等）
- どうしても必要なら、ユーザーが `~/.claude/settings.json` の該当パターンを一時的に外す（Claude Code 側からは変更しない）

> **検証時の注意**: `Test-Path '\\.\pipe\docker_engine'` は名前付きパイプに対して機能せず **false（偽陰性）** を返す。パイプの存在確認は `[System.IO.Directory]::GetFiles('\\.\pipe\')` を使う。また、この配列を `container` で絞ると `AppContainerNamedObjects` が大量に一致するため、`docker_engine` のように具体名で判定する。

## 運用上の注意

- **変換と検証で同じツールを使わない**: 形式変換の検証は変換に使ったツールとは別系統を選ぶ（anydoc / markitdown ↔ pandoc / openpyxl / python-pptx / pdftotext / anytomd）。詳細は `.claude/skills/office/SKILL.md`「変換の検証（クロスツール検証）」
- Python ライブラリ由来の CLI は、Windows では `<name>.exe` が PATH に載らないことがある。**`python -m <module>` 形式を第一候補**とし、キャッシュの `invocation` にもその形で記録する
- `pac` のような .NET グローバルツールは `%USERPROFILE%\.dotnet\tools`（Unix は `~/.dotnet/tools`）に入る。PATH 未反映時はこのパスを直接叩く（`references/typical_install_paths.md`）
- カタログに載っていないコマンドを新たに使った場合は、Tier B に 1 行追加してから使う（次セッション以降の再調査を防ぐため）
