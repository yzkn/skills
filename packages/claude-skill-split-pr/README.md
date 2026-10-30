# /split-pr

大きすぎる変更を PR の鎖に分割する（1 PR 300 行上限・1 PR = 1 機能 + テスト）。「PR が大きすぎる」「変更を分割して」で自動適用。/split-pr [対象ブランチ]。push と PR 作成はユーザーが実行する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/split-pr/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | liam-hq/liam の `.claude/commands/split-pr.md`, Apache-2.0 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

大きすぎる変更を、スケルトン PR を先頭に置いた PR の鎖に分割する（1 PR 300 行上限・1 PR = 1 機能 + テスト）

## なぜ作られたか

**方法論のみ採り、実行手順は本リポジトリの Git 規約に合わせて書き直した**（ADR-019）。`git push` と `gh pr create` はユーザーが実行する

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/split-pr .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/split-pr/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/split-pr` での呼び出しもできない。

## 使い方

`/split-pr` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/split-pr/LICENSE`（10.1 KB）
- `skills/split-pr/SKILL.md`（13.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/grill` `/project-code-review` `/tdd`

## ライセンス

同梱の `skills/split-pr/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: liam-hq/liam の `.claude/commands/split-pr.md`, Apache-2.0

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
