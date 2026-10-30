# /apple-design

Apple のインターフェースデザインと物理的なモーションを Web に翻案した実装・レビュー指針。「Apple 風の UI を設計して」「モーションを診断して」で自動適用。/apple-design [対象]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/apple-design/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | emilkowalski/skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

Apple 流の流体 UI・spring モーション原則を Web（CSS / Framer Motion）へ翻案した知識集

## なぜ作られたか

既存 UI/UX 系スキルが**アニメーション / モーションを深く扱っておらず明確な空白**だった（ADR-004）。日本語化し、CSS 値・cubic-bezier・ライブラリ名は英語のまま維持

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/apple-design .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/apple-design/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/apple-design` での呼び出しもできない。

## 使い方

`/apple-design` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/apple-design/LICENSE`（1.4 KB）
- `skills/apple-design/SKILL.md`（31.2 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

同梱の `skills/apple-design/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: emilkowalski/skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
