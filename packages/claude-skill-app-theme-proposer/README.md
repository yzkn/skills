# /app-theme-proposer

アプリ実装テーマ提案スキル。「何を作るか決まっていない」ユーザーに 5 問ヒアリングし、テーマ候補を比較表で提示する。確定後は仕様書とワイヤーフレームを design/ に生成する。/app-theme-proposer [テーマ名または要件]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/app-theme-proposer/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

アプリ実装テーマの提案（5 問ヒアリング → 比較表 → 仕様書とワイヤーフレーム）

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 2026-06-25。エージェント版と対

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/app-theme-proposer .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/app-theme-proposer/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/app-theme-proposer` での呼び出しもできない。

## 使い方

`/app-theme-proposer` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/app-theme-proposer/SKILL.md`（6.6 KB）
- `skills/app-theme-proposer/themes.md`（17.9 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
