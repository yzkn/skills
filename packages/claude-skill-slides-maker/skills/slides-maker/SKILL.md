---
name: slides-maker
description: "自然言語プロンプトからコンサルティング品質の PowerPoint (.pptx) を生成する。2 エンジン・テーマ切り替えに対応。/slides-maker <プロンプト> [--engine <名前>] [--theme <名前>]。"
---

# /slides-maker — スライド資料自動生成

ユーザーのプロンプトをもとにコンサルティング品質の PowerPoint スライドを生成するスキル。
**2 つのレンダリングエンジン**をサポートし、環境・好みに応じて選択する。

| エンジン | レンダラー | デザイン |
|---|---|---|
| python-pptx | `.claude/scripts/office/write_pptx_design.py` | 游明朝・ロイヤルネイビーの端正なコンサル体裁（`references/design-system.md`） |
| PptxGenJS | `.claude/scripts/office/node/render_slides.mjs` | グラデ・カード・シャドウのモダンでリッチな体裁（`references/design-system-pptxgenjs.md`） |

両エンジンは**共通コアの slides.json**（8 レイアウト）を解釈する。PptxGenJS 固有表現は `ext.pptxgenjs` 名前空間で付与する。

**テーマ**: デザイントークン（配色・フォント・チャートパレット）は `themes/<テーマ名>.json` に外部化されており、両エンジンとも `--theme` で切り替えられる（既定: `royal-navy`）。1 つのテーマファイルが両エンジン分のトークン（`fonts` / `chart_palette` の `python-pptx` / `pptxgenjs` キー）を持つ。

| テーマ名 | デザイン |
|---|---|
| `royal-navy`（既定） | ロイヤルネイビー（標準） |
| `terracotta` | 暖色系（テラコッタ） |
| `glacier` | 寒色系（グレイシャー） |
| `indigo` | 理知的（インディゴ） |
| `sunrise` | エネルギッシュ（サンライズ） |
| `graphite` | 厳粛（グラファイト） |

- ユーザーが「暖色系で」「落ち着いた配色で」等とデザインを指定した場合は上表から該当テーマを選ぶ。最新の一覧は `themes/*.json` を Glob で確認する
- 新しいテーマの追加: `themes/royal-navy.json` を複製し、色（HEX・`#` なし）・フォント・パレットを書き換える。未指定キーは既定テーマの値のまま使われる
- office-pandoc スキルのテーマとは**別管理**（同名テーマは同一パレットだが将来統合までは別ファイル）

**呼び出し方**: `/slides-maker $ARGUMENTS`（`--engine python-pptx|pptxgenjs` でエンジン、`--theme <テーマ名>` でデザインを明示指定可）

`$ARGUMENTS` の例:
- `新入社員向け情報セキュリティ研修 10枚`
- `Q2売上報告 エグゼクティブ向け 8枚`
- `AI活用推進の提言資料 コンサルスタイル --engine pptxgenjs`
- `design-system.mdの内容を6枚に`

---

## 前提確認

エンジンの導入状況を検出する（選択は Step 4 で行う）。

```bash
python -c "import pptx; print('python-pptx OK')"                    # python-pptx エンジン
(cd .claude/scripts/office/node && npm run --silent check)          # PptxGenJS エンジン（docx/exceljs/pptxgenjs/jszip の解決確認）
```

- python-pptx 未導入: `pip install python-pptx`
- PptxGenJS 未導入: `.claude/scripts/office/node/` で `npm install`（`pptxgenjs` は 4.x 系）
  - PptxGenJS には PowerPoint の「修復」ダイアログを招く複数の不正出力（**notesMaster と slideMaster の theme 共有**〈主因〉・cNvPr id 重複・Content_Types の幻 slideMaster・presentation.xml の要素順序・チャートの axId/grouping/invertIfNegative/dPt・影オブジェクトの値膨張）がある。うち theme 共有と id 重複はスキーマ検証では検出されない意味制約。`render_slides.mjs` の `savePresentation()` が生成後にこれらを補正するため、**レンダラー経由での生成は必須**（`pptx.writeFile()` を直接使わない）。詳細は `references/design-system-pptxgenjs.md`

---

## 手順

### Step 1: プロンプトを解析する

`$ARGUMENTS` から以下を読み取る。

| 情報 | 読み取り方 |
|---|---|
| テーマ・トピック | 主語・目的語から推定 |
| 想定読者 | 「エグゼクティブ向け」「研修」等のキーワード |
| 枚数 | 数字＋「枚」「スライド」で指定 / なければ**8枚**をデフォルトとする |
| スタイル | 「コンサル」「シンプル」等 / なければ標準コンサルスタイル |

