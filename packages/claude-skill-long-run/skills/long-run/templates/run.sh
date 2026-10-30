#!/usr/bin/env bash
# run.sh — 長時間ジョブを nohup で detach 起動する（セッションリミット耐性）
# このスクリプトはジョブディレクトリ内で自己完結する。
set -euo pipefail
job_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$job_dir/command.txt" ] || { echo "command.txt が見つかりません" >&2; exit 1; }

# 二重起動ガード（実行中なら何もしない）
if [ -f "$job_dir/job.pid" ] && kill -0 "$(cat "$job_dir/job.pid")" 2>/dev/null && [ ! -f "$job_dir/exit.code" ]; then
  echo "既に実行中です (PID=$(cat "$job_dir/job.pid"))。状態は check.sh で確認してください。"
  exit 0
fi

# 前回の完了マーカーを掃除
rm -f "$job_dir/exit.code"
date '+%Y-%m-%dT%H:%M:%S%z' > "$job_dir/started.at"

# ワーカーを親から切り離して起動（ターミナルを閉じても継続）
nohup bash "$job_dir/_worker.sh" >/dev/null 2>&1 &
worker_pid=$!
echo "$worker_pid" > "$job_dir/job.pid"
disown "$worker_pid" 2>/dev/null || true

echo "起動しました。PID=$worker_pid 開始=$(cat "$job_dir/started.at")"
echo "確認: bash \"$job_dir/check.sh\""
