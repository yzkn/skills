# /project-code-review

実装フェーズのコードレビュー（本プロジェクト規約準拠）。「コードレビューして」「このコード見て」「PR チェックして」で自動適用。規約の機械的チェックは /lint、設計原則は /se-principles。組み込みの /code-review とは別物。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/project-code-review/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット ba3de65） |

## これは何か

実装フェーズのコードレビュー。前提確認・独立反証パス・後続提案を担い、レビュー本体は `code-reviewer` に委任

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 元は `code-review` という名称だったが、**Claude Code 組み込みの `/code-review` と名前が衝突するため**リネームした（ADR-001）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/project-code-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/project-code-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/project-code-review` での呼び出しもできない。

## 使い方

`/project-code-review` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/project-code-review/SKILL.md`（7.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/agents/code-reviewer.md` — 未同梱（別パッケージ `claude-agent-code-reviewer` に収録）
- `.claude/project-types/development.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/code-refactor` `/db-review` `/lint` `/record` `/se-principles` `/security-review`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
