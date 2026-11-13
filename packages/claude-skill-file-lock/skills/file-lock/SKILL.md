---
name: file-lock
description: "編集・削除すべきでないファイルを OS レベルでロック・解除・状態確認する。「ファイルをロックして」「編集禁止にして」「ロックを解除して」で自動適用。/file-lock <lock|unlock|status> [パス...]。"
---

# /file-lock スキル — ファイルの編集・削除ロック

`.claude/scripts/file-lock.ps1` を実行し、指定ファイルを OS レベルでロックする。

## 仕組み

常駐 PowerShell プロセスが対象ファイルを `FileMode.Open` / `FileAccess.Read` / **`[System.IO.FileShare]::Read`** で開いたまま保持する。FileShare.Read により他プロセスには**読み取りのみが許可**され、書き込み・削除・リネームは OS が拒否する。

- Claude Code の **Read ツールでの参照は可能**（読み取りは共有される）
- Claude Code の **Edit / Write / 削除は OS レベルで失敗**する（ルール遵守に依存しない物理的な保護）
- ロックは常駐プロセスが生きている間のみ有効。**PC 再起動・プロセス終了で解除される**（永続的な保護には ACL や読み取り専用属性を検討する）

## 使い方

| 操作 | コマンド |
|---|---|
| ロック | `/file-lock lock <パス> [<パス>...]` |
| 全解除 | `/file-lock unlock` |
| 状態確認 | `/file-lock status` |

## 実行手順（Claude Code 向け）

Bash ツールで以下を実行する（アクションと引数は依頼に応じて置き換える）。

```sh
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 lock <パス1> <パス2>
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 unlock
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 status
```

- `lock` は既存ロックに指定ファイルを**追加マージ**する（常駐プロセスを再起動して引き継ぐ）
- `unlock` は**全ファイル**のロックを一括解除する（個別解除が必要な場合は unlock 後に残したいファイルを再 lock する）
- 実行後は出力の `[ロック]` / `[失敗]` 表示で結果を確認し、失敗があればユーザーに報告する
- ロック状態は `.claude/scripts/file-lock.state.json`（git 管理外）に記録される

## 遵守事項

- **ロックされたファイルへの Edit / Write が失敗した場合、ロック解除による回避を独断で行わない**。ロックは「ユーザーが変更を禁止した」意思表示であり、変更が必要な場合は必ずユーザーに確認して指示を得る
- `unlock` はユーザーの明示的な指示がある場合のみ実行する（【要指示】相当として扱う）
- ロック対象は**ファイルのみ**（ディレクトリは指定不可。配下ファイルを個別に指定する）

## 制約・注意

- ロック中のファイルは `git checkout` / `git stash` / `git merge` 等の**作業ツリー書き換えも失敗**する。git 操作前に必要に応じて解除する
- VS Code 等のエディタからの保存も失敗する（ユーザー自身の編集もブロックされる）
- 常駐プロセスは Windows 専用（`powershell.exe` / `pwsh.exe`）
