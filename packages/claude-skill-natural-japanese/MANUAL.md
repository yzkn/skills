# /natural-japanese — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・uv |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/natural-japanese/LICENSE` | 1.1 KB | ライセンス |
| `skills/natural-japanese/SKILL.md` | 25.6 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/natural-japanese/assets/style-profile-template.md` | 2.3 KB | — |
| `skills/natural-japanese/references/diagnose.md` | 4.6 KB | — |
| `skills/natural-japanese/references/doctypes/guide.md` | 9.4 KB | — |
| `skills/natural-japanese/references/doctypes/memo.md` | 10.4 KB | — |
| `skills/natural-japanese/references/doctypes/minutes.md` | 9.1 KB | — |
| `skills/natural-japanese/references/doctypes/report.md` | 8.3 KB | — |
| `skills/natural-japanese/references/doctypes/slide.md` | 9.8 KB | — |
| `skills/natural-japanese/references/examples.md` | 2.9 KB | — |
| `skills/natural-japanese/references/forbidden-patterns.md` | 10.4 KB | — |
| `skills/natural-japanese/references/genre-notes.md` | 5.1 KB | — |
| `skills/natural-japanese/references/manual-checklist.md` | 6.2 KB | — |
| `skills/natural-japanese/references/readability-antipatterns.md` | 31.0 KB | — |
| `skills/natural-japanese/references/readability-principles.md` | 10.8 KB | — |
| `skills/natural-japanese/references/revision-guide.md` | 26.6 KB | — |
| `skills/natural-japanese/references/translationese.md` | 7.8 KB | — |
| `skills/natural-japanese/references/writing-constitution.md` | 21.3 KB | — |
| `skills/natural-japanese/scripts/lint.py` | 118.9 KB | Python スクリプト |
| `skills/natural-japanese/scripts/outline.py` | 18.8 KB | Python スクリプト |
| `skills/natural-japanese/scripts/terms.py` | 12.4 KB | Python スクリプト |
| `skills/natural-japanese/scripts/textcore.py` | 22.1 KB | Python スクリプト |
| `skills/natural-japanese/scripts/yomiyasu/LICENSE` | 1.1 KB | ライセンス |
| `skills/natural-japanese/scripts/yomiyasu/yomiyasu_diff.py` | 32.0 KB | Python スクリプト |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/natural-japanese .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/natural-japanese/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/natural-japanese` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/natural-japanese`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/natural-japanese` を名指しする。

## 4. 内容の構成

本体（`skills/natural-japanese/SKILL.md`）の見出し構成:

- 他スキルとの棲み分け（先に確認する）
  - 競合したときの裁定【重要】
- 前提ツール
  - Windows では UTF-8 を強制する【必須】
- 実行モード — クイックとフル
- 呼び出し方 — write / score
- 1. 設計 — 書く前に決める
  - 1-1. 読者・目的・文書タイプ
  - 1-2. 主メッセージとスケルトン
  - 1-3. 濃淡設計
  - 1-4. 素材集め（任意・新規執筆時）
  - 1-5. 文体プロファイル（任意）
- 2. 執筆 — 文体憲法の下で書く
- 3. 検査(1) — 静的検知

## 5. 導入後の検証

```sh
python -m py_compile skills/natural-japanese/scripts/lint.py skills/natural-japanese/scripts/outline.py skills/natural-japanese/scripts/terms.py skills/natural-japanese/scripts/textcore.py skills/natural-japanese/scripts/yomiyasu/yomiyasu_diff.py
echo "exit=$?"
```
- `/natural-japanese` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/natural-japanese/` |
| 元の格納先 | `.claude/skills/natural-japanese/` |
| 出典 | coji/natural-japanese, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

`references`・`scripts` は原典無改変、SKILL.md のみ書き直し（ADR-019）。**`semantic.py` は取り込まない**（torch 依存・約 1GB）ため `exp` モードは使えない。社内文書では `/ghostwriter` を優先する旨を追加（見出しの体言止め・箇条書きの是非が競合するため）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
