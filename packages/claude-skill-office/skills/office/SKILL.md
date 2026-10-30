---
name: office
description: "Word・Excel・PowerPoint・PDF の読み書きを行う。「Excel を読んで」「Word に書いて」「PowerPoint を作って」等の製品名、または .docx / .xlsx / .pptx / .csv / .pdf の拡張子を含む依頼で自動適用。"
---

# /office スキル — Office ファイル操作

Office ファイルの読み書きを、事前作成済みのユーティリティスクリプトを呼び出して行う（スクリプトの都度生成はしない）。

- **読み取り**: `read_document.py`（anydoc 一次変換 → 使えない・品質が低い場合 markitdown → なお品質が低い場合 Docling へ自動フォールバック。anytomd は複数手法のクロスチェック用）
- **書き込み**: 操作 × 形式で手段を使い分ける（下記「書き込みの手段選択」）

> **Markdown ファイルとして保存する変換では、変換に使ったツールとは別のツールで検証する**（下記「変換の検証（クロスツール検証）」。同一ツールの再実行は検証にならない）

## 適用方法

`/office` で直接呼び出せるほか、Office ファイルの読み書き依頼（「Excel を読んで」「Word に書いて」等）で自動適用される。

---

## 前提確認

作業開始前に、使用する手段に応じて確認する。不足時はユーザーに通知してからインストールを案内する。

### 読み取り

```bash
anydoc --version                                         # 一次変換（推奨・未導入なら下記の手順で導入する）
python -c "import markitdown; print('markitdown OK')"   # フォールバック（必須）
python -c "import docling; print('docling OK')"          # 最終フォールバック（任意・高忠実・OCR 可）
```

- **anydoc 未導入時はグローバルインストールする**（`npx` での都度実行はしない。実行のたびにレジストリへ取りに行くため）。

  ```bash
  npm install -g @firecrawl/anydoc
  ```

  - **パッケージ名はスコープ付きの `@firecrawl/anydoc` を完全に指定する。** スコープなしの `anydoc` は同名の別パッケージ（2018 年公開の web server）であり、これを入れても変換はできない
  - Node.js 20 以上が必要（この端末は Volta 管理。`npm install -g` で Volta のシムに登録され、`anydoc` として PATH から呼べる）
  - インストール後の確認: `anydoc --version` と `which anydoc`（PowerShell では `Get-Command anydoc`）
- markitdown 未導入: `pip install markitdown`
- Docling 未導入（任意）: `pip install docling`（初回はモデル DL で時間・ストレージを要する）
- `read_document.py` は内部で `anydoc` → `python -m markitdown` の順に起動する（Windows では `markitdown` CLI がシェルの PATH に載らないことがあるためモジュール実行を優先する）。

検証用ツール（Markdown ファイルとして保存する変換の場合は必須）:

```bash
pandoc --version                                              # docx / csv の検証用
python -c "import docx, openpyxl, pptx; print('libs OK')"      # xlsx / pptx の検証用
pdftotext -v                                                   # pdf の検証用（poppler-utils）
~/.cargo/bin/anytomd --version                                 # 複数手法のクロスチェック用（推奨。docx / xlsx / pptx / csv）
```

- pandoc 未導入: `winget install --id JohnMacFarlane.Pandoc`（Windows）/ `brew install pandoc`（macOS）
- pdftotext 未導入: `winget install --id oschwartz10612.Poppler`（Windows）/ `brew install poppler`（macOS）
- anytomd 未導入: `cargo install anytomd --locked --no-default-features`（Rust 1.89 以上。配布バイナリは無い）。導入先の `~/.cargo/bin` が PATH に無くてもスクリプトはそこを探す
- 【絶対禁止】**anytomd の `--gemini` は使わない。** 画像を Gemini API へ送信する（`--no-default-features` で導入してもこのオプションは残る）。`read_document.py` はこのオプションを渡さず、`GEMINI_API_KEY`・`GOOGLE_API_KEY` も子プロセスへ渡さない

### 書き込み

| 手段 | 確認 | 不足時 |
|---|---|---|
| 単純生成（Python） | `python -c "import openpyxl, docx, pptx; print('OK')"` | `pip install openpyxl python-docx python-pptx` |
| リッチ新規生成（Node） | `.claude/scripts/office/node/` で `npm run --silent check` | 同ディレクトリで `npm install` |
| 既存ファイルの書式保持編集 | Anthropic 公式 `docx` / `xlsx` / `pptx` スキル | 各スキルの手順に従う |

