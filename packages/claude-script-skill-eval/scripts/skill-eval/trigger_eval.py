#!/usr/bin/env python3
"""スキルのトリガー精度（発動すべきときに発動し、すべきでないときに発動しないか）を測る。

`.claude/skills/<skill>/eval/trigger.json` のケースごとに `claude -p` を実行し、
対象スキルが発動したかを判定する。**判定はストリームの最初のツール選択で打ち切る**ため、
1 ケースあたりの消費は最小限で済む。

  # 実行計画とフィクスチャの検証だけ（claude を起動しない・課金なし）
  python .claude/scripts/skill-eval/trigger_eval.py --skill newcomer-guide --dry-run

  # 実測（claude -p を ケース数 x --runs 回 起動する。実行前にユーザーの承認を得ること）
  python .claude/scripts/skill-eval/trigger_eval.py --skill newcomer-guide --runs 3

Windows 対応: skill-creator の run_eval.py は `select.select()` をパイプに使うため
WinError 10038 で動かない。本ハーネスはリーダースレッド + キューで読むため動作する
（背景は .claude/docs/windows-python-tooling.md）。子プロセスを一切起動しない
handoff 方式は同ディレクトリの handoff_eval.py を使う。

出力: report/skill-eval/<日時>_<スキル>.json（全ケース）と .md（要約）。
"""

import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

for _s in (sys.stdout, sys.stderr):  # cp932 コンソールでも日本語を出す
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8")

REPO = Path(__file__).resolve().parents[3]
OUT_DIR = REPO / "report" / "skill-eval"


def die(msg, code=1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def fixtures_path(skill, override=None):
    return Path(override) if override else REPO / ".claude" / "skills" / skill / "eval" / "trigger.json"


def load_cases(path):
    if not path.exists():
        die(f"フィクスチャがありません: {path}\n"
            f"       規約は .claude/docs/authoring-guide.md「トリガー精度の評価」を参照")
    try:
        cases = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        die(f"フィクスチャの JSON が壊れています: {path}（{e}）")
    if not isinstance(cases, list) or not cases:
        die(f"フィクスチャは 1 件以上の配列である必要があります: {path}")
    for i, c in enumerate(cases):
        if "query" not in c or "should_trigger" not in c:
            die(f"{path} の {i} 番目に query / should_trigger がありません")
        if not isinstance(c["should_trigger"], bool):
            die(f"{path} の {i} 番目の should_trigger が真偽値ではありません")
    return cases


# --- 1 ケースの実行 ---------------------------------------------------------

def _reader(stdout, q):
    try:
        for raw in iter(stdout.readline, b""):
            q.put(raw)
    finally:
        q.put(None)  # sentinel: ストリーム終了


def run_one(query, skill, timeout, model):
    """このクエリで対象スキルが発動したら True。最初のツール選択が分かった時点で打ち切る。"""
    def matches(name):
        return skill in (name or "")

    cmd = ["claude", "-p", query, "--output-format", "stream-json",
           "--verbose", "--include-partial-messages"]
    if model:
        cmd += ["--model", model]
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               cwd=str(REPO), env=env)
    q: "queue.Queue" = queue.Queue()
    threading.Thread(target=_reader, args=(process.stdout, q), daemon=True).start()

    pending_tool, acc, result, start = None, "", None, time.time()
    try:
        while time.time() - start < timeout:
            try:
                raw = q.get(timeout=1.0)
            except queue.Empty:
                if process.poll() is not None:
                    break
                continue
            if raw is None:
                break
            line = raw.decode("utf-8", errors="replace").strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            etype = event.get("type")
            if etype == "stream_event":
                se = event.get("event", {})
                st = se.get("type", "")
                if st == "content_block_start":
                    cb = se.get("content_block", {})
                    if cb.get("type") == "tool_use":
                        tname = cb.get("name", "")
                        if tname in ("Skill", "Read"):
                            # content_block_start の時点で input が完結して配信される
                            # ことがある（その場合 input_json_delta は来ない）。acc を
                            # 空で初期化すると content_block_stop で matches("") = False
                            # となり、実際には発動していても不発動と誤判定する。
                            pending_tool = tname
                            acc = json.dumps(cb.get("input") or {}, ensure_ascii=False)
                            if matches(acc):
                                result = True
                                break
                        else:  # 別のツールを選んだ = このスキルは発動しなかった
                            result = False
                            break
                elif st == "content_block_delta" and pending_tool:
                    delta = se.get("delta", {})
                    if delta.get("type") == "input_json_delta":
                        acc += delta.get("partial_json", "")
                        if matches(acc):
                            result = True
                            break
                elif st in ("content_block_stop", "message_stop"):
                    if pending_tool:
                        result = matches(acc)
                        break
                    # message_stop を「不発動」の根拠にしてはならない。Claude は
                    # ツール呼び出しの前に短い前置きテキストだけのメッセージを返す
                    # ことがあり、その message_stop で打ち切ると、次のメッセージに
                    # ある Skill 呼び出しを見ずに不発動と誤判定する（前置きが出るか
                    # は揺れるため、少数ケースでは通り多数ケースで全滅する形で現れる）。
                    # 判定を確定させるのは「別のツールが実際に選ばれたとき」と
                    # 「result イベント / ストリーム終了」だけにする。
            elif etype == "assistant":
                # --include-partial-messages では tool_use が確定する前に
                # 部分スナップショット（thinking のみ等）が来る。含まれない
                # ことを「不発動」と判定してはならない。一致したときだけ確定する。
                for item in event.get("message", {}).get("content", []):
                    if item.get("type") != "tool_use":
                        continue
                    tin = item.get("input", {})
                    if item.get("name") == "Skill" and matches(tin.get("skill", "")):
                        result = True
                    elif item.get("name") == "Read" and matches(tin.get("file_path", "")):
                        result = True
                if result:
                    break
            elif etype == "result":  # 最後まで発動しなかった
                break
    finally:
        if process.poll() is None:
            process.kill()
            try:
                process.wait(timeout=5)
            except Exception:
                pass
    return bool(result)


