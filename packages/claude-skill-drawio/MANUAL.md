# /drawio — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・pandoc・Graphviz |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/drawio/LICENSE` | 1.1 KB | ライセンス |
| `skills/drawio/SKILL.md` | 19.3 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/drawio/upstream/SKILL.md` | 42.6 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/drawio/upstream/data/SHAPE-INDEX-NOTICE.md` | 897 B | — |
| `skills/drawio/upstream/data/lobe-icons.json` | 13.5 KB | データ・設定 |
| `skills/drawio/upstream/data/shape-index.json.gz` | 425.9 KB | — |
| `skills/drawio/upstream/references/autolayout.md` | 19.0 KB | — |
| `skills/drawio/upstream/references/derasterize.md` | 2.5 KB | — |
| `skills/drawio/upstream/references/diagram-types.md` | 16.5 KB | — |
| `skills/drawio/upstream/references/live-infra.md` | 3.7 KB | — |
| `skills/drawio/upstream/references/mermaid-authoring.md` | 4.9 KB | — |
| `skills/drawio/upstream/references/pr-bot.md` | 3.5 KB | — |
| `skills/drawio/upstream/references/shapes.md` | 7.1 KB | — |
| `skills/drawio/upstream/references/style-extraction.md` | 17.4 KB | — |
| `skills/drawio/upstream/references/style-presets.md` | 10.9 KB | — |
| `skills/drawio/upstream/references/toolbox.md` | 9.0 KB | — |
| `skills/drawio/upstream/references/troubleshooting.md` | 5.2 KB | — |
| `skills/drawio/upstream/references/tubemap.md` | 3.3 KB | — |
| `skills/drawio/upstream/references/xml-authoring.md` | 12.5 KB | — |
| `skills/drawio/upstream/scripts/aiicons.py` | 8.0 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/autolayout.py` | 18.3 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/buildup.py` | 14.4 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/c4.py` | 6.7 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/ciimports.py` | 7.8 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/composeimports.py` | 4.7 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/compress.py` | 10.6 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/dockerimports.py` | 6.4 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/drawio2mermaid.py` | 6.0 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/drawio2pptx.py` | 4.5 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/drawiodiff.py` | 7.2 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/drawiohtml.py` | 10.5 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/edgeports.py` | 9.3 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/encode_drawio_url.py` | 2.3 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/explain.py` | 6.1 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/goimports.py` | 5.6 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/heatmap.py` | 9.2 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/jsimports.py` | 6.4 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/k8simports.py` | 9.8 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/openapiimports.py` | 6.8 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/prdiff.py` | 8.0 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/pyclasses.py` | 6.3 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/pyimports.py` | 6.4 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/raster2drawio.py` | 7.5 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/relabel.py` | 4.2 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/repair_png.py` | 1.1 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/restyle.py` | 7.2 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/runbook.py` | 10.2 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/rustimports.py` | 7.7 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/seqlayout.py` | 9.9 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/shapesearch.py` | 6.0 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/sqlerd.py` | 6.8 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/svgflow.py` | 3.8 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/tfimports.py` | 11.9 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/tfstate.py` | 5.6 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/timelapse.py` | 11.3 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/tubemap.py` | 7.0 KB | Python スクリプト |
| `skills/drawio/upstream/scripts/validate.py` | 13.4 KB | Python スクリプト |
| `skills/drawio/upstream/styles/built-in/colorblind-safe.json` | 1.5 KB | データ・設定 |
| `skills/drawio/upstream/styles/built-in/corporate.json` | 1.5 KB | データ・設定 |
| `skills/drawio/upstream/styles/built-in/dark.json` | 1.6 KB | データ・設定 |
| `skills/drawio/upstream/styles/built-in/default.json` | 1.5 KB | データ・設定 |
| `skills/drawio/upstream/styles/built-in/handdrawn.json` | 1.5 KB | データ・設定 |
| `skills/drawio/upstream/styles/schema.json` | 5.5 KB | データ・設定 |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/drawio .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/drawio/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/drawio` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/drawio`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/drawio` を名指しする。

## 4. 内容の構成

本体（`skills/drawio/SKILL.md`）の見出し構成:

- 使い分け【最初に判断する】
- 前提ツールと使える機能【重要・実行前に必ず確認】
  - 前提ツール
  - 機能の区分
- 実行手順
- 日本語で使うときの注意
- 成果物の置き場所
- 関連
- 検証記録（Windows 11 / Python 3.14.3 / Graphviz 16.0.0 / draw.io 31.1.8）

## 5. 導入後の検証

```sh
python -m py_compile skills/drawio/upstream/scripts/aiicons.py skills/drawio/upstream/scripts/autolayout.py skills/drawio/upstream/scripts/buildup.py skills/drawio/upstream/scripts/c4.py skills/drawio/upstream/scripts/ciimports.py skills/drawio/upstream/scripts/composeimports.py skills/drawio/upstream/scripts/compress.py skills/drawio/upstream/scripts/dockerimports.py skills/drawio/upstream/scripts/drawio2mermaid.py s
echo "exit=$?"
```
- `/drawio` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/drawio/` |
| 元の格納先 | `.claude/skills/drawio/` |
| 出典 | Agents365-ai/drawio-skill v2.1.1, MIT（図形インデックスは jgraph/drawio-mcp 由来 Apache-2.0） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

原典一式を `upstream/` に無改変同梱（ADR-026）。**取り込み時点でスクリプトの実行確認は未実施であり、2 度の検証 ADR が続いた**: ADR-027 で 38 本の起動確認と主要経路を検証、ADR-028 で前提ツール（Graphviz 16.0.0・draw.io Desktop 31.1.8）を winget 導入して全区分を検証。**Windows では 2 点の準備が要る**（どちらも PATH 未登録／スクリプトがバイナリ名 `drawio` をハードコードしているため `drawio.exe` のハードリンクが必要）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
