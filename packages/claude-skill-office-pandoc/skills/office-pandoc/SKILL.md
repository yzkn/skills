---
name: office-pandoc
description: "Markdown を pandoc で Word（.docx）/ PowerPoint（.pptx）へ一括変換する。「Word に変換して」「設計書を納品用 Word にして」で自動適用。/office-pandoc <入力md> [--to docx|pptx]。凝ったスライドは slides-maker。"
---

# /office-pandoc スキル — Markdown → docx / pptx 変換（pandoc）

`office` スキルのサブスキル。Markdown 正本を pandoc で Word / PowerPoint に一括変換する。
デザインは reference-doc テンプレート（`.claude/scripts/office/pandoc/themes/<テーマ名>/reference.docx` / `reference.pptx`）で適用する。
テーマはディレクトリ単位で切り替えられる（既定: `royal-navy`）。利用可能なテーマは `.claude/scripts/office/pandoc/themes/` 配下のディレクトリ名を Glob で確認する。

> 設計判断・前提条件・テンプレート再生成の保守手順は [README.md](README.md) を参照。

## デザインテンプレートについて

- **reference.pptx は 2 通りの方式で構築できる**: テーマの `theme.json` に `_source`（potx のパス）があればその potx **そのもの**を基底に構築し（背景画像・図形・帯を含むデザインを完全継承。pandoc が照合する 7 レイアウトへ改名・合成し、未使用部分は削除して軽量化）、無ければ pandoc デフォルト reference へ配色・フォントを移植する（テーマ移植方式）。同梱の 6 テーマはすべてテーマ移植方式
- reference.docx は テーマの `theme.json`（配色・フォント。用紙は A4）に基づき、pandoc が参照する**全スタイル（段落・文字・表）を定義済み**: 見出し・本文（両端揃え）・引用（左罫線）・コードブロック（Source Code・等幅+薄灰背景）・インラインコード・キャプション（斜体なし灰色）・脚注・ハイパーリンク・表（ヘッダー行はテーマの dk2 色地に白字）。詳細は [README.md](README.md) の一覧を参照
- **slides-maker のデザイントークン（ロイヤルネイビー #1B3A6B・游明朝）とは独立**した別系統として共存する。互いに参照・流用しない

## 前提確認

```bash
pandoc --version
```

未導入の場合はユーザーに報告し、インストールを案内する: `winget install --id JohnMacFarlane.Pandoc`（Windows）/ `brew install pandoc`（macOS）

### 入力 md に Mermaid・SVG が含まれる場合

**変換前に確認する。** どちらも pandoc だけでは納品物として成立しない。

| 入力に含まれるもの | pandoc だけで変換すると | 対処 |
|---|---|---|
| ```mermaid コードブロック | 図にならず**コードのまま本文に出る** | `/pretty-mermaid` で SVG 化 → PNG 化し、`![図1 〜](図.png)` に差し替えた納品用 md を別に作る |
| SVG 画像（`![](図.svg)`） | `rsvg-convert` 未導入だと `Could not convert image` を警告しつつ **exit 0** で完了し、ラスタ参照を持たない図が埋まる | `/pretty-mermaid` の `scripts/rasterize.mjs` で PNG 化してから貼る |

**`design/` の Markdown 正本は書き換えない。** Mermaid は正本に残したまま、納品用の md を派生物として別に作る（`.claude/rules/design-docs.md`）。

## 変換コマンド

### Markdown → Word（.docx）

```bash
pandoc <入力.md> -o <出力.docx> \
  --reference-doc .claude/scripts/office/pandoc/themes/<テーマ名>/reference.docx \
  --toc --toc-depth 2 \
  --resource-path <画像等の基準ディレクトリ>
```

- 目次が不要な場合は `--toc --toc-depth 2` を外す
- 見出しはテーマの基調色（dk2）、本文はテーマの本文フォント、用紙は A4

### Markdown → PowerPoint（.pptx）

```bash
pandoc <入力.md> -o <出力.pptx> \
  --reference-doc .claude/scripts/office/pandoc/themes/<テーマ名>/reference.pptx \
  --slide-level 2 \
  --resource-path <画像等の基準ディレクトリ>
```

`--slide-level 2` により見出しがスライドに対応する:

| Markdown | スライド上の扱い |
|---|---|
| `% タイトル` `% 作成者` `% 日付`（先頭のタイトルブロック）または YAML front matter | タイトルスライド（Title Slide） |
| `# 見出し1` | セクション区切りスライド（Section Header） |
| `## 見出し2` | 通常スライドのタイトル（Title and Content） |
| `:::notes 〜 :::` | スピーカーノート |
| `::: columns` + `::: column` | 2 カラムスライド（Two Content） |
| 水平線 `---` | 強制スライド区切り |

- 1 スライドに収まらない量の本文を 1 見出しに詰め込まない（pandoc は自動分割しない）
- 画像は `![代替テキスト](パス){width=50%}` のように幅指定できる

## 出力先の規約

| 入力 | 出力先 |
|---|---|
| `design/` 配下の設計書 Markdown | `dist/`（納品用派生物。`.claude/rules/design-docs.md` — Markdown が正本、Office ファイルは派生物） |
| その他の Markdown | ユーザー指定パス（未指定なら入力と同じディレクトリを提案） |

- 変換後は出力ファイルの存在とサイズを確認し、パスを報告する
- 変換結果の内容確認が必要な場合は `read_document.py`（office スキル）で読み戻せる

## 変換の検証（往復検証・クロスツール）