Node.js 未導入の場合は `node --version` / `npm --version` を確認し、未導入ならユーザーに報告する（バージョン下限・導入手順は `~/.claude/CLAUDE.md` に記録済みであればそれに従う）。

---

## 読み取り（Word / Excel / PowerPoint / PDF → Markdown）

`read_document.py` を Bash ツールで呼び出す。anydoc で一次変換し、anydoc が使えない・抽出品質が低いと判定した場合は markitdown へ、それでも品質が低い場合は Docling へ自動フォールバックする。

```bash
python .claude/scripts/office/read_document.py <ファイルパス>
```

- 出力の Markdown をそのまま解析・要約・回答に使用する。先頭コメント（`<!-- read_document: engine=... -->`）で使用エンジンが分かる。
- エンジンを固定したい場合: `--force-engine anydoc` / `markitdown` / `docling` / `anytomd`（固定時はフォールバックしない）
- 自動フォールバックの判定基準（表の欠落 D-1／列数不整合 D-2／抽出過少 D-3／多段組崩れ D-4）は `read_document.py` 冒頭の定数で調整できる。

#### エンジンの序列と役割

| 順 | エンジン | 実装 | 役割 | 次段へ落ちる条件 |
|---|---|---|---|---|
| 1 | **anydoc**（`@firecrawl/anydoc`） | Rust（Node CLI） | 既定の一次変換 | 未導入・対応形式外・OCR が必要・変換失敗・品質判定 NG |
| 2 | **markitdown** | Python | anydoc が使えない場合のフォールバック | 未導入・変換失敗・品質判定 NG |
| 3 | **Docling** | Python | 最終フォールバック。**OCR を行えるのはここだけ** | （最終段） |
| — | **anytomd**（`anytomd-rs`） | Rust（CLI） | クロスチェック専用。自動判定の序列には入れず、`--force-engine anytomd` と検証エンジンとしてだけ使う。PDF は読めない | — |

- **anydoc も markitdown も OCR を行わない。** スキャン PDF・画像のみの PDF は anydoc が終了コード 3（`needsOcr`）で拒否し、markitdown も本文を取り出せないため、実質的に Docling が担当する。Docling 未導入の環境でスキャン PDF を扱う場合は `pip install docling` の導入をユーザーに提案する
- 【絶対禁止】**anydoc の `--ocr hosted` は使わない。** このオプションは文書そのものを Firecrawl のホスト API（`api.firecrawl.dev`）へ送信する。受領資料・設計書を外部へ送る操作であり、`.claude/rules/external-resources.md`「タスク実行時の外部送信の抑制」に反する（`read_document.py` もこのオプションを渡さない）

#### 対応フォーマット

| 拡張子 | 一次変換 | 変換内容 |
|---|---|---|
| `.docx` / `.doc` / `.docm` | anydoc | 段落・見出し・表・脚注 |
| `.xlsx` / `.xls` / `.xlsm` / `.xlsb` | anydoc | 各シートをテーブルとして変換 |
| `.pptx` / `.ppt` ほか PowerPoint 系 | anydoc | スライドのテキスト・表を抽出 |
| `.pdf` | anydoc | テキスト抽出（スキャン PDF は Docling、複雑レイアウトも Docling が有利） |
| `.csv` | anydoc | そのまま表として変換 |
| `.odt` / `.ods` / `.odp` / `.rtf` / `.epub` | anydoc | OpenDocument・リッチテキスト・EPUB |
| 上記以外（`.html`・画像 等） | markitdown | anydoc の対応形式外のため markitdown が直接処理する |

---

## 変換の検証（クロスツール検証）

Office / PDF を **Markdown ファイルとして保存する**変換（`intake/extract/` の全文抽出・`guide/for-llm/` 相当の Markdown 化・設計書の取り込み等）を行った場合は、**変換に使ったツールとは別のツールで同じ原本を再変換し、両者を突き合わせて欠落・崩れを検出する**。

- 同一ツールの再実行・同じツールのオプション変更は**検証にならない**（同じ欠落を同じように再現するため）
- `read_document.py` が markitdown・Docling へ自動フォールバックした場合は、**実際に採用したエンジンとは別のツール**を検証側に選ぶ（採用エンジンは md 冒頭の `engine=` コメントに出る。`verify_conversion.py` はこれを読んで自動で別ツールを選ぶ）
- 画面上で内容を読むだけ（要約・質問への回答）でファイルを残さない場合は必須ではないが、数値・日付・固有名詞をそのまま引用して成果物に転記するなら検証する

### 変換ツールと検証ツールの対応

