# /record

会話内容を doc/prompt/ と doc/thought/ に記録するスキル。/record adr でアーキテクチャ意思決定を doc/adr/ に ADR として記録する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/record/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット d7c15f4） |

## これは何か

会話内容を `doc/prompt/` と `doc/thought/` に記録する。`/record adr` でアーキテクチャ意思決定を `doc/adr/` に記録

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: ADR 節の「検討した選択肢の散らし方」（制約変化・アプローチ変化・ペルソナ変化）は、ensemble-solving を見送った際に思想だけを移植したもの（ADR-016）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/record .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/record/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/record` での呼び出しもできない。

## 使い方

`/record` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/record/SKILL.md`（7.6 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
