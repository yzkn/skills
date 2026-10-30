# /auto-resume

5 時間のセッションリミット（429）で中断した作業を、解除時刻に自動で再開できる状態にする。「リミットが解けたら自動で続けて」「セッションが切れても再開したい」「自動再開の状態を見せて」で自動適用。/auto-resume <status|intent|optin|optout|claim|disable|enable>。長時間処理そのものの実行は long-run。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/auto-resume/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット cca05e5） |

## これは何か

5 時間リミット（429）で中断した作業を解除時刻に自動再開する（W1 / W2 の 2 系統待機・既定は通知のみ・headless 再開は optin）

## なぜ作られたか

ADR-039 の機構が `/long-run` のジョブに紐づいており**通常作業の中断を拾えなかった**ため汎用化（ADR-043）。ADR-039 の時点では「別セッションになるため対話画面に応答が戻らない」として見送っていた経路を、実データで前提を再確認して採用した

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/auto-resume .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/auto-resume/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/auto-resume` での呼び出しもできない。

## 使い方

`/auto-resume` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/auto-resume/SKILL.md`（8.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/hooks/session-resume-check.ps1` — 未同梱（別パッケージ `claude-hook-session-resume-check` に収録）
- `.claude/rules/prohibition-levels.md` — 未同梱（別パッケージ `claude-rule-prohibition-levels` に収録）
- `.claude/scripts/resume-watch.ps1` — 未同梱（別パッケージ `claude-script-resume-watch` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/long-run`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
