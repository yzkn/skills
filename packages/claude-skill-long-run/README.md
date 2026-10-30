# /long-run

5 時間のセッションリミットを超えうる長時間処理を、OS 側に detach した自走・再開可能なジョブとして起動する。「セッションが切れても続く形で走らせて」「時間のかかるビルドを流して」で自動適用。/long-run <コマンド> [--name <名前>]。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/long-run/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 518ae8e） |

## これは何か

5 時間のセッションリミットを超えうる処理を OS 側に detach した自走ジョブとして起動する（`.jobs/<id>/`）

## なぜ作られたか

セッションリミット・途中中断の影響が大きい処理への備え（コミット `dbf542b`、2026-07-22）。**ジョブ化を禁止事項の回避手段にしない**旨を明記している。cron 周期は当初 15 分だったが、**待機中に同じプロンプトが 9 回積み上がる**実測を受けて 1 時間に改めた（ADR-042）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/long-run .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/long-run/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/long-run` での呼び出しもできない。

## 使い方

`/long-run` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/long-run/SKILL.md`（13.1 KB）
- `skills/long-run/templates/README.sh.md`（1006 B）
- `skills/long-run/templates/README.win.md`（1.5 KB）
- `skills/long-run/templates/check.ps1`（1.9 KB）
- `skills/long-run/templates/check.sh`（1.2 KB）
- `skills/long-run/templates/resume-intent.md`（711 B）
- `skills/long-run/templates/run.ps1`（1.9 KB）
- `skills/long-run/templates/run.sh`（1.1 KB）
- `skills/long-run/templates/worker.ps1`（1.7 KB）
- `skills/long-run/templates/worker.sh`（702 B）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/hooks/job-resume-check.ps1` — 未同梱（別パッケージ `claude-hook-job-resume-check` に収録）
- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/scripts/long-run.ps1` — 未同梱（別パッケージ `claude-script-long-run` に収録）
- `.claude/scripts/long-run.sh` — 未同梱（別パッケージ `claude-script-long-run` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/auto-resume`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
