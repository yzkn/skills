# /container

Containerfile / Dockerfile・compose.yaml・.dockerignore を Podman 前提で作成・レビューする（マルチステージ・キャッシュ・非 root・ヘルスチェック）。「コンテナ化して」「Dockerfile を見直して」で自動適用。/container [対象]。K8s・IaC は infra-iac-expert / iac-reviewer。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/container/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | docker/skills, Apache-2.0 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット a286b46） |

## これは何か

`Containerfile` / `Dockerfile`・`compose.yaml`・`.dockerignore` を Podman 前提で作成・レビューする（マルチステージ・レイヤーキャッシュ・非 root・タグ固定・ヘルスチェックによる起動順・公開ポートの `127.0.0.1` 限定・認証情報を書かない）。データを消すコマンド（`compose down -v`・`system prune` 等）は実行前に確認する。

## なぜ作られたか

外部 3 リポジトリを評価した際に、docker/skills（Apache-2.0）の汎用スキル 3 件（project-foundations・build-strategies・compose-patterns）を 1 スキルに統合し、日本語で書き下ろして取り込んだ（ADR-057）。原典の同梱スクリプトは `docker` を呼び、Docker CLI を deny しているこの端末では動かないため取り込まず、`docker` を `podman` に読み替えてPodman 5.8.5 での実測差異（OCI 形式では `HEALTHCHECK` が無視される・`--secret` が失敗する等）を表にまとめた。Docker 製品専用の 7 件は取り込んでいない。改変点は `references/upstream.md` にある。

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/container .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/container/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/container` での呼び出しもできない。

## 使い方

`/container` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/container/LICENSE`（11.3 KB）
- `skills/container/SKILL.md`（10.4 KB）
- `skills/container/eval/trigger.json`（1.9 KB）
- `skills/container/references/templates.md`（5.4 KB）
- `skills/container/references/upstream.md`（1.2 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/hooks/safety-net.ps1` — 未同梱（別パッケージ `claude-hook-safety-net` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/deploy-guide`

## ライセンス

同梱の `skills/container/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: docker/skills, Apache-2.0

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
