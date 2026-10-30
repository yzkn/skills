# /16minds

16 タイプの人格エージェントに議論・レビュー・助言をさせる。`/16minds mind <type> <お題>` / `pair <a> <b> <お題>` / `all <お題>`。明示的に呼び出したときだけ動作し、自動適用しない。3 体以上の並列起動は実行前に確認する。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/16minds/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | yukurash/16minds-plugin, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

立場の異なる 16 タイプの人格に議論・レビュー・助言をさせる（**明示呼び出し専用**）

## なぜ作られたか

**「明示的に呼び出したときだけ読み込まれる」という条件を満たす置き場所が問題になった**（ADR-018）。`.claude/agents/` に置くと `description` がセッション開始時に載り、16 件 × 約 350 字 = 約 5,600 字が使わないセッションでも固定費になる。原典の "Invoke ONLY when explicitly requested" は**発動の抑制であって読み込みの抑制ではない**。解決として登録機構に載らない `.claude/skills/16minds/agents/*.md` へ原典無改変で収録し、必要なタイプだけを Read して `general-purpose` に注入する形にした

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/16minds .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/16minds/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/16minds` での呼び出しもできない。

## 使い方

`/16minds` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/16minds/LICENSE`（1.1 KB）
- `skills/16minds/SKILL.md`（15.1 KB）
- `skills/16minds/agents/enfj.md`（3.1 KB）
- `skills/16minds/agents/enfp.md`（3.0 KB）
- `skills/16minds/agents/entj.md`（3.1 KB）
- `skills/16minds/agents/entp.md`（3.0 KB）
- `skills/16minds/agents/esfj.md`（3.1 KB）
- `skills/16minds/agents/esfp.md`（3.0 KB）
- `skills/16minds/agents/estj.md`（3.0 KB）
- `skills/16minds/agents/estp.md`（2.8 KB）
- `skills/16minds/agents/infj.md`（3.0 KB）
- `skills/16minds/agents/infp.md`（3.0 KB）
- `skills/16minds/agents/intj.md`（3.5 KB）
- `skills/16minds/agents/intp.md`（3.2 KB）
- `skills/16minds/agents/isfj.md`（3.0 KB）
- `skills/16minds/agents/isfp.md`（3.0 KB）
- `skills/16minds/agents/istj.md`（3.0 KB）
- `skills/16minds/agents/istp.md`（2.9 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/adversarial-review.md` — 未同梱（別パッケージ `claude-rule-adversarial-review` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/citation-format` `/document-review` `/project-code-review`

## ライセンス

同梱の `skills/16minds/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: yukurash/16minds-plugin, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
