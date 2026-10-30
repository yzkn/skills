# /ux-writing

UI コピー（マイクロコピー）の執筆・レビュー。「ボタンの文言を考えて」「エラーメッセージを書いて」で自動適用。/ux-writing [対象]。文書執筆は ghostwriter。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/ux-writing/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | plugin87/ux-ui-agent-skills, MIT（Copyright (c) 2026 Thientan Soparat。def84a7） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

UI コピー（ボタン・エラー・空状態・確認ダイアログ・通知）の執筆・レビュー

## なぜ作られたか

エラーは「何が起きた → なぜ → どうすれば」公式、破壊的操作は type-to-confirm

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/ux-writing .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/ux-writing/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/ux-writing` での呼び出しもできない。

## 使い方

`/ux-writing` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/ux-writing/LICENSE`（1.0 KB）
- `skills/ux-writing/SKILL.md`（3.3 KB）
- `skills/ux-writing/i18n-rtl.md`（3.3 KB）
- `skills/ux-writing/voice-tone.md`（6.3 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/domain-modeling`

## ライセンス

同梱の `skills/ux-writing/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: plugin87/ux-ui-agent-skills, MIT（Copyright (c) 2026 Thientan Soparat。def84a7）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
