# office-pandoc スキル — 設計・前提条件・保守手順

`/office-pandoc` スキル（Markdown → docx / pptx 変換）の保守用ドキュメント。
スキルの使い方は [SKILL.md](SKILL.md) を参照。本書は設計判断・環境前提・テンプレート再生成手順を記録する。

作成日: 2026-07-04（同日、reference.pptx に potx 直接ベース方式を追加）

---

## 1. 設計

### 全体構成

```
themes/<テーマ名>/theme.json（デザイントークン。手書き、または ① で potx から抽出）
        │
        │ ① extract_potx_theme.py（任意。potx のテーマ XML から配色・フォント・サイズを抽出）
        │
        │ ② build_reference.py
        │    ├ docx: pandoc デフォルト reference に OOXML パッチ
        │    └ pptx: theme.json に _source（potx パス）があれば potx 直接ベース、無ければテーマ移植方式
        ▼
themes/<テーマ名>/reference.docx / reference.pptx
        │
        │ ③ pandoc --reference-doc（SKILL.md の変換コマンド。テーマ名で切り替え）
        ▼
納品用 .docx / .pptx（design/ 正本からの変換は dist/ へ出力）
```

- **テーマ単位の管理**: `themes/<テーマ名>/` に theme.json と reference 2 点を格納する。
  既定テーマは `royal-navy`。同梱の 6 テーマ（`royal-navy`・`terracotta`・`glacier`・`indigo`・
  `sunrise`・`graphite`）はすべてテーマ移植方式で生成している
- **reference.pptx（テーマ移植方式）**: pandoc デフォルト reference に配色・フォント・16:9 スケーリング・
  日本語化を適用する（`build_pptx_transplant`）
- **reference.pptx（potx 直接ベース方式）**: 自組織のスライドマスター（potx）がある場合に使う。
  potx **そのもの**を基底に構築し、マスター・背景画像・図形・プレースホルダーデザインを完全に保持する
- **reference.docx**: pandoc デフォルト reference に theme.json のトークンをパッチ適用する
- slides-maker スキルのテーマ（`../../skills/slides-maker/themes/*.json`）とは**別管理**
  （同名テーマは同一パレットだが、ファイルは分離している）

### ファイル構成

| ファイル | 役割 | git 管理 |
|---|---|---|
| `.claude/skills/office-pandoc/SKILL.md` | スキル本体（変換コマンド・Markdown 執筆規約） | する |
| `.claude/scripts/office/pandoc/extract_potx_theme.py` | potx → theme.json 抽出（`--theme <名前>` で出力先テーマを指定。`_source` に potx パスを記録） | する |
| `.claude/scripts/office/pandoc/build_reference.py` | reference.docx / reference.pptx の生成（`--theme <名前>`、省略時は全テーマ） | する |
| `.claude/scripts/office/pandoc/themes/<テーマ名>/theme.json` | テーマごとのデザイントークン（配色・フォント / pptx の基底 potx パス）。`_source` を持たないテーマの pptx はテーマ移植方式で生成する | する |
| `.claude/scripts/office/pandoc/themes/<テーマ名>/reference.docx` / `reference.pptx` | pandoc 用テンプレート（**生成物**） | する（再生成可能だが、pandoc 未導入環境でも参照できるよう保持） |

### reference.pptx の構築方式（potx 直接ベース）

pandoc は pptx レイアウトを**英語の標準名**で照合するため、potx のレイアウトを改名して割り当て、
potx に存在しないレイアウトは `SYNTH_BASE` のレイアウトから合成する。
割り当ては `build_reference.py` の `PANDOC_LAYOUT_MAP` で定義する。**同梱の値（`表紙`・`中表紙`・
`コンテンツ`・`空白`）は例であり、使う potx のレイアウト名に合わせて書き換える。**

| pandoc が要求するレイアウト | 割り当てる potx のレイアウト（`PANDOC_LAYOUT_MAP` の例） | 備考 |
|---|---|---|
| Title Slide | 表紙 | ph 型を変換: タイトル→`ctrTitle`・`Subtitle` 図形→`subTitle`・`Version+Date` 図形→`dt`（日付） |
| Section Header | 中表紙 | 改名のみ |
| Title and Content | コンテンツ | 改名のみ（コンテンツは idx=1 の ph に入る） |
| Blank | 空白 | 改名のみ |
| Two Content | （`SYNTH_BASE` から合成） | idx=1 コンテンツ ph を左右 2 分割 |
| Comparison | （同上） | 見出しテキスト+コンテンツ ×2 組（PowerPoint 標準構成に準拠） |
| Content with Caption | （同上） | 左 35% テキスト + 右コンテンツ |

