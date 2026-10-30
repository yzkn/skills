# /domain-modeling

ドメインモデル（ユビキタス言語・用語集）を構築・精緻化する。「用語集を作って」「用語を統一して」「用語がぶれている」で自動適用。/domain-modeling。正本は design/GLOSSARY.md。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/domain-modeling/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mattpocock/skills, MIT（Copyright (c) 2026 Matt Pocock。59db609） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット d7c15f4） |

## これは何か

ドメイン用語を確定し `design/GLOSSARY.md`（正本）として維持する

## なぜ作られたか

同上。ADR 化の条件を 3 つ（覆すコスト大・文脈なしでは不可解・真のトレードオフ）に絞っているのは ADR の乱造を避けるため

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/domain-modeling .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/domain-modeling/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/domain-modeling` での呼び出しもできない。

## 使い方

`/domain-modeling` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/domain-modeling/LICENSE`（1.0 KB）
- `skills/domain-modeling/SKILL.md`（5.0 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）
- `.claude/skills/record/SKILL.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/grill` `/record`

## ライセンス

同梱の `skills/domain-modeling/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mattpocock/skills, MIT（Copyright (c) 2026 Matt Pocock。59db609）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
