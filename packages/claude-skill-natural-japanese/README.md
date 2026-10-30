# /natural-japanese

日本語の自然さ・読みやすさを lint で機械検出して直す。「AI っぽくない日本語にして」「読みやすく直して」で自動適用。/natural-japanese [write|score] [quick|full] <対象>。社内文書の型と表記は ghostwriter が優先。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/natural-japanese/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | coji/natural-japanese, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット a286b46） |

## これは何か

日本語の自然さ・読みやすさを lint で機械検出して直す（「検出は機械、判断は AI」）

## なぜ作られたか

`references`・`scripts` は原典無改変、SKILL.md のみ書き直し（ADR-019）。**`semantic.py` は取り込まない**（torch 依存・約 1GB）ため `exp` モードは使えない。社内文書では `/ghostwriter` を優先する旨を追加（見出しの体言止め・箇条書きの是非が競合するため）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/natural-japanese .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/natural-japanese/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/natural-japanese` での呼び出しもできない。

## 使い方

`/natural-japanese` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/natural-japanese/LICENSE`（1.1 KB）
- `skills/natural-japanese/SKILL.md`（25.6 KB）
- `skills/natural-japanese/assets/style-profile-template.md`（2.3 KB）
- `skills/natural-japanese/references/diagnose.md`（4.6 KB）
- `skills/natural-japanese/references/doctypes/guide.md`（9.4 KB）
- `skills/natural-japanese/references/doctypes/memo.md`（10.4 KB）
- `skills/natural-japanese/references/doctypes/minutes.md`（9.1 KB）
- `skills/natural-japanese/references/doctypes/report.md`（8.3 KB）
- `skills/natural-japanese/references/doctypes/slide.md`（9.8 KB）
- `skills/natural-japanese/references/examples.md`（2.9 KB）
- `skills/natural-japanese/references/forbidden-patterns.md`（10.4 KB）
- `skills/natural-japanese/references/genre-notes.md`（5.1 KB）
- `skills/natural-japanese/references/manual-checklist.md`（6.2 KB）
- `skills/natural-japanese/references/readability-antipatterns.md`（31.0 KB）
- `skills/natural-japanese/references/readability-principles.md`（10.8 KB）
- `skills/natural-japanese/references/revision-guide.md`（26.6 KB）
- `skills/natural-japanese/references/translationese.md`（7.8 KB）
- `skills/natural-japanese/references/writing-constitution.md`（21.3 KB）
- `skills/natural-japanese/scripts/lint.py`（118.9 KB）
- `skills/natural-japanese/scripts/outline.py`（18.8 KB）
- `skills/natural-japanese/scripts/terms.py`（12.4 KB）
- `skills/natural-japanese/scripts/textcore.py`（22.1 KB）
- `skills/natural-japanese/scripts/yomiyasu/LICENSE`（1.1 KB）
- `skills/natural-japanese/scripts/yomiyasu/yomiyasu_diff.py`（32.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/windows-python-tooling.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/model-profile.md` — 未同梱（別パッケージ `claude-rule-model-profile` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/citation-format` `/document-review` `/ghostwriter` `/newcomer-guide` `/tool-environment` `/ux-writing`

## ライセンス

同梱の `skills/natural-japanese/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: coji/natural-japanese, MIT

**第三者由来の同梱部品**: `scripts/yomiyasu/yomiyasu_diff.py` は原典（commit `986da6f`）を無改変で同梱したもので、原典のライセンス（MIT）に従う。同ディレクトリの `LICENSE` が原典の著作権表示と許諾文である。**この `LICENSE` を削除・改変してはならない。**

> 出典: nanaism/yomiyasu, MIT（Copyright (c) 2026 nanaism）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
