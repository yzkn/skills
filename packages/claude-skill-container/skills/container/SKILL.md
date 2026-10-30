---
name: container
description: "Containerfile / Dockerfile・compose.yaml・.dockerignore を Podman 前提で作成・レビューする（マルチステージ・キャッシュ・非 root・ヘルスチェック）。「コンテナ化して」「Dockerfile を見直して」で自動適用。/container [対象]。K8s・IaC は infra-iac-expert / iac-reviewer。"
license: Apache-2.0
---

# /container スキル — コンテナ定義の作成とレビュー（Podman 前提）

**引数（対象のパス、または依頼内容）:** $ARGUMENTS

アプリケーションをコンテナで動かすための 3 ファイル（`Containerfile` または `Dockerfile`・`compose.yaml`・`.dockerignore`）を作成・レビューする。**この端末は Docker CLI を使わず Podman で運用する**（`~/.claude/CLAUDE.md`「コンテナ運用」）。手順書に `docker ...` とあっても `podman ...` に読み替えて実行し、`docker` コマンドは打たない（deny 設定で止まる）。

> 出典: [docker/skills](https://github.com/docker/skills)（Apache License 2.0、同ディレクトリの `LICENSE`。commit `f791727`）の `docker-project-foundations`・`docker-build-strategies`・`docker-compose-patterns`・`docker-destructive-guardrails` を日本語で書き下ろし、1 スキルに統合した。変更点は [`references/upstream.md`](references/upstream.md)。

## 隣接スキル・エージェントとの棲み分け

| 依頼の実体 | 使うもの |
|---|---|
| コンテナ定義 3 ファイルの作成・レビュー・ビルドの最適化 | **本スキル** |
| Kubernetes マニフェスト・Terraform などのインフラ定義 | `infra-iac-expert`（設計）／ `iac-reviewer`（診断） |
| CI/CD パイプラインとデプロイ手順 | `/deploy-guide`・`cicd-expert` |
| 依存パッケージの CVE・ライセンス | `dependency-auditor` |

## Podman で実測した差異【先に読む】

2026-10-06、この端末（Podman 5.8.5・podman machine は WSL・compose プロバイダは docker-compose v5.3.1）で実測した。

| 項目 | 結果 | 対応 |
|---|---|---|
| `HEALTHCHECK` | 既定の OCI 形式では**警告を出して無視される**（イメージに残らない） | ヘルスチェックを持たせるなら `podman build --format docker` を付ける。または compose 側の `healthcheck:` に書く |
| `RUN --mount=type=cache` | 動作した | 原典どおり使ってよい |
| `COPY --link --chown=<UID>:<GID>` | 動作した | 原典どおり使ってよい |
| `--secret`（`src=` / `env=` とも） | **失敗した**（終了コード 125。ビルドコンテキスト内の一時ファイルのパスが Windows と WSL で混ざる） | この端末ではビルド時の秘密の受け渡しができない前提で設計する。必要ならユーザーに伝え、回避策は未検証として扱う |
| `podman compose config --quiet` | 正しい定義で 0、誤りで 1 を返した | 構文検査に使う |
| `# syntax=docker/dockerfile:1` | 付けてもビルドは成功した | 付けてよい。Podman での効果は確かめていない |

- イメージ名は**完全修飾で書く**（`docker.io/library/postgres:17`）。Podman は短縮名の解決をレジストリ設定に依存する
- rootless が既定のため、権限・ポート・ボリュームの挙動が Docker と異なることがある。失敗しても `sudo` で回避せず、エラーメッセージを読む
- 表に無い BuildKit 固有の機能（`RUN --mount=type=bind`・`--ssh` など）は**未実測**。使う前に小さなビルドで確かめる

## 1. 雛形を作る（コンテナ定義が無いとき）

3 ファイルを必ずそろえる。雛形は [`references/templates.md`](references/templates.md) を Read して使う。

1. **`.dockerignore`** を最初に作る。ビルドコンテキストを小さく保ち、秘密情報を入れないため。`.env`・`**/.npmrc`・鍵ファイルを必ず除外する
2. **`Containerfile`**（既存リポジトリが `Dockerfile` を使っていればその名前に合わせる）
3. **`compose.yaml`**。アプリと依存サービス（DB・キャッシュ・キュー）をまとめて定義する

- DB やキャッシュはホストに入れさせず、compose のサービスとして定義する。ホストへのインストール（`winget install postgresql` 等）を提案しない
- ファイルはプロジェクトのルートに置く。複数サービスを持つ構成だけ、サービスごとのディレクトリを使う
- 最初の雛形は単純に保つ。最適化は §2・§3 で後から行う

## 2. Containerfile の規約

- **マルチステージ**: 各ステージに名前を付ける（`FROM … AS build`）。実行用ステージには小さなベース（`distroless`・`alpine`・`slim`）を使い、成果物だけを `COPY --from=build` で持ち込む
- **レイヤーキャッシュ**: 変更頻度の低い命令から順に並べる。依存定義（`package.json`・`requirements.txt`・`go.mod`）のコピーとインストールを、ソースのコピーより前に置く。パッケージマネージャのキャッシュは `RUN --mount=type=cache,target=<キャッシュ先>` に置く
- **タグを固定する**。`latest` やタグ省略を使わない
- **秘密情報をイメージに入れない**。`ARG`・`ENV` に認証情報を渡さない（`podman history` で読める）。`.npmrc`・`.pypirc`・`.env`・クラウド認証情報・SSH 鍵を `COPY` しない（中間レイヤーとビルドキャッシュに残る）
- **非 root で動かす**。実行用ステージで専用ユーザーを作り、`USER` はファイル操作の後・`ENTRYPOINT` の前に置く。`COPY --link` と `--chown` を併用するときは数値の `UID:GID` を書く
- **イメージを小さくする**。実行用ステージにドキュメント・デバッグツールを入れない
- `WORKDIR` を最初の `COPY`・`RUN` より前に設定する。`ENTRYPOINT` は exec 形式（`["binary"]`）で書く。`EXPOSE` で待ち受けポートを示す

## 3. compose.yaml の規約

- ファイル名は `compose.yaml`。旧名（`docker-compose.yml`）で新規作成しない
- サービス名は役割を表す小文字（`web`・`db`・`cache`）。イメージは完全修飾名でタグを固定する
- **起動順は `depends_on` の `condition: service_healthy` で表す**。条件の無い `depends_on` は「起動した」ことしか保証しない。条件に使うサービスには必ず `healthcheck:` を書く
- DB のヘルスチェックはサービス自身のクライアントを使う（`pg_isready`・`redis-cli ping`・`mysqladmin ping`）。初期値は `interval: 5s`・`timeout: 3s`・`retries: 3`・`start_period: 10s`
- シェルを持たないイメージ（distroless など）には、ツールを足さずにヘルスチェック用のサイドカーを置く（`network_mode: "service:<対象>"`。雛形は `references/templates.md`）
- 永続データは名前付きボリュームに置き、トップレベルの `volumes:` に定義する。バインドマウントは開発時のソース同期だけに使う
- **公開ポートは既定で `127.0.0.1` に限定する**。認証の無いデータストアのポートは公開しない
- **認証情報を `compose.yaml` に直書きしない**（【絶対禁止】。`.claude/rules/security-hardstops.md`）。`env_file:` か変数置換を使い、`.env` を `.gitignore` に入れる。`.env` があり `.env.example` が無ければ、値を消した `.env.example` を作る
- 開発専用の設定（ソースのバインドマウント・デバッグ用ポート）は `compose.override.yaml` に分ける

## 4. 消すコマンドは実行前に確認する

次のコマンドは**データ・イメージ・キャッシュを戻せない形で消す**。実行する前に、何が消えるかを具体的に示してユーザーの確認を得る。「掃除して」「やり直したい」と言われても、まず消さずに済む方法（`compose down` を `-v` なしで実行する、`restart` する）を示す。

- `podman compose down -v`（名前付きボリューム＝DB のデータを消す）・`podman compose rm -v`
- `podman volume rm` / `podman volume prune`
- `podman system prune`（`-a` で未使用イメージ全部、`--volumes` でボリュームも消す）・`podman system reset`（すべて消す）
- `podman image prune -a`・`podman rmi -f`・`podman network prune`・`podman builder prune`
- `podman rm -f` / `podman kill`（**自分がこのセッションで検証用に作ったコンテナ・イメージを、名前を指定して消す場合だけ**確認を省き、消したことを報告する）

Safety Net フック（`.claude/hooks/safety-net.ps1`）も上記を確認ダイアログ（ask）に回す（自分が作った検証用のものでも区別せずダイアログが出る）。ただしフックは安全の担保にしない（fail-open のため）。

## 5. 検証

書いたら次を実行し、**終了コードと要点だけ**を報告する（ビルドログはファイルへ退避する）。

```sh
podman build --pull=never -t <名前>:verify . > build.log 2>&1; echo "exit=$?"   # ベースイメージが手元に無ければ --pull=never を外す（取得の可否をユーザーに確認）
podman image inspect <名前>:verify --format 'user={{.User}} healthcheck={{.HealthCheck}}'
podman image inspect <名前>:verify --format '{{.Size}}'
podman compose config --quiet; echo "exit=$?"   # 解決済みの設定は表示しない（認証情報が出るため）
```

- `user=` が空または `root` なら §2 の非 root 規約に反している
- `--format docker` を付けずに `HEALTHCHECK` を書いた場合、`healthcheck=<nil>` になる（上記の実測）
- 検証用に作ったイメージは、名前を指定して消し、消したことを報告する

## 完了条件

- [ ] 3 ファイルがそろっている（既存構成のレビューでは対象のファイル）
- [ ] `podman build` と `podman compose config --quiet` の終了コードを報告に載せた（実行できなかったものは「未検証」と明記した）
- [ ] 実行ユーザーが root でない
- [ ] 認証情報が Containerfile・compose.yaml・イメージ履歴に含まれていない
- [ ] イメージのタグが固定され、完全修飾名で書かれている
