# /auto-resume-global — マニュアル

## 1. 前提

| 項目       | 内容                                                                                 |
| ---------- | ------------------------------------------------------------------------------------ |
| 対象       | Claude Code の対話セッション（CLI。`claude --resume` で再開できるもの）              |
| 検証環境   | Windows 11 Home / PowerShell 7.1.4 / Claude Code 2.1.317 / Windows Terminal          |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 付き**（PowerShell 5.1 で日本語の文字列を正しく読むため） |
| 前提ツール | Claude Code（`claude` が PATH にあること）。Windows Terminal は任意                  |
| 権限       | 管理者権限は不要（ログオン中の利用者のタスクとして登録する）                         |

## 2. 収録物

| パス                                              | 役割                                                                    |
| ------------------------------------------------- | ----------------------------------------------------------------------- |
| `skills/auto-resume-global/SKILL.md`              | スキル本体（frontmatter の `description` で自動適用される）             |
| `skills/auto-resume-global/scripts/install.ps1`   | スクリプト一式をインストール先へコピーし、設定とタスクを登録する        |
| `skills/auto-resume-global/scripts/auto-resume.ps1` | 巡回の本体（上限で止まったセッションの検出・復帰タスクの登録・解除後の処理） |
| `skills/auto-resume-global/scripts/sleep-on-limit.ps1` | (任意) StopFailure フック。確認のスクリプトを起動してすぐ終わる |
| `skills/auto-resume-global/scripts/sleep-prompt.ps1` | (任意) 上限の確認・復帰タスクの登録・確認の画面 (既定 120 秒)・スリープ |
| `skills/auto-resume-global/scripts/keep-awake.ps1` | （`action: wake`）指定した分だけ PC をスリープさせない（同時に 1 つ。再開はしない）  |
| `skills/auto-resume-global/scripts/resume-session.ps1` | （`action: resume`）新しいウィンドウの中で claude を再開する（スリープ抑止） |
| `skills/auto-resume-global/scripts/run-hidden.vbs` | タスクから巡回をウィンドウを出さずに起動する                           |
| `skills/auto-resume-global/scripts/uninstall.ps1` | タスクを削除し、スリープ解除タイマーを元に戻す                         |

## 3. 導入手順

```powershell
mkdir -Force ~/.claude/skills
Copy-Item -Recurse packages/claude-skill-auto-resume-global/skills/auto-resume-global ~/.claude/skills/
pwsh -File ~/.claude/skills/auto-resume-global/scripts/install.ps1 -EnableWakeTimers
```

`install.ps1` が行うこと:

1. スクリプト一式を `-InstallDir`（既定 `~/.claude/auto-resume`）にコピーする。スキルの置き場所に依存せず動く。スキルを消しても、自動再開は止まらない
2. `config.json` を作る。既にあれば設定は残し、`claude`・`pwsh`・`wt` の場所だけ更新し、無い設定（`action: resume`・`keepAwakeMinutes: 20` など）を足す。`-Action resume|wake` で `action` を切り替えるclaude を入れ直して場所が変わったら、実行し直す
3. タスク `ClaudeAutoResume` を登録する。きっかけは 3 つ:
   - `-IntervalMinutes` ごと（既定 10 分）
   - ログオンの 1 分後
   - スリープからの復帰の 1 分後
