# pre-commit（gitleaks + 不可視文字検知）

① gitleaks による機密情報検知（`.gitleaks.toml` の 136 行のルール・allowlist を使う。未導入なら終了コード 1 で停止し導入コマンドを表示） ② **不可視 Unicode 文字の検知**（ゼロ幅スペース・Word Joiner・双方向制御文字。絵文字結合に正当に使う ZWJ / ZWNJ は除外）

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Git フック |
| 導入先 | `.githooks/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 466734d） |

## これは何か

① gitleaks による機密情報検知（`.gitleaks.toml` の 136 行のルール・allowlist を使う。未導入なら終了コード 1 で停止し導入コマンドを表示） ② **不可視 Unicode 文字の検知**（ゼロ幅スペース・Word Joiner・双方向制御文字。絵文字結合に正当に使う ZWJ / ZWNJ は除外）

## なぜ作られたか

gitleaks 部分は 2026-06-09 に追加（コミット本文なし）。**不可視文字の検知は Rules File Backdoor 対策**として後から追加した（`CLAUDE.md`・ルールファイルに不可視文字で悪意ある指示を埋め込む攻撃を想定）。有効化は `git config core.hooksPath .githooks`（手順は `SETUP.md`）

## 導入

```sh
mkdir -p .githooks
cp githooks/pre-commit .githooks/
cp .gitleaks.toml .
git config core.hooksPath .githooks
```

**`.sh` 系のフックは改行コードを LF にする**（CRLF だと Git Bash で `$'\r': command not found` になる。`bash -n` は CRLF を通すため構文検査では気づけない）。

## 収録ファイル

- `.gitleaks.toml`（7.1 KB）
- `githooks/pre-commit`（2.2 KB）

## 単体利用時の注意

元リポジトリ固有のパスへの参照は検出されなかった。

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