**納品用ファイルを生成した場合は、生成に使った pandoc とは別のツール（anydoc。未導入時は anytomd、それも無ければ markitdown）で読み戻し、正本 Markdown と突き合わせて欠落を検出する。** 同じ pandoc で読み戻しても pandoc 自身の取りこぼしは再現するため検証にならない（規約の正本は `.claude/skills/office/SKILL.md`「変換の検証（クロスツール検証）」）。読み戻しエンジンは `verify_conversion.py` が自動選択する（anydoc が PATH にあれば anydoc、無ければ anytomd、それも無ければ markitdown）。

```bash
# 生成物と正本 md を渡す。--mode roundtrip で「正本の内容が生成物に残っているか」を判定する
python .claude/scripts/office/verify_conversion.py <生成した.docx|.pptx> <正本.md> --mode roundtrip
```

| 終了コード | 意味 | 対応 |
|---|---|---|
| 0 | 差分なし | 生成物を採用し、パスを報告する |
| 1 | 差分あり | **独断で採用しない**。差分箇所と推定原因をユーザーに提示して採用方針を確認する |
| 2 | 実行不能 | エンジン未導入等。原因を報告する |

往復モードの判定は正方向と異なり、**正本（`<正本.md>`）を基準に「落ちていないか」を見る**。

- 正本の見出しがすべて読み戻し結果に存在すること
- 表の総行数が減っていないこと
- 本文文字数比が 0.8〜1.3（`--toc` の目次・スライド分割で増えるため正方向より広い。実測: `--toc --toc-depth 2` 付き docx で 0.844）
- 正本にある数値・日付・パーセントが読み戻し結果にすべて存在すること（増加分は目次由来があるため許容）
- **画像を含む文書では文字数比が下限を割ることがあるが、欠落ではない**（pandoc が画像の下にキャプション段落を追加するため。実測: 図 2 点で 0.62）。見出し数と表の総行数が一致していれば採用してよい。詳細は `.claude/skills/office/SKILL.md`「クロスツール検証」

検証で拾える典型的な取りこぼし:

| 症状 | よくある原因 |
|---|---|
| 見出しが消える | `--slide-level` の指定ミス（pptx で見出し階層がスライドに割り当てられない） |
| 表の行が減る | 1 スライドに収まらない量を 1 見出しに詰め込んだ（pandoc は自動分割しない） |
| 画像・図が落ちる | `--resource-path` の指定漏れ（読み戻しでは代替テキストのみ残るため、画像自体は目視確認する） |
| 数値が消える | `==〜==`（未確定マーク）等の記法が reference テンプレートのスタイル未定義で欠落 |

> 画像・配色・レイアウト崩れは文字ベースの往復検証では検出できない。デザイン面はユーザーが実ファイルを開いて確認する（Claude Code は `guide/for-human/` 配下を参照しない）。

## テーマの選択と使い分け

| テーマ名 | デザイン | 生成方式 |
|---|---|---|
| `royal-navy`（既定） | ロイヤルネイビー（標準・slides-maker と同一パレット） | テーマ移植方式 |
| `terracotta` | 暖色系（テラコッタ） | テーマ移植方式 |
| `glacier` | 寒色系（グレイシャー） | テーマ移植方式 |
| `indigo` | 理知的（インディゴ） | テーマ移植方式 |
| `sunrise` | エネルギッシュ（サンライズ） | テーマ移植方式 |
| `graphite` | 厳粛（グラファイト） | テーマ移植方式 |

- 変換コマンドの `<テーマ名>` には既定で `royal-navy` を使う。ユーザーが `--theme <名前>` や「暖色系で」等のデザイン指定をした場合は該当テーマを使う
- 指定されたテーマが存在しない場合は、`themes/` 配下のディレクトリ一覧を提示してユーザーに確認する
- **新しいテーマの追加（2 通り）**: ① potx を `guide/for-llm/` に配置し `extract_potx_theme.py --theme <新名>` で抽出（デザイン完全継承）、② `themes/<新名>/theme.json` を既存テーマの複製から手書き（`_source` なし＝トークンのみの移植方式）。いずれも `build_reference.py --theme <新名>` で生成する
- slides-maker スキルのテーマとは**別管理**（同名テーマは同一パレットだが将来統合までは別ファイル）

## テンプレートの再生成

スライドマスター（potx）が更新された・新テーマを追加する場合は、以下でテンプレートを生成する。

```bash
# 1. potx からデザイントークンを抽出（themes/<テーマ名>/theme.json を更新。--theme は必須）
python .claude/scripts/office/pandoc/extract_potx_theme.py "guide/for-llm/<マスター>.potx" --theme <テーマ名>

# 2. reference.docx / reference.pptx を再生成（--theme 省略時は全テーマ）
python .claude/scripts/office/pandoc/build_reference.py --theme <テーマ名>
```

- `reference.docx` / `reference.pptx` は生成物なので直接編集しない（再生成で上書きされる）。ロゴ追加などの恒久的なカスタマイズが必要な場合は `build_reference.py` にパッチとして実装するか、ユーザーが別名テンプレートとして管理する
- pandoc のバージョン更新でデフォルト構造が変わりパッチが不発になった場合、`build_reference.py` は該当箇所を明示してエラー終了する（握りつぶさない）

## 関連スキルとの棲み分け

| スキル | 担当 |
|---|---|
| **office-pandoc（本スキル）** | Markdown 正本 → docx / pptx の一括変換（テーマ別テンプレート適用） |
| `/office` | 要素単位の Office 生成（JSON 指定）・既存ファイルの書式保持編集・読み取り |
| `/slides-maker` | 自然言語プロンプトからのデザイン性の高いスライド新規生成（独立デザイン） |
