---
name: pretty-mermaid
description: "既存の Mermaid 記法を静的な SVG に描画する。主用途は design/ の図を Word・PowerPoint・PDF の納品物へ載せること。「Mermaid を画像にして」「納品用に図を焼き込んで」で自動適用。/pretty-mermaid <対象>。図の新規設計は visual-doc。"
license: MIT
---

# /pretty-mermaid スキル — Mermaid 記法の SVG 描画

**引数:** `$ARGUMENTS`（`<対象の .mmd / .md ファイル、または描きたい内容>`）

Mermaid のテキストを、ヘッドレスブラウザなしで SVG に描画する。`beautiful-mermaid`（純 JavaScript）を使うため Chrome の導入が要らず、`mermaid-cli` より軽い。

> 出典: [imxv/Pretty-mermaid-skills](https://github.com/imxv/Pretty-mermaid-skills)（MIT License、`LICENSE` 参照）。スクリプトの改変・`scripts/flatten.mjs` の追加・`references/` の書き直しを行った。詳細は末尾「原典からの改変点」。

---

## 日本語で使うときの制約【必ず先に読む】

2026-08-19 に `beautiful-mermaid@0.1.3` で実測して確定した事項。1・2・4・5 は**守らないと成果物が壊れる**。3 は品質上の目安。

| # | 制約 | 回避策 |
|---|---|---|
| 1 | 生成 SVG が **Google Fonts へ `@import` する**（外部リクエスト）。CSP 環境・オフラインでは失敗する | `scripts/flatten.mjs` を通す（下記 Step 4） |
| 2 | 生成 SVG が **CSS カスタムプロパティと `color-mix()`** に依存する。これらを解釈しないレンダラー（Word・PowerPoint の SVG 取り込み、PyMuPDF・librsvg 等の変換ツール）では**全ノードが黒く潰れる** | 同上 |
| 3 | ノード枠の幅が **欧文字幅（1 文字 ≒ 0.55em）** で計算される。全角は 1.0em 必要なため、**全角 6 文字以上でラベルが枠幅を超える**（実害は軽微。下記参照） | ノードラベルは**全角 5 文字以内が目安**。超えても直ちに不可ではない |
| 4 | **ASCII 出力（`--format ascii`）は全角を半角 1 文字幅として数える**ため、日本語では罫線が崩れて読めない | 日本語を含む図で ASCII 出力を使わない |
| 5 | ER 図の関連ラベルに引用符を付けると、**引用符ごと描画される**（`"発注する"`）。標準 Mermaid と異なる | 引用符を付けずに `CUSTOMER \|\|--o{ ORDER : 発注する` と書く |

制約 3 の実測値（`--theme github-light` / ノードの `font-size` 13）:

| 全角文字数 | 必要幅 | 枠幅 | 片側余白 |
|---|---|---|---|
| 4 | 52.0px | 60.6px | +4.3px |
| 5 | 65.0px | 67.8px | +1.4px |
| **6** | 78.0px | 74.9px | **−1.5px** |
| 8 | 104.0px | 89.2px | −7.4px |

枠幅は `32 + 7.15 × 文字数` で決まる。7.15px は欧文の平均字幅で、全角の 13px との差が文字数に比例して開く。

**ただしブラウザでの実際の見え方は「ぎりぎり収まっている」程度**で、判読性は損なわれない（2026-08-19 にユーザーが Chrome で確認。8 文字の「受注データベース」でも可読）。数値上の超過は文字の外形ではなく字送りの計算差によるもので、グリフの実体は枠内に近い位置に収まる。

したがって全角 5 文字は**推奨であって禁止ではない**。8 文字を超えるあたりから余白が明らかに詰まるため、そこを目安に語を削るか図を分割する。枠の余白を厳密に揃えたい納品物では 5 文字以内に収める。

---

## 使いどころ — 他スキルとの棲み分け（先に確認する）

このスキルは**既にある Mermaid のテキストを画像化する**のが仕事で、図をゼロから設計するスキルではない。

| やりたいこと | 使うもの |
|---|---|
| `design/` の Markdown 正本に書いた Mermaid を、`dist/` の Word・PDF に**画像として載せる** | **本スキル** |
| 図を**新規に設計**して単体の HTML として作る（構成図・ガント・データ可視化） | `/visual-doc` |
| 解説文書まるごとを HTML で作る | `/explainer-html` |
| Artifact として共有する | Artifact は Mermaid をそのまま描画するため**変換不要**。```mermaid フェンスをそのまま書く |
| 設計書に書く Mermaid の**記法の約束**（`<br/>` 禁止・方向・用語） | `.claude/rules/design-docs.md`「Mermaid 図の記述規約」 |
| ER 図・工程表そのものの設計 | `data-modeler` エージェント / `/visual-doc timeline` |
| **サービス・製品のアイコン／ロゴを入れた図** | **`/drawio` または `/visual-doc`**。Mermaid は任意の画像アイコンを扱えず、本スキルの `beautiful-mermaid` でも同様（**未検証だが対応の記載がない**）。アイコンが要件なら Mermaid を選ばない |

**`design/` では Markdown が正本である**（`.claude/rules/design-docs.md`）。本スキルが生成する SVG は**派生物**であり、正本の Mermaid コードブロックを SVG に置き換えてはならない。正本には Mermaid を残し、SVG は納品物の生成過程で作る。

---

## 前提ツール（初回のみユーザーによる導入が必要）

- **Node.js**（`~/.claude/CLAUDE.md`「端末環境」に記録あり。Volta 管理のためバージョンは固定値として扱わない）
- **`beautiful-mermaid`**（MIT / lukilabs）— スキルディレクトリにローカル導入する

【要指示】初回は次のコマンドを**ユーザー自身が実行する**。スクリプトは依存が見つからない場合、自動インストールせずこの手順を表示して終了する（`.claude/rules/external-resources.md`「ツールのインストールは無断で実行しない」）。

```sh
cd .claude/skills/pretty-mermaid && npm install
```

生成される `node_modules/` はリポジトリの `.gitignore` で除外済み。

> **バージョンを上げない。** `package.json` は `beautiful-mermaid@^0.1.3`（0.1.x）を指す。1.x は export 名が `renderMermaid` → `renderMermaidSVG`、`renderMermaidAscii` → `renderMermaidASCII` に変わり、テーマの渡し方も変わっているため、**そのままでは動かない**。1.x に上げる場合は `scripts/*.mjs` の書き換えとテストが必要。

---

## 実行手順

### Step 1: 入力の確定

対象が `.mmd` ファイルならそのまま使う。Markdown 中の ```mermaid コードブロックや、チャットで渡された Mermaid コードの場合は、作業用の `.mmd` ファイルに切り出す。切り出し先は作業用の `wip/` かスクラッチパッドとし、`design/` や `report/` に中間ファイルを置かない。

図の内容を新規に考える場合は、先に `references/DIAGRAM_TYPES.md` で図種別を選び、`.claude/rules/design-docs.md` の記述規約に従って Mermaid を書く。**このとき上記「日本語で使うときの制約」の 3・5 をラベル設計に織り込む**（ノードラベルは全角 5 文字以内が目安・ER の関連ラベルは引用符なし）。

### Step 2: テーマを決める

| 出力先 | テーマ |
|---|---|
| `dist/` の Word・PowerPoint・PDF（納品物） | `github-light` |
| `design/` の設計書に添える補助図 | `github-light` |
| `report/` の HTML レポート | `github-light` または `tokyo-night` |

**印刷・納品物ではダークテーマを使わない。** 背景の塗りつぶしがそのまま印刷される。テーマは 14 種（`zinc-light` は存在しない）。一覧と実測値は `references/THEMES.md`。

### Step 3: 描画する

```sh
node .claude/skills/pretty-mermaid/scripts/render.mjs \
  --input <入力>.mmd \
  --output <出力>.svg \
  --theme github-light
```

ディレクトリごと一括で描く場合:

```sh
node .claude/skills/pretty-mermaid/scripts/batch.mjs \
  --input-dir <入力ディレクトリ> \
  --output-dir <出力ディレクトリ> \
  --format svg --theme github-light --workers 4
```

テーマの一覧は `node .claude/skills/pretty-mermaid/scripts/themes.mjs`。

> `render.mjs` の `--font` は使わない。指定した名前を Google Fonts の `@import` URL に埋めるだけで、`Yu Gothic UI` のようなシステムフォントは Google Fonts に存在せず、リクエストが失敗して `system-ui` にフォールバックする。**フォント指定は次の Step 4 で行う。**

### Step 4: 自己完結 SVG に変換する【必須】

Step 3 の出力をそのまま使ってはならない。制約 1・2 のため、外部リクエストを含み、限定的なレンダラーでは黒く潰れる。

```sh
node .claude/skills/pretty-mermaid/scripts/flatten.mjs \
  --input <出力>.svg \
  --output <最終>.svg
```

これで次が行われる。

- CSS カスタムプロパティと `color-mix()` を実際の色（`#RRGGBB`）に展開する
- Google Fonts への `@import` を含む `<style>` ブロックを除去する
- 和文対応のフォントスタックを各 `<text>` の属性として埋め込む（既定は Yu Gothic UI → Yu Gothic → Hiragino → Noto Sans JP → Meiryo → system-ui）
- 背景色を明示的な矩形として挿入する

フォントを変えたい場合は `--font "<フォントスタック>"`、背景を透過のままにしたい場合は `--no-background` を付ける。未解決の変数が残った場合は件数を表示して exit 1 になるので、その場合は報告する。

### Step 5: Word / PowerPoint に載せる場合は PNG 化する【必須】

**`dist/` の納品物に図を載せる場合、SVG のまま `/office-pandoc` に渡してはならない。**

pandoc が SVG を docx / pptx に埋め込むにはラスタのフォールバック画像を作るため `rsvg-convert` が必要で、この端末には導入されていない。未導入のまま実行すると `Could not convert image` と警告しつつ **exit 0 で完了し**、`<a:blip>` にラスタ参照（`r:embed`）を持たない図が docx に入る（`asvg:svgBlip` 拡張のみを持つ形）。

**この docx を Word で開くと図は表示される**（2026-08-19 にユーザーが実機確認）。それでも PNG 化を必須とするのは次の理由による。

- **ラスタのフォールバックが無い**ため、SVG 拡張に対応しないビューア・古い Office・PDF への変換経路で図が失われうる（どの経路で失われるかは未検証）
- pandoc が毎回 `Could not convert image` を警告するため、**本物の変換失敗を見落とす**
- PNG なら経路を問わず表示される

PNG に変換してから Markdown に貼れば、この経路を丸ごと回避できる。

```sh
node .claude/skills/pretty-mermaid/scripts/rasterize.mjs \
  --input <最終>.svg --output <図>.png --scale 3
```

インストール済みの Chrome / Edge をヘッドレスで使う（追加パッケージの導入は不要。外部通信は `--host-resolver-rules` で遮断した状態で実行する）。`--scale` は解像度の倍率で、印刷用は 3 以上を推奨する。

**簡易レンダラーでラスタライズしない。** PyMuPDF・cairosvg 等は和文グリフの一部（長音符 `ー` など）を落とす。ヘッドレスブラウザはシステムの日本語フォントで正しく描画することを実測で確認している。

納品経路の全体像:

```
design/ の Markdown 正本（Mermaid のまま残す）
  → render.mjs    → 素の SVG（外部参照あり・CSS 変数依存）
  → flatten.mjs   → 自己完結 SVG（report/ の HTML に貼るならここまで）
  → rasterize.mjs → PNG
  → 納品用 Markdown に ![図1 〜](図.png) として貼る
  → /office-pandoc → dist/ の docx / pptx
```

docx / pptx を生成したら、`office-pandoc` の規約どおり pandoc とは別ツール（anydoc。未導入時は anytomd、それも無ければ markitdown）での往復検証を行う。**画像を含む文書では本文文字数比が下振れするが、これは pandoc が画像の下にキャプション段落を追加し、代替テキストとキャプションが二重に数えられるためで、内容の欠落ではない**（実測で比 0.62・欠落なしを確認）。見出し数・表の行数が一致していれば問題ない。

### Step 6: 検証

**生成した SVG は必ず確認する。**

```sh
grep -c "googleapis\|var(--\|color-mix" <最終>.svg   # 0 であること
```

見た目の確認は次のいずれかで行う。

- `report/` 配下の HTML に埋めてブラウザで開く
- `rasterize.mjs` で PNG にして Read ツールで開く（推奨。実ブラウザ描画なので見た目が一致する）
- PyMuPDF（`fitz.open("x.svg")` → `get_pixmap()`）でも PNG 化できるが、**CSS 変数を解釈せず全ノードが黒く潰れ、和文グリフの一部（長音符 `ー` 等）も落とす**。切り分け用途に留める

確認したのが SVG のソースだけなのか、描画結果まで見たのかを区別して報告する。見ていない場合は「未検証」と明記する（`.claude/rules/code-quality.md`「完了の証拠主義」）。

### Step 7: 後片付け

作業用の `.mmd`、Step 3 の中間 SVG、比較用に作った複数テーマの SVG は、採用を決めた時点で片付ける。**削除の前に対象一覧をユーザーに提示して確認を得る**（`.claude/rules/safe-file-ops.md`）。

---

## 描画できない図種別

`beautiful-mermaid@0.1.3` が対応するのは **flowchart / sequenceDiagram / stateDiagram-v2 / classDiagram / erDiagram の 5 種のみ**。gantt・pie・journey・mindmap・timeline・quadrantChart 等はパースに失敗する。

- 工程表・ガントチャート → `/visual-doc timeline`
- 円グラフ・棒グラフ等のデータ可視化 → `/visual-doc dashboard`

---

## 完了条件

- 最終 SVG に `googleapis` / `var(--` / `color-mix` が 1 件も残っていない（`flatten.mjs` を通した）
- 納品物（`dist/`）に載せる場合は `rasterize.mjs` で PNG 化し、SVG のまま pandoc に渡していない
- 日本語のノードラベルが長すぎないか確認した（全角 5 文字以内が目安。超える場合は描画結果で判読性を確認する）
- ER 図の関連ラベルに引用符を付けていない
- `design/` 配下の Markdown 正本の Mermaid コードブロックを削除・置換していない
- 描画結果を確認したか、「未検証」と明記している
- 中間ファイルの削除はユーザーの確認後に行っている

---

## 原典からの改変点

| # | 改変 | 理由 |
|---|---|---|
| 1 | `render.mjs`・`batch.mjs`・`themes.mjs` から `npm install` の自動実行（`execSync`）を削除し、未導入時は手順を表示して終了する形に変更 | `.claude/rules/external-resources.md`【要指示】「ツールのインストールは無断で実行しない」に抵触するため |
| 2 | **`scripts/flatten.mjs` を新規追加**（原典にない） | 生成 SVG が Google Fonts へ外部リクエストし、CSS 変数と `color-mix()` に依存するため。そのままでは Word・PowerPoint 取り込みで黒く潰れ、CSP 環境でも失敗する |
| 2b | **`scripts/rasterize.mjs` を新規追加**（原典にない） | pandoc は `rsvg-convert` なしで SVG をラスタ化できず、警告のみで exit 0 のままラスタ参照を持たない図を docx に埋め込むため。納品経路では PNG を渡す |
| 3 | `references/THEMES.md` を日本語で書き直し、テーマ数を 15 → **14** に訂正、前景色の値を実測値に修正、コマンド例を実在する `node scripts/render.mjs` に修正 | 原典は中国語で、実在しない `zinc-light` を掲載し、複数テーマで `accent` の値を `fg` として記載し、存在しない `python render_mermaid.py` を例示していた |
| 4 | `references/DIAGRAM_TYPES.md` を日本語化し、存在しない `monokai` の推奨を削除。対応 5 図種以外は描画できない旨を追記 | 誤解防止のため |
| 5 | `references/api_reference.md` を取り込まない | スキルテンプレートの雛形が未記入のまま残ったファイルで、内容が無関係だったため |
| 6 | ASCII 出力を推奨から外した | 全角を半角 1 文字幅として数えるため、日本語では罫線が崩れる（実測） |
| 7 | 日本語ラベルの幅の目安・ER 関連ラベルの引用符・`--font` の実挙動を明文化 | いずれも実測で確認した、原典に記載のない日本語環境固有の挙動のため |
| 8 | 出力先・テーマ選択を本リポジトリの規約に合わせて再構成し、後片付けを「確認してから削除」に変更 | `.claude/rules/design-docs.md` / `safe-file-ops.md` との整合 |
| 9 | Step 5 の往復検証の読み戻し順を、anydoc → anytomd → markitdown に更新（2026-10-21。この一文は本リポジトリの追記で原典に無い） | `office-pandoc`・`verify_conversion.py` が anytomd を読み戻しに加えたため（ADR-063・ADR-064） |

---

## 関連

- 図種別の記法: `references/DIAGRAM_TYPES.md`
- テーマ一覧: `references/THEMES.md`
- 図のテンプレート: `assets/example_diagrams/*.mmd`
- 設計書での Mermaid 記述規約: `.claude/rules/design-docs.md`
- 図の新規設計: `/visual-doc`
- Markdown → Word / PowerPoint 変換: `/office-pandoc`
