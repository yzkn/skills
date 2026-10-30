#!/usr/bin/env python3
"""measure-context.py — セッション開始時に常時ロードされるコンテキスト量を測る。

なぜ必要か:
    トークン削減の改善は、削減前後を数値で比べられないと効果を検証できない
    （`.claude/rules/code-quality.md`「完了の証拠主義」）。本スクリプトは
    ベースラインを機械的に出し、規約違反（description の文字数超過）も検出する。

測る対象は「セッション開始時に必ず読まれるもの」だけに限る:
    1. ルート CLAUDE.md と .claude/CLAUDE.md
    2. ルート CLAUDE.md の `@` 行が指すファイル（常時適用ルール・案件種別）
    3. .claude/rules/*.md のうち `paths:` frontmatter を持たないもの。`@` 行に書かれて
       いなくても常時ロードされる（2026-09-02 実機確認）。「分離したつもりで実は載って
       いる」詳細編を見落とさないため、暗黙のロードとして別枠で報告する
    4. .claude/skills/*/SKILL.md の description（1 階層のみ。_disabled/ は対象外）
    5. .claude/agents/**/*.md の description（配下は再帰的に走査される）

対象に含めないもの（読まれるきっかけが別にあるため）:
    パス条件付きルール・.claude/docs/ の索引・SKILL.md の本文・references/
    （退避先の references/_disabled-agents/ も登録されないため対象外）

使い方:
    python .claude/scripts/measure-context.py
    python .claude/scripts/measure-context.py --json      # 機械可読な出力
    python .claude/scripts/measure-context.py --top 10    # 上位 N 件だけ表示

出力は要約のみを標準出力に載せる（`~/.claude/CLAUDE.md`「トークン経済性」）。
文字数はコンテキスト量の代理指標であり、トークン数そのものではない。
日本語では 1 文字がおおむね 1 トークン前後になるが、正確な換算は行わない。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# authoring-guide.md「スキルファイルの作成規約」が定める description の上限
DESCRIPTION_LIMIT = 200

FRONT_MATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.S)
DESCRIPTION_RE = re.compile(r"^description:\s*(.*?)(?=\n[a-z_-]+:|\Z)", re.S | re.M)
AT_LINE_RE = re.compile(r"^@(\S+)", re.M)
PATHS_RE = re.compile(r"^paths:", re.M)


def repo_root() -> Path:
    """スクリプトの位置からリポジトリルートを決める（.claude/scripts/ の 2 つ上）。"""
    return Path(__file__).resolve().parent.parent.parent


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def extract_description(path: Path) -> str | None:
    """frontmatter の description を取り出す。無ければ None。"""
    text = read_text(path)
    if text is None:
        return None
    fm = FRONT_MATTER_RE.search(text)
    if not fm:
        return None
    m = DESCRIPTION_RE.search(fm.group(1))
    if not m:
        return None
    return m.group(1).strip().strip('"').strip("'")


def is_path_scoped(path: Path) -> bool:
    """frontmatter に `paths:` があるか（＝パス条件付きで、常時ロードされない）。"""
    text = read_text(path)
    if text is None:
        return False
    fm = FRONT_MATTER_RE.search(text)
    return bool(fm and PATHS_RE.search(fm.group(1)))


def collect_always_loaded(root: Path) -> tuple[list[tuple[int, str]], list[str], list[tuple[int, str]]]:
    """常時ロードされるファイルの (文字数, 相対パス)、解決できなかったパス、暗黙ロード分を返す。"""
    entries: list[tuple[int, str]] = []
    missing: list[str] = []

    base_files = [root / "CLAUDE.md", root / ".claude" / "CLAUDE.md"]
    claude_md = read_text(root / "CLAUDE.md")
    if claude_md is None:
        print("エラー: ルートの CLAUDE.md が読めません。", file=sys.stderr)
        raise SystemExit(1)

    # `@` 行はルート CLAUDE.md からの相対パスで書かれている
    at_targets = [root / rel for rel in AT_LINE_RE.findall(claude_md)]

    for path in base_files + at_targets:
        text = read_text(path)
        rel = path.relative_to(root).as_posix()
        if text is None:
            missing.append(rel)
            continue
        entries.append((len(text), rel))

    # `@` 行に無くても、.claude/rules/ 直下で `paths:` を持たないものは常時ロードされる。
    # 詳細編をここへ置くと「分離したのに減らない」状態になるため、別枠で数えて警告する
    at_resolved = {p.resolve() for p in at_targets}
    implicit: list[tuple[int, str]] = []
    for rule_md in sorted((root / ".claude" / "rules").glob("*.md")):
        if rule_md.resolve() in at_resolved or is_path_scoped(rule_md):
            continue
        text = read_text(rule_md)
        if text is None:
            continue
        rel = rule_md.relative_to(root).as_posix()
        implicit.append((len(text), rel))
        entries.append((len(text), rel))

    entries.sort(key=lambda x: -x[0])
    implicit.sort(key=lambda x: -x[0])
    return entries, missing, implicit


def collect_descriptions(
    root: Path,
) -> tuple[list[tuple[int, str]], list[tuple[int, str]], int, int]:
    """スキル・サブエージェントの description と、退避中スキル・エージェントの件数を返す。"""
    skills: list[tuple[int, str]] = []
    # スキル登録機構は 1 階層のみ走査する。_disabled/ と anthropics/ はその対象外
    for skill_md in sorted((root / ".claude" / "skills").glob("*/SKILL.md")):
        desc = extract_description(skill_md)
        if desc is not None:
            skills.append((len(desc), skill_md.parent.name))

    agents: list[tuple[int, str]] = []
    # エージェント登録機構は .claude/agents/ 配下を再帰的に走査する（スキルと違い 1 階層では
    # ない。2026-08-19 実機検証・ADR-021）。サブディレクトリに置いても登録されてしまうため、
    # 計測を実態に合わせて rglob を使う。glob だと「退避したつもりで実は載っている」定義を
    # 見落とし、削減効果を過大に報告することになる
    for agent_md in sorted((root / ".claude" / "agents").rglob("*.md")):
        desc = extract_description(agent_md)
        if desc is not None:
            agents.append((len(desc), agent_md.stem))

    skills_dir = root / ".claude" / "skills" / "_disabled"
    disabled_skills = len(list(skills_dir.glob("*/SKILL.md"))) if skills_dir.is_dir() else 0

    # エージェントの退避先は上記の再帰走査を避けるため .claude/agents/ ツリーの外にある。
    # README.md 等の説明ファイルを数えないよう description を持つものだけを対象にする
    agents_dir = root / ".claude" / "references" / "_disabled-agents"
    disabled_agents = (
        len([p for p in agents_dir.glob("*.md") if extract_description(p) is not None])
        if agents_dir.is_dir()
        else 0
    )

    return skills, agents, disabled_skills, disabled_agents


def build_report(root: Path) -> dict:
    always, missing, implicit = collect_always_loaded(root)
    skills, agents, disabled_skills, disabled_agents = collect_descriptions(root)

    always_total = sum(n for n, _ in always)
    skills_total = sum(n for n, _ in skills)
    agents_total = sum(n for n, _ in agents)
    over = [(n, name) for n, name in skills + agents if n > DESCRIPTION_LIMIT]

    return {
        "always_loaded": {
            "files": always,
            "total": always_total,
            "missing": missing,
            "implicit": implicit,
        },
        "skills": {"count": len(skills), "total": skills_total, "items": skills},
        "agents": {"count": len(agents), "total": agents_total, "items": agents},
        "disabled_skills": disabled_skills,
        "disabled_agents": disabled_agents,
        "description_limit": DESCRIPTION_LIMIT,
        "over_limit": sorted(over, reverse=True),
        "grand_total": always_total + skills_total + agents_total,
    }


def print_report(r: dict, top: int) -> None:
    always = r["always_loaded"]
    print("# 常時コンテキストの計測")
    print("\n文字数はコンテキスト量の代理指標であり、トークン数そのものではない。")

    print(f"\n## 1. 常時ロードされるファイル（{len(always['files'])} 件）\n")
    print("| 文字数 | ファイル |")
    print("|---:|---|")
    for n, rel in always["files"][:top]:
        print(f"| {n:,} | `{rel}` |")
    if len(always["files"]) > top:
        rest = sum(n for n, _ in always["files"][top:])
        print(f"| {rest:,} | （残り {len(always['files']) - top} 件） |")
    print(f"| **{always['total']:,}** | **合計** |")
    if always["missing"]:
        print(f"\n**要確認**: `@` 行が指すファイルが見つかりません: {', '.join(always['missing'])}")
    if always["implicit"]:
        total = sum(n for n, _ in always["implicit"])
        names = ", ".join(f"`{rel}`（{n:,}）" for n, rel in always["implicit"])
        print(
            f"\n**要確認**: `@` 行に無いのに常時ロードされるルールが "
            f"{len(always['implicit'])} 件・計 {total:,} 文字あります: {names}。"
            "\n`.claude/rules/` 直下は `paths:` frontmatter が無いと常時ロードされます。"
            "詳細編なら `.claude/docs/` へ、条件付きルールなら `paths:` の付与を検討してください"
            "（`.claude/docs/authoring-guide.md`「詳細編の置き場所」）。"
        )

    sk, ag = r["skills"], r["agents"]
    print("\n## 2. 常時ロードされる description\n")
    print("| 区分 | 件数 | 文字数 | 平均 |")
    print("|---|---:|---:|---:|")
    print(f"| スキル | {sk['count']} | {sk['total']:,} | {sk['total'] // max(sk['count'], 1)} |")
    print(f"| サブエージェント | {ag['count']} | {ag['total']:,} | {ag['total'] // max(ag['count'], 1)} |")
    print(f"| **小計** | **{sk['count'] + ag['count']}** | **{sk['total'] + ag['total']:,}** | |")

    print(f"\n## 3. 合計\n\n**{r['grand_total']:,} 文字**")
    share = (sk["total"] + ag["total"]) * 100 // max(r["grand_total"], 1)
    print(
        f"\nうち description が {share}%。"
        f"退避中はスキル {r['disabled_skills']} 件・サブエージェント {r['disabled_agents']} 件。"
    )

    if sk["count"]:
        avg = sk["total"] // sk["count"]
        print(
            f"\nスキルを 1 件 `.claude/skills/_disabled/` へ退避するごとに、"
            f"平均 {avg} 文字が毎セッション減る（`SETUP.md`「使わないスキルの退避」）。"
        )
    if ag["count"]:
        avg = ag["total"] // ag["count"]
        print(
            f"\nサブエージェントを 1 件 `.claude/references/_disabled-agents/` へ退避するごとに、"
            f"平均 {avg} 文字が毎セッション減る（`SETUP.md`「使わないサブエージェントの退避」）。"
        )

    print(f"\n## 4. description が {r['description_limit']} 文字を超えているもの\n")
    if not r["over_limit"]:
        print(f"超過なし（規約は `.claude/docs/authoring-guide.md`）。")
    else:
        print(f"{len(r['over_limit'])} 件。規約は `.claude/docs/authoring-guide.md`。\n")
        print("| 文字数 | 名前 |")
        print("|---:|---|")
        for n, name in r["over_limit"]:
            print(f"| {n} | `{name}` |")


def main() -> int:
    ap = argparse.ArgumentParser(description="常時ロードされるコンテキスト量を測る")
    ap.add_argument("--json", action="store_true", help="機械可読な JSON で出力する")
    ap.add_argument("--top", type=int, default=8, help="ファイル一覧に表示する件数（既定 8）")
    args = ap.parse_args()

    report = build_report(repo_root())

    if args.json:
        json.dump(report, sys.stdout, ensure_ascii=False, indent=2)
        print()
    else:
        print_report(report, args.top)

    # description の超過は規約違反なので終了コードで知らせる（lint と同じ扱いにはしない）
    return 1 if report["over_limit"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
