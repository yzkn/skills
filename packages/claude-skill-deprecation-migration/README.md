# /deprecation-migration

旧システム・API・機能の廃止と移行を計画・実行する。「移行計画を作って」「この機能を廃止したい」「カラム名を安全に変えたい」で自動適用。/deprecation-migration [対象]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/deprecation-migration/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | addyosmani/agent-skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

廃止・移行の計画と実行（廃止判断の 5 問 → 代替構築 → 告知 → 1 件ずつ移行 → 撤去）と移行パターン

## なぜ作られたか

日本語化し、`design/07_migration/` への接続・本番 DB の破壊的操作の【要指示】・後続スキルへの引き継ぎを追加（ADR-026）。DB スキーマ変更を expand → 二重書き → バックフィル → 読み替え → contract に分割し、**in-place の改名・削除と「追加と破壊的変更の同一リリース」を禁じている**

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/deprecation-migration .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/deprecation-migration/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/deprecation-migration` での呼び出しもできない。

## 使い方

`/deprecation-migration` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/deprecation-migration/LICENSE`（1.0 KB）
- `skills/deprecation-migration/SKILL.md`（13.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/wbs-tasks.md` — 未同梱（別パッケージ `claude-rule-wbs-tasks` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/db-review` `/record` `/split-pr` `/tdd`

## ライセンス

同梱の `skills/deprecation-migration/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: addyosmani/agent-skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
