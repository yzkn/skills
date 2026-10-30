# PowerShell のリファクタリング（code-refactor 補助ファイル・常時ロードしない）

`/code-refactor` の Step 1 で対象が `.ps1` / `.psm1` / `.psd1` のときに Read する。汎用の手順・承認ゲート・対象外の定義は `SKILL.md` が正。

**このリポジトリの `.claude/hooks/*.ps1` を対象にする場合は先に 6 節を読む**（変更が【要指示】であり、BOM の扱いを誤るとフックが起動しなくなる）。

## 1. 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| 関数・コマンドレット | `動詞-名詞`（動詞は**承認済み動詞**。`Get-Verb` で確認）。名詞は**単数形** | `Get-UserProfile`、`New-BackupArchive` |
| パラメータ | PascalCase。標準的な名前を優先（`Path`・`Name`・`Force`・`PassThru`・`Filter`） | `-ComputerName`、`-OutputPath` |
| スイッチパラメータ | 肯定形で命名する（`-NoValidate` ではなく `-Validate`） | `-Force`、`-Recurse` |
| ローカル変数 | camelCase | `$userId`、`$retryCount` |
| スクリプト／グローバルスコープの変数・定数 | PascalCase（UPPER_SNAKE_CASE は使わない） | `$script:MaxRetryCount` |
| クラス・enum | PascalCase | `class BackupPolicy` |
| ファイル名 | 関数 1 つのスクリプトは `動詞-名詞.ps1`、モジュールは PascalCase | `New-Report.ps1`、`ReportTools.psm1` |

- **エイリアスを使わない**（`ls`・`%`・`?`・`cat`）。完全なコマンドレット名（`Get-ChildItem`・`ForEach-Object`・`Where-Object`・`Get-Content`）に置き換える。可読性の改善であり振る舞いは変わらない
- モジュールで公開する関数には衝突回避の接頭辞を付ける（`Get-YaUser` 等）。既存モジュールの方針を優先する

## 2. まず機械で直す（手作業より安全）

```powershell
Invoke-ScriptAnalyzer -Path <対象> -Recurse            # 静的解析
Invoke-ScriptAnalyzer -Path <対象> -Recurse -Fix       # 自動修正可能な指摘のみ
Invoke-Formatter -ScriptDefinition (Get-Content <file> -Raw)   # 整形
```

- **PSScriptAnalyzer は未導入の可能性がある**。`Get-Module -ListAvailable PSScriptAnalyzer` で確認し、無ければ `Install-Module PSScriptAnalyzer -Scope CurrentUser` の実行可否を**ユーザーに確認する**（PSGallery からの取得＝`.claude/rules/external-resources.md`・【要指示】）
- リポジトリに `PSScriptAnalyzerSettings.psd1` がある場合は**その設定を正**とする
- `-Fix` は書き換えを伴う。`SKILL.md` Step 3 のプレビューとして差分を提示してから適用する
- `pwsh`（7 系）と `powershell`（5.1）で解析結果・利用可能構文が異なる。**対象スクリプトの実行環境を先に確認する**（このリポジトリのフックは `powershell` = 5.1 で起動される）

## 3. 振る舞い保持の検証

| 手段 | 方法 |
|---|---|
| 構文検査（最低限） | `[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors); $errors` |
| テスト | `Invoke-Pester`（Pester が導入されている場合） |
| 破壊的操作の確認 | `-WhatIf` / `-Confirm` に対応しているか（`SupportsShouldProcess`）。対応していれば `-WhatIf` で実行して差分を確認 |
| 終了コード | `$LASTEXITCODE` / `$?` を確認する（`.claude/rules/code-quality.md`「完了の証拠主義」） |

- スクリプトの検証で**実際に実行する場合は副作用の有無を先に確認**する。ファイル削除・レジストリ変更・リモート接続を含むスクリプトは実行せず、構文検査と読解に留めてユーザーに実行を委ねる

## 4. PowerShell 固有のリファクタリング手法

