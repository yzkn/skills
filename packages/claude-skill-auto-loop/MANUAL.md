# /auto-loop — マニュアル

## 1. 前提

| 項目       | 内容                                                                                   |
| ---------- | -------------------------------------------------------------------------------------- |
| 対象       | Claude Code の対話セッション。Claude Code 以外のエージェントは、指令リポジトリの `AGENTS.md` の手順を git で行う |
| 検証環境   | Windows 11 Home / PowerShell 7.1.4 / Git 2.52 / gh / glab                              |
| 文字コード | すべて UTF-8、改行は LF。`.ps1`・`.psm1` は **BOM 付き**                               |
| 前提ツール | Git、PowerShell 7（`pwsh`。スクリプトは `#requires -Version 7.0`）。GitHub の案件は `gh`、GitLab の案件は `glab` |
| 権限       | 管理者権限は不要。タスクの登録・フックの追加はしない                                   |
| 指令リポジトリ | 非公開の git リポジトリ 1 つ（GitHub など）。読み書きするエージェントのアカウントを、共同作業者（書き込み可）にする |

## 2. 収録物

| パス | 役割 |
|---|---|
| `skills/auto-loop/SKILL.md` | スキル本体。サブコマンドに応じて `references/` の該当ファイルだけを読む |
| `skills/auto-loop/references/*.md` | サブコマンドごとの手順 |
| `skills/auto-loop/scripts/install.ps1` | 導入（スキルの写し、`~/.claude/auto-loop/` の設定とフォルダ）。何度実行しても安全。`-LinkAutoResume` で `auto-resume-global` と連携。`-EnableKick` / `-DisableKick` で、起動時・スリープ解除時の自動起動（タスク `AutoLoopKick`。`-KickIntervalMinutes` で一定間隔も。週の上限の解除時刻が分かれば `AutoLoopKickWeekly` も）を登録・削除 |
| `skills/auto-loop/scripts/new-control-repo.ps1` | 指令リポジトリをひな形から手元に作る（`git init` と最初のコミットまで） |
| `skills/auto-loop/scripts/preflight.ps1` | 着手前の確認。1 行 1 項目で `OK / INFO / WARN / NG`。NG があれば終了コード 1 |
| `skills/auto-loop/scripts/status.ps1` | 全案件の状態の要約（`-Json` あり）。状態ごとに、優先度の高い順 → `order`（利用者が並べた順）→ 古い順 |
| `skills/auto-loop/scripts/new-task.ps1` | タスクファイルの作成（ID は `<日付>-<名前>`）。`-Priority urgent`（利用者が緊急と指定したとき）、`-Source idle`（手が空いたときの作業） |
| `skills/auto-loop/scripts/claim.ps1` | 担当の主張・印・解放・引き継ぎ（`claim` / `heartbeat` / `release` / `takeover`）。終了コード 2 = 担当できない |
| `skills/auto-loop/scripts/sync.ps1` | 指令リポジトリの同期（コミット → `pull --rebase` → push）。競合したら取り消して報告する |
| `skills/auto-loop/scripts/kick.ps1` | 起動時（ログオン時）・スリープ解除時（と、設定すれば一定間隔・週の上限の解除時刻）に、手を動かしているセッションが無く、やることがあるかを git とファイルだけで判断し、あるときだけ新しいウィンドウでセッションを起こす。PC の状況を指令リポジトリの `state/pcs/<ID>.json` に書く（`-EnableKick` で有効にしたときだけ。Windows 専用。`auto-resume-global` が要る）。`-DryRun` で判断だけを表示。見送った理由はログに残る |
| `skills/auto-loop/scripts/kick-session.ps1` | `kick.ps1` が起こしたウィンドウの中で `claude` を起動し、`/auto-loop next` を実行させる。記録が書かれなくなったら終わらせる |
| `skills/auto-loop/scripts/lib/AutoLoop.psm1` | 共通の関数 |
| `skills/auto-loop/assets/control-repo/` | 指令リポジトリのひな形 |

## 3. 導入手順

[README.md](README.md) の「導入」のとおり。

| 実行時のファイル | 場所 |
|---|---|
| 設定（`agentId`・`controlRepoPath`・`repoPaths`・`leaseHours`・`maxParallel`） | `~/.claude/auto-loop/config.json` |
| この PC で進行中の印 | `~/.claude/auto-loop/state/active/<タスク ID>.json` |
| セッションをまたぐ補助ファイル | `~/.claude/auto-loop/work/<タスク ID>/` |
| ログ | `~/.claude/auto-loop/logs/auto-loop.log` |

同じ PC で別の道具（Copilot など）も使うときは、その道具の起動時に環境変数 `AUTO_LOOP_AGENT_ID` で別の ID を渡す。`AUTO_LOOP_HOME` で実行時のフォルダを変えられる（試験用）。

### 3-1. 呼び出し方

`/auto-loop <setup|status|intake|start|next|preflight|checkpoint|resume|delegate|finish>`。引数が無いときは `status`。

## 4. 内容の構成

```
依頼（inbox.md / 直接 / タスクファイル）
  → intake     タスクファイルに起こす（status: ready）
  → start      claim（push で確定）→ preflight → 計画・承認が要る操作の洗い出し
  → 作業       区切りごとに checkpoint。必要なら delegate。判断待ちは status: waiting
  → （中断）   上限・再起動・分岐 → resume
  → finish     報告 → 解放（done → archive/）→ 片付け
  → next       次にやることを決める（起動時・スリープ解除時に自動で起こされたときも、ここから）
```

