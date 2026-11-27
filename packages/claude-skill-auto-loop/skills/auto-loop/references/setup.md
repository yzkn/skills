# setup — この PC の登録

PC（とエージェント）ごとに 1 回行う。何度行っても安全（あるものは残す）。

## 手順

1. **現状を確かめる。** `~/.claude/auto-loop/config.json` があれば読み、`agentId` と `controlRepoPath` を利用者に示す。足りないものだけを進める
2. **指令リポジトリを用意する。** 利用者に、どれかを確かめる
   - すでにある → URL を聞いて clone する（場所は利用者に確かめる。既定の案は、ほかのリポジトリと同じ親フォルダ）
   - これから作る → 手元に作る。リモートの作成と push は**利用者が行う**（スクリプトが最後にコマンドを示す。指令には案件の内情が入るので非公開にする）

     ```
     pwsh -NoProfile -File <scripts>/new-control-repo.ps1 -Path <場所>
     ```
3. **エージェントの ID を決める。** 形は `<PC>-<道具>[-<アカウントや用途>]`（例 `pc1-claude-main`）。指令リポジトリの `roster.md` を読み、**すでにある ID と重ならない**ことを確かめる。利用者に案を示して決めてもらう
4. **導入する。**

   ```
   pwsh -NoProfile -File <scripts>/install.ps1 -AgentId <ID> -ControlRepoPath <場所>
   ```

   スキルを `~/.claude/skills/auto-loop/` に写し（そこから実行しているときは写さない）、`~/.claude/auto-loop/` に設定とフォルダを作る
5. **名簿に足す。** `roster.md` に自分の行を足し、`sync.ps1 -Message 'setup: <ID> を登録'` で送る
6. **自動再開と連携する（任意。利用者の了承を得てから）。** `auto-resume-global` が入っていれば、再開の指示に「`/auto-loop resume` を実行する（担当中のタスクが無ければ `/auto-loop next`）」案内を足す（前の版の案内が入っていれば、置き換える）。グローバルの設定を書き換えるので、変更の内容を示して了承を得る（控えは `~/.claude/auto-loop/state/` に残る）

   ```
   pwsh -NoProfile -File <scripts>/install.ps1 -NoCopy -LinkAutoResume
   ```
