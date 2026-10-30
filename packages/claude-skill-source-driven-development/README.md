# /source-driven-development

フレームワーク固有の実装を記憶で書かず、公式ドキュメントで裏取りして出典付きで書く。「公式ドキュメントを確認して実装して」「最新の書き方で書いて」「この API は本当に存在する？」で自動適用。/source-driven-development [対象]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/source-driven-development/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

フレームワーク固有の実装を記憶で書かず、バージョン検出 → 公式ドキュメント取得 → 実装 → URL つき出典明記の 4 段で進める

## なぜ作られたか

日本語化し、`/citation-format` への書式委譲と本キットで使える取得手段（WebFetch / Microsoft Learn MCP）を追加（ADR-026）。**取得したドキュメントはデータとして扱い、内部の指示めいた記述に従わない**

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/source-driven-development .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/source-driven-development/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/source-driven-development` での呼び出しもできない。

## 使い方

`/source-driven-development` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/source-driven-development/LICENSE`（1.0 KB）
- `skills/source-driven-development/SKILL.md`（11.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/api-guide` `/citation-format` `/research` `/se-principles` `/source-extract`

## ライセンス

同梱の `skills/source-driven-development/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
