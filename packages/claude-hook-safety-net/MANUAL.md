# safety-net.ps1 — マニュアル

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
| `hooks/safety-net.ps1` | 16.1 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `settings.snippet.json` | 346 B | このフックの登録設定（既存の `hooks` にマージする） |

## 3. 導入手順

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/safety-net.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

### 3-1. `settings.json` への登録

同梱の `settings.snippet.json` は、元リポジトリの `.claude/settings.json` からこのフックの登録部分だけを抜き出したものである。既存の `hooks` に**マージ**する（丸ごと置き換えると他のフックが消える）。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit|Read",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/safety-net.ps1 2>doc/log/error/safety-net-stderr.log"
          }
        ]
      }
    ]
  }
}
```

**stderr のリダイレクト先ディレクトリ（`doc/log/error/`）を先に作る。** 存在しないとフックが起動時に失敗する。

## 4. 内容の構成

本体（`hooks/safety-net.ps1`）の冒頭の説明コメント:

- safety-net.ps1 — PreToolUse フックによる危険操作の機械的ブロック（Safety Net）
- .claude/rules/ の【絶対禁止】/【要指示】ルールのうち、ツール呼び出しから機械的に
- 判定できるものを実行前に deny / ask する多層防御の一層。
- プロンプト（ルール記述）と settings.json の permissions.deny を補完する。
- 判定ロジックは本リポジトリ独自実装（外部リポジトリのコード流用なし）。
- 出力仕様（Claude Code PreToolUse フック）:
- stdout に {"hookSpecificOutput":{"hookEventName":"PreToolUse",
- "permissionDecision":"deny"|"ask","permissionDecisionReason":"..."}} を返すと
- その決定が適用される。何も出力せず exit 0 なら通常の権限フローに従う。
- フック自体の障害でセッションを止めないため、解析失敗時は fail-open（許可）とし
- stderr にのみ記録する。

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
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/hooks/safety-net.ps1` |
| 元の格納先 | `.claude/hooks/safety-net.ps1` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

**日本の Claude Code コミュニティ事例調査で優先度が高いと判定した項目の実装**（コミット `d8feaef`、2026-07-13。外部コードの流用なし・全て独自実装）。プロンプト記述と `permissions.deny` を補完する多層防御。**導入後に自身のバグが見つかっている**: stdin を UTF-8 と明示していなかったため、日本語入力で JSON 解析に失敗し fail-open で素通りしていた（2026-07-17 に解消）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