# --- 集計とレポート ---------------------------------------------------------

def summarize(ordered):
    tp = [r for r in ordered if r["should_trigger"]]
    tn = [r for r in ordered if not r["should_trigger"]]
    return {
        "total": len(ordered),
        "passed": sum(1 for r in ordered if r["pass"]),
        "failed": sum(1 for r in ordered if not r["pass"]),
        "should_trigger_passed": sum(1 for r in tp if r["pass"]),
        "should_trigger_total": len(tp),
        "should_not_trigger_passed": sum(1 for r in tn if r["pass"]),
        "should_not_trigger_total": len(tn),
    }


def write_report(skill, args, ordered, summary, stamp):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    base = OUT_DIR / f"{stamp}_{skill}"
    base.with_suffix(".json").write_text(
        json.dumps({"skill": skill, "runs": args.runs, "model": args.model,
                    "summary": summary, "results": ordered},
                   ensure_ascii=False, indent=2), encoding="utf-8")

    fails = [r for r in ordered if not r["pass"]]
    lines = [
        f"# トリガー精度評価: {skill}", "",
        f"- 実施: {stamp} / 試行 {args.runs} 回 / モデル: {args.model or '既定'}",
        f"- 判定: 発動率 0.5 以上を「発動した」とみなす", "",
        "| 指標 | 値 |", "|---|---:|",
        f"| 合格 | {summary['passed']} / {summary['total']} |",
        f"| 発動すべきケース | {summary['should_trigger_passed']} / {summary['should_trigger_total']} |",
        f"| 発動すべきでないケース | {summary['should_not_trigger_passed']} / {summary['should_not_trigger_total']} |",
        "",
    ]
    if fails:
        lines += ["## 不合格ケース", "", "| 期待 | 発動率 | クエリ |", "|---|---:|---|"]
        lines += [f"| {'発動' if r['should_trigger'] else '不発動'} | {r['trigger_rate']:.2f} | "
                  f"{r['query'][:60].replace(chr(10), ' ')} |" for r in fails]
    else:
        lines.append("不合格ケースなし。")
    base.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return base


def main():
    ap = argparse.ArgumentParser(description="スキルのトリガー精度を測る")
    ap.add_argument("--skill", required=True, help="対象スキル名（.claude/skills/<name>/）")
    ap.add_argument("--fixtures", help="既定は .claude/skills/<skill>/eval/trigger.json")
    ap.add_argument("--runs", type=int, default=3, help="1 ケースあたりの試行回数")
    ap.add_argument("--workers", type=int, default=4, help="並列数")
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--model", help="claude --model に渡す値（既定はセッションの既定）")
    ap.add_argument("--dry-run", action="store_true",
                    help="claude を起動せず、フィクスチャの検証と実行計画だけを出す")
    args = ap.parse_args()

    path = fixtures_path(args.skill, args.fixtures)
    cases = load_cases(path)
    n_trig = sum(1 for c in cases if c["should_trigger"])
    print(f"対象スキル: {args.skill}")
    print(f"フィクスチャ: {path}")
    print(f"ケース: {len(cases)} 件（発動すべき {n_trig} / すべきでない {len(cases) - n_trig}）")
    print(f"起動回数: {len(cases)} x {args.runs} = {len(cases) * args.runs} 回の `claude -p`")

    if args.dry_run:
        print("dry-run のため実行しません。フィクスチャの形式は妥当です")
        return

    if not (REPO / ".claude" / "skills" / args.skill).is_dir():
        die(f"スキルが見つかりません: .claude/skills/{args.skill}/（退避中の場合は戻してから測る）")

    def score(item):
        hits = sum(1 for _ in range(args.runs)
                   if run_one(item["query"], args.skill, args.timeout, args.model))
        rate = hits / args.runs
        return {"query": item["query"], "should_trigger": item["should_trigger"],
                # 循環小数をそのまま書くと小数部が 16 桁になり、gitleaks の
                # credit-card ルール（\d{4}[ -]?...×4）に誤検知されてレポートを
                # コミットできなくなる。判定は triggers / runs から再現できるので丸める。
                "triggers": hits, "runs": args.runs, "trigger_rate": round(rate, 3),
                "pass": (rate >= 0.5) if item["should_trigger"] else (rate < 0.5)}

    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(score, it): i for i, it in enumerate(cases)}
        for done, fut in enumerate(as_completed(futs), 1):
            results.append((futs[fut], fut.result()))
            r = results[-1][1]
            print(f"[{done}/{len(cases)}] {'PASS' if r['pass'] else 'FAIL'} "
                  f"({'trigger' if r['should_trigger'] else 'no-trig'}) "
                  f"rate={r['trigger_rate']:.2f} :: {r['query'][:50]}", file=sys.stderr, flush=True)

    ordered = [r for _, r in sorted(results, key=lambda x: x[0])]
    summary = summarize(ordered)
    base = write_report(args.skill, args, ordered, summary,
                        datetime.now().strftime("%Y%m%d_%H%M%S"))
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"\nsaved: {base.with_suffix('.md')}")
    sys.exit(0 if summary["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