4. `-EnableWakeTimers` を付けたときだけ、電源接続時のスリープ解除タイマーを「有効」にする。元の値は `state/wake-timer-before.txt` に記録する
5. `-EnableSleepOnLimit` を付けたときだけ、`~/.claude/settings.json` の `hooks.StopFailure` に matcher `rate_limit` のフック (`sleep-on-limit.ps1`) を足し、`sleepOnLimit` を `true` にする。前に足したものは外してから足す (何度実行しても 1 つ)。ほかのフックは残す。書き換える前の控えは `state/settings.json.bak`。`-DisableSleepOnLimit` で外す

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/auto-resume-global`

## 4. 内容の構成

本体（`skills/auto-resume-global/SKILL.md`）の見出し構成:

- 前提となる制約（設計がこの形になっている理由）
- 仕組み
  - ファイル（インストール先）
- 使い方
- Claude Code 向けの手順
- 遵守事項
- 制約・未検証

## 5. 導入後の検証

1. タスクを確かめる。`Get-ScheduledTask ClaudeAutoResume` が `Ready` で、`Triggers` が 3 つ（時刻・ログオン・イベント）あること
2. 判断を確かめる。`auto-resume.ps1 -DryRun` を実行し、上限で止まっているセッションが無ければ「上限で止まっているセッションはありません」と出ること
3. 試験用のセッション記録で確かめる（上限を人為的に起こせないため）。
   - 手順:
     1. 実物の上限の記録を写したセッション記録を、別のフォルダに置く
     2. `-ProjectsDir <そのフォルダ>` を付けて `auto-resume.ps1` を実行する
   - 期待する判断:
     | 試験用のセッション | 期待する判断 |
     |---|---|
     | 解除済み（`action: wake`） | 解除時刻 + 3 分 + `keepAwakeMinutes` まで PC を起こしておく（`(DryRun) N 分 (… まで) PC を起こしておく`） |
     | 解除済み（`action: resume`） | 再開する |
     | 解除前 | 待機し、解除時刻 + 3 分に `ClaudeAutoResume-Wake` を登録する |
     | 上限のあとに入力あり | 対象外 |
   - `keep-awake.ps1 -Minutes 2` を 2 つ続けて起動し、先のものが止まって後のものだけが残ること（同時に 1 つ）
   - 起動まで確かめるときは、インストール先のコピーで `config.json` の `claudePath` を引数を記録する代役に替える。作業ディレクトリと引数（`--resume <id> --fork-session --session-id <分岐先> --remote-control <名前> --permission-mode <モード> <指示>`。`remoteControl: false` なら `--remote-control` は付かない）を確かめる
4. (`-EnableSleepOnLimit` の場合) スリープの判断を確かめる。試験用のセッション記録 (最後の会話が上限の記録) を作り、
   `sleep-prompt.ps1 -DryRun -TranscriptPath <記録> -SimulateClick cancel` (または `sleep`、`-Seconds 3` で時間切れ) を実行して、`logs/auto-resume.log` に「キャンセル」「スリープする」と書かれること。
   上限の記録が無い記録では「スリープしない: 利用上限の記録が無い」、解除まで 15 分未満では「スリープしない」と書かれること
5. 再起動で中断したときの判断を確かめる。試験用のフォルダに `state/running/<ID>.json` (`startedAt` を OS の起動時刻より前にする) とセッション記録を置き、
   `auto-resume.ps1 -DryRun -ProjectsDir <記録のフォルダ> -StateDir <state のフォルダ>` を実行する。**`-StateDir` を必ず付ける** (インストール先の `state/running` に試験用の印を置くと、10 分ごとの巡回が本当に再開する)
   | 試験用の印と記録 | 期待する判断 |
   |---|---|
   | 最後の会話がツールの結果・ツールの呼び出し | 「再起動後の再開」 |
   | 最後の会話が `end_turn` / 上限の記録 | 再開しない / 上限からの再開に任せる |
   | 分岐先の記録が無い | 元のセッションの記録があれば「再起動後の再開」、無ければ skip |
   | `startedAt` が起動時刻より後でプロセスが無い (利用者が閉じた) | 再開しない |
   | `attempt` が `maxRebootResumes` + 1 | skip (回数を超えた) |
6. スリープからの復帰を確かめる。`powercfg /query SCHEME_CURRENT SUB_SLEEP RTCWAKE` の AC の現在値が `0x00000001` であること（`-EnableWakeTimers` を付けた場合）

## 6. 既知の制約

- Windows 専用
- 上限の記録の形は Claude Code の内部形式。版が変わったら、`auto-resume.ps1` の `$isLimit` と `resetsAt` の読み取りを、実物の記録に合わせて直す
- `action: wake` は PC を起こしておくだけで、再開はしない。Claude Code は上限の解除後に止まったターンを自分では続けない（元のウィンドウは上限のメッセージのまま止まる）ので、別の仕組みが再開する場合だけに使う
- `action: resume` で、解除時刻 + 3 分から最初の巡回（最大 10 分）までの間に元のウィンドウで入力しないと、自動で再開したウィンドウも開く
- PC の電源が切れている間は再開しない（次のログオン時に再開する）
- Windows Update の再起動は、スリープの抑止に関係なく行われる。再開したセッションがそれで中断したら、次のログオン時にもう一度再開する（この仕組みが再開したセッションだけ。`--session-id` と `--fork-session` を一緒に使える版の Claude Code が要る）
- 上限の記録のあとに Claude Code が差し込む `user` の記録（バックグラウンドのサブエージェントの通知 `<task-notification>`、`isMeta` の記録）は、利用者の入力とみなさない。見分けには記録の `origin.kind` / `promptSource` / `isMeta` を使う（内部形式。版が変わったら `Test-SyntheticUser` を実物の記録に合わせて直す）
- `-EnableWakeTimers` はバッテリ駆動時の設定を変えない (ノート PC がバッテリで勝手に起きないように)
- 上限で止まったらスリープする機能は、`StopFailure` フックの入力の `error` が `rate_limit` のときに動く。一時的な 429 でも `rate_limit` になるため、セッション記録の上限の記録 (`usage_limit_reached`) を最大 20 秒待って確かめる

## 7. 出典と経緯

| 項目     | 内容                                                                                             |
| -------- | ------------------------------------------------------------------------------------------------ |
| 出典     | 本リポジトリ独自                                                                                 |
| 参考     | [yzkn/Claude-LoopEngineeringKit](https://github.com/yzkn/Claude-LoopEngineeringKit)（上限の判定・定期起動のタスク・スリープ抑止） |
| 公開区分 | 🟢 公開可（本リポジトリ独自）                                                                     |

### 作成の経緯

長時間の作業が利用上限で止まり、解除後に人が戻るまで進まなかった。そこで、どのリポジトリの作業でも、PC のスリープ・終了をまたいでも、解除後に続きから再開する仕組みとして作った。

参考元 `Claude-LoopEngineeringKit` は `claude -p` を回すループの仕組みである。ここでは対話セッションの再開に合わせて、次の 3 点を作り直した。

- 上限の判定に、セッション記録の構造化された値（`apiError` / `resetsAt`）を使う
- `--fork-session` で再開する
- 解除時刻に WakeToRun のタスクを登録する

その後、既定の動作を「PC を起こしてしばらく起こしておくだけ」（`action: wake`）に変えた。Claude Code 自体が上限の解除後に続きを進めると見込んだためである。しかし実際には、解除時刻にスリープから復帰しても作業は再開しなかった（2026-11-09、復帰のログは `ClaudeAutoResume-Wake`、ウィンドウは上限のメッセージのまま）。Claude Code は上限の解除後に止まったターンを自分では続けない。そこで既定を `action: resume`（新しいウィンドウで再開し、claude が動いている間はスリープさせない）に戻し、`wake` は別の仕組みが再開する場合のために残した。

2026-11-13 には、解除時刻 (03:30) の復帰と再開 (03:33) はできたが、再開したセッションが 04:45 ごろ Windows Update (機能更新) の計画済みの再起動で、ツールの結果を返した直後に終わった。再起動後の記録は最後がツールの結果で上限の記録ではないため、巡回では拾えず、そのまま止まっていた。そこで、再開した claude が動いている印 (`state/running/`) を置き、再起動で残った印から、作業の途中で終わったセッションをもう一度再開するようにした。あわせて、Windows Terminal の場所を版を含まない実行エイリアスにした (版を含む場所は Terminal の更新で無くなる)。

同じ日、再開は別のセッション (`--fork-session`) になるため、元のセッションに張っていた Remote Control の接続が切れ、スマートフォンから続きを見られなくなった。そこで、再開する claude を `--remote-control <名前>` つき (起動後に `/remote-control` を実行したのと同じ) で起動するようにした (`remoteControl`。既定 `true`)。名前は省略できる引数なので、後ろの指示を名前と取り違えないよう、常に名前を渡す。

2026-11-13 には、バックグラウンドのサブエージェント 4 本を動かしている間に上限で止まったセッションが、スリープも解除後の再開もされなかった。上限の記録のあとに、サブエージェントが失敗したという通知が `user` の記録（`origin.kind = task-notification`）として付き、「最後の会話の記録」が上限の記録でなくなっていた。巡回は「上限のあとに利用者が入力した」とみなし、スリープの確認は「利用上限の記録が無い」とみなしていた。そこで、利用者の入力ではない `user` の記録を飛ばして最後の会話の記録を探すようにした（`auto-resume.ps1` の `Test-SyntheticUser`、`sleep-prompt.ps1` の `$isSynthetic`）。利用者が実際に入力した記録（`origin.kind = human`）は飛ばさない。あわせて、再開時の指示に「サブエージェントも止まっていれば、起動し直さず続きから」を足した。止まった時点の実物の記録の写しで、`-DryRun` の判断が「再開」になることを確かめた。

## 8. 公開前チェック

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること
2. 本文・スクリプトに個人の環境のパス・ユーザー名が残っていないこと（`$env:USERPROFILE`・`Get-Command` で解決している）
3. `.ps1` が UTF-8（BOM 付き）であること
