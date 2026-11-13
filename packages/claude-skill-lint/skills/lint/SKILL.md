---
name: lint
description: "コーディング規約への準拠をチェックする。静的解析ツールを優先実行し、ツールで検出できない点を補足する。「lint して」「規約チェックして」で自動適用。構造的レビューは /project-code-review。"
---

# /lint スキル — コーディング規約チェック

指定したコードを言語ごとの公式コーディング規約と照合し、違反箇所を報告する。

## 対応言語と採用する規約

| 言語 | 採用する規約 | 出典 |
|---|---|---|
| C# / .NET | Microsoft C# Coding Conventions | https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions |
| Python | PEP 8 - Style Guide for Python Code | https://peps.python.org/pep-0008/ |
| JavaScript（Node.js） | Airbnb JavaScript Style Guide | https://github.com/airbnb/javascript |
| TypeScript | Microsoft TypeScript Coding Guidelines | https://github.com/microsoft/TypeScript/wiki/Coding-guidelines |
| PowerShell | PowerShell Best Practices and Style Guide | https://poshcode.gitbook.io/powershell-practice-and-style/ |

---

## 適用方法

`/lint [パス]` で直接呼び出せるほか、以下のような依頼で自動適用される。

- 「`<ファイルパス>` の規約準拠をチェックして」
- 「`<ディレクトリパス>` 配下を lint して」
- 「変更差分（未コミットの git diff）を lint して」

---

## 前提確認

チェックを開始する前に、以下が不明な場合は**必ずユーザーに確認してから**作業を進める。

| 確認事項 | 不明と判断する状況 |
|---|---|
| プログラミング言語 | ファイル拡張子・内容から一意に特定できない場合 |
| プロジェクト固有の規約 | `.editorconfig` / `.eslintrc` / `pyproject.toml` 等に標準規約と異なる設定がある場合（プロジェクト設定を優先する） |

---

## 実行手順

1. **対象言語に応じた追加スキルの確認（優先）**

   対象ファイルの拡張子に応じて、lint 実行前に専用スキルの導入を確認する。

   ---

   **C# / .NET の場合（`.cs` / `.csproj` / `.sln` を含む）**

   **dotnet/skills（公式 .NET エージェントスキル集）は導入済みですか？**

   未導入または不明な場合は、以下のコマンドを Claude Code のターミナルで実行してください。

   ```
   /plugin marketplace add dotnet/skills
   /plugin install dotnet@dotnet-agent-skills
   ```

   使用するフレームワークに応じて追加プラグインも選択してください：

   ```
   /plugin install dotnet-aspnet@dotnet-agent-skills   # ASP.NET Core
   /plugin install dotnet-blazor@dotnet-agent-skills   # Blazor
   /plugin install dotnet-data@dotnet-agent-skills     # Entity Framework
   /plugin install dotnet-diag@dotnet-agent-skills     # デバッグ・診断
   ```

   ---

   **PowerShell の場合（`.ps1` / `.psm1` / `.psd1` を含む）**

   **powershell-expert スキルは導入済みですか？**

   未導入または不明な場合は、以下の手順でインストールしてください。
   詳細は同ディレクトリの `lint-reference.md`（「PowerShell 開発向け追加スキル」セクション）を参照。

   ```powershell
   # リポジトリをクローン
   git clone https://github.com/hmohamed01/powershell-expert

   # スキルディレクトリへコピー（Windows PowerShell）
   Copy-Item -Recurse .\powershell-expert "$env:USERPROFILE\.claude\skills\powershell-expert"

   # macOS / Linux の場合
   # cp -r powershell-expert ~/.claude/skills/
   ```

   ---

   いずれもインストール済みの場合、またはスキップする場合はそのまま続行します。

2. **静的解析ツールの試行**
   - 以下のツールが利用可能か確認し、存在する場合はまず実行する

   | 言語 | 優先ツール | 確認・実行コマンド例 |
   |---|---|---|
   | C# | dotnet-format | `dotnet format --verify-no-changes <path>` |
   | Python | ruff（優先）/ flake8 | `ruff check <path>` / `flake8 <path>` |
   | JavaScript | ESLint | `npx eslint <path>` |
   | TypeScript | ESLint + TypeScript parser | `npx eslint --ext .ts <path>` |
   | PowerShell | PSScriptAnalyzer | `Invoke-ScriptAnalyzer -Path <path> -Recurse` |

3. **Claude による補足解析**
   - ツールが未インストール・設定ファイルなしの場合は Claude が下記「言語別チェックルール」に基づいてコードを解析する
   - ツール出力がある場合はその結果を解釈・補完する形で分析する

4. **結果の統合・報告**
   - ツール出力と Claude 解析を統合し、下記「結果フォーマット」で出力する
   - 重要度は `.claude/project-types/development.md`「レビュー重要度」に準拠する（🔴高 / 🟡中 / 🟢低）

---

## 言語別チェックルール

各言語の命名規則・コーディング規則の詳細は、同ディレクトリの `lint-reference.md`（`.claude/skills/lint/lint-reference.md`）に定義されている。
**Claude による解析を行う際は、必ず対象言語のセクション（C# / Python / JavaScript / TypeScript / PowerShell）を Read してから解析すること。** 記憶からの再現・規則の省略は禁止。


---

## 言語別の追加スキル導入ガイド

dotnet/skills（C# / .NET 公式スキル集）および powershell-expert の詳細（提供プラグイン一覧・インストール方法・検討するタイミング）は `lint-reference.md` の該当セクションを Read して参照する。


---

## 結果フォーマット

```markdown
# lint 結果

**対象:** <ファイルパス>
**日時:** YYYY-MM-DD HH:MM
**言語:** <言語名>
**採用規約:** <規約名>
**解析方法:** 静的解析ツール（<ツール名>） / Claude 解析 / 併用

## サマリー

違反 N 件（🔴 高 N 件 / 🟡 中 N 件 / 🟢 低 N 件）

## 違反一覧

| # | 重要度 | 場所 | 違反内容 | 規約の根拠 | 修正案 |
|---|---|---|---|---|---|
| 1 | 🔴 高 | <ファイル名:行番号> | <違反の説明> | <該当する規約ルール> | <修正後のコード例> |
| 2 | 🟡 中 | <ファイル名:行番号> | <違反の説明> | <該当する規約ルール> | <修正後のコード例> |
| 3 | 🟢 低 | <ファイル名:行番号> | <違反の説明> | <該当する規約ルール> | <修正案> |

## 問題なし

- <違反のなかったカテゴリ>
```

---

## 重要度の判断基準

| 重要度 | 基準 |
|---|---|
| 🔴 高 | 型安全性・インターフェース命名等、他のコードや型検査に影響する違反 |
| 🟡 中 | 命名規則・インポート順等、可読性・保守性に影響する違反 |
| 🟢 低 | フォーマット・コメントスタイル等、スタイル上の指摘 |

---

## 注意事項

- プロジェクトに `.eslintrc` / `ruff.toml` / `.editorconfig` 等が存在する場合はその設定を優先し、標準規約との差異をユーザーに通知する
- 自動修正は行わない。修正が必要な場合は `/code-refactor` スキルの利用を提案する
- `./doc/prompt/`・`./doc/thought/`・`./doc/adr/` 配下のファイルは証跡のため対象外とする（`.claude/CLAUDE.md`「証跡の不変性」）
