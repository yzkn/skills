# /research

特定トピックの詳細調査を行う。「調べて」「リサーチして」「詳しく教えて」「情報収集して」で自動適用。一次情報を優先し、情報源の信頼性を評価してレポートを作成する。/research <トピック>。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/research/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971） / MaryCache/imozuru, MIT（Copyright (c) 2026 MaryCache。659f46c） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 67d5d67） |

## これは何か

一次情報を優先した調査と信頼性評価付きレポート

## なぜ作られたか

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 2026-06-22。後に DeepTutor 由来の 4 段パイプライン（問い直し → 分解 → 調査 → 報告）を採用する方針が決まった（ADR-008）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/research .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/research/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/research` での呼び出しもできない。

## 使い方

`/research` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/research/LICENSE-imozuru`（1.0 KB）
- `skills/research/LICENSE-mathbullet-skills`（1.0 KB）
- `skills/research/SKILL.md`（12.6 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/citation-format`

## ライセンス

同梱の `skills/research/LICENSE-imozuru`・`skills/research/LICENSE-mathbullet-skills` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971） / MaryCache/imozuru, MIT（Copyright (c) 2026 MaryCache。659f46c）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
