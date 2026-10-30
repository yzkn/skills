# security-hardstops — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | なし（Claude Code のみ） |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `rules/security-hardstops.md` | 1.1 KB | — |

## 3. 導入手順

```sh
mkdir -p .claude/rules
cp rules/security-hardstops.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/security-hardstops.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 4. 内容の構成

（見出し構成の抽出対象なし）

## 5. 導入後の検証

- `/status` か新規セッションで、意図どおりロードされているか

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/rules/security-hardstops.md` |
| 元の格納先 | `.claude/rules/security-hardstops.md` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

記録なし（2026-06-23 に既存ルールから切り分け）。後に `/vnl testdata`・`/bulk-ops mask` を代替手段として名指しする形へ改修（ADR-033）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