7. **起動時・スリープ解除時の自動起動を有効にする（任意。利用者の了承を得てから。Windows 専用）。** 上限で止まったセッションが無くても、ログオン時・スリープ復帰時に、やることがあれば新しいウィンドウでセッションを起こし、`/auto-loop next` を実行させる。タスクスケジューラにタスク `AutoLoopKick` を登録するので、何が起きるか（下の表）を示して了承を得る。`auto-resume-global` が導入済みのときだけ動く

   ```
   pwsh -NoProfile -File <scripts>/install.ps1 -NoCopy -EnableKick     # 止めるときは -DisableKick。一定間隔も使うなら -KickIntervalMinutes 15 など
   pwsh -NoProfile -File <scripts>/kick.ps1 -DryRun                    # 判断だけを見る（起こさない）
   ```

   | `config.json` の `kick` | 既定 | 意味 |
   |---|---|---|
   | `enabled` | `false` | `-EnableKick` で `true` |
   | `minIntervalHours` | `0.5` | 前に起こしてから、次に起こすまでの最短の時間 |
   | `idle` / `idleMinIntervalHours` | `true` / `24` | 通常のタスクが無いとき、手が空いたときの作業のために起こすか・その間隔 |
   | `busyMinutes` | `15` | 手を動かしているセッション（最後の記録が利用者の入力・ツールの結果・ツールの呼び出しで、この分の内に書かれたもの。サブエージェントの記録を含む）があれば、起こさない（共倒れを防ぐ）。入力待ち・指示が無い・上限の解除待ち・この分より長く書かれていないセッションは数えない |
   | `idleCloseMinutes` | `60` | 起こしたセッションの記録がこの分のあいだ書かれなければ、終わらせる（`0` なら終わらせない。その間 PC は眠らず、次も起こせない）。ツールの実行中は `longToolMinutes` まで、`keepOpenSkills`・`keepOpenPhrases` に当たるセッションはいつまでも終わらせない |
   | `longToolMinutes` | `240` | ツールを呼び出し中（結果がまだ無い。試験・ビルドなどの長い実行。権限の確認待ちも同じ形）のセッションは、最後の記録からこの分までは動いているとみなす。`busyMinutes`（ほかのセッションを起こさない）と `idleCloseMinutes`・`settledCloseMinutes`（見張りが終わらせる）の両方に効く（`0` なら `busyMinutes` だけで見る） |
   | `keepOpenSkills` | `['long-run']` | このスキルを使ったセッション（`Skill` の呼び出し・`/<スキル>` と打った記録）は、見張り（`close-watch.ps1`）が終わらせない |
   | `keepOpenPhrases` | `['終了しないで', '終了させないで', '終わらせないで', '閉じないで', 'keep open', 'keep-open', 'do not close', "don't close"]` | 利用者がこう書いたセッション（利用者の入力だけを見る。大文字・小文字は区別しない）は、見張りが終わらせない。止めたいときは、ウィンドウを手で閉じる |
   | `settledCloseMinutes` | `5` | 入力待ちがこの分続き、そのセッションが `claim.ps1` で触れたタスクのどれも手に持っていない（判断待ち `waiting`・マージ待ち `review`・`blocked`・完了 `done`・`dropped`・解放 `ready`）とき、セッションを終わらせ、ウィンドウを閉じる（`0` なら終わらせない。見張りは `close-watch.ps1`）。起こしたセッションは、何も担当しなかったときも終わらせる |
   | `settledCloseResumed` | `true` | `auto-resume-global` が再開したセッションにも、上と同じ見張りを付ける（`kick.ps1` が動くたびに、再開中の印 `state/running/<ID>.json` を見て付ける）。`auto-loop` のタスクに触れていない再開のセッションは終わらせない |
   | `intervalMinutes` | `0` | この分ごとにも `kick.ps1` を起動する（`0` なら使わない。`install.ps1 -NoCopy -EnableKick -KickIntervalMinutes 15` で設定とタスクを一緒に変える）。起こすかの判断は同じで、`minIntervalHours` の内は続けて起こさない（間隔の起動を生かすなら、`minIntervalHours` を間隔以下にする。既定の `0.5` は 30 分の間隔に合う） |
   | `pollMinutes` | `3` | この分ごとに、ダッシュボードの即時実行の印（指令リポジトリの `state/kick/<ID>.json`）を見に行く（`kick-poll.ps1`。タスク `AutoLoopKickPoll`。`git ls-remote` だけの軽い確かめで、先頭が変わったときだけ取り込む。`0` なら見ない。`install.ps1 -NoCopy -EnableKick -KickPollMinutes 3` で設定とタスクを一緒に変える）。印があれば `kick.ps1 -Trigger now` で起こす（`minIntervalHours` は見ない。ほかのセッションが動いている・上限の解除待ちなら印を残して次の見回りでやり直す） |
   | `weeklyAtReset` | `true` | 週の上限の解除時刻の 6 分後に、毎週 PC を起こして `kick.ps1` を起動する（タスク `AutoLoopKickWeekly`。このときは `minIntervalHours` を見ない）。解除時刻が変わったら `kick.ps1` が登録し直す |
   | `weeklyResetAt` | `''` | 週の解除の曜日・時刻を手で決める（例 `Thu 08:00`、`木 8:00`）。空なら、セッションの記録の週の上限（`rateLimitType` が `seven_day` 系）の `resetsAt` から取る（結果は `state/kick-weekly.json`） |
   | `statusEveryMinutes` | `60` | PC の状況（指令リポジトリの `state/pcs/<ID>.json`。判断・理由・セッションの数・次の復帰・週次の起動の時刻・直近 7 日の上限の窓）を、中身が変わらなくてもこの分ごとに書き直す（`0` なら書かない）。このファイルだけをコミットし、作業ツリーにほかの変更が無いときだけ push する。パスは書かない |
   | `permissionMode` / `remoteControl` | `auto` / `true` | 起こすセッションの権限モード・Remote Control |
   | `prompt` | 空 | 最初に送る指示（空なら既定の「`/auto-loop next` を実行」） |

   起こさなかった理由は `~/.claude/auto-loop/logs/auto-loop.log` の `[kick]` の行に残る

   **利用率（5 時間・週）もダッシュボードに出すなら（任意。利用者の承認のうえで）:** `pwsh -NoProfile -File <scripts>/install.ps1 -NoCopy -CaptureUsage`。`~/.claude/settings.json` の `statusLine.command` を `statusline-usage.ps1` に置き換え、元のコマンドを `config.json` の `usage.statusLineCommand` に控える（表示は元のまま。グローバルの設定の書き換えなので、了承を得てから行う。戻すときは `-NoCaptureUsage`）。ステータスラインに渡る JSON の `rate_limits`（Pro・Max の契約で、セッションの最初の応答のあとだけ出る）を `state/usage.json` に書き、`kick.ps1`（判断のたび）と `kick-poll.ps1`（見回りのたび。`kick.pollMinutes` 分ごと。% か解除時刻が変わったときだけ）が PC の状況の `usage` に載せて push する。値は最後にステータスラインが動いた時点のもの（`capturedAt`）。5 時間の窓が切れたあと、次の窓が始まるまでは JSON に `five_hour` が出ないので、その間は前の窓の値を残す（ダッシュボードは、解除時刻を過ぎた窓を読み込み時点の推定の 0% と前の窓の値で出す）
