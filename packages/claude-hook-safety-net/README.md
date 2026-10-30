# safety-net.ps1

`.claude/rules/` の【絶対禁止】/【要指示】のうち機械的に判定できる操作（`git push`・証跡の編集 / 上書き・`guide/for-human/` の参照・`.env` の読取・再帰的強制削除）をツール実行前に deny / ask する。判定表は `.claude/hooks/README.md`

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code フック |
| 導入先 | `.claude/hooks/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 882bd6b） |

## これは何か

`.claude/rules/` の【絶対禁止】/【要指示】のうち機械的に判定できる操作（`git push`・証跡の編集 / 上書き・`guide/for-human/` の参照・`.env` の読取・再帰的強制削除）をツール実行前に deny / ask する。判定表は `.claude/hooks/README.md`

## なぜ作られたか

**日本の Claude Code コミュニティ事例調査で優先度が高いと判定した項目の実装**（コミット `d8feaef`、2026-07-13。外部コードの流用なし・全て独自実装）。プロンプト記述と `permissions.deny` を補完する多層防御。**導入後に自身のバグが見つかっている**: stdin を UTF-8 と明示していなかったため、日本語入力で JSON 解析に失敗し fail-open で素通りしていた（2026-07-17 に解消）

## 導入

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/safety-net.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

## 収録ファイル

- `hooks/HOOK-SPEC.md`（9.7 KB）
- `hooks/safety-net.ps1`（16.1 KB）
- `settings.snippet.json`（346 B）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/guide-access.md` — 未同梱（別パッケージ `claude-rule-guide-access` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）
- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/skills/anthropics/` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/container/SKILL.md` — 未同梱（別パッケージ `claude-skill-container` に収録）

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
