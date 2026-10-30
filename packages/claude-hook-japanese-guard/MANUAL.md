# japanese-guard.ps1 — マニュアル

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
| `hooks/japanese-guard.ps1` | 7.1 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `settings.snippet.json` | 282 B | このフックの登録設定（既存の `hooks` にマージする） |

## 3. 導入手順

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/japanese-guard.ps1 .claude/hooks/
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
            "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/japanese-guard.ps1 2>doc/log/error/japanese-guard-stderr.log"
          }
        ]
      }
    ]
  }
}
```

**stderr のリダイレクト先ディレクトリ（`doc/log/error/`）を先に作る。** 存在しないとフックが起動時に失敗する。

## 4. 内容の構成

本体（`hooks/japanese-guard.ps1`）の冒頭の説明コメント:

- japanese-guard.ps1
- Stop hook から呼び出される日本語応答ガード。
- そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら
- {"decision":"block","reason":...} を返し、終了させずに日本語で書き直させる。
- 出典: minorun365/claude-code-japanese-guard（Apache License 2.0）
- Copyright 2026 Minoru Onda
- hooks/japanese-guard.py の判定ロジックを PowerShell へ移植し、以下を変更した。
- - トランスクリプトを末尾から読み、今回のターンの行だけを JSON 解析する（大きな .jsonl で遅くならないように）
- - 障害時は fail-open（何も出力せず exit 0）とし、trace ログにだけ理由を残す
- ライセンス全文: https://www.apache.org/licenses/LICENSE-2.0
- 判定: コードブロック・インラインコード・URL・メールアドレス・Markdown リンクを除いたうえで、
- 英字が MIN_LATIN 字以上、かつ 英字数 > 日本語字数 × RATIO なら英語主体とみなす。

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
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/hooks/japanese-guard.ps1` |
| 元の格納先 | `.claude/hooks/japanese-guard.ps1` |
| 出典 | minorun365/claude-code-japanese-guard, Apache-2.0（Copyright 2026 Minoru Onda） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

外部の資料 15 件を評価した際に採用した唯一のコード移植である（ADR-055）。minorun365/claude-code-japanese-guard（Apache-2.0）の Python 版の判定ロジックをPowerShell へ移植し、トランスクリプトを末尾から読んで今回のターンだけを解析する変更（大きな .jsonl で遅くならないように）と、障害時の fail-open を加えた。導入にあわせて `auto-record.ps1` を修正し、差し戻し後の停止でも記録して書き直した回答を証跡に残すようにした（証跡は実際の応答と一致していることが第一、という判断）。判定ロジックは合成したトランスクリプト 7 ケースで確認したが、実セッションでの動作は未検証である。

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
