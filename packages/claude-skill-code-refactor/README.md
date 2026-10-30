# /code-refactor

コードの外部的な振る舞いを変えずに内部構造を改善するスキル。/project-code-review の指摘事項を受けて呼び出されるほか、単独でも使用できる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/code-refactor/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット e2858ea） |

## これは何か

振る舞いを変えずに内部構造を改善する（9 種別を diff プレビュー → 承認 → 適用）。言語固有の手法は `references/` の 5 言語別ファイル

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/code-refactor .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/code-refactor/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/code-refactor` での呼び出しもできない。

## 使い方

`/code-refactor` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/code-refactor/SKILL.md`（12.2 KB）
- `skills/code-refactor/references/csharp-dotnet.md`（7.9 KB）
- `skills/code-refactor/references/powerfx-canvas.md`（6.6 KB）
- `skills/code-refactor/references/powershell.md`（8.5 KB）
- `skills/code-refactor/references/python.md`（6.0 KB）
- `skills/code-refactor/references/typescript.md`（6.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/hooks-architecture.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/api-conventions.md` — 未同梱（別パッケージ `claude-rule-api-conventions` に収録）
- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）
- `.claude/scripts/fix-bom.py` — 未同梱（別パッケージ `claude-script-fix-bom` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/api-guide` `/governance` `/project-code-review` `/record` `/tool-environment` `/unit-test-gen` `/unit-test-run`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