| `status` | 意味 |
|---|---|
| `draft` | 人が書きかけ。エージェントは触らない |
| `ready` | 着手できる |
| `doing` | 作業中（`claimed_by` が担当） |
| `waiting` | 利用者の判断・承認を待っている |
| `blocked` | 外部の要因で進めない |
| `done` / `dropped` | 完了 / 取りやめ（`archive/` に移る） |

## 5. 導入後の検証

1. `preflight.ps1` が `NG 0 件` で終わること。指令リポジトリの行が `OK 指令リポジトリ: 取得・push 可`
2. `status.ps1` が自分の ID と指令リポジトリを表示すること
3. 試しのタスクで一巡させる

   ```powershell
   $s = "$HOME/.claude/skills/auto-loop/scripts"
   pwsh -NoProfile -File $s/new-task.ps1 -Project <案件> -Title '試し' -Slug trial
   pwsh -NoProfile -File $s/sync.ps1 -Message 'intake: 試し'
   pwsh -NoProfile -File $s/claim.ps1 claim <表示された ID>        # OK … を担当（push 済み）
   pwsh -NoProfile -File $s/claim.ps1 release <ID> -Status dropped   # archive/ に移る
   ```

4. 2 台目の PC（または別の ID）から同じタスクを `claim` すると、終了コード 2（`… が担当中`）になること

スクリプトの通し試験（起票・担当の主張・push の競り負け・引き継ぎ・主張の喪失の検出・同期の競合・着手前の確認。一時フォルダで完結）は、正本のリポジトリの `tests/smoke.ps1` にある。

## 6. 既知の制約

- Windows 11 / PowerShell 7.1.4 で検証した。macOS / Linux の `pwsh` では未検証
- 利用枠の残りは機械的に取れない。並列の委任の前に、利用者に確かめる手順にしている
- 担当の調停は git の push の先着に頼る。指令リポジトリにリモートが無い構成では、同じ PC の中でしか効かない
- Git Credential Manager に同じホストのアカウントが複数保存されていると、入力を無効にした git が「どのアカウントを使うか」で止まる。clone ごとに `git config credential.https://<ホスト>.username <アカウント>` で固定する（`preflight.ps1` と `sync.ps1` が直し方を示す）
- 状態の記録は手順で求めているだけで、フックなどで強制はしていない
- Claude Code 以外のエージェントでの運用（`AGENTS.md` の手順）は、まだ実際に通していない

## 7. 出典と経緯

本リポジトリ独自。正本は https://github.com/aiyzkn/auto-loop-engineering の `skills/auto-loop/`（設計の根拠 `docs/design.md`、運用の手引き `docs/operations.md`、実地確認の記録 `docs/field-checks.md`）。

### 作成の経緯

1. 2026-11-13〜14 に、あるリポジトリでの長時間の作業（MR 8 本、サブエージェント 4 本の並列）が、利用上限による停止と自動再開を 4 回挟んだ。状態が会話の中にしかない、着手前の確認が遅い、分岐後にサブエージェントを呼び戻せない、などの教訓を得た
2. 以前に試作した、`claude -p` を回すループのキットから、技術スタックに依存しない部分（状態の要約、事前の道具・認証の確認、回避せずに報告する方針）を取り入れた
3. 2026-11-15 に作成し、通し試験と、実際の GitHub / GitLab の案件での `preflight.ps1` で確かめた
4. 2026-11-15 に、着手の順（着手のたびの優先度の判定・緊急・PC 1 台 1 リポジトリ・手が空いたときの作業）と、起動時・スリープ解除時の自動起動（`kick.ps1`）を足した。自動起動は、通し試験（判断だけ）と、一時の指令リポジトリでの 1 回の起動で確かめた。実際のログオン・スリープ復帰をまたぐ一連は確かめていない
5. 2026-11-19 に、自動起動を次のように変えた
   - 手が止まっているセッション（入力待ち・指示が無い・上限の解除待ち・長く書かれていない）は、1 台 1 セッションの数に入れない。記録が新しいかだけで数えると、入力待ちのまま開いたウィンドウがあるだけで起こせなかったため
   - 起動のきっかけに、一定間隔（`-KickIntervalMinutes`）と、週の上限の解除時刻の週次（タスク `AutoLoopKickWeekly`、PC を起こす）を足した
   - PC の状況を、指令リポジトリの `state/pcs/<ID>.json` に書くようにした（参照だけのダッシュボード用）
   - 作成した PC で、タスクスケジューラへの登録（30 分ごとの繰り返し、週次の起動）と、タスクから起動した `kick.ps1` が見送りの判断と PC の状況を書いて push するところまでを確かめた
6. 2026-11-20 に、次を足した
   - 自動起動（`kick.ps1`）は、`auto-resume-global` の復帰タスクが無くても、セッションの記録にある上限の解除時刻が先なら起こさない（解除前に起こして、すぐ上限で止まるのを避ける）
   - 同じ PC・同じエージェントの ID の別のセッション（上限からの再開と自動起動など）が、同じタスクを並行して進めない。担当したセッションを進行中の印に書き、そのセッションが手を動かしている間は、`claim.ps1` が終了コード 2 で止める。実際に 2 つのセッションが同じタスクを進め、同じブランチに push したことがあったため
   - タスクの先頭に `order`（同じ優先度の中の順。小さいほど先、空は後ろ）。利用者がダッシュボードなどで並べ、一覧と着手の順に使う。エージェントは書き換えない
   - 指令リポジトリのひな形で、グローバルの設定の場所を `~/.claude/CLAUDE.md` に直した

## 8. 公開前チェック

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること
2. 本文・スクリプトに個人の環境のパス・ユーザー名が残っていないこと（パスは `$HOME`・設定から解決している）
3. `.ps1`・`.psm1` が UTF-8（BOM 付き）であること
