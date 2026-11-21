# status — 全案件の状態の要約

タスクファイルは増えるので、**全文を読まずに**スクリプトの要約を使う。

## 手順

1. 実行する（先に指令リポジトリを取り込む）

   ```
   pwsh -NoProfile -File <scripts>/status.ps1 [-Project <案件>] [-Mine] [-All]
   ```

2. 次の順で、短く報告する
   1. **人の対応が要るもの**: `waiting`（判断・承認待ち。質問の要点を、タスクファイルの「利用者への質問と回答」から 1 行で）、`review`（マージ待ちの PR / MR の URL）、`blocked`（原因と直し方）
   2. 受付（`inbox.md`）の未整理の件数。あれば「整理しますか（`/auto-loop intake`）」と添える
   3. 進行中（`doing`）: 担当と、印からの時間。`stale` の印は「上限の解除待ちか、止まっているかは分からない」と添える（勝手に引き継がない）
   4. 着手できるもの（`ready`）: 自分に合うもの（`assignee` が `any`・自分の ID・自分の道具）を優先度の順に（一覧は、状態ごとに優先度の高い順 → `order` → 古い順に並んでいる）。`priority: urgent` があれば、最初に伝える
   5. 「手が空いた時に実行するタスク」の定義の件数（あれば）
3. 詳しく聞かれたときだけ、該当のタスクファイルを読む

## 読み方

| 印 | 意味 |
|---|---|
| `mine` | 自分（この PC のこのエージェント）が担当 |
| `stale` | `doing` のまま、最後の印から `leaseHours`（既定 24 時間）を超えた |

「この PC で進行中の印」に出るのに一覧で `mine` でないタスクは、担当を失っている（引き継がれた・完了した）。利用者に伝える。

印に「← 別のセッションが作業中」と出るタスクは、同じ PC・同じエージェント ID の別のセッションが手を動かしている（`-Json` では `active[].otherSessionLive`）。このセッションからは claim・heartbeat・release が終了コード 2 で止まる。

`-Json` の `active[].sessionState` は、印に書かれたセッションの状態。`otherSessionLive` は、「生きて手を動かしている」とみなしたものだけが `true` になる（判定は `lib/AutoLoop.psm1` の `Test-SessionLive`・`Get-SessionActivity`）。

| `sessionState` | 意味 | `otherSessionLive` |
|---|---|---|
| `this` | このセッション自身の印 | `false` |
| `working` | 会話の記録の最後が利用者の入力・ツールの結果、またはツールの呼び出し中で、15 分の内に書かれた | `true` |
| `stale` | `working` の形だが、15 分より長く書かれていない（権限の確認待ち・長いツールの実行・異常終了もありうる） | `true` |
| `no-transcript` | 会話の記録が見つからない。プロセスが生きていれば、確かめられないので生きているとみなす | プロセスが生きていれば `true` |
| `waiting-input` | 最後が応答で、ツールの呼び出しが無い（利用者の入力待ち） | `false` |
| `limit` | 最後が利用上限の記録（解除待ち） | `false` |
| `empty` | 会話の記録に中身が無い（起動したが何も指示されていない） | `false` |
| `process-ended` | 印のプロセスが終わっている（番号の使い回しを含む） | `false` |
| `no-session` | 印にセッションが書かれていない | `false` |

`otherSessionLive` が `false` の印は、手放されたものとみなし、同じ PC・同じエージェント ID の別のセッションが続きを引き取れる（claim・heartbeat が止まらない）。
