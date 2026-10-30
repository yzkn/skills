# long-run

長時間ジョブのスキャフォールド生成エンジン。`.jobs/<id>/` に run / check / worker スクリプトと手順書を自己完結生成し、OS 側に detach して起動する

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | 共有スクリプト |
| 導入先 | `.claude/scripts/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット a0036a4） |

## これは何か

長時間ジョブのスキャフォールド生成エンジン。`.jobs/<id>/` に run / check / worker スクリプトと手順書を自己完結生成し、OS 側に detach して起動する

## なぜ作られたか

5 時間のセッションリミットや途中中断の影響が大きい処理（ビルド・データ移行・E2E・ベンチマーク）で、直接実行して待機すると中断の影響が大きいため（コミット `dbf542b`、2026-07-22）。完了判定を「プロセス生存＋`exit.code` マーカー」の二段にしたのは、別セッションから再合流できるようにするため

## 導入

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 収録ファイル

- `scripts/long-run.ps1`（6.2 KB）
- `scripts/long-run.sh`（5.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/hooks/job-resume-check.ps1` — 未同梱（別パッケージ `claude-hook-job-resume-check` に収録）
- `.claude/scripts/long-run.ps1` — **同梱**
- `.claude/scripts/long-run.sh` — **同梱**

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
