# /systematic-debugging

修正着手前に根本原因を確定させる 4 フェーズの規律。「原因が分からない」「直したのに再発する」「とりあえず動くようにした」で自動適用。/systematic-debugging [症状]。実行して特定するのは debugger、本番障害は /trouble-shoot。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/systematic-debugging/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | obra/superpowers, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

修正着手前に根本原因を確定させる 4 フェーズの規律（**修正が 3 回失敗したらアーキテクチャを疑い、4 回目の前にユーザーと構造を議論する**）

## なぜ作られたか

SKILL.md のみ日本語化し、補助 3 文書と `find-polluter.sh` は原典無改変（英語）で同梱（ADR-026）。同リポジトリの `verification-before-completion` は ADR-009 で既に規約化していたため重複を避けた

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/systematic-debugging .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/systematic-debugging/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/systematic-debugging` での呼び出しもできない。

## 使い方

`/systematic-debugging` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/systematic-debugging/LICENSE`（1.1 KB）
- `skills/systematic-debugging/SKILL.md`（11.5 KB）
- `skills/systematic-debugging/references/condition-based-waiting-example.ts`（4.9 KB）
- `skills/systematic-debugging/references/condition-based-waiting.md`（3.4 KB）
- `skills/systematic-debugging/references/defense-in-depth.md`（3.6 KB）
- `skills/systematic-debugging/references/root-cause-tracing.md`（5.2 KB）
- `skills/systematic-debugging/scripts/find-polluter.sh`（1.9 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record` `/tdd` `/trouble-shoot`

## ライセンス

同梱の `skills/systematic-debugging/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: obra/superpowers, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
