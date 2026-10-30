# テーマ一覧（beautiful-mermaid 0.1.3）

`--theme <名前>` で指定する組み込みテーマは **14 種**。各テーマは背景色 `bg` と前景色 `fg` の 2 色を土台にし、テーマによって線色 `line`・強調色 `accent`・淡色 `muted` を追加で持つ。指定しなかった色は `bg` と `fg` から自動導出される。

> 本表の値は `beautiful-mermaid@0.1.3` の `dist/index.js` に定義された `THEMES` から機械的に抽出した実測値。実行時に確認する場合は `node .claude/skills/pretty-mermaid/scripts/themes.mjs`。

## ダークテーマ（10 種）

| テーマ名 | `bg` | `fg` | `accent` | 性格・向いている用途 |
|---|---|---|---|---|
| `tokyo-night` | `#1a1b26` | `#a9b1d6` | `#7aa2f7` | 落ち着いた青系。開発者向けドキュメントの既定候補 |
| `tokyo-night-storm` | `#24283b` | `#a9b1d6` | `#7aa2f7` | `tokyo-night` の背景を明るくした変種 |
| `github-dark` | `#0d1117` | `#e6edf3` | `#4493f8` | GitHub のダーク配色。README・Issue に貼る図向け |
| `dracula` | `#282a36` | `#f8f8f2` | `#bd93f9` | 高コントラスト。紫・ピンク寄りの強調色 |
| `nord` | `#2e3440` | `#d8dee9` | `#88c0d0` | 寒色・低彩度。システム構成図など硬めの資料向け |
| `catppuccin-mocha` | `#1e1e2e` | `#cdd6f4` | `#cba6f7` | 暖かみのある暗色。長時間の閲覧向け |
| `one-dark` | `#282c34` | `#abb2bf` | `#c678dd` | Atom One Dark 配色 |
| `solarized-dark` | `#002b36` | `#839496` | `#268bd2` | 低コントラスト設計。長文中の図向け |
| `zinc-dark` | `#18181B` | `#FAFAFA` | （なし） | 無彩色のみ。色を持たせたくない図向け |

## ライトテーマ（5 種）

| テーマ名 | `bg` | `fg` | `accent` | 性格・向いている用途 |
|---|---|---|---|---|
| `github-light` | `#ffffff` | `#1f2328` | `#0969da` | 白背景。**印刷・Word/PDF 納品物の既定候補** |
| `nord-light` | `#eceff4` | `#2e3440` | `#5e81ac` | 寒色系のライト |
| `catppuccin-latte` | `#eff1f5` | `#4c4f69` | `#8839ef` | 柔らかいライト |
| `tokyo-night-light` | `#d5d6db` | `#343b58` | `#34548a` | `tokyo-night` のライト版 |
| `solarized-light` | `#fdf6e3` | `#657b83` | `#268bd2` | クリーム色背景 |

> **`zinc-light` は存在しない。** 原典の SKILL.md・THEMES.md は「15 テーマ（`zinc-light` を含む）」と記載しているが、`beautiful-mermaid@0.1.3` の `THEMES` に該当キーはなく、指定すると `undefined` が渡ってテーマ未指定と同じ扱いになる。白背景が必要な場合は `github-light` を使うか、`--bg '#FFFFFF' --fg '#27272A'` を直接指定する。

---

## 用途からの選び方

| 出力先 | 推奨 |
|---|---|
| `dist/` の Word・PowerPoint・PDF（納品物） | `github-light`（白背景・黒文字で印刷に耐える） |
| `design/` の設計書に添える補助図 | `github-light`（Markdown 正本と一緒に閲覧するため） |
| `report/` の HTML レポート（ダーク前提） | `tokyo-night` |
| GitHub の README・Issue | `github-light` / `github-dark` |
| 投影するスライド | `github-light`（会議室の明るさでは白背景が読みやすい） |

**印刷・納品物ではダークテーマを使わない。** 背景の塗りつぶしがそのまま印刷され、インク消費と可読性の両面で不利になる。

---

## テーマを使わず色を直接指定する

テーマ名の代わりに個別の色を渡せる。`--bg` と `--fg` の 2 つだけで残りは自動導出される（mono モード）。

```sh
node .claude/skills/pretty-mermaid/scripts/render.mjs \
  --input diagram.mmd --output diagram.svg \
  --bg '#FFFFFF' --fg '#1F2328'
```

さらに細かく指定する場合（enriched モード）:

| オプション | 対象 |
|---|---|
| `--bg` | 背景色（mono モードで必須） |
| `--fg` | 文字色（mono モードで必須） |
| `--accent` | 矢印の先端・強調 |
| `--muted` | 副次的な文字・ラベル |
| `--line` | エッジ（接続線） |
| `--surface` | ノードの塗り |
| `--border` | ノードの枠線 |

`--transparent` を付けると背景を塗らない。ライト/ダークどちらのページに貼るか未定の図に使う。

---

## テーマを見比べる

同じ図を複数テーマで書き出して比較する。

```sh
for t in github-light tokyo-night dracula; do
  node .claude/skills/pretty-mermaid/scripts/render.mjs \
    --input diagram.mmd --output "diagram-$t.svg" --theme "$t"
done
```

比較用に生成したファイルは採用テーマを決めた時点で片付ける（残すものをユーザーに確認してから削除する）。

---

> 出典: [imxv/Pretty-mermaid-skills](https://github.com/imxv/Pretty-mermaid-skills)（MIT License）の `references/THEMES.md`。原典は中国語で、実在しない `python render_mermaid.py` を例示し、テーマ数と一部の前景色の値も誤っていたため、`beautiful-mermaid@0.1.3` の実測値に基づいて日本語で書き直した。
