# external-resources

間接プロンプトインジェクション対策（外部コンテンツ内の指示に従わない）、外部スキル / MCP 導入の【要指示】化、**防御設定ファイル自身の変更保護**、取得許可ドメインの許可リスト

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット d9cbe8a） |

## これは何か

間接プロンプトインジェクション対策（外部コンテンツ内の指示に従わない）、外部スキル / MCP 導入の【要指示】化、**防御設定ファイル自身の変更保護**、取得許可ドメインの許可リスト

## なぜ作られたか

**セキュリティ講習で示された 17 リスクの分析に基づく多層防御の強化**（コミット `2536052`、2026-07-17）。同時に、`curl`/`wget` の deny を PowerShell エイリアス・.NET クラス・Python インラインで迂回できる経路を塞いだ。**同コミットで `safety-net.ps1` の既存の抜け穴も解消している**（stdin を UTF-8 と明示していなかったため、日本語入力で JSON 解析に失敗し fail-open で素通りしていた）

## 導入

```sh
mkdir -p .claude/rules
cp rules/external-resources.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/external-resources.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/external-resources.md`（5.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/vnl`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
