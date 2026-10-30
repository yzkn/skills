# /explainer-html — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・pandoc |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/explainer-html/LICENSE` | 1.1 KB | ライセンス |
| `skills/explainer-html/SKILL.md` | 16.2 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/explainer-html/assets/sample.html` | 26.9 KB | — |
| `skills/explainer-html/assets/template.html` | 18.3 KB | — |
| `skills/explainer-html/references/components.md` | 5.4 KB | — |
| `skills/explainer-html/scripts/build_sample.py` | 3.2 KB | Python スクリプト |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/explainer-html .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/explainer-html/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/explainer-html` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/explainer-html`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/explainer-html` を名指しする。

## 4. 内容の構成

本体（`skills/explainer-html/SKILL.md`）の見出し構成:

- 隣接スキルとの棲み分け（先に確認する）
- 成果物の規約
- デザインシステム
- 読み手を決める
- 文書構成
- コード
- 数式
- 図
  - 原典の図表を引用する（PDF から切り出す）
- 実行手順
- 検証（スクリプトで機械的に行う）
- 完了条件

## 5. 導入後の検証

```sh
python -m py_compile skills/explainer-html/scripts/build_sample.py
echo "exit=$?"
```
- `/explainer-html` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/explainer-html/` |
| 元の格納先 | `.claude/skills/explainer-html/` |
| 出典 | mathbullet/skills, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**CDN 4 本を排除し、ダーク対応と MathML / skylighting への置換を加えて作り直した**（ADR-017）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
