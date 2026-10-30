# pre-commit（gitleaks + 不可視文字検知） — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | gitleaks |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `.gitleaks.toml` | 7.1 KB | — |
| `githooks/pre-commit` | 2.2 KB | — |

## 3. 導入手順

```sh
mkdir -p .githooks
cp githooks/pre-commit .githooks/
cp .gitleaks.toml .
git config core.hooksPath .githooks
```

**`.sh` 系のフックは改行コードを LF にする**（CRLF だと Git Bash で `$'\r': command not found` になる。`bash -n` は CRLF を通すため構文検査では気づけない）。

## 4. 内容の構成

本体（`githooks/pre-commit`）の冒頭の説明コメント:

- Gitleaks による情報漏洩検知

## 5. 導入後の検証

- （このパッケージに機械的な検証手段はない）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.githooks/pre-commit` |
| 元の格納先 | `.githooks/pre-commit` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

gitleaks 部分は 2026-06-09 に追加（コミット本文なし）。**不可視文字の検知は Rules File Backdoor 対策**として後から追加した（`CLAUDE.md`・ルールファイルに不可視文字で悪意ある指示を埋め込む攻撃を想定）。有効化は `git config core.hooksPath .githooks`（手順は `SETUP.md`）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
