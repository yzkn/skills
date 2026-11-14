---
name: auto-resume-global
description: "Claude Code の利用上限（5 時間・週）で止まった対話セッションを、この PC の全プロジェクトについて見張り、解除時刻に Windows をスリープから復帰させ、新しいターミナルのウィンドウで claude --resume --fork-session を起動して続きから再開する（設定 action=wake なら PC を起こしておくだけ）。終了していた場合は次のログオン時に処理する。「上限の解除時刻にスリープから復帰させて」「上限で止まったらスリープして」「上限で止まっても自動で再開するようにして」「どのプロジェクトでも自動再開したい」「自動再開の予定を見せて」で自動適用。/auto-resume-global <install|status|pause|resume|uninstall>。Windows 専用。プロジェクト単位で通知・headless 再開するのは auto-resume。"
---

# /auto-resume-global スキル — 利用上限の解除時刻にスリープから復帰（PC 全体・対話セッション）

Claude Code の利用上限（5 時間・週）で対話セッションが止まったとき、**上限の解除時刻に Windows をスリープから復帰させ、新しいウィンドウで続きから再開する**（再開した claude が動いている間はスリープさせない）。対象はこの PC の**すべてのプロジェクト**の対話セッション（`~/.claude/projects/` 配下）で、プロジェクトごとの設定・フックは要らない。

解除後の再開には 2 つの動作がある（`config.json` の `action`）。

| `action` | 解除後に行うこと | 向いている場合 |
|---|---|---|
| `resume`（既定） | 新しいターミナルのウィンドウで `claude --resume <id> --fork-session` を起動して再開する。claude が動いている間は PC をスリープさせない | 人が見ていなくても、スリープをまたいで先へ進めたい |
| `wake` | `keepAwakeMinutes`（既定 20 分）の間 PC を起こしておくだけ。**再開はしない** | 別の仕組み（`/auto-resume` のタスクなど）が再開する場合だけ。Claude Code は上限の解除後に止まったターンを自分では続けないので、これだけでは進まない |

プロジェクト単位で「通知 + 次回起動時の提示」を基本にするのは `/auto-resume`。こちらは PC 全体を対象に、**人が見ていなくても、スリープをまたいで先へ進む**ことを基本にする。

## 前提となる制約（設計がこの形になっている理由）

- **上限の解除時刻は、止まったときの記録にだけ残る。** 上限に当たると、セッション記録（`~/.claude/projects/<プロジェクト>/<セッション ID>.jsonl`）に次のアシスタント記録が書かれる（Claude Code 2.1.317 で実物を確認）

  ```json
  {"type":"assistant","apiError":"usage_limit_reached","error":"rate_limit","isApiErrorMessage":true,
   "apiErrorParams":{"rate_limit_info":{"resetsAt":1794132000,"rateLimitType":"five_hour", ...}}, ...}
  ```

  文言（`You've hit your 5-hour limit · resets 7pm`）ではなく、この構造化された値（`resetsAt` は Unix 秒）で判定する
- **常駐プロセスは置かない。** タスク スケジューラが一定間隔で全セッション記録を調べる。PC の終了・スリープで常駐プロセスが消えても、取りこぼさない
- **スリープ中は、Claude Code もタスクも動かない。** 解除時刻を過ぎても PC が寝ていれば作業は進まない。`StartWhenAvailable` だけでは、人が PC を起こすまで実行されない。そこで解除時刻に WakeToRun のタスクを登録する
- **タイマーで起こされた PC は、無操作だと 2 分ほどでまたスリープする**（無人のスリープのタイムアウト）。起こしただけでは足りないので、`keep-awake.ps1` が `SetThreadExecutionState` でしばらく起こしておく。画面は消えたままでよい
- **（`resume` のとき）止まった対話画面そのものは復活しない。** 新しいウィンドウで `claude --resume <id> --fork-session` を起動する。`--fork-session` で新しいセッション ID に分けるので、止まったときのウィンドウが開いたままでも、同じ記録に二重に書き込まない

