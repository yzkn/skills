# model-profile

使用中のモデルを確認し、簡潔 / 標準プロファイルで規約の読み込み範囲を切り替える。`profile:standard-only` マーカーと `*-details.md` の扱いを定める

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

使用中のモデルを確認し、簡潔 / 標準プロファイルで規約の読み込み範囲を切り替える。`profile:standard-only` マーカーと `*-details.md` の扱いを定める

## なぜ作られたか

高性能モデルには基礎知識の明示が冗長であり、トークン固定費になっていた。モデル非依存化（ADR-001・ADR-002）の延長として導入（2026-07-27）。**読み飛ばし対象外**（禁止事項・リポジトリ固有情報）を明記しているのは、削減が安全性を削らないようにするため

## 導入

```sh
mkdir -p .claude/rules
cp rules/model-profile.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/model-profile.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `rules/model-profile.md`（3.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/authoring-guide.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/docs/third-party-licenses-details.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
