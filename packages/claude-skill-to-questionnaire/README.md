# /to-questionnaire

自分だけでは決められない事項を、相手に記入してもらう質問票（Markdown）に変換する。「顧客に確認したいことを整理して」「ヒアリングシートを作って」で自動適用。/to-questionnaire [トピック]。自分に問うのは grill、回答の反映は design-sync。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/to-questionnaire/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット e2d8f4b） |

## これは何か

自分では答えを持たない事項を、知っている相手に記入してもらう質問票にする

## なぜ作られたか

出力先と後続スキルへの接続を追加（ADR-046）。**題材そのものをユーザーに問い詰めず、答えられる「送り先」に関することだけを 2 往復で聞く**

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/to-questionnaire .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/to-questionnaire/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/to-questionnaire` での呼び出しもできない。

## 使い方

`/to-questionnaire` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/to-questionnaire/LICENSE`（1.1 KB）
- `skills/to-questionnaire/SKILL.md`（6.0 KB）
- `skills/to-questionnaire/eval/trigger.json`（2.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/design-docs.md` — 未同梱（別パッケージ `claude-rule-design-docs` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/design-sync` `/domain-modeling` `/ghostwriter` `/grill` `/record` `/source-extract` `/trouble-shoot`

## ライセンス

同梱の `skills/to-questionnaire/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