## 仕組み

```
上限で停止 ─▶ セッション記録の最後の会話が「usage_limit_reached」になる
                │
タスク ClaudeAutoResume（10 分ごと / ログオン時 / スリープ復帰時）
                │  auto-resume.ps1 が全プロジェクトのセッション記録の末尾を調べる
                ├─ まだ解除前 ─▶ 解除時刻 + 3 分 に、スリープから復帰して起動するタスク ClaudeAutoResume-Wake を登録
                └─ 解除時刻 + 3 分 を過ぎた
                      ├─ action=wake          ─▶ keep-awake.ps1 で、解除時刻 + 3 分 + 20 分 まで PC をスリープさせない (再開はしない)
                      └─ action=resume（既定）─▶ 新しいウィンドウで
                                                 claude --resume <id> --fork-session --remote-control <名前> --permission-mode <元のモード> "続けて…"
```

| 状況 | どうなるか |
|---|---|
| PC が起きている | 10 分ごとの巡回で処理する（`wake` は起こしておくだけ、`resume` は解除時刻 + 3 分を過ぎてから最大 10 分で再開） |
| スリープ中に解除時刻が来る | `ClaudeAutoResume-Wake`（WakeToRun）が PC を起こして処理する。電源接続時の「スリープ解除タイマー」が有効な場合だけ |
| スリープ・休止から手動で復帰 | 復帰のイベント（System ログ、Power-Troubleshooter、イベント ID 1）で起動する |
| PC を終了していた | 次のログオンの 1 分後に処理する。電源を自動で入れることはしない（BIOS / UEFI の RTC 起動は扱わない） |
| 自動で再開したセッションが、作業の途中で PC の再起動（Windows Update など）に遭った | 次のログオンの 1 分後に、そのセッションをもう一度再開する（下記） |

### 再起動で中断した再開セッションの再開

Windows Update の再起動は、スリープの抑止（`SetThreadExecutionState`）に関係なく行われ、再開した claude をターンの途中で終わらせる。そのときの記録は最後がツールの結果などになり、上限の記録ではないので、上の巡回では拾えない。

```
resume-session.ps1 ─ 起動時に state/running/<分岐先の ID>.json を置く（ID は auto-resume.ps1 が決めて --session-id で渡す）
                   └ claude が終われば消す（再起動で強制終了されると残る）
auto-resume.ps1（ログオン時など）
   印が残っている
     ├─ 印より後に OS が起動していない ─▶ プロセスが無ければ利用者が閉じたもの。印を消す（再開しない）
     └─ 印より後に OS が起動した（再起動で中断）
           ├─ 最後の会話が上限の記録       ─▶ 上の巡回に任せる
           ├─ 最後の会話が end_turn（入力待ち）─▶ 作業は終わっていた。再開しない
           ├─ 分岐先の記録が無い          ─▶ 元のセッションから、元の理由でやり直す（元の記録も無ければやめる）
           └─ それ以外（ターンの途中）    ─▶ 新しいウィンドウで claude --resume <分岐先> --fork-session … rebootResumePrompt
```

- 続けて再開し直すのは `maxRebootResumes`（既定 3）回まで
- 扱うのは、この仕組みが再開したセッションだけ。利用者が自分で開いていたセッションは扱わない
- 再起動のあとサインインされないと動かない（タスクはサインイン中の利用者として動く）。Windows の「更新後にサインイン情報を使ってセットアップを自動的に完了する」が有効なら、更新の再起動のあと自動でサインインされる

対象にしないもの:

- 上限のあとに利用者が入力した、または Claude Code 側で再開済みのセッション（最後の会話の記録が上限の記録でなくなる）
  - バックグラウンドのサブエージェントの通知（`<task-notification>`）など、Claude Code が差し込む `user` の記録は、利用者の入力に数えない。サブエージェントを動かしている間に上限で止まったセッションも再開する