**pandoc は xlsx / pptx / pdf を入力として読めない**（pptx は出力専用）。原本の形式ごとに検証ツールを選ぶ。

| 原本 | 変換（一次） | 検証（必ず別ツール） |
|---|---|---|
| `.docx` | anydoc（`read_document.py`） | `pandoc -f docx -t gfm --wrap=none "<原本>" -o "<検証出力.md>"` |
| `.csv` | anydoc / Read | `pandoc -f csv -t gfm "<原本>" -o "<検証出力.md>"` |
| `.xlsx` / `.xlsm` | anydoc（`read_document.py`） | openpyxl（`load_workbook(..., read_only=True, data_only=True)`）でシート数・各シートの行数/列数・セル値を照合 |
| `.pptx` | anydoc（`read_document.py`） | python-pptx でスライド数・各スライドのテキスト/表・スピーカーノートを照合 |
| `.pdf` | anydoc（`read_document.py`） | `pdftotext -layout "<原本>" "<検証出力.txt>"`、または Docling（`--force-engine docling`） |
| markitdown へフォールバックした場合 | markitdown | xlsx / pptx は **anytomd**（導入済みなら自動で選ぶ。未導入なら openpyxl / python-pptx）。それ以外は上表と同じ。または anydoc（`--verify-engine anydoc`） |
| Docling へフォールバックした場合 | Docling | pandoc（docx）/ pdftotext（pdf）/ openpyxl（xlsx）/ python-pptx（pptx）/ anydoc / anytomd |

**複数手法でのクロスチェック**: `--verify-engine` にカンマ区切りで複数のエンジンを指定すると、全エンジンで照合する（例: `--verify-engine openpyxl,anytomd`）。1 つでも差分があれば終了コード 1、1 つでも実行不能なら 2。数値・日付・固有名詞を成果物へ転記する変換、顧客受領資料の全文抽出（`intake/extract/`）では、docx / xlsx / pptx を既定の検証と anytomd の 2 本で照合する。

### 手順（`verify_conversion.py` で実行する）

照合は手作業で行わず、`verify_conversion.py` に任せる（両者の全文をコンテキストに載せずに済む）。

```bash
# 1) 一次変換を Markdown として保存する
python .claude/scripts/office/read_document.py <原本> > <出力.md>

# 2) 別ツールで再変換して突き合わせる（検証エンジンは原本の形式から自動選択）
python .claude/scripts/office/verify_conversion.py <原本> <出力.md>
```

| 終了コード | 意味 | 対応 |
|---|---|---|
| 0 | 差分なし | 出力を採用し、注記行を md 冒頭に付ける |
| 1 | 差分あり | **独断で採用しない**。差分箇所と推定原因をユーザーに提示して採用方針を確認する |
| 2 | 実行不能 | 一次と検証が同じツール・エンジン未導入・未対応形式。原因を報告する |

- 主なオプション: `--verify-engine <名前>[,<名前>...]`（自動選択を上書き。複数指定で全エンジンと照合）・`--primary-engine <名前>`（md に engine コメントがない場合に明示）・`--out-dir <dir>`（既定は一時ディレクトリ）・`--json`（指標を JSON で取得）
- **一次変換と検証エンジンが同じ場合はスクリプトが実行前にエラー終了する**（規約違反を機械的に防ぐ）
- 検証出力は一時ディレクトリに置かれる。成果物ディレクトリ（`intake/extract/`・`design/` 等）に残さない
- スクリプトが使えない環境では上表の検証ツールを直接実行し、下記の指標を手作業で照合する

### スクリプトが照合する指標

| 指標 | 判定 |
|---|---|
| 見出し数 | 一致すること。xlsx はシート名が見出しになるため**シートの落ちも検出できる** |
| 表の個数・表の総行数 | 一致すること |
| 本文文字数の比 | **正規化後**に一次変換 ÷ 検証出力が 0.9〜1.1（往復モードは 0.8〜1.3） |
| 数値・日付・パーセント | 双方向で差集合が空であること（ISO 日付・`YYYY/M/D`・`〇年〇月〇日`・桁区切り数値・`n%` を抽出して照合） |

- `.pdf` の検証（pdftotext）は出力がプレーンテキストのため、**見出し・表の指標は自動的に対象外**となり文字数比とトークン照合で判定する
- **画像を含む文書では本文文字数比が下振れするが、内容の欠落ではない。** pandoc は画像の下にキャプション段落を生成するため、代替テキストとキャプションが読み戻し時に二重に数えられる（実測: 図 2 点を含む docx の往復で比 0.62・欠落なし）。この場合は**見出し数と表の総行数の一致**、および正本の本文が読み戻し結果に残っていることで判定する
- 原本に含まれる固有名詞・記述の欠落まで見る必要がある場合は、スクリプトの判定に加えて該当箇所を目視で照合する（スクリプトは数値・日付・パーセントのみ機械照合する）

