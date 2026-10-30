#!/usr/bin/env bash
# _worker.sh — detach されたワーカー本体。run.sh から nohup で起動される。
# command.txt を実行し、完了時に exit.code（完了マーカー）を書く。直接実行しないこと。
job_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command="$(cat "$job_dir/command.txt")"

# 実処理を実行し、stdout/stderr をログへ。set -e は使わず終了コードを必ず取得する。
bash -c "$command" > "$job_dir/stdout.log" 2> "$job_dir/stderr.log"
code=$?

# 完了状態を確定（exit.code は最後に書く＝完了判定の唯一の根拠）
date '+%Y-%m-%dT%H:%M:%S%z' > "$job_dir/finished.at"
echo "$code" > "$job_dir/exit.code"
