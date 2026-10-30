# /handoff

現在の会話を、別セッション・別担当が続きを引き継げる文書に圧縮する。「引き継ぎ資料を作って」「別のセッションに渡したい」で自動適用。/handoff [次にやること]。不変の証跡は record、リミット中断からの復帰は auto-resume。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/handoff/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | mattpocock/skills, MIT |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット e2d8f4b） |

## これは何か

現在の会話を、文脈を持たないエージェント・別担当が続きを始められる引き継ぎ文書に圧縮する（6 項）

## なぜ作られたか

出力先と証跡との切り分けを追加（ADR-046）。**証跡（`doc/prompt/`・`doc/thought/`・`doc/adr/`）には置かない**（証跡は不変であるのに対し引き継ぎ文書は作業が進めば古くなる）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/handoff .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/handoff/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/handoff` での呼び出しもできない。

## 使い方

`/handoff` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/handoff/LICENSE`（1.1 KB）
- `skills/handoff/SKILL.md`（4.6 KB）
- `skills/handoff/eval/trigger.json`（2.5 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/auto-resume` `/context-engineering` `/design-sync` `/long-run` `/record` `/tdd`

## ライセンス

同梱の `skills/handoff/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: mattpocock/skills, MIT

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
