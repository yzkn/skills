# code-quality

コード生成・修正・レビューのすべての場面で常に適用するコード品質制約。明示的な依頼がなくても遵守する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット ba3de65） |

## これは何か

AI 支援開発の追加原則（単一目的の変更・型と静的解析・人間のゲート）、**完了の証拠主義**、DB 命名規約

## なぜ作られたか

「完了の証拠主義」節は obra/superpowers の `verification-before-completion` と loki-mode の Evidence Receipt を統合して追加（ADR-009）。**「決定論的に求まる値を暗算・記憶で出さない」列挙は実測から生まれた**: 列挙にあるカテゴリでは `/vnl` が発動し、無いカテゴリでは発動しなかった（ADR-038・ADR-040）。さらに、正確さを期して添えた但し書き 2 行が列挙自体の拘束力を弱め、発動が 16/20 → 10/20 に落ちる現象を実測したため、但し書きを括弧内 1 文へ戻した（ADR-041）

## 導入

```sh
mkdir -p .claude/rules
cp rules/code-quality.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/code-quality.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `docs/code-quality-details.md`（5.2 KB）
- `rules/code-quality.md`（5.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/project-types/development.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/code-quality.md` — **同梱**
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/db-review` `/long-run` `/se-principles` `/source-driven-development` `/systematic-debugging` `/vnl`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