**軽量化**: 上記 7 レイアウト以外・potx 内のサンプルスライド・ノートスライド・未参照メディアを削除する。
`docProps/app.xml` は削除パートへの参照が残るため最小化する。

### 主要な設計判断

| 判断 | 理由 |
|---|---|
| **pptx に potx 直接ベース方式を用意**（テーマ移植方式と併存） | テーマ移植ではマスターの背景画像・図形・帯が再現できない。potx を基底にレイアウト改名・合成で pandoc 互換にすることで、デザインを完全継承する |
| Title Slide の ph 型を ctrTitle / subTitle / dt に変換 | pandoc は Title Slide でこの 3 型を探す。型が合わないと**空の `<p:sp/>`（スキーマ違反）を出力**し、タイトル消失・ファイル破損の原因になる |
| 合成レイアウトは `SYNTH_BASE` の複製 + idx=1 ph の分割 | 背景・タイトル位置・装飾を保ったまま、PowerPoint 標準のプレースホルダー構成（idx 1〜4）を再現する。リード文の body ph は pandoc の誤配置を避けるため合成版からは削除 |
| 未使用レイアウト・スライド・未参照メディアを削除 | potx はサンプルスライドやメディアで巨大になりやすく、そのままでは reference・変換出力すべてが巨大化する。残存 .rels から到達可能なメディアだけ残す GC 方式 |
| パート削除は**コアパートのホワイトリスト方式**（`core_re`） | potx にはサンプルスライドの残骸（customXml / charts / diagrams / embeddings / handoutMaster / authors / changesInfos 等）が含まれる。pandoc はこれらを出力へコピーしないのに presentation.xml.rels の参照は引き継ぐため、reference に残すと**変換出力が宙に浮いた relationship を持ち PowerPoint の修復ダイアログを招く** |
| presentation.xml の `p:extLst`（`p14:sectionLst` 含む）・handoutMasterIdLst・カスタムショーを除去 | セクション定義は削除済みサンプルスライドの ID を参照したまま出力へ引き継がれ、修復ダイアログの原因になる |
| ビルド時に参照整合性セルフチェック（`_verify_package`） | 宙に浮いた relationship・rels に無い r:id 参照・実在しないパートへの Content_Types Override を検出したらビルドを失敗させる（壊れた reference を黙って生成しない） |
| デザインは `theme.json` に外部化 | マスター更新時にスクリプト修正なしで再生成できる。値がレビュー可能なテキストになる。`_source` が pptx 構築の基底 potx パスを兼ねる |
| docx の見出し色は themeColor 参照ではなく dk2 の直接指定 | pandoc デフォルト docx の見出しは `themeColor="accent1"` 参照だが、テーマによっては accent1 が薄灰色などの補助色であり、テーマ移植だけでは見出しが読みにくい色になる |
| docx は A4・既定東アジア言語 ja-JP に変更 | pandoc デフォルトは Letter / zh-CN。日本語の納品文書向けに補正（pandoc デフォルトの sectPr には pgSz が無いため挿入で対応） |
| パッチ不発は明示エラーで停止（`sub_checked`） | pandoc・potx の構造が変わった場合に、壊れたテンプレートを黙って生成しない（Fail Fast） |
| docx スタイルの変更は `<w:style>` ブロック完全置換方式（`docx_style_overrides`） | OOXML は子要素の並び順が厳格（CT_PPr / CT_RPr / CT_TblPrBase）で、部分挿入は破損ファイル（Word の修復ダイアログ）を生みやすい |
| `Source Code` 段落スタイルを新規追加（docx） | pandoc はコードブロックに「Source Code」スタイルを使用するが、pandoc デフォルト reference.docx には未定義 |
| レガシー MS フォントを游フォントへ置換（`LEGACY_FONT_MAP`・docx テーマ） | ＭＳ ゴシック／ＭＳ Ｐゴシック → 游ゴシック、ＭＳ 明朝／ＭＳ Ｐ明朝 → 游明朝 |
| docx サンプル本文を日本語化（`DOCX_JP_SAMPLES` / `_SEQ`） | スタイル見本として日本語化。重複文字列（定義リスト・表ヘッダー）は出現順に別訳語を割当 |
| **レイアウト名・スタイル名は英語のまま維持（翻訳禁止）** | pandoc は pptx レイアウトを `Title Slide` 等の名前で、docx スタイルを `Body Text` 等の名前で照合する。翻訳すると変換が壊れる |
| docx `settings.xml` の `themeFontLang` に `w:eastAsia="ja-JP"` を追加 | Word が日本語本文へテーマの東アジアフォントを適用するための設定 |

### docx スタイル定義の網羅