- `claude -p` など対話でないセッション（記録の `entrypoint` が `cli` でない）
- 止まってから `maxAgeHours`（既定 192 時間）を過ぎたセッション、`excludeCwd` に当たるディレクトリのセッション
- 処理済みのもの（上限の記録の ID ごとに `state/handled.json` に覚える）

再開したセッションがまた上限に当たれば、その記録に新しい上限の記録が付き、次の解除時刻にもう一度処理する。

### 上限で止まったらスリープする (任意。`install.ps1 -EnableSleepOnLimit`)

```
上限で停止 ─▶ Claude Code の StopFailure フック (matcher: rate_limit) ─▶ sleep-on-limit.ps1 (すぐ終わる)
                │  sleep-prompt.ps1 を別のプロセスで起動
                ├─ セッション記録の最後の会話が usage_limit_reached でなければ (一時的な 429 など) 何もしない
                ├─ 解除まで sleepMinMinutes (既定 15 分) 未満なら何もしない
                ├─ auto-resume.ps1 を実行し、解除時刻 + 3 分に復帰するタスク ClaudeAutoResume-Wake を登録
                └─ 確認の画面 (既定 120 秒の残り時間)
                      ├─ 「今すぐスリープ」/ 応答が無いまま時間切れ ─▶ Windows をスリープ (SetSuspendState)
                      └─ 「キャンセル」/ 閉じる ─▶ 何もしない
```

- 確認の画面には、上限の種類・解除時刻・復帰タスクの時刻を出す。復帰タスクが無い・スリープ解除タイマーが無効・バッテリ駆動中なら、その旨も出す (スリープしても解除時刻に起きない場合がある)
- 複数のセッションが同時に上限に当たっても、確認は 1 つ (Mutex)
- 解除時刻に起こされたあとは、既定の `resume` の動作で、新しいウィンドウで続きから再開する（再開した claude が動いている間はスリープさせない）

### ファイル（インストール先、既定 `~/.claude/auto-resume/`）

| ファイル | 役割 |
|---|---|
| `install.ps1` / `uninstall.ps1` | 設定・タスクの登録 / 削除 |
| `auto-resume.ps1` | 巡回の本体。`-DryRun` で判断だけを表示する |
| `keep-awake.ps1` | （`wake`）指定した分だけ PC をスリープさせない。同時に 1 つだけで、後から起動したほうに置き換わる |
| `sleep-on-limit.ps1` | (任意) Claude Code の StopFailure フック。sleep-prompt.ps1 を起動してすぐ終わる |
| `sleep-prompt.ps1` | (任意) 上限の記録の確認・復帰タスクの登録・確認の画面・スリープ。`-DryRun` で判断だけをログに書く |
| `resume-session.ps1` | （`resume`）新しいウィンドウの中で claude を再開する。終わるまで PC をスリープさせない |
| `run-hidden.vbs` | タスクから巡回をウィンドウを出さずに起動する |
| `config.json` | 設定（下表） |
| `state/handled.json` / `logs/auto-resume.log` | 処理済みの記録（14 日で消す） / 実行の記録（1 MB で切り替え） |
| `state/running/<ID>.json` | 再開した claude が動いている印。再起動で中断したかの判断に使う |
| `disabled` | このファイルがあれば何もしない（一時停止） |

