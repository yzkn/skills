# /review-animations

Emil Kowalski のデザインエンジニアリング哲学に基づく高いクラフト基準で、アニメーション・モーションのコードをレビューする。デフォルトは指摘（flag）であり、承認（approval）は勝ち取るもの。「アニメーションをレビューして」「モーションをレビューして」「このトランジションを見て」「アニメーションの品質をチェックして」といったリクエストで使用する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/review-animations/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | emilkowalski/skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 88f533c） |

## これは何か

アニメーション / モーションコードに特化したレビュー（easing・duration・origin・interruptibility・GPU-only プロパティ・アクセシビリティの 10 基準）。

## なぜ作られたか

同上（ADR-004・ADR-021）。原典は `disable-model-invocation: true` を維持しており、自動適用ではなく直接呼び出し専用として導入した。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/review-animations .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/review-animations/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/review-animations` での呼び出しもできない。

## 使い方

`/review-animations` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/review-animations/LICENSE`（1.4 KB）
- `skills/review-animations/SKILL.md`（13.0 KB）
- `skills/review-animations/STANDARDS.md`（13.9 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

同梱の `skills/review-animations/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: emilkowalski/skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
