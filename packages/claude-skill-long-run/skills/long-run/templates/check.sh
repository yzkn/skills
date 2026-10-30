#!/usr/bin/env bash
# check.sh — ジョブ状態を確認する（副作用なし・冪等・別セッションからでも実行可）
job_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==== ジョブ状態 ===="
echo "コマンド : $(cat "$job_dir/command.txt" 2>/dev/null)"
echo "開始     : $(cat "$job_dir/started.at" 2>/dev/null)"

if [ -f "$job_dir/exit.code" ]; then
  code="$(cat "$job_dir/exit.code")"
  if [ "$code" = "0" ]; then echo "状態     : 完了（成功） 終了コード=0"
  else echo "状態     : 完了（失敗） 終了コード=$code"; fi
  echo "完了     : $(cat "$job_dir/finished.at" 2>/dev/null)"
elif [ -f "$job_dir/job.pid" ] && kill -0 "$(cat "$job_dir/job.pid")" 2>/dev/null; then
  echo "状態     : 実行中（PID=$(cat "$job_dir/job.pid")）"
else
  echo "状態     : 中断/異常終了（プロセスが存在せず完了マーカーもありません）"
  echo "           stderr.log を確認してください。"
fi

echo ""
echo "---- stdout.log (末尾20行) ----"; tail -n 20 "$job_dir/stdout.log" 2>/dev/null || echo "(なし)"
echo "---- stderr.log (末尾20行) ----"; tail -n 20 "$job_dir/stderr.log" 2>/dev/null || echo "(なし)"
