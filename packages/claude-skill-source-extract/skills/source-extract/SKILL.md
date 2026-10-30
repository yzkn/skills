---
name: source-extract
description: "顧客受領資料・議事メモを要約せず全文抽出する（PDF / pptx / docx / xlsx / テキスト）。「資料を全文抽出して」「議事録を取り込んで」で自動適用。/source-extract [対象パス]。"
---

# /source-extract スキル — 受領資料の全文抽出

**引数(対象パス。省略時は intake/ 配下全体):** $ARGUMENTS

`intake/customer/`・`intake/minutes/` 配下の資料を全文抽出し、`intake/extract/extract_<資料グループ>.md` を作成する。

## 大原則: 要約ではなく転記する

- 日付・数値・人名・固有名詞・条件は**原文どおり**に書き写す
- 「○○が重要」のような要約・主観を加えない
- 表は表形式のまま、リストはリストのまま転記する
- 推測で値を補完しない。読み取れない箇所は `（読み取り不能）` と明示する

> 要約は情報を落とすため、後続の要件定義・設計・WBS の精度低下の最大要因になる。

## 実行手順

### Step 1: 抽出対象の確認

1. `intake/customer/`・`intake/minutes/` の全ファイルと、ユーザーが指定した追加資料を一覧化する
2. 一覧をユーザーに提示し、抽出してよいかを確認する
3. 既存の `intake/extract/extract_*.md` がある場合は、上書きせず**追記するか別名で新規作成するか**をユーザーに確認する

### Step 2: 資料グループへの分割

資料が多い場合はグループ単位に分け、並列サブエージェント（`general-purpose`）へ委譲してメインのコンテキストを温存する（1 エージェント = 1 グループ）。

グループ分けの目安:

| グループ | 出力ファイル |
|---|---|
| 顧客の制度・規程類 | `extract_顧客制度.md` |
| 業務フロー・現行運用 | `extract_業務現行.md` |
| キックオフ・定例会資料 | `extract_定例.md` |
| 議事メモ・メール転記 | `extract_議事メモ.md` |

### Step 3: ファイル形式ごとの抽出方法

office スキル（自動適用）の方法に準拠する。

一次変換は `read_document.py` が anydoc → markitdown → Docling の順で自動的に選ぶ（`anydoc` 未導入の場合は `npm install -g @firecrawl/anydoc` でグローバルインストールしてから実行する。詳細は office スキル「前提確認」）。

| 形式 | 方法（一次変換） | 検証（必ず別ツール） |
|---|---|---|
| PDF | Read ツール。10 ページ超は `pages` パラメータで分割し**全ページ読む** | `pdftotext -layout` または Docling |
| .docx | `read_document.py`（anydoc） | `pandoc -f docx -t gfm --wrap=none` ＋ anytomd |
| .xlsx | `read_document.py`（anydoc）。非表示シートの有無も確認する | openpyxl（`read_only=True`）でシート数・行列数・セル値を照合 ＋ anytomd |
| .pptx | `read_document.py`（anydoc）。表・スピーカーノートも拾う | python-pptx でスライド数・テキスト・ノートを照合 ＋ anytomd |
| テキスト・md | Read ツールでそのまま | 不要（変換していないため） |

- 【絶対禁止】**スキャン PDF に anydoc の `--ocr hosted` を使わない**（受領資料そのものが Firecrawl のホスト API へ送信される）。OCR が必要な資料はローカルの Docling で処理し、Docling が未導入なら導入の可否をユーザーに確認する

**PDF の図表を画像として残す場合**は、手で描き直さず `python .claude/scripts/pdf/extract_figures.py <PDF パス>` で切り出す（`Figure N` / `Table N` のキャプション直上を 300 dpi でクリップレンダリングし、既定で `report/figures/` に PNG と `*-manifest.json` を出力する）。転記ミスと元レイアウト（太字・下線・色分け）の欠落を防ぐため。抽出した画像は extract ファイルから相対パスで参照する。

### Step 3.5: クロスツール検証（必須）

extract は要件定義・設計・WBS の一次情報になるため、**変換に使ったツールとは別のツールで再変換して欠落・崩れを検出してから転記する**。同一ツールの再実行は検証にならない。

```bash
python .claude/scripts/office/read_document.py <資料> > <一時ディレクトリ>/primary.md
python .claude/scripts/office/verify_conversion.py <資料> <一時ディレクトリ>/primary.md --verify-engine <既定の検証>,anytomd
# <既定の検証> は docx=pandoc / xlsx=openpyxl / pptx=python-pptx。PDF は anytomd が読めないので --verify-engine を付けない
# 終了コード 0=差分なし / 1=差分あり（ユーザーに報告）/ 2=実行不能
```

- docx / xlsx / pptx は**既定の検証と anytomd の 2 本で照合する**（受領資料の全文抽出は数値・固有名詞の一次情報になるため。office スキル「複数手法でのクロスチェック」）。anytomd が未導入なら、導入の可否をユーザーに確認し、断られたら 1 本で照合して報告にその旨を書く

照合指標・形式別の検証ツール・既知の制約は `.claude/skills/office/SKILL.md`「変換の検証（クロスツール検証）」に従う。並列サブエージェントへ委譲する場合は、各エージェントに検証まで実施させ、**差分の有無を報告に含めさせる**。

- 検証出力は一時ディレクトリに置き、`intake/extract/` に残さない
- 差分があった場合は独断でどちらかを採用せず、差分箇所と推定原因をユーザーに提示して採用方針を確認する
- extract 冒頭の「抽出元」に続けて、使用した変換ツールと検証ツールを記録する

### Step 4: extract ファイルの構成

```markdown
# extract: <資料グループ名>

抽出日: YYYY-MM-DD
抽出元:
- <ファイルパス1>
- <ファイルパス2>
変換ツール: <例: anydoc> / 検証ツール: <例: pandoc 3.10>（差分: なし ／ あり=内容）

---

## <資料1のファイル名>

<原文の章立てに沿った転記。見出し階層・表・リストを保つ>
```

### Step 5: 要点インデックスの作成

以下が含まれる場合、extract 末尾に**要点インデックス**を作る（要約ではなく、一次情報の所在への参照リスト）。

- スケジュール（フェーズ・期間・キックオフ日・定例日程）
- 体制（人名・役職・役割）
- 契約条件（期間・工数上限・支払条件）
- 制約（ライセンス・技術制約・前提条件）
- 業務ルール

```markdown
## 要点インデックス

- 月次工数上限: 150 時間/月 → 業務改善提案制度規程 p.3
- キックオフ日: 2026-06-11 → キックオフ議事録 p.1
```

## 完了条件

- [ ] 対象の全資料が読み取られている
- [ ] 変換した資料は**変換ツールとは別のツール**で検証済みで、差分の有無を報告している（Step 3.5）
- [ ] `intake/extract/extract_*.md` が作成されている
- [ ] 要約ではなく転記の原則が守られている
- [ ] スケジュール・体制・契約条件・制約が要点インデックスに整理されている

## 注意事項

- `intake/customer/` の**原本は変更・リネームしない**（`.claude/rules/design-docs.md`）
- 個人情報・認証情報が含まれる場合はユーザーに通知し、extract への記載可否を確認する。認証情報の実値は転記せずマスキングする（`.claude/rules/security-hardstops.md`）
- 数百ページの大資料は段階的に読む。一度のコンテキストに詰め込まない
