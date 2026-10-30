# file-lock — マニュアル

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
| `scripts/file-lock.ps1` | 7.2 KB | PowerShell スクリプト（UTF-8 BOM 必須） |

## 3. 導入手順

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 4. 内容の構成

本体（`scripts/file-lock.ps1`）の冒頭の説明コメント:

- file-lock.ps1 — Claude Code が編集・削除すべきでないファイルを OS レベルでロックする
- 仕組み:
- 常駐プロセス（hold アクション）が対象ファイルを
- FileMode.Open / FileAccess.Read / FileShare.Read で開いたまま保持する。
- FileShare.Read により、他プロセスには「読み取りのみ」が許可され、
- 書き込み・削除・リネームは OS レベルで拒否される（Edit/Write ツールも失敗する）。
- 使い方:
- powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 lock <パス> [<パス>...]
- powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 unlock
- powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 status
- hold は lock が内部的に起動する常駐用アクション（直接実行しない）。
- 状態ファイル: .claude/scripts/file-lock.state.json（git 管理外）

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**

## 6. 既知の制約

- **Windows / PowerShell 専用**（PowerShell 5.1 と 7.x で動くよう書かれている）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/scripts/file-lock.ps1` |
| 元の格納先 | `.claude/scripts/file-lock.ps1` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

記録なし（2026-07-04、コミット本文なし）。ロック解除を【要指示】としている点だけが規約側に残っている

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