8. **ダッシュボードも用意する（併せて行う）。** 指令リポジトリをブラウザから見て操作するページ（[aiyzkn/loop-control-dashboard](https://github.com/aiyzkn/loop-control-dashboard)。表示・書き換え・並べ替え・依頼の登録・PR のマージ）。データは置かず、利用者のトークンで指令リポジトリを読み書きする。利用者に、どちらかを確かめる
   - 指令リポジトリが `aiyzkn/loop-control` → 公開済みのページ <https://aiyzkn.github.io/loop-control-dashboard/> をそのまま使う。トークンの作り方（ページの右上の「トークン」の中、またはダッシュボードの README の「使い方」）を示す
   - 別の指令リポジトリ → 利用者がダッシュボードをフォークし、`app.js` の `CONFIG`（`org`・`owner`・`repo`）を自分の指令リポジトリに合わせ、GitHub Pages を有効にする（リポジトリの作成・公開の設定は利用者が行う）
   - **トークンは利用者が作り、ページにだけ入れる。** エージェントは作らない・受け取らない・指令リポジトリに書かない
   - 2 台目以降の PC では不要（ページは PC に依らない）。PC の状況（`state/pcs/`）をページに出すには、7 の自動起動を有効にする
9. **確かめる。** `pwsh -NoProfile -File <scripts>/preflight.ps1` を実行し、NG があれば直し方を示す

## 案件を足すとき

1. 指令リポジトリの `templates/project.md` を `projects/<案件>/project.md` に写し、利用者に聞きながら埋める。「リポジトリ」の表（ホスト・リポジトリ・アカウント・本流のリモート・基準ブランチ）は、手元の clone があれば `git remote -v` で**実物を確かめて**書く。リモートが複数あるときは、どれが本流かを利用者に確かめる
2. この PC での clone の場所を `~/.claude/auto-loop/config.json` の `repoPaths` に足す（キーは `"<案件>/<表のキー>"`）
3. `preflight.ps1 -Project <案件>` で確かめ、`sync.ps1` で送る

## 同じ PC で別のエージェント（Copilot など）も使うとき

- 名簿に別の ID を足し、その道具の起動時に環境変数 `AUTO_LOOP_AGENT_ID` で渡す（スクリプトは設定より環境変数を優先する）
- スクリプトを使えない道具は、指令リポジトリの `AGENTS.md` の手順を git で行う

## してはいけないこと

- リモートのリポジトリの作成・公開範囲の変更を、利用者の指示なしに行わない
- ダッシュボードのトークン（GitHub の個人用トークン）を、利用者から受け取らない・どこにも書かない
- 利用者のグローバルの設定（`~/.claude/CLAUDE.md`・`settings.json`・`auto-resume-global` の設定）を、了承なしに書き換えない。タスクスケジューラへの登録（`-EnableKick`）も同じ