| 設定 | 既定値 | 意味 |
|---|---|---|
| `action` | `resume` | 解除後の動作。`resume`: 新しいウィンドウで再開する / `wake`: PC を起こしておくだけ（再開しない）。`install.ps1 -Action` で切り替える |
| `keepAwakeMinutes` | `20` | （`wake`）解除時刻 + `marginMinutes` から、PC をスリープさせない分（1〜240） |
| `sleepOnLimit` | `false` | 上限で止まったら確認のうえスリープする (`-EnableSleepOnLimit` で `true`、`-DisableSleepOnLimit` で `false`) |
| `sleepPromptSeconds` | `120` | スリープするまでの確認の秒数 (応答が無ければスリープ) |
| `sleepMinMinutes` | `15` | 解除までこの分より短ければスリープしない |
| `permissionMode` | `fromSession` | （`resume`）再開時の権限モード。止まったセッションと同じにする。`manual` などに固定もできる |
| `fallbackPermissionMode` | `manual` | （`resume`）セッションの記録にモードが無いとき |
| `forkSession` | `true` | （`resume`）新しいセッション ID に分けて再開する |
| `remoteControl` | `true` | （`resume`）再開した claude を `--remote-control` つきで起動する（起動後に `/remote-control` を実行したのと同じ）。再開は別のセッションになり元のリモート接続は切れるので、スマートフォンの Claude アプリなどから新しいセッションへ接続し直せるようにする |
| `remoteControlName` | `""` | （`resume`）Remote Control のセッション名。空なら `<フォルダー名> (上限後の再開 MM/dd HH:mm)`（再起動からの再開は「再起動後の再開」） |
| `marginMinutes` / `fallbackWaitMinutes` | `3` / `60` | 解除時刻から待つ分 / 解除時刻が記録に無いときに待つ分 |
| `maxAgeHours` | `192` | これより前に止まったセッションは扱わない |
| `excludeCwd` | `[]` | 扱わない作業ディレクトリ（ワイルドカード可） |
| `resumePrompt` | 日本語の指示 | （`resume`）再開時に最初に送る指示 |
| `rebootResumePrompt` | 日本語の指示 | （`resume`）再起動で中断したセッションを再開するときに最初に送る指示 |
| `maxRebootResumes` | `3` | （`resume`）再起動で中断したとき、続けて再開し直す回数の上限 |

既存の `config.json` は `install.ps1` を実行し直しても `action` を変えない（`action` が無ければ `resume` を足す）。前の版の既定の `wake` になっている場合は、`install.ps1 -Action resume` で切り替える（`wake` のままだと、復帰しても再開しない）。

## 使い方

`<skill>` はこのスキルのフォルダ（`.claude/skills/auto-resume-global` または `~/.claude/skills/auto-resume-global`）。インストール後は `~/.claude/auto-resume/` のスクリプトを使う。

| 操作 | コマンド |
|---|---|
| `install` | `pwsh -File <skill>/scripts/install.ps1 [-EnableWakeTimers] [-EnableSleepOnLimit] [-IntervalMinutes 10] [-InstallDir <パス>]` |
| スリープの取り消し | `pwsh -File ~/.claude/auto-resume/install.ps1 -DisableSleepOnLimit` (フックを外し、`sleepOnLimit` を `false` にする) |
| `status` | `pwsh -File ~/.claude/auto-resume/auto-resume.ps1 -DryRun`（何も起動せず、待機中・起こしておく・再開予定のセッションを表示する） |
| `pause` / `resume` | `New-Item ~/.claude/auto-resume/disabled` / `Remove-Item ~/.claude/auto-resume/disabled` |
| `uninstall` | `pwsh -File ~/.claude/auto-resume/uninstall.ps1 [-RestoreWakeTimers]` |

`pwsh` が無ければ `powershell -NoProfile -ExecutionPolicy Bypass -File` で同じように動く（PowerShell 5.1 対応）。管理者権限は不要。

## Claude Code 向けの手順

1. **`install` を頼まれたら**、次を利用者に確かめてから `install.ps1` を実行する（どれも利用者の判断が要る）
   - スリープから復帰させるか（`-EnableWakeTimers`。電源オプションの設定を変える。これが無いと、スリープ中に解除時刻が来ても寝たままで、次に起こしたときに再開する）
   - 上限で止まったら確認のうえスリープするか (`-EnableSleepOnLimit`。~/.claude/settings.json にフックを足す)。スリープさせるなら `-EnableWakeTimers` も要る (起こせないと、解除後に作業が進まない)
   - 解除後の動作 (`action`)。既定の `resume` は新しいウィンドウで再開する。人が見ていない間に、元のセッションと同じ権限モードで作業が進んでよいか（よくなければ `permissionMode` を `manual` にする、または `excludeCwd` に入れる）
