# resume-watch — マニュアル

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
| `scripts/_resume-watcher.ps1` | 9.6 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `scripts/resume-watch.ps1` | 21.1 KB | PowerShell スクリプト（UTF-8 BOM 必須） |

## 3. 導入手順

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 4. 内容の構成

本体（`scripts/_resume-watcher.ps1`）の冒頭の説明コメント:

- _resume-watcher.ps1 — セッションリミット(429)の常駐ウォッチャー本体（detach 起動される）
- 役割は 3 つ。
- 1. 自セッションのトランスクリプト .jsonl を追尾し、quotaLimits.status = "rejected" を検出する
- 2. 検出したら解除時刻 resetsAt を state.json へ記録し、中断された指示を intent.md へ写し取り、
- W2（タスクスケジューラのワンショットタスク）を登録する
- 3. 自分でも解除時刻まで待ち（W1）、到達したら resume-watch.ps1 fire を呼ぶ
- W1 と W2 はどちらが先に到達しても構わない（fire 側が排他ロックで二重発火を防ぐ）。
- 検出は「行を JSON として解釈し、トップレベルに quotaLimits があるか」で判定する。
- 文字列一致だけで判定すると、会話の中に 429 レコードの文字列が引用されたときに誤検出する
- （実際に本リポジトリの調査ログがトランスクリプトへ埋め込まれた）。
- 直接呼び出さず、resume-watch.ps1 start から起動する。

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
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/scripts/resume-watch.ps1 / _resume-watcher.ps1` |
| 元の格納先 | `.claude/scripts/resume-watch.ps1 / _resume-watcher.ps1` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

ADR-043。**判定方法そのものが失敗から決まっている**: 文字列一致で `quotaLimits` を探すと、調査ログ中の 429 レコードが会話へ引用されたときに誤検出する（**実際に本リポジトリで発生した**）。そのため行を JSON として解釈し、トップレベルに `quotaLimits` があるかで判定する。二重発火は `.resume/fired/<yyyymmddhhmmss>.lock` の排他生成で防ぐ

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