参照ファイルがある場合（ファイルパスが `$ARGUMENTS` に含まれる場合）は Read で読み込んでコンテンツを把握する。

---

### Step 2: スライド構成を決定する

`references/design-system.md` を Read で参照し、「標準デッキ構成」をもとに各スライドのレイアウトとアクションタイトルを決定する（レイアウト種別・共通コア構造は両エンジン共通）。

**必須ルール:**
- `action_title` は「〇〇により××が達成される」形式の**洞察を述べる文**にする。トピックラベル（「〇〇について」）は禁止
- 先頭は必ず `title` レイアウト
- 末尾は必ず `closing` レイアウト
- `section` レイアウトで論理的なブロックを区切る
- 1スライドに箇条書きは最大6点まで（3点が理想）

---

### Step 3: slides.json を生成してスクラッチパッドに保存する

スクラッチパッドに `slides_<slug>.json` として保存する。

**ファイル全体のフォーマット:**

```json
{
  "meta": {
    "title": "内部識別用タイトル"
  },
  "slides": [
    {
      "layout": "title",
      "title": "...",
      "subtitle": "...",
      "date": "2026年6月",
      "author": ""
    },
    ...
  ]
}
```

サポートするレイアウトと JSON 構造は `references/design-system.md` の「レイアウト別 JSON 構造」を参照すること（共通コア）。

**PptxGenJS エンジンを使う場合の拡張**: 各スライドに任意で `ext.pptxgenjs` を付与できる（カード表現・シャドウ・スピーカーノート・拡張チャート種別など）。詳細は `references/design-system-pptxgenjs.md` を参照。python-pptx エンジンは `ext` を無視するため、共通コアだけでも両エンジンで成立する。

---

### Step 4: エンジンの選択と出力パスの決定

**エンジン選択ロジック（自動判定＋未確定時に確認）:**

1. `$ARGUMENTS` に `--engine python-pptx|pptxgenjs` があればそれを優先する
2. なければ前提確認の結果で判定する
   - 片方のみ利用可能 → それを使用し、使用エンジンをユーザーに通知する
   - 両方利用可能 → **ユーザーに選択を求める**（下表の判断材料を提示）
   - 両方 NG → 導入手順を案内して中断する

| 観点 | python-pptx 版 | PptxGenJS 版 |
|---|---|---|
| デザイン | 游明朝・ネイビーの端正な体裁 | グラデ・カード・シャドウのモダンな体裁 |
| チャート | 縦棒・横棒・折れ線・円 | 上記＋ドーナツ・面・レーダー・散布・バブル |
| 付加機能 | なし | スピーカーノート・スライド番号 |
| 依存 | Python のみ | Node.js 必要 |

**出力ファイルパス:**
- `$ARGUMENTS` にパス指定がある場合: そのパスを使用する
- ない場合: `<スライドタイトルの slug>_YYYYMMDD.pptx` をプロジェクトルートに生成する

---

### Step 5: 選択したエンジンでレンダリングする

**python-pptx エンジン:**

```bash
python .claude/scripts/office/write_pptx_design.py \
  --out "<出力パス>" --slides "<slides.json のパス>" [--theme <テーマ名>]
```

**PptxGenJS エンジン:**

```bash
node .claude/scripts/office/node/render_slides.mjs \
  --out "<出力パス>" --slides "<slides.json のパス>" [--theme <テーマ名>]
```

- `--theme` はテーマ名（`themes/<名前>.json`）または JSON ファイルパス。省略時は `royal-navy`
- ユーザーがテーマを指定した場合はそのまま渡す。存在しないテーマ名はレンダラーが利用可能一覧付きでエラー終了する

---

### Step 6: QA チェック

生成後に以下を確認する。エラーがあれば修正して再実行する（チェック項目は両エンジン共通。画像失敗の WARNING は両エンジンとも stderr に出る）。

