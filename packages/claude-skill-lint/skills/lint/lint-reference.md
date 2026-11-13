# lint リファレンス — 言語別チェックルール・追加スキル導入ガイド

`/lint` スキル（`SKILL.md`）から参照されるリファレンス。スキル本体ではないため直接呼び出しはできない。

---

## 言語別チェックルール

Claude 解析を行う際は、対象言語のセクションを Read してから解析すること。

### C# / .NET — Microsoft C# Coding Conventions

#### 命名規則

| 要素 | 規則 | 違反例 → 正例 |
|---|---|---|
| クラス・構造体・レコード | PascalCase | `customerOrder` → `CustomerOrder` |
| インターフェース | `I` + PascalCase | `Printable` → `IPrintable` |
| メソッド・プロパティ・イベント | PascalCase | `getTotal()` → `GetTotal()` |
| ローカル変数・パラメータ | camelCase | `CustomerName` → `customerName` |
| プライベートフィールド | camelCase（`_` プレフィックスは任意） | `CustomerName` → `customerName` / `_customerName` |
| 定数 | PascalCase | `MAX_SIZE` → `MaxSize` |
| 列挙型・列挙値 | PascalCase | `enum color { red }` → `enum Color { Red }` |
| 非同期メソッド | `Async` サフィックス | `Task FetchData()` → `Task FetchDataAsync()` |

#### コーディング規則

- `var` は右辺から型が明らかな場合に使用する（`var list = new List<string>()` ✓、`var x = GetSomething()` ✗）
- 文字列結合より補間文字列（`$"..."`) を使用する
- `nameof` を使用してメンバー名を文字列として参照する
- `?.` `??` `??=` 等のnull条件演算子を活用する
- `using` 宣言は `System.*` → その他（アルファベット順）の順に記述する
- 識別子にアンダースコア・ハンガリアン記法を使わない（プライベートフィールドの `_` 除く）

---

### Python — PEP 8

#### 命名規則

| 要素 | 規則 | 違反例 → 正例 |
|---|---|---|
| モジュール・パッケージ | lowercase / lowercase_with_underscores | `MyModule.py` → `my_module.py` |
| クラス | CapWords（PascalCase） | `customer_order` → `CustomerOrder` |
| 関数・メソッド | lowercase_with_underscores | `GetTotal()` → `get_total()` |
| 変数・引数 | lowercase_with_underscores | `customerName` → `customer_name` |
| 定数 | UPPER_SNAKE_CASE | `maxSize` → `MAX_SIZE` |
| 非公開属性 | `_` プレフィックス | `name` → `_name`（モジュール外非公開） |

#### コーディング規則

- インデント: スペース4つ（タブ不可）
- 最大行長: 79文字（コード）、72文字（コメント・docstring）
- 関数・クラス間: トップレベルは2行空け、クラス内メソッド間は1行空け
- インポート順: 標準ライブラリ → サードパーティ → ローカル（各グループを空行で区切る）
- インポートは1行1モジュール（`import os, sys` ✗）
- `None` との比較は `is` / `is not` を使う（`== None` ✗）
- 型ヒント（PEP 484）を推奨する
- f-string を推奨する（`%` 演算子・`.format()` より）

---

### JavaScript（Node.js） — Airbnb JavaScript Style Guide

#### 命名規則

| 要素 | 規則 | 違反例 → 正例 |
|---|---|---|
| 変数・関数 | camelCase | `customer_name` → `customerName` |
| クラス・コンストラクタ | PascalCase | `customerOrder` → `CustomerOrder` |
| 定数（不変の値） | UPPER_SNAKE_CASE | `maxSize` → `MAX_SIZE` |
| ファイル名 | kebab-case | `CustomerOrder.js` → `customer-order.js` |

#### コーディング規則

- `var` は使用しない。`const`（再代入なし）または `let`（再代入あり）を使う
- `===` / `!==` を使う（`==` / `!=` ✗）
- セミコロンを必ず付ける
- 文字列はシングルクォートを使う（テンプレートリテラルは適宜）
- インデント: スペース2つ
- コールバックにはアロー関数を使う
- オブジェクトの分割代入を活用する
- 未使用の変数を残さない
- ファイル末尾に改行を入れる

---

### TypeScript — Microsoft TypeScript Coding Guidelines

#### 命名規則

| 要素 | 規則 | 違反例 → 正例 |
|---|---|---|
| 変数・関数 | camelCase | `CustomerName` → `customerName` |
| クラス | PascalCase | `customerOrder` → `CustomerOrder` |
| インターフェース | PascalCase（`I` プレフィックスなし） | `ICustomer` → `Customer` |
| 型エイリアス | PascalCase | `customerType` → `CustomerType` |
| 列挙型・列挙値 | PascalCase | `enum direction { up }` → `enum Direction { Up }` |
| ファイル名 | camelCase | `CustomerOrder.ts` → `customerOrder.ts` |

#### コーディング規則

- `any` 型を避ける。型が不明な場合は `unknown` を使い、型ガードで絞り込む
- `null` を使わず `undefined` を使う
- 配列型は `Array<Foo>` でなく `Foo[]` と表記する
- 何も返さないコールバックには `void` を使う（`undefined` を返す意図と区別）
- 省略できる場合でも型注釈を付け、型を明示する
- Airbnb JavaScript Style Guide の命名規則以外の規則（`const`/`let`・`===`・セミコロン等）を継承して適用する
- 完全な単語を使う（略語は避ける: `e` → `event`、`err` → `error`）

