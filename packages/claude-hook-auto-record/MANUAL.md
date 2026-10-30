# auto-record.ps1 — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `hooks/HOOK-SPEC.md` | 9.7 KB | フックの仕様リファレンス（stdin JSON・判定表） |
| `hooks/auto-record.ps1` | 13.4 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `settings.snippet.json` | 276 B | このフックの登録設定（既存の `hooks` にマージする） |

## 3. 導入手順

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/auto-record.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

### 3-1. `settings.json` への登録

同梱の `settings.snippet.json` は、元リポジトリの `.claude/settings.json` からこのフックの登録部分だけを抜き出したものである。既存の `hooks` に**マージ**する（丸ごと置き換えると他のフックが消える）。

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/auto-record.ps1 2>doc/log/error/auto-record-stderr.log"
          }
        ]
      }
    ]
  }
}
```

**stderr のリダイレクト先ディレクトリ（`doc/log/error/`）を先に作る。** 存在しないとフックが起動時に失敗する。

## 4. 内容の構成

本体（`hooks/auto-record.ps1`）の冒頭の説明コメント:

- auto-record.ps1
- Stop hookから呼び出される自動記録スクリプト。
- 各会話ターン終了時に ./doc/prompt/ へ基本的な記録を残す。
- 思考過程の詳細記録は /record スキルを手動で呼び出すこと。

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**
- Claude Code を再起動し、`doc/log/error/` に stderr ログが出ていないか
- **fail-open である**（フックが壊れても処理は続く）ため、「フックがあるから安全」という前提を作らない

## 6. 既知の制約

- **Windows / PowerShell 専用**（PowerShell 5.1 と 7.x で動くよう書かれている）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/hooks/auto-record.ps1` |
| 元の格納先 | `.claude/hooks/auto-record.ps1` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

初期構成（2026-06-02）。**その後 2 件の事故で改修している。** ① `git commit -m <msg>` にパス指定が無く、フック起動前にステージされていた 14 ファイルを巻き込んでコミットした（ADR-023）→ `-- <ファイル>` を追加し、失敗理由を `doc/log/error/auto-record-trace.log` に記録するようにした ② `git add` の標準エラーを `2>$null` で捨てていたため、コミット失敗時に真因の手掛かりが残らなかった（ADR-052）→ add の失敗を記録し、失敗したら commit をスキップするようにした

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
