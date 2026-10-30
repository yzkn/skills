# /find-animation-opportunities

コードベースや UI を調査し、アニメーションが入っていないが入れるべき箇所を洗い出し、不要な箇所は明確に却下するスキル。読み取り専用であり、正確な数値を伴う motion の提案は行うが実装はしない。「どこにアニメーションを入れられる?」「この UI をもっと生き生きさせたい」といったリクエストで使用する。既存アニメーションの修正は improve-animations または review-animations を使用する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/find-animation-opportunities/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | emilkowalski/skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 88f533c） |

## これは何か

読み取り専用。モーションを入れるべき箇所を抑制的に洗い出し、過剰なアニメーションを却下する。

## なぜ作られたか

emilkowalski/skills（MIT）のアニメーション系スキル 4 件を日本語化して導入した際の 1 件（ADR-004）。既存の UI/UX 系スキル（`ui-ux-pro-max`・`ux-review`・`ui-designer`・`ux-designer`）がアニメーション / モーションを深く扱っておらず、この領域が明確な空白だったことが動機である。その後、トークン削減のため `.claude/skills/_disabled/` へ退避した（`description` はセッション開始時にまとめてコンテキストへ載るため、使わない定義が毎セッションの固定費になる。ADR-021 の計測）。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/find-animation-opportunities .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/find-animation-opportunities/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/find-animation-opportunities` での呼び出しもできない。

## 使い方

`/find-animation-opportunities` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/find-animation-opportunities/LICENSE`（1.4 KB）
- `skills/find-animation-opportunities/SKILL.md`（13.8 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

同梱の `skills/find-animation-opportunities/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: emilkowalski/skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