---

### PowerShell — PowerShell Best Practices and Style Guide

#### 命名規則

| 要素 | 規則 | 違反例 → 正例 |
|---|---|---|
| 関数・コマンドレット | `承認済み動詞-単数名詞`（PascalCase） | `fetch-users()` → `Get-User` |
| 動詞 | `Get-Verb` で承認された動詞のみ使用 | `Fetch-Data` → `Get-Data`（Fetch は非承認） |
| パラメータ | PascalCase | `-inputpath` → `-InputPath` |
| モジュールスコープ変数 | `$PascalCase` | `$username` → `$UserName` |
| ローカル変数 | `$camelCase` | `$UserCount` → `$userCount` |
| スクリプトファイル | 関数名に合わせた `Verb-Noun.ps1` | `getusers.ps1` → `Get-User.ps1` |

#### コーディング規則

- 高度な関数には `[CmdletBinding()]` 属性を付ける
- パラメータは必ず `param()` ブロックで定義し、型と `[Parameter()]` 属性を明示する
- `[OutputType()]` で戻り値の型を宣言する
- コメントベースのヘルプ（`.SYNOPSIS` / `.DESCRIPTION` / `.PARAMETER` / `.EXAMPLE`）を記述する
- スクリプト内でエイリアスを使わない（`ls` → `Get-ChildItem`、`%` → `ForEach-Object`）
- エラー処理は `try/catch` と `-ErrorAction Stop` を組み合わせて使う
- 進捗・デバッグ情報は `Write-Host` でなく `Write-Verbose` / `Write-Debug` を使う
- 変更を伴う操作には `-WhatIf` / `ShouldProcess` サポートを実装する
- インデント: スペース4つ
- 開き波括弧 `{` は同じ行に置く

---

## C# 開発向け公式スキル（dotnet/skills）

C# / .NET プロジェクトでは、[dotnet/skills](https://github.com/dotnet/skills)（Microsoft 公式の .NET エージェントスキル集）の利用を検討する。本スキルの `/lint` による規約チェックを補完し、Entity Framework・ASP.NET Core・Blazor 等のフレームワーク固有の作業を専門スキルで行うことができる。

### 提供されるプラグイン

| プラグイン | 用途 |
|---|---|
| `dotnet` | コアスキル集（ビルド・テスト・NuGet 管理等） |
| `dotnet-aspnet` | ASP.NET Core 開発 |
| `dotnet-blazor` | Blazor 開発 |
| `dotnet-data` | Entity Framework・データアクセス |
| `dotnet-diag` | デバッグ・パフォーマンス診断 |
| `dotnet-msbuild` | ビルド設定・MSBuild スキル |
| `dotnet-ai` | LLM インテグレーション・ML 機能 |

### インストール方法

詳細は [https://github.com/dotnet/skills#installation](https://github.com/dotnet/skills#installation) を参照。Claude Code では以下のコマンドで追加できる。

```
/plugin marketplace add dotnet/skills
/plugin install <プラグイン名>@dotnet-agent-skills
```

例（ASP.NET Core プロジェクトの場合）:

```
/plugin install dotnet@dotnet-agent-skills
/plugin install dotnet-aspnet@dotnet-agent-skills
```

### 検討するタイミング

- `/lint` で C# ファイルが対象となる際に、`dotnet format` より踏み込んだ支援が必要な場合
- Entity Framework / ASP.NET Core / Blazor 等のフレームワーク固有の実装作業を行う場合
- .NET プロジェクト固有のビルド・診断・NuGet 管理を行う場合

---

## PowerShell 開発向け追加スキル（powershell-expert）

PowerShell プロジェクトでは、[powershell-expert](https://github.com/hmohamed01/powershell-expert) スキルの利用を検討する。Microsoft のベストプラクティスに沿ったスクリプト開発・GUI 構築・モジュール管理を専用スキルで支援できる。

### 主な機能

| 機能 | 内容 |
|---|---|
| スクリプト開発 | 命名規則・パラメータ設計・パイプラインパターンのテンプレート |
| GUI 開発 | Windows Forms および WPF/XAML の実装パターン |
| PowerShell Gallery 連携 | PSResourceGet を使ったモジュール検索・インストール・管理 |
| ライブ検証 | モジュール可用性とコマンドレット構文のドキュメント照合 |

### インストール方法

`/plugin` コマンドは使用せず、スキルディレクトリへのファイルコピーで導入する。

```powershell
# リポジトリをクローン
git clone https://github.com/hmohamed01/powershell-expert

# スキルディレクトリへコピー（Windows PowerShell）
Copy-Item -Recurse .\powershell-expert "$env:USERPROFILE\.claude\skills\powershell-expert"
```

```bash
# macOS / Linux
cp -r powershell-expert ~/.claude/skills/
```

コピー後は Claude Code を再起動することで自動的に有効になる。

### 検討するタイミング

- `/lint` で PowerShell ファイルが対象となり、`PSScriptAnalyzer` より踏み込んだ支援が必要な場合
- Windows Forms / WPF による GUI スクリプトを開発する場合
- PowerShell Gallery のモジュール管理を行う場合

