# DESIGN.md 仕様のローカル要約

> **出典**: [google-labs-code/design.md](https://github.com/google-labs-code/design.md)（Google Labs, Apache License 2.0）の `docs/spec.md`。
> **取得日**: 2026-09-03（`main` ブランチ）。**仕様バージョン: alpha**（変更が予告されている）。
> 本ファイルは原文の要約であり、原文そのものではない。**キー名・セクション名は原文の英語表記を保持している**（翻訳すると仕様非準拠になるため）。

このファイルはローカル要約であり、**実行時に外部へ取得しに行かない**。仕様の追随（再要約）はユーザーの判断で行う。判断が割れる細部に当たったときだけ、上記 URL の `docs/spec.md` を確認する。

---

## 1. ファイルの全体構造

DESIGN.md は 2 層で構成される。

| 層 | 内容 | 読み手 |
|---|---|---|
| YAML front matter | デザイントークンの厳密な値 | エージェント（機械可読） |
| Markdown 本文 | その値がなぜ存在し、どう適用するか | 人間とエージェント |

**トークンだけでも散文だけでも仕様を満たさない。** 値は front matter に、判断の根拠は本文に書く。

---

## 2. YAML front matter のトップレベルキー

| キー | 型（原文表記） | 必須 | 内容 |
|---|---|---|---|
| `version` | `<string>` | 任意 | 仕様バージョン。現在は `alpha` |
| `name` | `<string>` | **必須** | デザインシステムの名前（例: `Daylight Prestige`） |
| `description` | `<string>` | 任意 | 短い説明 |
| `omitted` | `<string[]｜OmittedSection[]>` | 任意 | **意図的に省いたセクション**の配列。linter の「セクション欠落」警告を抑止する |
| `colors` | `map<string, Color>` | 任意 | カラートークン |
| `typography` | `map<string, Typography>` | 任意 | タイポグラフィトークン（フォントプロパティの厳密値） |
| `rounded` | `map<string, Dimension>` | 任意 | 角丸トークン |
| `spacing` | `map<string, Dimension｜number>` | 任意 | スペーシングトークン |
| `components` | `map<string, map<string, string｜token reference>>` | 任意 | コンポーネント共通のスタイルトークン |

- **`omitted` は「書き忘れ」と「意図的な省略」を区別するための鍵**である。該当セクションを書かないと決めたら、必ず `omitted` に列挙する。空欄・`TBD` の放置は本リポジトリでも禁止（`.claude/rules/design-docs.md`）
- キー名は**英語のまま**使う。値の説明（散文）は日本語でよい

front matter の最小例:

```yaml
---
version: alpha
name: Daylight Prestige
colors:
  primary: "#1A1C1E"
  secondary: "#6C7278"
---
```

---

## 3. Markdown 本文の 8 セクション

**すべて `##`（h2）で書き、下記の順序を保つ。** 冒頭に `#`（h1）を置いてもよいが、パースされない。

| # | 見出し（原文表記） | 別称 | 書く内容 |
|---|---|---|---|
| 1 | `Overview` | `Brand & Style` | プロダクトの見た目と質感の全体像。ブランドの人格・対象ユーザー・UI が喚起すべき感情 |
| 2 | `Colors` | — | カラーパレットの定義。**最低でも `primary` パレットは定義する** |
| 3 | `Typography` | — | タイポグラフィのレベル定義。多くのデザインシステムで 9〜15 レベル |
| 4 | `Layout` | `Layout & Spacing` | レイアウトとスペーシングの戦略 |
| 5 | `Elevation & Depth` | `Elevation` | そのスタイルにおいて視覚的階層をどう表現するか |
| 6 | `Shapes` | — | 視覚要素の形状（角丸・輪郭など）の扱い |
| 7 | `Components` | — | デザインシステム内のコンポーネント要素へのスタイル指針 |
| 8 | `Do's and Don'ts` | — | 実践的な指針と陥りやすい失敗。**デザイン生成時のガードレールとして働く** |

- **無関係なセクションは省いてよい**が、書いたセクションはこの順序を保つ
- 散文では、体系的なトークン名に対応する**説明的な色名**（「深い藍」など）を使ってよい
- 第 8 セクション「Do's and Don'ts」は**このリポジトリで特に価値が高い**。ui-designer の visual-audit 観点・`anti-slop-review` が指摘するアンチパターンを、成果物側に固定するための欄として使う

---

## 4. 本リポジトリでの運用上の補足

仕様そのものではなく、このリポジトリの規約と接続するための取り決め。

- **正本は `design/03_basic_design/DESIGN.md` の 1 つだけ**とする。詳細設計側（`design/04_detailed_design/ui/`）にはコンポーネントカタログを置き、DESIGN.md を重複させない（`.claude/rules/design-docs.md`「Single Source of Truth」）
- **未確定値は `==〜==` で囲む**（同ルール）。front matter 内では YAML の文字列として `"==検討中=="` のように書く
- **公式 CLI（`npx @google/design.md lint`）は使わない。** 外部パッケージの実行は【要指示】であり、承認とネットワークが要る。本スキルの `scripts/validate_design_md.py`（標準ライブラリのみ）で構造を検証する
- 検証できるのは**構造**（front matter のキー・セクション名・順序・必須値の有無）までである。**色の妥当性・コントラスト比は検証しない**。コントラスト比は `/vnl` で算出する（`.claude/rules/code-quality.md`「決定論的に求まる値を暗算・記憶で出さない」）
