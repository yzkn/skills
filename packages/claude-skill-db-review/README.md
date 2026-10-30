# /db-review

DB 設計（スキーマ・テーブル定義・マイグレーション）のアンチパターンを深刻度別に検出する。「DB 設計をレビューして」「スキーマをチェックして」で自動適用。/db-review [対象パス]。新規設計は data-modeler。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/db-review/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | takuya-38/claude-skills, MIT（Copyright (c) 2026 takuya-38。c6f0e8b） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

DB 設計のアンチパターンを深刻度別（CRITICAL / HIGH / MEDIUM）に検出

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 2026-07-04。改善案作成は `data-modeler`、性能解析は `perf-analyzer` に引き継ぐ

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/db-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/db-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/db-review` での呼び出しもできない。

## 使い方

`/db-review` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/db-review/LICENSE`（1.0 KB）
- `skills/db-review/SKILL.md`（11.1 KB）
- `skills/db-review/references/full-checks.md`（9.1 KB）
- `skills/db-review/references/schema-checks.md`（20.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record`

## ライセンス

同梱の `skills/db-review/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: takuya-38/claude-skills, MIT（Copyright (c) 2026 takuya-38。c6f0e8b）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