> **文字数比は正規化してから比べる。** ツールごとに Markdown 記法の書き方が違うため、生の文字数では内容が完全一致していても 1 割以上ずれる（実測: 同一内容の docx で markitdown 151 文字 / pandoc 132 文字 = 1.14。差分はエンジン注記コメントと表区切り行 `| --- |` vs `|------|` のみ）。スクリプトは比較前に ①HTML コメント ②表の区切り行 ③記法文字（`|`・`#`・`*`・`_`・`>`・`-`・バッククォート）④空白 を除去する（上記サンプルは正規化後 81 / 81 = 1.000）。

### 検証後の記録

差分なしの場合、保存した Markdown の冒頭に使用ツールと検証日を注記する（スクリプトが注記行を出力する）。

```markdown
<!-- 変換: anydoc / 検証: pandoc 3.10（2026-08-31・差分なし） -->
```

### 既知の制約

- **一次が markitdown のとき、xlsx / pptx の検証は低レベルパーサを共有する**（markitdown も内部で openpyxl / python-pptx を使う）。抽出パス・レンダリングの違いによる欠落（シートの取りこぼし・行の打ち切り・結合セルの潰れ等）は検出できるが、パーサ自体に起因する欠落は検出できない。真に独立した検証が必要な場合は LibreOffice headless（`soffice --headless --convert-to csv`）で変換して照合する。スクリプトはこの制約を実行時に stderr へ表示する
  - **anytomd を検証に使えばこの制約を受けない**（calamine / quick-xml を使い、openpyxl / python-pptx を使わない）。導入済みなら `verify_conversion.py` が自動で選ぶ
  - **一次が anydoc の場合はこの制約を受けない**（anydoc は Rust の独自パーサで openpyxl / python-pptx を使わない）。そのため anydoc → openpyxl / python-pptx の組み合わせは、markitdown 一次のときより検証の独立性が高い
- **anydoc と anytomd は最下層のクレートを共有する**（どちらも zip 8.x / quick-xml 0.41 系。2026-10-21 に anydoc 0.2.4 のバイナリで確認）。本文の解釈は別実装なので抽出漏れの多くは検出できるが、ZIP 展開・XML 字句解析に起因する欠落は検出できない。anydoc 一次のときは既定の検証（pandoc / openpyxl / python-pptx）を外さず、anytomd は 2 本目に足す（スクリプトは該当時に stderr へ表示する）
- **エンジン固有のラベルは照合前に除く**: anytomd の `Slide N:`（見出し）・`Note:`（ノート）、markitdown の `### Notes:` 見出し。内容ではない表記差で見出し数・文字数比がずれるため（`verify_conversion.py` の `ENGINE_LABELS`）
- **pptx を python-pptx で検証すると、ノートの分だけ文字数比が上振れする**（python-pptx の検証出力はノートを HTML コメントに入れ、正規化で除かれるため。実測: ノート 1 枚の pptx で anydoc 一次の比 1.163）。差分がこれだけのときは、anytomd でも照合して内容の欠落でないことを確かめる
- **anydoc は Node.js 20 以上を要求する**。Node のバージョンはプロジェクトの `package.json` の `volta` フィールドで切り替わるため、変換に失敗したら `node --version` を確認する
- **Windows のリダイレクト保存**: `read_document.py` は stdout を UTF-8 / LF 固定にしているため `>` での保存で文字化け・改行の二重変換は起きない。他のツールの出力をリダイレクトする場合は `PYTHONUTF8=1 PYTHONIOENCODING=utf-8` を付ける（`.claude/docs/windows-python-tooling.md`）

```markdown
<!-- 変換: anydoc / 検証: pandoc 3.10（2026-08-31・差分なし） -->
```

---

## 書き込みの手段選択

依頼内容から次のツリーで手段を決める。**判定が曖昧な場合はユーザーに確認する**（単純 or リッチ／新規 or 既存編集）。

```
Q0. 入力が Markdown（正本）で、docx / pptx への一括変換か？
      └─ Yes → 【md変換】/office-pandoc サブスキル（pandoc + テーマ切替）
Q1. 既存ファイルの体裁を保持して編集したいか？
      └─ Yes → 【既存編集】Anthropic 公式 docx / xlsx / pptx スキル（OOXML 編集・Python）
Q2. （新規生成）見栄え・リッチ表現（装飾・グラフ・デザイン）が必要か？
      ├─ Yes → 【新規・リッチ】Node レンダラー（.claude/scripts/office/node/）
      └─ No  → 【新規・単純】現行 Python スクリプト
```