pandoc が参照する全スタイル（段落 30・文字 17・表 1）が reference.docx に定義されている。うち以下を日本語文書向けに再定義・追加している（それ以外は pandoc デフォルト定義のまま。フォントはテーマ経由で全スタイルに適用済み）。色はテーマの theme.json から取る。

| スタイル | 種別 | 変更内容 |
|---|---|---|
| Heading 1〜9・TOC Heading | 段落 | 見出し色 = dk2（themeColor="accent1" 参照の一括置換） |
| Body Text | 段落 | 両端揃え（`w:jc both`。日本語ビジネス文書の標準） |
| Title / Subtitle | 段落 | タイトル = dk2 / サブタイトル灰色 |
| Block Text（引用） | 段落 | 左罫線 + 灰色文字。斜体は使わない |
| Caption（Table/Image Caption が継承） | 段落 | 斜体廃止・灰色 9pt |
| Footnote Text | 段落 | 9pt |
| **Source Code（新規追加）** | 段落 | Consolas + 游ゴシック 9pt・薄灰背景・枠線 |
| Verbatim Char（インラインコード） | 文字 | Consolas + 游ゴシック 10pt・薄灰背景 |
| Hyperlink | 文字 | テーマ hlink 色 + 下線 |
| Table | 表 | ヘッダー行 = dk2 地に白太字（firstRow 条件付き書式） |
| docDefaults | — | テーマフォント・既定東アジア言語 ja-JP |

---

## 2. 前提条件

| 依存 | 用途 | 備考 |
|---|---|---|
| pandoc | 変換本体・docx 用デフォルト reference の取得 | 3.x で確認。未導入環境では `winget install --id JohnMacFarlane.Pandoc`（Windows）/ `brew install pandoc`（macOS） |
| Python | 抽出・ビルドスクリプトの実行 | 3.x |
| Python 追加パッケージ | — | **不要**。extract / build とも標準ライブラリのみ（zipfile・re・json・xml.etree・subprocess） |
| スライドマスター（potx） | potx 直接ベース方式の基底（任意） | theme.json の `_source` に記録したパス。**同梱していない**。同梱テーマはすべて potx を使わない |

- 変換結果の検証に `python-pptx` / `python-docx` を使う場合があるが、これは office スキル側の依存（`pip install openpyxl python-docx python-pptx`）であり本スキルの必須要件ではない
- 別端末で作業する場合は `pandoc --version` / `python --version` を再調査すること

---

## 3. マスター更新・テーマ追加時の再生成手順（2 コマンド）

スライドマスター（potx）が更新された・新テーマを追加する場合は、以下を順に実行する。
potx を使う場合は `guide/for-llm/` 配下に置き、`--theme` に新しいテーマ名を指定する。

```bash
# ① potx からデザイントークンを抽出（themes/<テーマ名>/theme.json を上書き。--theme は必須）
python .claude/scripts/office/pandoc/extract_potx_theme.py "guide/for-llm/<マスター>.potx" --theme <テーマ名>

# ② reference.docx / reference.pptx を再生成（--theme 省略時は全テーマ。pptx は _source があれば potx を基底に構築）
python .claude/scripts/office/pandoc/build_reference.py --theme <テーマ名>
```

potx を使わないテーマは、既存テーマの `theme.json` を複製して配色・フォントを書き換え、② だけを実行する。

### 再生成後の確認

1. `theme.json` の差分（配色・フォント・サイズ）が想定どおりか確認する
2. サンプル Markdown を SKILL.md のコマンドで docx / pptx に変換し、開けること・デザイン反映を確認する
3. `build_reference.py` が「パッチ不発」エラーで止まった場合は、pandoc のデフォルト構造または potx の構造（レイアウト名・プレースホルダー構成）が変わっている。エラーメッセージ中のパターンを手がかりに該当パッチを修正する（エラーの握りつぶし・パターンの安易な緩和はしない）
4. potx 直接ベース方式で「potx にレイアウト '…' が見つからない」と止まった場合は、`build_reference.py` の `PANDOC_LAYOUT_MAP`・`SYNTH_BASE` を potx のレイアウト名に合わせる

### 注意

- `reference.docx` / `reference.pptx` は生成物。**直接編集しない**（次回の再生成で失われる）
- potx は `guide/for-llm/` 配下に置くこと。`guide/for-human/` 配下は Claude Code から参照できない（`.claude/rules/guide-access.md`【絶対禁止】）ため、抽出・再生成を実行できるのはユーザーのみになる
- potx 直接ベース方式では、Title Slide に割り当てる表紙レイアウトに `Subtitle`・`Version+Date` という名前の body 型プレースホルダーが**必要**（ph 型変換の対象。無いと「Title Slide の ph 型変換に失敗」で止まる。名前が違う場合は `build_reference.py` の変換ロジックを合わせる）
