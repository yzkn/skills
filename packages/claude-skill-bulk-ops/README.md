# /bulk-ops

多数ファイル（目安 10 件以上）の一括解析・一括改名・一括置換をスクリプトで完結させ、要約だけをコンテキストに載せる。「まとめてリネームして」「一括削除して」で自動適用。/bulk-ops <サブコマンド>。書き込みは dry-run→承認→--apply の順。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/bulk-ops/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上（execution-runtime） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

10 件以上のファイルにまたがる解析・変更を 1 回のスクリプト実行に集約し、**要約 JSON だけ**をコンテキストに載せる（7 サブコマンド）

## なぜ作られたか

変更系は dry-run 既定、`--apply` 時は git クリーンを検査。**git 書き込み API は意図的に未移植**（`git push` の迂回路を作らないため）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/bulk-ops .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/bulk-ops/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/bulk-ops` での呼び出しもできない。

## 使い方

`/bulk-ops` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/bulk-ops/LICENSE`（9.5 KB）
- `skills/bulk-ops/SKILL.md`（8.5 KB）
- `skills/bulk-ops/scripts/bulk_ops.py`（24.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/skills/anthropics` — 未同梱（切り出しの対象外。読み替えか削除が必要）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/code-refactor` `/long-run` `/tool-environment`

## ライセンス

同梱の `skills/bulk-ops/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上（execution-runtime）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
