# 長時間ジョブ: {{ID}}

セッションリミット（5時間枠）に強い detach 実行ジョブです。処理は OS 側で自走するため、Claude Code のセッションが切れても継続し、解除後に `check.ps1` で結果を確認できます。

## 実行するコマンド

```
{{COMMAND}}
```

## 使い方（Windows PowerShell）

1. 起動:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "run.ps1"
   ```
2. 状態確認（何度でも・別セッションでも可）:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "check.ps1"
   ```

## 完了判定

- `exit.code` が生成されていれば完了（ファイル内容が終了コード。`0`=成功）
- 実行中は `status.json` の `processId` のプロセスが生存
- プロセス消滅かつ `exit.code` なし = 中断/異常終了 → `stderr.log` を確認

## セッションリミットに当たったら

新しいセッションで `check.ps1` を実行するだけで状態を再確認できます（`run.ps1` の再実行は不要。完了済みなら結果を、実行中なら経過を表示します）。

## 生成物

| ファイル | 内容 |
|---|---|
| command.txt | 実行コマンド（正） |
| run.ps1 / _worker.ps1 / check.ps1 | 起動・ワーカー本体・確認 |
| status.json / stdout.log / stderr.log / exit.code | 実行時に生成される状態・ログ・完了マーカー |

## 後片付け

確認が済んだらこのディレクトリごと削除して構いません（`.jobs/` は `.gitignore` 済み）。
