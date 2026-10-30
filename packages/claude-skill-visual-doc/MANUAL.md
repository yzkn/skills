# /visual-doc — マニュアル

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
| `skills/visual-doc/LICENSE` | 9.5 KB | ライセンス |
| `skills/visual-doc/SKILL.md` | 9.0 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/visual-doc/assets/base_template.html` | 10.7 KB | — |
| `skills/visual-doc/references/diagram_patterns.md` | 12.8 KB | — |
| `skills/visual-doc/references/svg_library.md` | 10.9 KB | — |
| `skills/visual-doc/scripts/verify_output.py` | 8.2 KB | Python スクリプト |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/visual-doc .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/visual-doc/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/visual-doc` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/visual-doc`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/visual-doc` を名指しする。

## 4. 内容の構成

本体（`skills/visual-doc/SKILL.md`）の見出し構成:

- モードと出力先
- 既存スキルへの委譲（先に確認する）
- 生成の必須要件
  - `design/` に出力する場合の追加規約
- 実行手順
  - Step 1: 入力の確定
  - Step 2: 図の型を選ぶ
  - Step 3: SVG を実装する
  - Step 4: HTML を組み立てる
  - Step 5: 検証（スクリプトで機械的に行う）
  - Step 6: 報告
- 完了条件
- 関連

## 5. 導入後の検証

```sh
python -m py_compile skills/visual-doc/scripts/verify_output.py
echo "exit=$?"
```
- `/visual-doc` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/visual-doc/` |
| 元の格納先 | `.claude/skills/visual-doc/` |
| 出典 | mhattingpete/claude-skills-marketplace, Apache-2.0 |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**原典 5 スキルを 1 本に統合し、リファレンスの 4 重複を解消**（ADR-015）。**原典の配色・タイポ体系は採用せず**、紫グラデーションを排除して意味色のみ CSS 変数として残し、`prefers-color-scheme` 対応（原典は 0 件）と日本語フォントスタックを追加

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
