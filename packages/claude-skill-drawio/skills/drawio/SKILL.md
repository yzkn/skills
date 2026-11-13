---
name: drawio
description: "顧客が編集できる .drawio 図（UML・ER・BPMN・C4・クラウド構成等）を生成する。「draw.io の図を作って」「編集できる構成図が欲しい」で自動適用。/drawio <対象>。Mermaid の画像化は pretty-mermaid。"
license: MIT
---

# /drawio スキル — 編集可能な .drawio 図の生成

**引数:** `$ARGUMENTS`（`<描きたい図の内容、または入力ファイル（.tf / manifest / .yaml / .sql / ソースディレクトリ / 既存の .drawio）>`）

`.drawio`（diagrams.net）形式の図を XML として生成する。**成果物を顧客が draw.io で開いて自分で直せる**ことが本スキルの価値であり、画像だけを納める用途では他のスキルの方が軽い。

> 出典: [Agents365-ai/drawio-skill](https://github.com/Agents365-ai/drawio-skill) v2.1.1（MIT License、`LICENSE` 参照）。**原典一式を `upstream/` に無改変で同梱**しており、本ファイルは本キット向けの入口（前提ツールの可否・外部送信の統制・成果物の置き場所・関連スキルとの使い分け）のみを定義する。手順の詳細は `upstream/SKILL.md` と `upstream/references/*` を Read する。
>
> 同梱データの帰属: `upstream/data/shape-index.json.gz` は [jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp) 由来の図形検索インデックス（Apache License 2.0。10,446 図形）。詳細は `upstream/data/SHAPE-INDEX-NOTICE.md`。

---

## 使い分け【最初に判断する】

| 作りたいもの | 使うもの |
|---|---|
| **顧客・保守担当が後から編集する図**（納品する構成図・業務フロー・ER 図） | **本スキル**（`.drawio` が正本の編集可能ファイル） |
| Markdown 正本に書いた Mermaid を Word・PDF に載せる画像 | `/pretty-mermaid`（Mermaid → SVG/PNG） |
| 自己完結 HTML の図を新規設計する（インライン SVG・ライト/ダーク対応） | `/visual-doc` |
| 概念・仕組みを説明する HTML 文書まるごと | `/explainer-html` |
| スライド | `/slides-maker`・`/office-pandoc` |

`design/` 配下では **Markdown が正本**である（`.claude/rules/design-docs.md`）。`.drawio` を置く場合も、図が表す情報は Markdown 側に文章・表として残す。`.drawio` から書き出した PNG / SVG / PDF は派生物として扱う（`dist/` は git 管理外・直接編集禁止）。

---

## 前提ツールと使える機能【重要・実行前に必ず確認】

2026-08-25 に**同梱スクリプトを実際に実行して**確認した（38 本の起動確認と、下表の全区分の実行。結果は本ファイル末尾「検証記録」）。**未導入のツールを勝手に入れない**（`.claude/rules/external-resources.md`【要指示】）。

### 前提ツール

| ツール | 何に要るか | 検証環境（Windows 11）での状態 |
|---|---|---|
| Python 3.14 ＋ PyYAML | 全スクリプトの実行基盤 | 導入済み（PyYAML 6.0.3。`ciimports` / `k8simports` が使う） |
| Graphviz（`dot`・`tred`） | 自動レイアウト・C4・要約・依存グラフの推移的削減 | **導入済み 16.0.0**（winget `Graphviz.Graphviz`）。**既定の `C:\Program Files\Graphviz\bin` は PATH 未登録**のため実行時に通す |
| draw.io Desktop CLI | 画像・PDF 書き出し、HTML ビューア、PPTX、Mermaid→`.drawio` 変換 | **導入済み 31.1.8**（winget `JGraph.Draw`）。`%LOCALAPPDATA%\Programs\draw.io\draw.io.exe` に入り **PATH 未登録**。さらに**スクリプトはバイナリ名 `drawio` をハードコード**しているため、Windows の `draw.io.exe` のままでは解決できない（下記のシムが必要） |

**Windows での実行前の準備**（毎回のコマンドで PATH を通す。恒久設定はユーザーの判断に委ねる）:

```sh
export PATH="$PATH:$LOCALAPPDATA/Programs/draw.io:/c/Program Files/Graphviz/bin"
```

`drawio.exe` のシムは同一ディレクトリへのハードリンクで作る（管理者権限不要・ディスク消費なし。Electron がリソースを実行ファイルと同じ場所から解決するため、**別の場所にコピーしてはならない**）。PowerShell で 1 回だけ実行する。

```powershell
$d = Join-Path $env:LOCALAPPDATA 'Programs\draw.io'
New-Item -ItemType HardLink -Path (Join-Path $d 'drawio.exe') -Value (Join-Path $d 'draw.io.exe')
```

**別端末では必ず再確認する**（導入状況・パスは端末依存。手順は `/tool-environment`）。未導入時の失敗の出方は、Graphviz が 1 行のエラー、draw.io CLI が Python のトレースバック（`FileNotFoundError: [WinError 2]`）で、**いずれも前提不足であって図データの不具合ではない**。トレースバックを見てもデバッグに入らない。

### 機能の区分

| 区分 | 機能 | 追加の前提 |
|---|---|---|
| **A. Python だけで完結** | `.drawio` XML の手書き、構造 lint（`validate` / `--score`）、説明文生成（`explain`）、Mermaid への変換（`drawio2mermaid`）、ラベル一括差し替え（`relabel`）、再テーマ（`restyle`）、メトリクス色分け（`heatmap`）、**シーケンス図（`seqlayout`）**、**メトロマップ（`tubemap`）**、画像からの再構成（`raster2drawio`）、図形検索（`shapesearch`）、エッジのポート整列（`edgeports`）、クリック式ランブック（`runbook`）、2 図の差分（`drawiodiff`）、各種インポータの**グラフ JSON 出力**（`tfimports` / `k8simports` / `composeimports` / `sqlerd` / `openapiimports` / `pyimports` / `pyclasses` / `jsimports` / `goimports` / `rustimports` / `ciimports`）、URL エンコード（`encode_drawio_url`） | なし |
| **B. Graphviz が要る** | 自動レイアウト（`autolayout`）、**C4 モデル（`c4`）**、大図の要約（`compress`）、**A のインポータが出したグラフ JSON の `.drawio` 化**、`pyimports` 等の推移的削減（`tred`。無い場合は警告を出して全エッジを残す） | `dot` / `tred` |
| **C. draw.io CLI が要る** | PNG / SVG / PDF / JPG 書き出し、対話 HTML ビューア（`drawiohtml`）、PPTX 化（`drawio2pptx`）、アニメ SVG（`svgflow`）、構築アニメ（`buildup`）、git 履歴のタイムラプス（`timelapse`）、PR 図レビュー（`prdiff`）、**Mermaid テキスト →`.drawio` 変換**（CLI v30 以上） | `drawio`（シム必須） |
| **D. 【要指示】外部取得を伴う** | `aiicons.py` のみ（AI ベンダーのロゴを unpkg / simpleicons の CDN から取得する。**実行前に送信先 URL・取得内容・目的を提示して確認を得る**。`.claude/rules/external-resources.md`「外部送信の抑制」） | ネットワーク |
| **E. 【要指示】稼働環境の状態を読む** | `tfstate`（`terraform show -json`）、`dockerimports`（`docker inspect` → **本端末では `podman inspect` に読み替える。出力形式に互換性があることを実機確認済み**）、`k8simports -`（`kubectl get -o json`）。手順は `upstream/references/live-infra.md` | 各 CLI と認証済みの接続先 |

- **`encode_drawio_url.py` は外部送信しない**（`urllib.parse` だけを使い、図を圧縮して URL 文字列を作るだけ）。ただし**生成された URL を開けば図の内容が diagrams.net に渡る**ため、ユーザーに提示するときは必ずその旨を添える
- 区分 E で本番環境（`production` / `prod` / `prd` を含む接続先）を対象にする場合は実行前に確認する（`.claude/rules/environment-safety.md`）

---

## 実行手順

1. **要件を 1〜3 問で確定する**（不足がある場合のみ）— 図の種類（ER / UML / シーケンス / BPMN / スイムレーン / ネットワーク / クラウド構成 / C4 / フローチャート）、出力先パス、規模（コンポーネント数）、書き出し形式の要否
2. **`upstream/SKILL.md` を Read する** — 生成手順の正本。図種別ごとの作法は `upstream/references/diagram-types.md`、XML の手書き規則（骨格・セル・コンテナ・余白）は `upstream/references/xml-authoring.md`、どのスクリプトを使うかの索引は `upstream/references/toolbox.md`
3. **生成する** — 入力に応じて経路を選ぶ（いずれも実行確認済み）。
   - **既存の資材があるならインポータ → `autolayout.py`**。Terraform / Kubernetes / docker-compose / SQL DDL / OpenAPI / GitHub Actions / Python・JS・Go・Rust のソースから**グラフ JSON を経由して `.drawio` になる**。インポータ単体では `graph.json` で止まるので、必ず `autolayout.py` まで通す
   - **シーケンス図は `seqlayout.py`、メトロマップは `tubemap.py`、C4 は `c4.py`、画像の再構成は `raster2drawio.py`**（`raster2drawio` の graph JSON は **`edges` のキーが `source` / `target`**。`from` / `to` では通らない。スキーマは `upstream/references/derasterize.md`）
   - **それ以外は `xml-authoring.md` に従って XML を手書きする**（骨格・セル・コンテナ・余白の規則）
   - **図形・アイコンが要る場合は draw.io 内蔵の `shapesearch.py`（10,446 図形・ベクター・取得不要）で探す。** 外部のアイコン画像を使う場合は、ライセンスが permissive であることを確認し、**納品物では data URI で埋め込む**（URL 参照のままだと顧客環境・オフラインで画像が出ない）。`image=` の data URI に `;base64,` を付けないこと（`.claude/rules/third-party-licenses.md`）
   - **15 ノードを超える図を座標手打ちで作らない**。グラフ JSON を書いて `autolayout.py` に置く（`--tune` で方向を自動選択）
   - 標準的な図で装飾が不要なら、**Mermaid テキストを書いて CLI に変換させる**のも速い（`drawio -x -f xml -o out.drawio in.mmd`。日本語ラベルで動作確認済み）
4. **`validate.py` で構造 lint をかける** — 宛先のないエッジ・ID 重複・親子関係の破損・重なりを検出する。`--score` で可読性スコアを出せる
5. **プレビュー PNG を書き出して自分で見る** — `drawio -x -f png --width 2000 -o <名前>.png <名前>.drawio` を実行し、**生成した PNG を Read して崩れを確認してから**ユーザーに出す（ラベルのはみ出し・線の重なり・意図しない重複はここでしか分からない）。**この段階で `-e` を付けない**（埋め込まれた XML のチャンクで画像の読み取りが失敗する）。幅は 2000 程度に抑える（画像読み取りの上限 2576px を超えないため）
6. **提示・納品する** — 用途で形式を選ぶ。
   - **編集させるなら `.drawio` のまま**（＋ `explain.py` の Markdown を添えると差分レビューが楽になる）
   - **Word・PDF に貼るなら PNG か PDF**。`-e` を付けて書き出すと**画像の中に図の XML が入り、draw.io で開き直して編集できる**（`name.drawio.png` のように二重拡張子にする。書き出し後に `repair_png.py` を通す）
   - **スライドにするなら `drawio2pptx.py`**（ページごとに 16:9 スライド 1 枚。多ページの C4 がそのまま説明資料になる）
   - **配布して眺めてもらうだけなら `drawiohtml.py`**（1 ファイルで pan / zoom / 検索・ドリルダウン可。外部通信なし）
   - 書き出しができない環境では `.drawio` と `explain.py` の説明をセットで渡し、**レイアウト未確認である旨を明記する**

**スクリプトの呼び出し方（この端末）:**

```
python .claude/skills/drawio/upstream/scripts/validate.py <対象>.drawio
```

- 原典のドキュメントは `python3` と書かれているが、**この端末では `python`** を使う（`~/.claude/CLAUDE.md`「端末環境」）
- **ファイル出力に `PYTHONUTF8=1` は不要**（各スクリプトが `encoding="utf-8"` を明示しており、付けた場合と付けない場合の出力バイト列が完全一致することを確認した）。**必要なのは標準出力を読むときだけ**で、日本語を含む実行結果（`explain.py` の画面出力・`shapesearch.py` の図形名など）はコンソールが cp932 のため付けないと文字化けする
- 原典が `<this-skill-dir>` と書いている箇所は `.claude/skills/drawio/upstream/` に読み替える

---

## 日本語で使うときの注意

原典は英語圏の利用を前提にしているが、**日本語で不利になる点は見つからなかった**（下記はすべて実測）。

- **全角ラベルの枠幅は問題ない。** 12 文字の「アプリケーションサーバー」が 200px 幅の枠に、8 文字の「受注データベース」がシリンダ図形に収まって描画されることを、書き出した PNG を読んで確認した。**`/pretty-mermaid` にある「全角 5 文字以内」の制約はこのスキルには当てはまらない**（draw.io は文字幅を実測して配置するため）。`seqlayout.py` が座標を計算するシーケンス図でも、参加者名・メッセージ文が枠と矢印に収まる
- 日本語は全経路で保持される（`.drawio` の `value` 属性・`explain.py` の Markdown・`drawio2mermaid.py` の Mermaid・`relabel.py` の抽出 JSON・Mermaid からの変換）。**日本語ファイル名・空白を含む出力パスも通る**
- **`relabel.py` は日英の入れ替えに使える**。`--extract` でラベルを恒等マップの JSON に落とし、値だけを書き換えて `--map` で戻す。レイアウト・スタイル・ID は変わらないため、図を作り直すより安全
- 書き出した SVG のフォントは**既定で埋め込まれる**（CLI の `--embed-svg-fonts` が既定 true）。`/pretty-mermaid` のように外部フォントを取りに行くことはない
- `heatmap.py` の凡例セルは負座標（x=−90）に置かれ、生成物を `validate.py` にかけると warning が 1 件出る。**図としては壊れていない**ので既知として扱う（原典の挙動・無改変で同梱）
- `upstream/references/*` は英語のまま同梱している（原典無改変の方針）。翻訳せずに読む

---

## 成果物の置き場所

| 図の種類 | 置き場所 |
|---|---|
| システム構成図・方式設計の図 | `design/03_basic_design/diagrams/` |
| ER 図・クラス図・シーケンス図・API 図 | `design/04_detailed_design/diagrams/` |
| 業務フロー・BPMN・スイムレーン | `design/02_requirements/diagrams/`（要件）または `03_basic_design/diagrams/` |
| 移行方式・切替手順の図 | `design/07_migration/` |
| 運用フロー・ランブック | `design/08_operations/` |
| 納品用の書き出し（PNG / SVG / PDF / PPTX） | `dist/`（派生物・git 管理外・直接編集禁止） |

- 既存図の更新は上書きではなく、**変更前後を `drawiodiff.py` で比較して差分を提示**してから反映する（`.claude/rules/safe-file-ops.md`「編集後の diff 検証」）
- 図の内容に未確定情報が含まれる場合、Markdown 正本側で `==〜==` を使って明示する（`.claude/rules/design-docs.md`）

---

## 関連

- 図に**顧客名・実在の氏名・メールアドレス・IP アドレス**が入りうる。コミット前に `.claude/rules/git-safety.md`「コミット前の機密情報チェック」を適用する（`.drawio` はテキストなので grep が効く）
- IaC を図にした後のリスク診断は `iac-reviewer` サブエージェント、DB スキーマの設計・レビューは `data-modeler` / `/db-review`
- 図の型と意味色の考え方は `/visual-doc` の `references/diagram_patterns.md` と共通の判断で揃える
- 上流の設計判断（構成の選択そのもの）は `system-architect` サブエージェントに委ねる。本スキルは**決まった構成を描く**役割に限る

---

## 検証記録（Windows 11 / Python 3.14.3 / Graphviz 16.0.0 / draw.io 31.1.8）

上記の区分表の根拠。**同梱の 38 本すべてが import エラーなく起動する**ことを確認したうえで、日本語を含む題材（システム構成図・障害切り分けフロー・受注 DB の DDL・docker-compose・OpenAPI・K8s マニフェスト・GitHub Actions・Python パッケージ・シーケンス JSON・メトロ JSON・メトリクス CSV）で各経路を実行した。2026-08-24 は前提ツール未導入の状態、2026-08-25 は winget で導入した後の再検証。

| 実行した経路 | 結果 |
|---|---|
| 区分 A（14 種） | **全件成功**。生成した `.drawio` は `validate.py` に戻して 0 error（`heatmap.py` の凡例のみ warning 1 件） |
| インポータ 11 種 → `autolayout.py` | **全件成功**（ERD・compose・OpenAPI・K8s・CI・Python の import グラフがいずれも `.drawio` になった）。`--tune` の方向自動選択も動作 |
| `c4.py` | **成功**（2 ページ・ドリルダウンリンク付き。`validate` 0 error） |
| `compress.py` | **成功**（3 ノード → 2 クラスタの要約 2 ページ） |
| PNG（`-e` あり / なし）・SVG・PDF 書き出し | **全件成功**。`--width 2000` 指定で 2000×872px。`-e` 付き PNG には図の XML が埋め込まれ、IEND も正常（`repair_png.py` は v31 では修復対象なしで正常終了） |
| `drawiohtml.py` / `drawio2pptx.py` / `svgflow.py` / `buildup.py`（`--gif` 含む） | **全件成功**。PPTX は 16:9・2 スライド・ページ名がタイトルに入ることを python-pptx で確認。生成 HTML・SVG に**外部リクエストは無い**（含まれる URL は XML 名前空間と FAQ リンクのみ） |
| `timelapse.py` / `prdiff.py` | **成功**（一時 git リポジトリで実行。`prdiff` は base / head / diff の 3 PNG と Markdown レポートを生成） |
| Mermaid テキスト → `.drawio` 変換（CLI v31） | **成功**（日本語ラベルのフローチャート。`validate` 0 error） |
| `raster2drawio.py` | **成功**（ただし `edges` のキーは `source` / `target`。`from` / `to` を渡すと `every edge needs 'source' and 'target'` で停止する） |
| `encode_drawio_url.py` | **成功**（`viewer.diagrams.net` の URL 文字列を出力するだけで、送信は行わない） |
| 区分 E: `tfstate.py` / `k8simports.py -` | 実データ形式を模した入力で**成功**（`autolayout` まで通して `.drawio` 化を確認） |
| 区分 E: `dockerimports.py` | **実際の `podman inspect` 出力で成功**（Docker 互換の形式が受け付けられることを実機確認。検証後にコンテナは削除した） |
| 全角ラベルの描画 | **問題なし**（書き出した PNG を読んで確認。上記「日本語で使うときの注意」） |
| `encode_drawio_url.py` / `repair_png.py` の `--help` | argparse を使わず `sys.argv` を直接読む実装のため `--help` でトレースバックになる（**仕様。不具合ではない**） |

**未検証のまま残っているもの**: `aiicons.py`（区分 D。外部取得のため、送信先を提示して承認を得るまで実行しない）と、実際のクラウド・クラスタに接続した状態での区分 E（模擬入力と podman での確認にとどまる）。