| チェック項目 | 確認内容 |
|---|---|
| レンダラー終了コード | `0` であること（エラーがないこと） |
| スライド枚数 | 指定枚数と一致しているか |
| `action_title` の質 | 全スライドに洞察を述べる文が入っているか |
| データ整合性 | `table` の行列数が一致しているか |
| `chart` の値 | `values` の長さが `categories` の長さと一致しているか |
| 文字数 | `action_title` が 30文字以内、箇条書き1点が 60文字以内 |
| 画像 WARNING | stderr に `WARNING: 画像の読み込みに失敗` が出ていないか |
| プレースホルダ残存 | `Text 1`・`タイトルを入力`・`XX`・`TBD` 等の仮置き文字列が残っていないか（`[要確認: …]` は意図的な明示なので可） |
| タイトル通読 | `action_title` だけを順に並べて読み、それだけで主張の流れが通じるか |
| 結果スライドの図表 | データを示すスライドは図表 1 つに絞り、読み取ってほしい点を図中か `action_title` に書いているか |
| 禁止語（社外に出す資料のみ） | 顧客名・他案件名・社内語・案件コードを 1 行 1 語で書いたリスト（**リポジトリの外**に置く。例: `~/.config/deck-forbidden-terms.txt`）を、`read_document.py` で読み戻したテキストに `grep -ciFf <リスト> <読み戻し.md>` で当てる。0 件でなければ `grep -niFf <リスト> <読み戻し.md> \| cut -d: -f1` で**行番号だけ**を出して直す。**ヒットした語そのものを出力・応答に出さない**（会話は `doc/prompt/` に自動記録され、取り消せない） |
| 文書プロパティ（社外に出す資料のみ） | 作成者・最終更新者を python-pptx の `core_properties`（`author`・`last_modified_by`）で空にする。会社名（`docProps/app.xml` の `Company`）は python-pptx で扱えないため、PowerPoint の「ドキュメント検査」で消すようユーザーに伝える |

機械的な確認の後に、**内容の確認を別の観点で 1 回行う**。`action_title` の一覧を示し、「結論が先に来ているか」「根拠のないスライドがないか」「同じ主張が重複していないか」を確かめてから報告する。顧客提出物や承認を求める資料では、`.claude/rules/adversarial-review.md` の独立パスを併用する。

> 出典: carnot-tech/consulting-pptx-skill（MIT。現 carnot-tech/jinba-consulting-pptx-skill）の 3 段階 QA・プレースホルダ検出・社外向けの禁止語照合とプロパティ消去、Gabberflast/academic-pptx-skill（MIT）の Ghost Deck Test の着想。コードと原文は持ち込んでいない（判断は ADR-055・ADR-060）。

エラー例と対処:
- `IndexError: list index out of range` → table の行列数を確認し JSON を修正
- `InvalidChartDataError` → chart の categories と series.values の長さを揃える
- `WARNING: 画像の読み込みに失敗` → URL の到達性・Base64 文字列の正当性・ファイルパスの存在を確認する

---

### Step 7: 結果を報告する

ユーザーに以下を伝える:

1. 出力ファイルのパス（クリック可能な markdown リンク形式）
2. **使用したエンジン**（python-pptx / PptxGenJS）
3. 生成したスライド数とレイアウト一覧
4. 次のアクション提案（例: PowerPoint で開いて微調整、別エンジンでの再生成）

---

## 注意事項

- `title` と `action_title` に実在しない数値・統計を創作しない。データが不明な場合は `"[要確認: 〇〇の数値]"` と明示する
- フォント（游明朝・游ゴシック）は Windows 10 以降に標準搭載。macOS では Hiragino または Noto Sans/Serif に置き換えが必要な場合がある
- `pie` チャートは系列が 1 つの場合のみ使用すること
- ファイルが既に存在する場合は上書き前にユーザーに確認する
- `$ARGUMENTS` に個人情報・認証情報が含まれる場合は slides.json に含めない

### 画像埋め込みに関する注意事項

- **サービス・製品のアイコンは、ライセンスを確認したうえでローカルの PNG として貼る**（`.claude/rules/third-party-licenses.md`）。任意の URL をそのまま `slides.json` に書かない（取得先は `.claude/rules/external-resources.md` の許可リストに限る）
- URL 画像はスクリプト実行時にダウンロードされる。ネットワーク接続が必要（タイムアウト: 15秒）
- Base64 data URI は JSON ファイルサイズが大きくなる（1MB 画像 ≈ 1.3MB テキスト）。1スライドあたり最大2枚程度にとどめること
- 読み込みに失敗した場合は WARNING を標準エラー出力に出力し、画像なしでスライドを生成する（クラッシュしない）
- `image.src` に認証が必要な URL（社内システム・S3 署名付き URL 等）を使う場合、URLが外部公開できる情報かユーザーに確認すること
- 著作権のある画像を使用する場合はライセンスを確認すること
