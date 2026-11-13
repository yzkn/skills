---
name: design-md
description: "デザイントークンを DESIGN.md（Google Labs 仕様）として作成・検証・取り込みする。「DESIGN.md を作って」「デザイントークンを整理して」「DESIGN.md を検証して」で自動適用。/design-md <new|lint|import>。配色・スタイルの選定は ui-ux-pro-max。"
---

# DESIGN.md（デザインシステムの正本）

デザイントークンとその適用規則を、**エージェントが読める単一ファイル**として作る・検証する・取り込む。
形式は [google-labs-code/design.md](https://github.com/google-labs-code/design.md)（Google Labs, Apache-2.0, 仕様バージョン **alpha**）に準拠する。

**仕様の詳細（front matter のキー・8 セクションの正式名と順序）は [`references/spec-summary.md`](references/spec-summary.md) にある。DESIGN.md を書く前・直す前に必ず Read すること。** 記憶からキー名やセクション名を再現しない（英語表記が 1 文字違うと仕様非準拠になる）。

**正本は `design/03_basic_design/DESIGN.md` の 1 つだけ**とする。詳細設計側にコピーを置かない（`.claude/rules/design-docs.md`「Single Source of Truth」）。

---

## モード

| モード | 呼び方 | すること |
|---|---|---|
| `new` | `/design-md new` | 既存のスタイル情報からトークンを起こし、DESIGN.md を新規作成する |
| `lint` | `/design-md lint [パス]` | 既存の DESIGN.md の構造を機械検証する |
| `import` | `/design-md import` | 他形式（`design-system/MASTER.md`・design-dna の診断・既存 CSS）から DESIGN.md へ寄せる |

モードの指定がなければ、対象ファイルの有無から判断する（無ければ `new`、あれば `lint`）。

---

## new — 新規作成

1. **入力を集める。** 既存の CSS カスタムプロパティ・`tailwind.config.*`・ブランドガイドライン・design-dna の診断結果を Read する。入力が無ければ、`ui-ux-pro-max` の `--design-system` で初期案を出してから戻る（配色・フォントペアの**選定**はそちらの担当であり、本スキルは選定結果を仕様形式に固定する担当である）
2. **[`references/spec-summary.md`](references/spec-summary.md) を Read する。**
3. **front matter を書く。** `name` は必須。値が決まっていない項目は `"==検討中（顧客確認待ち）=="` と書き、空欄や `TBD` で放置しない
4. **本文 8 セクションを仕様の順序で書く。** 書かないと決めたセクションは front matter の `omitted` に列挙する（「書き忘れ」と区別するため）
5. **`Do's and Don'ts` を必ず埋める。** ここがデザイン生成時のガードレールになる。`anti-slop-review` が指摘する兆候（意味のないグラデーション・全要素同一の角丸・`transition: all`・Inter 一択）のうち、この案件で禁じるものを Don't として明記する
6. **lint を通す**（下記）。ERROR が残った状態で完了報告しない

### 雛形

```markdown
---
version: alpha
name: <デザインシステム名>
description: <1 行の説明>
omitted:
  - <意図的に書かないセクションの正式名>
colors:
  primary: "#000000"
  secondary: "#000000"
typography:
  heading-1:
    family: "<フォント名>"
    size: 32px
    weight: 700
    lineHeight: 1.25
rounded:
  md: 8px
spacing:
  md: 16px
components:
  button:
    background: "#000000"
---

# DESIGN.md — <プロジェクト名>

## Overview
<ブランドの人格・対象ユーザー・UI が喚起すべき感情>

## Colors
<パレットの意図。primary が何を担うか>

## Typography
<タイポグラフィレベルの設計意図>

## Layout
<グリッド・スペーシング戦略>

## Elevation & Depth
<視覚的階層の表現方法>

## Shapes
<形状の扱い>

## Components
<コンポーネント要素へのスタイル指針>

## Do's and Don'ts
- **Do**: <守ること>
- **Don't**: <禁じるアンチパターン>
```

見出しは**英語のまま**にする（仕様がこの名前でパースする）。本文の散文は日本語で書く。

---

## lint — 構造の検証

```sh
python .claude/skills/design-md/scripts/validate_design_md.py design/03_basic_design/DESIGN.md
```

- ERROR があれば終了コード 1。`--json` で機械可読出力
- 検証するのは**構造**だけである（front matter のキー・セクション名・順序・`colors.primary` の有無・重複・未確定マーカーの残存）。**色の妥当性・コントラスト比・実装との一致は検証しない**
- **コントラスト比は `/vnl` で算出する。** 目測・暗算で「AA を満たす」と書かない（`.claude/rules/code-quality.md`）
- 公式 CLI（`npx @google/design.md lint`）は使わない。外部パッケージの実行は【要指示】であり、このスクリプトで足りる

---

## import — 他形式からの取り込み

| 入力 | 変換の要点 |
|---|---|
| `design-system/MASTER.md`（`ui-ux-pro-max --persist` の出力） | CSS 変数表 → front matter のトークン、選定理由の散文 → Overview / Colors / Typography、アンチパターン一覧 → Do's and Don'ts |
| design-dna の診断スキーマ | `paper_value`/`accent_value` → colors、`display_face`/`body_face` → typography、`macrostructure` → Layout、`anti_patterns` → Don't。出所は `## Provenance` に残す |
| 既存 CSS / Tailwind 設定 | 実装値をそのまま写す。**値を「整えて」書き換えない**（実装とのドリフトになる）。整えるべき値は Don't ではなく課題として別途報告する |

- 既に DESIGN.md がある場合は**上書きしない**。差分を提示して統合方針をユーザーに確認する
- 変換後は必ず lint を通す

### 【要指示】外部のデザインシステム集を取り込む場合

`styles.refero.design` のような**実在プロダクトの UI から抽出したデザインシステム集**、および `designmd.app` のような**第三者が集めた DESIGN.md ライブラリ**を、そのまま案件の DESIGN.md として取り込んではならない。

- 実在プロダクト由来のものは、`design-dna` が定めた出力拒否の層（第三者サイトからのポータブル仕様の出力は拒否）と同じ基準で扱う。着想を得るのは可、トークンを写すのは不可
- ライセンス表記が確認できない配布物は「全権利留保」とみなす（`.claude/rules/third-party-licenses.md`）
- これらのサイトは `.claude/rules/external-resources.md` の取得許可ドメインに**入っていない**。スキルから自動取得しない
- 行政・公共系の案件では、[デジタル庁デザインシステム](https://www.digital.go.jp/policies/servicedesign/designsystem)を顧客側が採用基準にしていることがある。着手時に採用の有無を顧客に確認する。採用する場合も、トークンを取り込む前に利用条件を一次情報で確かめ、取り込んだ値の出所を `## Provenance` に残す（同サイトも取得許可ドメインに入っていない）
  - DADS はブランドを持たない共通基盤であり、案件ごとに「ローカルデザインシステム」を作る前提で設計されている（[ガイダンス](https://design.digital.go.jp/dads/guidance/local-design-system/)）。作る順序は、ブランド規定 → スタイル（色・タイポグラフィ・余白・角丸・エレベーション・レイアウト）→ コンポーネントの調整とする
  - トークンを案件向けに変えても、アクセシビリティの骨格は崩さない。テキストのコントラスト比 4.5:1 以上・非テキスト 3:1 以上、本文 16 CSS px 以上、読み物の行の高さ 1.5 倍以上、ターゲットサイズ、フォーカスインジケーター、強制カラーモードへの対応、WAI-ARIA 属性を維持し、DESIGN.md の Do's and Don'ts に明記する
  - 利用条件は取得元ごとに異なる（[利用上の注意事項](https://design.digital.go.jp/dads/introduction/notices/)、2026-10-16 確認）。文書は出典を記載し、加工した場合はその旨も書く。デジタル庁が作成したと誤認させる使い方はしない。Figma データは CC BY 4.0（一部の Material Symbols は Apache-2.0）、コードは MIT である。イラスト・アイコンは別の利用規約が優先するため、使う前に確かめる。`## Provenance` には、どの取得元から取った値かを書く

---

## 受け渡し

```
design-dna（診断）→ ui-ux-pro-max（選定）→ design-md（正本化）→ ui-designer（モックアップ・監査）→ 実装
```

- 実装コードへのトークン反映は本スキルの担当ではない。DESIGN.md を正本として ui-designer・実装側が参照する
- DESIGN.md を更新したら、既存のモックアップ・実装との差分をユーザーに報告する（黙って両方を書き換えない）
