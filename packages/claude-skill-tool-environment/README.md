# /tool-environment

外部コマンドを実行する前に必ず確認する。呼び出し方・格納パス・文字コード・未導入時の導入手順をキャッシュから解決する。「pip が見つからない」「pandoc が無い」「文字化けする」でも参照。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/tool-environment/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 5f3ae03） |

## これは何か

外部コマンドの呼び方・格納パス・文字コード・未導入時の導入手順をキャッシュから解決する（Tier A〜D のツールカタログ）

## なぜ作られたか

**毎セッションの再調査を省くため**（2026-07-27）。参照序列（`~/.claude/CLAUDE.md` の記録 → キャッシュ → 検出スクリプト）を定め、インストールは【要指示】とした

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/tool-environment .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/tool-environment/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/tool-environment` での呼び出しもできない。

## 使い方

`/tool-environment` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/tool-environment/SKILL.md`（12.9 KB）
- `skills/tool-environment/references/cache_schema.md`（8.0 KB）
- `skills/tool-environment/references/official_install.md`（2.2 KB）
- `skills/tool-environment/references/official_install_unix.md`（2.1 KB）
- `skills/tool-environment/references/package_manager_ids.md`（3.2 KB）
- `skills/tool-environment/references/tool_catalog.md`（21.1 KB）
- `skills/tool-environment/references/typical_install_paths.md`（3.7 KB）
- `skills/tool-environment/references/winget_ids.md`（3.8 KB）
- `skills/tool-environment/scripts/detect_unix.sh`（4.9 KB）
- `skills/tool-environment/scripts/detect_windows.ps1`（12.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/text-encoding.md` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/safe-file-ops.md` — 未同梱（別パッケージ `claude-rule-safe-file-ops` に収録）
- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/scripts/pdf/extract_figures.py` — 未同梱（別パッケージ `claude-script-pdf-extract-figures` に収録）
- `.claude/skills/office/SKILL.md` — **同梱**

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
