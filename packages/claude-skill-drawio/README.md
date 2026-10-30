# /drawio

顧客が編集できる .drawio 図（UML・ER・BPMN・C4・クラウド構成等）を生成する。「draw.io の図を作って」「編集できる構成図が欲しい」で自動適用。/drawio <対象>。Mermaid の画像化は pretty-mermaid。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/drawio/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | Agents365-ai/drawio-skill v2.1.1, MIT（図形インデックスは jgraph/drawio-mcp 由来 Apache-2.0） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

顧客・保守担当が後から編集できる `.drawio` を生成・逆生成・変換する（UML / ER / BPMN / C4 / クラウド構成ほか）

## なぜ作られたか

原典一式を `upstream/` に無改変同梱（ADR-026）。**取り込み時点でスクリプトの実行確認は未実施であり、2 度の検証 ADR が続いた**: ADR-027 で 38 本の起動確認と主要経路を検証、ADR-028 で前提ツール（Graphviz 16.0.0・draw.io Desktop 31.1.8）を winget 導入して全区分を検証。**Windows では 2 点の準備が要る**（どちらも PATH 未登録／スクリプトがバイナリ名 `drawio` をハードコードしているため `drawio.exe` のハードリンクが必要）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/drawio .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/drawio/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/drawio` での呼び出しもできない。

## 使い方

`/drawio` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/drawio/LICENSE`（1.1 KB）
- `skills/drawio/SKILL.md`（19.3 KB）
- `skills/drawio/upstream/SKILL.md`（42.6 KB）
- `skills/drawio/upstream/data/SHAPE-INDEX-NOTICE.md`（897 B）
- `skills/drawio/upstream/data/lobe-icons.json`（13.5 KB）
- `skills/drawio/upstream/data/shape-index.json.gz`（425.9 KB）
- `skills/drawio/upstream/references/autolayout.md`（19.0 KB）
- `skills/drawio/upstream/references/derasterize.md`（2.5 KB）
- `skills/drawio/upstream/references/diagram-types.md`（16.5 KB）
- `skills/drawio/upstream/references/live-infra.md`（3.7 KB）
- `skills/drawio/upstream/references/mermaid-authoring.md`（4.9 KB）
- `skills/drawio/upstream/references/pr-bot.md`（3.5 KB）
- `skills/drawio/upstream/references/shapes.md`（7.1 KB）
- `skills/drawio/upstream/references/style-extraction.md`（17.4 KB）
- `skills/drawio/upstream/references/style-presets.md`（10.9 KB）
- `skills/drawio/upstream/references/toolbox.md`（9.0 KB）
- `skills/drawio/upstream/references/troubleshooting.md`（5.2 KB）
- `skills/drawio/upstream/references/tubemap.md`（3.3 KB）
- `skills/drawio/upstream/references/xml-authoring.md`（12.5 KB）
- `skills/drawio/upstream/scripts/aiicons.py`（8.0 KB）
- `skills/drawio/upstream/scripts/autolayout.py`（18.3 KB）
- `skills/drawio/upstream/scripts/buildup.py`（14.4 KB）
- `skills/drawio/upstream/scripts/c4.py`（6.7 KB）
- `skills/drawio/upstream/scripts/ciimports.py`（7.8 KB）
- `skills/drawio/upstream/scripts/composeimports.py`（4.7 KB）
- `skills/drawio/upstream/scripts/compress.py`（10.6 KB）
- `skills/drawio/upstream/scripts/dockerimports.py`（6.4 KB）
- `skills/drawio/upstream/scripts/drawio2mermaid.py`（6.0 KB）
- `skills/drawio/upstream/scripts/drawio2pptx.py`（4.5 KB）
- `skills/drawio/upstream/scripts/drawiodiff.py`（7.2 KB）
- `skills/drawio/upstream/scripts/drawiohtml.py`（10.5 KB）
- `skills/drawio/upstream/scripts/edgeports.py`（9.3 KB）
- `skills/drawio/upstream/scripts/encode_drawio_url.py`（2.3 KB）
- `skills/drawio/upstream/scripts/explain.py`（6.1 KB）
- `skills/drawio/upstream/scripts/goimports.py`（5.6 KB）
- `skills/drawio/upstream/scripts/heatmap.py`（9.2 KB）
- `skills/drawio/upstream/scripts/jsimports.py`（6.4 KB）
- `skills/drawio/upstream/scripts/k8simports.py`（9.8 KB）
- `skills/drawio/upstream/scripts/openapiimports.py`（6.8 KB）
- `skills/drawio/upstream/scripts/prdiff.py`（8.0 KB）
- `skills/drawio/upstream/scripts/pyclasses.py`（6.3 KB）
- `skills/drawio/upstream/scripts/pyimports.py`（6.4 KB）
- `skills/drawio/upstream/scripts/raster2drawio.py`（7.5 KB）
- `skills/drawio/upstream/scripts/relabel.py`（4.2 KB）
- `skills/drawio/upstream/scripts/repair_png.py`（1.1 KB）
- `skills/drawio/upstream/scripts/restyle.py`（7.2 KB）
- `skills/drawio/upstream/scripts/runbook.py`（10.2 KB）
- `skills/drawio/upstream/scripts/rustimports.py`（7.7 KB）
- `skills/drawio/upstream/scripts/seqlayout.py`（9.9 KB）
- `skills/drawio/upstream/scripts/shapesearch.py`（6.0 KB）
- `skills/drawio/upstream/scripts/sqlerd.py`（6.8 KB）
- `skills/drawio/upstream/scripts/svgflow.py`（3.8 KB）
- `skills/drawio/upstream/scripts/tfimports.py`（11.9 KB）
- `skills/drawio/upstream/scripts/tfstate.py`（5.6 KB）
- `skills/drawio/upstream/scripts/timelapse.py`（11.3 KB）
- `skills/drawio/upstream/scripts/tubemap.py`（7.0 KB）
- `skills/drawio/upstream/scripts/validate.py`（13.4 KB）
- `skills/drawio/upstream/styles/built-in/colorblind-safe.json`（1.5 KB）
- `skills/drawio/upstream/styles/built-in/corporate.json`（1.5 KB）
- `skills/drawio/upstream/styles/built-in/dark.json`（1.6 KB）
- `skills/drawio/upstream/styles/built-in/default.json`（1.5 KB）
- `skills/drawio/upstream/styles/built-in/handdrawn.json`（1.5 KB）
- `skills/drawio/upstream/styles/schema.json`（5.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/db-review` `/explainer-html` `/office-pandoc` `/pretty-mermaid` `/slides-maker` `/tool-environment` `/visual-doc`

## ライセンス

同梱の `skills/drawio/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: Agents365-ai/drawio-skill v2.1.1, MIT（図形インデックスは jgraph/drawio-mcp 由来 Apache-2.0）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
