# /unit-test-run

単体テストを実行し、結果を報告するスキル。「テストを実行して」「テストを走らせて」「テスト結果を確認して」などのリクエストがあった場合に自動で適用される。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/unit-test-run/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 77eeb74） |

## これは何か

単体テストを実行し結果をサマリー報告

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/unit-test-run .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/unit-test-run/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/unit-test-run` での呼び出しもできない。

## 使い方

`/unit-test-run` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/unit-test-run/SKILL.md`（6.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/project-types/development.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/deploy-guide` `/project-code-review` `/unit-test-gen`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