2. 実行後に `status`（`-DryRun`）で、上限で止まっているセッションが正しく見えるかを確かめる。上限で止まっているセッションが無ければ「上限で止まっているセッションはありません」と出る
3. **解除後に再開されたセッションでは**（`resume` で新しいウィンドウが開いた場合）、中断時点で何をしていたかを確かめてから続きを行う。同じ作業を二重に行わない（別のウィンドウで続けていないかを、記録・成果物で確かめる）
4. Claude Code の版が変わって検出できなくなったら、実物の上限の記録を確かめ、`auto-resume.ps1` の上限の判定（`$isLimit` と `resetsAt` の読み取り）だけを直す

## 遵守事項

- 【要指示】**`install` と `-EnableWakeTimers` は、利用者の明示的な指示がある場合のみ行う。** タスクの登録と電源設定の変更は、利用者の PC 全体に効く
- 【要指示】**`-EnableSleepOnLimit` は、利用者の明示的な指示がある場合のみ行う。** 利用者の ~/.claude/settings.json を書き換え (控えを state/settings.json.bak に残す)、作業中の PC をスリープさせうる
- 【要指示】**`action` を `resume` にするのは、利用者の指示がある場合のみ。** 人が見ていない間に、新しいウィンドウで作業が進む
- 【要指示】**`permissionMode` を `auto` / `bypassPermissions` などの緩いモードに固定するのは、利用者の指示がある場合のみ。** 既定（`fromSession`）は、利用者が止まる前に選んでいたモードを引き継ぐだけで、緩めはしない
- **無人の再開を、禁止事項や承認の回避手段にしてはならない。** 再開したセッションにも、プロジェクトの CLAUDE.md・ルール・権限設定はそのまま効く
- `--dangerously-skip-permissions` を使わない

## 制約・未検証

- **Windows 専用。** タスク スケジューラ・`SetThreadExecutionState`・Windows Terminal（無ければ PowerShell のウィンドウ）・`powercfg` に依存する
- タスクはログオン中の利用者として動く（`InteractiveToken`）。ロック中も動き、サインアウト中は動かない
- **上限を人為的に起こせないため**、検出から処理までは、実物の上限の記録を写した試験用のセッション記録と、claude を引数を記録する代役に替えた起動で確かめている（解除済み → `wake` は起こしておく・`resume` は再開、解除前 → 待機と復帰タスクの登録、上限のあとに入力あり → 対象外、2 回目の巡回で処理し直さない、`keep-awake.ps1` を 2 つ起動すると先のものが止まる）
- `wake` で起こしておいても、Claude Code は上限の解除後に止まったターンを自分では続けない（2026-11-09 に、スリープから復帰したが再開しなかったことで確かめた）。`wake` は別の仕組みが再開する場合だけに使う。`resume` では、再開した claude が終わるまでスリープを抑止する
- `resume` で、自分で続けるつもりでも、解除時刻 + 3 分を過ぎてから最初の巡回までに元のウィンドウで入力しないと、再開したウィンドウも開く。どちらかを閉じる
- 記録の形 (`apiError` / `apiErrorParams.rate_limit_info.resetsAt`) は Claude Code の内部形式で、版によって変わりうる
- スリープは `StopFailure` フックを持つ版の Claude Code (フックの入力の `error` が `rate_limit`) が要る。確認の画面はログオン中の利用者の画面に出る (ロック中も出るが見えない。応答が無いので時間切れでスリープする)
- スリープは `SetSuspendState` (Suspend)。休止状態を有効にしていると休止状態になることがある。スリープの直前に別の操作をしていても、確認の時間が過ぎればスリープする
- 確認の画面とスリープそのものは、自動の試験では確かめていない (`-DryRun` と `-SimulateClick` で、判断・画面の流れ・ログを確かめている)
