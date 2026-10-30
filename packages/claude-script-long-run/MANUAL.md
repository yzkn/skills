# long-run — マニュアル

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
| `scripts/long-run.ps1` | 6.2 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `scripts/long-run.sh` | 5.3 KB | シェルスクリプト（BOM 禁止・改行 LF） |

## 3. 導入手順

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 4. 内容の構成

本体（`scripts/long-run.ps1`）の冒頭の説明コメント:

- long-run.ps1 — 長時間ジョブのスキャフォールド生成エンジン（/long-run スキル）
- セッションリミットに強い detach 実行ジョブを .jobs/<id>/ に生成する。
- create: ジョブディレクトリを生成（-Start で即起動。-Intent で完了後にやることを残す）
- list  : 既存ジョブの状態一覧（完了済みで未報告のものに ★未回収 を付す）
- claim : 結果をユーザーへ報告し終えたジョブを回収済みにする（collected マーカーを作る）
- collected マーカーは SessionStart フック（.claude/hooks/job-resume-check.ps1）が参照し、
- 「完了しているが未報告」のジョブがある場合だけ再開を促す。報告前に claim してはならない。

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
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/scripts/long-run.ps1 / long-run.sh` |
| 元の格納先 | `.claude/scripts/long-run.ps1 / long-run.sh` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

5 時間のセッションリミットや途中中断の影響が大きい処理（ビルド・データ移行・E2E・ベンチマーク）で、直接実行して待機すると中断の影響が大きいため（コミット `dbf542b`、2026-07-22）。完了判定を「プロセス生存＋`exit.code` マーカー」の二段にしたのは、別セッションから再合流できるようにするため

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