> Node 系ライブラリ（docx / exceljs / pptxgenjs）は**新規生成専用で既存ファイルの編集は不可**。既存ファイルの書式を保って編集する用途では必ず公式 OOXML 編集スキルを使う。

---

## 書き込み手順

### 【新規・単純】Python スクリプト（軽量・依存最小）

#### Excel

```bash
python .claude/scripts/office/write_excel.py --out <out.xlsx> --sheet <シート名> --data <data.json>
```
`data.json`: `{ "headers": ["列A","列B"], "rows": [["値1","値2"]] }`（`--template <既存.xlsx>` で既存ベース）

#### Word

```bash
python .claude/scripts/office/write_word.py --out <out.docx> --content <content.json>
```
`content.json`: `{ "title": "...", "sections": [ { "heading": "...", "level": 1, "body": "...", "table": {"headers":[],"rows":[]} } ] }`

#### PowerPoint

```bash
python .claude/scripts/office/write_pptx.py --out <out.pptx> --slides <slides.json>
```
`slides.json`: `{ "title": "...", "subtitle": "...", "slides": [ { "title": "...", "body": "..." } ] }`

> デザイン性の高いスライドは `/slides-maker` スキルを使う（python-pptx / PptxGenJS の 2 エンジン対応）。

---

### 【新規・リッチ】Node レンダラー（見栄え重視）

初回のみ `.claude/scripts/office/node/` で `npm install`。以降は各レンダラーを呼び出す。

#### Word（dolanmiu/docx）

```bash
node .claude/scripts/office/node/write_docx.mjs --out <out.docx> --content <content.json>
```
`content.json`: `{ "title": "...", "sections": [ { "heading": "...", "level": 1, "body": "...", "bullets": ["..."], "table": {"headers":[],"rows":[]} } ] }`

#### Excel（ExcelJS）

```bash
node .claude/scripts/office/node/write_xlsx.mjs --out <out.xlsx> --data <data.json>
```
`data.json`（単一シート）: `{ "sheet": "S1", "headers": [...], "rows": [[...]], "numberFormats": {"2":"#,##0"} }`
複数シート: `{ "sheets": [ { "name": "S1", "headers": [...], "rows": [[...]] } ] }`
> ExcelJS はネイティブなグラフ生成に非対応。グラフが必須の場合はテンプレート方式または手動対応をユーザーに案内する。

#### PowerPoint（PptxGenJS・単発生成）

```bash
node .claude/scripts/office/node/write_pptx.mjs --out <out.pptx> --slides <slides.json>
```
中間形式は `/slides-maker` と共通コア（8 レイアウト＋任意の `ext.pptxgenjs`）。連続したデッキ生成は `/slides-maker` を推奨。

---

### 【既存編集】Anthropic 公式 OOXML スキル（書式保持）

既存の Office ファイルの体裁を壊さずに編集する場合は、Node/現行 Python の生成スクリプトではなく公式スキルを使う。

- Word: `.claude/skills/anthropics/docx/`
- Excel: `.claude/skills/anthropics/xlsx/`
- PowerPoint: `.claude/skills/anthropics/pptx/`

各スキルの手順に従い、OOXML を直接編集して差分適用する。

---

### 既存ファイルを参照して新規生成するフロー

1. `read_document.py` で現在の内容を読み取る
2. 変更内容をユーザーに確認する
3. 書式保持が必要なら【既存編集】、作り直しでよければ【新規・リッチ/単純】で生成する

---

## 注意事項

- `read_document.py` の変換はテキスト・表・見出しが対象。画像・グラフ・セル書式・数式は保持されない（anydoc は埋め込み画像を代替テキストとして出力する。高忠実が必要なら Docling へ自動/手動で切替）
- 書き込みスクリプトは既存ファイルを上書きする。重要なファイルは作業前にユーザーへ確認する
- 本番環境の設定ファイルや共有ドライブ上のファイルを操作する場合は `.claude/rules/environment-safety.md`「本番環境文字列の二重確認」に従い二重確認する
- Node レンダラーは新規生成専用。既存ファイルの書式保持編集には使わない
- `.claude/scripts/office/node/node_modules/` は git 管理外（`.gitignore`）。`package.json` / `package-lock.json` はコミットしてバージョンを固定する
