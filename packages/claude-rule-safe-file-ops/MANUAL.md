# safe-file-ops — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・pandoc |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `docs/text-encoding.md` | 6.8 KB | 詳細編（常時ロードしない参照ドキュメント） |
| `rules/safe-file-ops.md` | 3.7 KB | — |

## 3. 導入手順

```sh
mkdir -p .claude/rules
cp rules/safe-file-ops.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/safe-file-ops.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 4. 内容の構成

（見出し構成の抽出対象なし）

## 5. 導入後の検証

- `/status` か新規セッションで、意図どおりロードされているか

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/rules/safe-file-ops.md` |
| 元の格納先 | `.claude/rules/safe-file-ops.md` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

2026-06-23 に切り分け。**失敗起点の加筆が 2 回ある。** ① 変換ツールと同じツールで検証しても欠落を再現するだけだと判明 → クロスツール検証を必須化 ② 2 日間で 3 件連続した文字コード起因の失敗（ADR-050）→ `check-encoding.py` を名指しする項目を追加。従前は `.claude/hooks/` 配下の PowerShell に限定した BOM の記述しかなかった

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
