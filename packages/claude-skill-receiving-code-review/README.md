# /receiving-code-review

受け取ったレビュー指摘を、空返事にも鵜呑みにもせず、コードベースの事実に照らして検証してから実装する。`/receiving-code-review` で呼び出す。明示的に呼び出したときだけ動作し、自動適用しない。レビューする側は project-code-review。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/receiving-code-review/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | obra/superpowers, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 338e09c） |

## これは何か

受け取ったレビュー指摘を、空返事にも鵜呑みにもせず 6 段で処理する（**明示呼び出し専用・自動適用しない**）

## なぜ作られたか

**自動適用の断念が実測に基づいて記録されている稀な例。** 発動すべき依頼文 8 件での発動は 3 回の実測で 0/8 → 2/8 → 0/8 だった（各 3〜5 試行）。同じ改善策（常時適用ルールからの名指し）は `wizard` では有効だったため、施策の無効ではなくこのスキル固有の結果と判定し、**明示呼び出し専用に位置づけを変更した**（ADR-051・ADR-053・ADR-054）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/receiving-code-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/receiving-code-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/receiving-code-review` での呼び出しもできない。

## 使い方

`/receiving-code-review` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/receiving-code-review/LICENSE`（1.1 KB）
- `skills/receiving-code-review/SKILL.md`（8.1 KB）
- `skills/receiving-code-review/eval/trigger.json`（2.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/code-refactor` `/lint` `/project-code-review` `/split-pr`

## ライセンス

同梱の `skills/receiving-code-review/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: obra/superpowers, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
