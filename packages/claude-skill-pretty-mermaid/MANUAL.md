# /pretty-mermaid — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Node.js + npm |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/pretty-mermaid/LICENSE` | 1.1 KB | ライセンス |
| `skills/pretty-mermaid/SKILL.md` | 17.6 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/pretty-mermaid/assets/example_diagrams/class.mmd` | 544 B | — |
| `skills/pretty-mermaid/assets/example_diagrams/er.mmd` | 616 B | — |
| `skills/pretty-mermaid/assets/example_diagrams/flowchart.mmd` | 261 B | — |
| `skills/pretty-mermaid/assets/example_diagrams/sequence.mmd` | 307 B | — |
| `skills/pretty-mermaid/assets/example_diagrams/state.mmd` | 233 B | — |
| `skills/pretty-mermaid/package-lock.json` | 1.5 KB | データ・設定 |
| `skills/pretty-mermaid/package.json` | 327 B | データ・設定 |
| `skills/pretty-mermaid/references/DIAGRAM_TYPES.md` | 7.0 KB | — |
| `skills/pretty-mermaid/references/THEMES.md` | 5.1 KB | — |
| `skills/pretty-mermaid/scripts/batch.mjs` | 5.5 KB | — |
| `skills/pretty-mermaid/scripts/flatten.mjs` | 7.3 KB | — |
| `skills/pretty-mermaid/scripts/rasterize.mjs` | 5.9 KB | — |
| `skills/pretty-mermaid/scripts/render.mjs` | 5.3 KB | — |
| `skills/pretty-mermaid/scripts/themes.mjs` | 1.6 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/pretty-mermaid .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/pretty-mermaid/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/pretty-mermaid` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/pretty-mermaid`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/pretty-mermaid` を名指しする。

## 4. 内容の構成

本体（`skills/pretty-mermaid/SKILL.md`）の見出し構成:

- 日本語で使うときの制約【必ず先に読む】
- 使いどころ — 他スキルとの棲み分け（先に確認する）
- 前提ツール（初回のみユーザーによる導入が必要）
- 実行手順
  - Step 1: 入力の確定
  - Step 2: テーマを決める
  - Step 3: 描画する
  - Step 4: 自己完結 SVG に変換する【必須】
  - Step 5: Word / PowerPoint に載せる場合は PNG 化する【必須】
  - Step 6: 検証
  - Step 7: 後片付け
- 描画できない図種別
- 完了条件
- 原典からの改変点

## 5. 導入後の検証

- `/pretty-mermaid` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/pretty-mermaid/` |
| 元の格納先 | `.claude/skills/pretty-mermaid/` |
| 出典 | imxv/Pretty-mermaid-skills, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**導入時点では描画結果を一度も確認しておらず、検証で複数の不具合が判明した**（ADR-020）。生成 SVG が Google Fonts へ `@import` し CSS 変数と `color-mix()` に依存するため、素のままでは対応レンダラー以外で全ノードが黒く潰れる → **原典にない `flatten.mjs` を追加**。さらに pandoc は `rsvg-convert` なしで SVG をラスタ化できず**警告のみで exit 0 のまま**壊れた図を docx に埋めるため `rasterize.mjs` を追加。日本語ラベルは全角 5 文字以内が目安（枠幅が欧文字幅で計算される・実測）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
