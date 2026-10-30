# design-docs

設計書の正本管理（Markdown 正本・Office 派生物）と未確定情報の表記規約。design/・dist/・intake/ 配下のファイルを扱う際に自動ロードされる。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 04711c6） |

## これは何か

設計書は Markdown を正本とし Office は `dist/` への派生物（直接編集は【絶対禁止】）。未確定情報は `==〜==` で表記

## なぜ作られたか

姉妹キット `ppf-pm-kit` との比較調査で、**正本と派生物の定義がなく Markdown 設計書と Office 納品物の二重管理ドリフトを防げない**ことが判明したため新設（ADR-003）

## 導入

```sh
mkdir -p .claude/rules
cp rules/design-docs.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/design-docs.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `LICENSE`（1.0 KB）
- `rules/design-docs.md`（5.2 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/pretty-mermaid` `/visual-doc`

## ライセンス

同梱の `LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
