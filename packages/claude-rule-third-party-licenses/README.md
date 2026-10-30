# third-party-licenses

持ち込み前のライセンス確認義務、permissive のみ原則許可、コピーレフト / 商用制限付きは【要指示】、**ハルシネーションパッケージ（slopsquatting）対策**、作図アイコンの用途区分

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code ルール（CLAUDE.md から読み込む規約） |
| 導入先 | `.claude/rules/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

持ち込み前のライセンス確認義務、permissive のみ原則許可、コピーレフト / 商用制限付きは【要指示】、**ハルシネーションパッケージ（slopsquatting）対策**、作図アイコンの用途区分

## なぜ作られたか

外部ライブラリ・コードの持ち込み時にライセンス確認が制度化されていなかったため新設（コミット `cd0fc07`、2026-07-16）。アイコンの節は後に追加（ADR-029・ADR-030。公開版では、ライセンスが permissive なアイコンだけを使う形に一般化した）

## 導入

```sh
mkdir -p .claude/rules
cp rules/third-party-licenses.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/third-party-licenses.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 収録ファイル

- `docs/third-party-licenses-details.md`（2.7 KB）
- `rules/third-party-licenses.md`（4.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）
- `.claude/rules/third-party-licenses.md` — **同梱**

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/record`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