| 症状 | 対応 | 根拠 |
|---|---|---|
| エイリアスの使用（`ls`・`%`・`?`） | 完全なコマンドレット名 | 可読性 |
| `if ($x -eq $null)` | `if ($null -eq $x)`（**$null を左辺に置く**。右辺だと配列比較で意図しない結果になる） | 罠の回避 |
| `$array += $item` のループ | `[System.Collections.Generic.List[object]]` の `Add()` | 配列は毎回再生成され O(n²) |
| ループ内の文字列連結 | `-join` または `System.Text.StringBuilder` | 同上 |
| `$global:` 変数の共有 | パラメータ渡し・戻り値・`$script:` スコープ | テスタビリティ |
| ハードコードされた絶対パス | `$PSScriptRoot` 起点の相対パス、`Join-Path` | 可搬性 |
| `-ErrorAction SilentlyContinue` の乱用 | 具体的な `try/catch` とエラー処理 | Fail Fast（握りつぶし禁止） |
| 外部コマンド実行後の成否未確認 | `$LASTEXITCODE` を検査して分岐 | Fail Fast |
| 関数内の裸の式が戻り値に混入 | `$null = <式>` または `[void]` でパイプラインへの流出を止める | 出力汚染の防止 |
| `param()` の型指定なし | 型を付ける（`[string]`・`[int]`・`[switch]`）と `[Parameter(Mandatory)]` | 型安全性 |
| 巨大なスクリプト本体 | 関数へ分割し、末尾で呼び出す（`param()` はファイル先頭のまま） | 単一責任 |
| コメントベースヘルプの欠如 | `.SYNOPSIS` / `.PARAMETER` / `.EXAMPLE` を追加 | ドキュメント品質 |
| `Write-Host` によるログ出力 | 用途に応じて `Write-Verbose`（詳細）・`Write-Warning`・`Write-Error` に分ける（下記【禁止】も参照） | 出力の分離 |

## 5. 【禁止】振る舞いが変わるため実施しない変換

- **`Write-Host` → `Write-Output` の一括置換**（標準出力パイプラインに値が流れ込み、呼び出し元の戻り値が変わる）
- **`Set-StrictMode -Version Latest` の追加**（未定義変数・存在しないプロパティ参照が例外になる。既存スクリプトが停止し得る）
- `$ErrorActionPreference` の変更、`-ErrorAction Stop` の一括付与（停止条件が変わる）
- **出力（return されていない式の評価結果）の整理**は関数の戻り値そのものを変える。パイプラインに何が流れているかを確認できない限り変更しない
- 文字エンコーディングと改行の変更。`Out-File` / `>` の既定は **PowerShell 5.1 が UTF-16LE、7 が UTF-8** で異なる。出力ファイルの形式が変わるため `-Encoding` を明示する変更もユーザーに確認する
- パラメータ名・関数名の改名（タスクスケジューラ・CI 定義・`settings.json` の hooks コマンド・他スクリプトから文字列で呼ばれる）
- モジュールの `Export-ModuleMember` / `.psd1` の `FunctionsToExport` に含まれる名前の改名（公開 API）
- PowerShell 7 専用構文（`?.`・`??`・`ForEach-Object -Parallel`・`Ternary ? :`）への置換（5.1 で構文エラーになる）
- `ForEach-Object -Parallel` 等による並列化（実行順序・同時実行数が変わる）

## 6. このリポジトリ固有（`.claude/hooks/*.ps1`）

| 項目 | 内容 |
|---|---|
| 変更の可否 | 【要指示】`.claude/hooks/*.ps1` は**防御設定ファイル**。作成・編集はユーザーの明示的な指示がある場合のみ（`.claude/rules/external-resources.md`） |
| BOM | 編集後は必ず `python .claude/scripts/fix-bom.py <ファイルパス>` を実行して BOM を 1 つに正規化する（`.claude/rules/safe-file-ops.md`）。**BOM を失うとフックが正しく起動しない** |
| 設計の前提 | フックは**障害時 fail-open（許可）で stderr にのみ記録する**設計。この方針を「エラーを明示すべき」として書き換えてはならない（ルート `CLAUDE.md`） |
| 起動方法 | `settings.json` の hooks から `powershell -ExecutionPolicy Bypass -File <path>` で起動される。**5.1 前提**であり 7 専用構文を使えない。ファイル名・パスの変更は `settings.json` の更新（【要指示】）を伴う |
| 依存関係 | `doc/log/error/` へのリダイレクトが前提。出力先ディレクトリの変更・`.gitkeep` の削除は禁止 |
| 構造の理解 | 3 フックの役割分担は `.claude/docs/hooks-architecture.md` を Read してから着手する |

その他のスクリプト（`.claude/scripts/**`・`.claude/skills/**/scripts/*.ps1`）は通常のリファクタリング対象。ただし `settings.json` の `permissions.allow` にパスが登録されているものは、**ファイル名・パスを変更すると承認ダイアログが出るようになる**ため改名を避ける。
