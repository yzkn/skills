# /slides-maker

自然言語プロンプトからコンサルティング品質の PowerPoint (.pptx) を生成する。2 エンジン・テーマ切り替えに対応。/slides-maker <プロンプト> [--engine <名前>] [--theme <名前>]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/slides-maker/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット aeaf860） |

## これは何か

プロンプトから .pptx を生成（python-pptx / PptxGenJS の 2 エンジン・テーマ 6 種）

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/slides-maker .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/slides-maker/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/slides-maker` での呼び出しもできない。

## 使い方

`/slides-maker` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/slides-maker/SKILL.md`（13.5 KB）
- `skills/slides-maker/references/design-system-pptxgenjs.md`（7.5 KB）
- `skills/slides-maker/references/design-system.md`（7.2 KB）
- `skills/slides-maker/themes/glacier.json`（1.1 KB）
- `skills/slides-maker/themes/graphite.json`（1.1 KB）
- `skills/slides-maker/themes/indigo.json`（1.1 KB）
- `skills/slides-maker/themes/royal-navy.json`（1.0 KB）
- `skills/slides-maker/themes/sunrise.json`（1.1 KB）
- `skills/slides-maker/themes/terracotta.json`（1.1 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/third-party-licenses.md` — 未同梱（別パッケージ `claude-rule-third-party-licenses` に収録）
- `.claude/scripts/office/node` — 未同梱（別パッケージ `claude-script-office` に収録）
- `.claude/scripts/office/node/` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/scripts/office/node/render_slides.mjs` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/scripts/office/write_pptx_design.py` — 未同梱（別パッケージ `claude-script-office` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
