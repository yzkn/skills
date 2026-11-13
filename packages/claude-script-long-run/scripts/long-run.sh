#!/usr/bin/env bash
# long-run.sh — 長時間ジョブのスキャフォールド生成エンジン（/long-run スキル）
# セッションリミットに強い detach 実行ジョブを .jobs/<id>/ に生成する。
#   create: ジョブディレクトリを生成（--start で即起動。--intent で完了後にやることを残す）
#   list  : 既存ジョブの状態一覧（完了済みで未報告のものに ★未回収 を付す）
#   claim : 結果をユーザーへ報告し終えたジョブを回収済みにする（collected マーカーを作る）
#
# collected マーカーは SessionStart フックが参照し、「完了しているが未報告」のジョブがある
# 場合だけ再開を促す。報告前に claim してはならない。
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tpl_dir="$script_dir/../skills/long-run/templates"

action="${1:-create}"; shift || true
name="job"; command=""; root=".jobs"; start=0; id=""; intent=""; all=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name)    name="$2"; shift 2;;
    --command) command="$2"; shift 2;;
    --root)    root="$2"; shift 2;;
    --id)      id="$2"; shift 2;;
    --intent)  intent="$2"; shift 2;;
    --all)     all=1; shift;;
    --start)   start=1; shift;;
    *) echo "不明な引数: $1" >&2; shift;;
  esac
done

create_job() {
  [ -n "$command" ] || { echo '--command は必須です（例: --command "npm run build"）' >&2; exit 1; }
  local safe job_id job_dir tpl check_cmd claim_cmd
  safe="$(printf '%s' "$name" | tr -c '[:alnum:]_-' '_')"
  [ -n "$safe" ] || safe="job"
  job_id="$(date '+%Y%m%d_%H%M%S')_${safe}"
  job_dir="$root/$job_id"
  mkdir -p "$job_dir"

  printf '%s' "$command" > "$job_dir/command.txt"
  cp "$tpl_dir/run.sh"    "$job_dir/run.sh"
  cp "$tpl_dir/worker.sh" "$job_dir/_worker.sh"
  cp "$tpl_dir/check.sh"  "$job_dir/check.sh"
  chmod +x "$job_dir/run.sh" "$job_dir/_worker.sh" "$job_dir/check.sh"

  # README: {{ID}} を置換し、コマンド行は sed 破損を避けるため追記で埋め込む
  sed "s|{{ID}}|$job_id|g" "$tpl_dir/README.sh.md" > "$job_dir/README.md"
  { printf '\n## 実行するコマンド\n\n```\n'; cat "$job_dir/command.txt"; printf '\n```\n'; } >> "$job_dir/README.md"

  # 再開意図: 会話履歴を持たない新しいセッションで開き直したときに読ませる。
  # コマンド・意図に任意の文字が入るため、sed ではなく bash のパラメータ展開で置換する。
  [ -n "$intent" ] || intent='（未記入）このジョブの完了後に何をすべきかが記録されていません。README.md と stdout.log を読み、何を依頼されていたかをユーザーに確認してください。'
  check_cmd="bash $root/$job_id/check.sh"
  claim_cmd="bash .claude/scripts/long-run.sh claim --id $job_id"
  tpl="$(cat "$tpl_dir/resume-intent.md")"
  tpl="${tpl//\{\{ID\}\}/$job_id}"
  tpl="${tpl//\{\{INTENT\}\}/$intent}"
  tpl="${tpl//\{\{COMMAND\}\}/$command}"
  tpl="${tpl//\{\{CHECK\}\}/$check_cmd}"
  tpl="${tpl//\{\{CLAIM\}\}/$claim_cmd}"
  printf '%s\n' "$tpl" > "$job_dir/resume-intent.md"

  echo "ジョブを作成しました: $job_dir"
  if [ "$start" -eq 1 ]; then
    bash "$job_dir/run.sh"
  else
    echo "起動: bash \"$job_dir/run.sh\""
  fi
}

list_jobs() {
  [ -d "$root" ] || { echo "ジョブはありません ($root)"; return; }
  local d state mark
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    if [ -f "${d}exit.code" ]; then
      state="完了(code=$(cat "${d}exit.code"))"
    elif [ -f "${d}job.pid" ] && kill -0 "$(cat "${d}job.pid")" 2>/dev/null; then
      state="実行中"
    else
      state="停止/未起動"
    fi
    mark=""
    if [ -f "${d}exit.code" ] && [ ! -f "${d}collected" ]; then mark="  ★未回収"; fi
    echo "$(basename "$d")  [$state]$mark"
  done
}

claim_jobs() {
  [ -d "$root" ] || { echo "ジョブはありません ($root)"; return; }
  local n=0 d stamp
  stamp="$(date '+%Y-%m-%d %H:%M:%S') 回収済み（結果をユーザーへ報告済み）"
  # 未完了のジョブ（exit.code なし）を回収済みにすると、完了後に再開通知が出なくなるため保護する
  if [ "$all" -eq 1 ]; then
    for d in "$root"/*/; do
      [ -d "$d" ] || continue
      if [ ! -f "${d}exit.code" ]; then
        echo "スキップ（未完了。exit.code がありません）: $(basename "$d")"
        continue
      fi
      [ -f "${d}collected" ] && continue
      printf '%s\n' "$stamp" > "${d}collected"
      echo "回収済みにしました: $(basename "$d")"
      n=$((n+1))
    done
  else
    [ -n "$id" ] || { echo '--id <ジョブID> か --all を指定してください' >&2; exit 1; }
    d="$root/$id/"
    [ -d "$d" ] || { echo "ジョブが見つかりません: $d" >&2; exit 1; }
    if [ ! -f "${d}exit.code" ]; then
      echo "スキップ（未完了。exit.code がありません）: $id"
    elif [ ! -f "${d}collected" ]; then
      printf '%s\n' "$stamp" > "${d}collected"
      echo "回収済みにしました: $id"
      n=1
    fi
  fi
  [ "$n" -gt 0 ] || echo '対象はありませんでした（すべて回収済み）'
}

case "$action" in
  create) create_job;;
  list)   list_jobs;;
  claim)  claim_jobs;;
  *) echo "usage: long-run.sh {create|list|claim} [--name N] [--command CMD] [--intent TEXT] [--id ID] [--all] [--root DIR] [--start]" >&2; exit 1;;
esac
