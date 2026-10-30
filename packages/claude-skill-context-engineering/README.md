# /context-engineering

Claude に渡す情報を意図的に絞り、トークン消費と出力品質を同時に改善する。「コンテキストを整理して」「トークンを減らしたい」「途中から精度が落ちてきた」で自動適用。/context-engineering。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/context-engineering/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

Claude に渡す情報を意図的に絞る手順（5 階層で置き場所を判断・詰め方 3 種・信頼区分 3 種）

## なぜ作られたか

**原典の MCP 推奨表は本リポジトリの【要指示】方針に合わせて書き換えた**（ADR-026）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/context-engineering .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/context-engineering/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/context-engineering` での呼び出しもできない。

## 使い方

`/context-engineering` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/context-engineering/LICENSE`（1.0 KB）
- `skills/context-engineering/SKILL.md`（11.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/authoring-guide.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/docs/skills-catalog.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/model-profile.md` — 未同梱（別パッケージ `claude-rule-model-profile` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/scripts/measure-context.py` — 未同梱（別パッケージ `claude-script-measure-context` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/bulk-ops` `/domain-modeling` `/grill` `/long-run` `/source-driven-development` `/tool-environment`

## ライセンス

同梱の `skills/context-engineering/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
