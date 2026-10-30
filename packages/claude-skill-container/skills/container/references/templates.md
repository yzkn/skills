# コンテナ定義の雛形

`/container` の §1〜§3 から参照する。出典は docker/skills（Apache License 2.0）の assets で、Podman 向けに完全修飾のイメージ名・`127.0.0.1` への公開ポート制限・ビルド時の秘密の削除を加えた。**`<…>` は案件に合わせて置き換える。** 言語のバージョンは案件の固定ファイル（`.nvmrc`・`.python-version` 等）に合わせる。

> 検証状況（2026-10-06）: compose の雛形 3 つは `podman compose config --quiet` で終了コード 0 を確認した。**Containerfile の雛形 2 つは未ビルド**（ベースイメージを取得していない）。使うときは `/container` §5 の手順で必ずビルドする。

## .dockerignore

```gitignore
# バージョン管理・CI・エディタ
.git/
.gitignore
.github/
.vscode/
.idea/

# ドキュメント
*.md
LICENSE
docs/

# コンテナ定義自身
Containerfile*
Dockerfile*
compose*.yaml
.dockerignore

# 秘密情報（多層防御。これに頼らず、そもそも COPY しない）
.env
.env.*
**/.npmrc
**/.pypirc
*.pem
*.key

# 依存・ビルド成果物（ビルドステージで作り直す）
node_modules/
__pycache__/
.venv/
dist/
build/
coverage/
```

## Containerfile — Node.js（マルチステージ・非 root）

```dockerfile
# syntax=docker/dockerfile:1
FROM docker.io/library/node:<版>-alpine AS deps
WORKDIR /src
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

FROM docker.io/library/node:<版>-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM docker.io/library/node:<版>-alpine AS runtime
WORKDIR /app
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser
COPY --from=deps  --chown=1001:1001 /src/node_modules ./node_modules
COPY --from=build --chown=1001:1001 /src/dist ./dist
COPY --from=build --chown=1001:1001 /src/package.json .
USER 1001
EXPOSE 3000
ENTRYPOINT ["node", "dist/index.js"]
```

## Containerfile — Python（仮想環境・非 root）

```dockerfile
# syntax=docker/dockerfile:1
FROM docker.io/library/python:<版>-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
COPY . .

FROM docker.io/library/python:<版>-slim AS runtime
WORKDIR /app
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup appuser
COPY --from=build --chown=1001:1001 /opt/venv /opt/venv
COPY --from=build --chown=1001:1001 /src /app
ENV PATH="/opt/venv/bin:$PATH"
USER 1001
EXPOSE 8000
ENTRYPOINT ["python", "-m", "<パッケージ名>"]
```

## compose.yaml — アプリ + PostgreSQL + Redis

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Containerfile
    ports:
      - "127.0.0.1:8080:8080"        # 既定はループバックのみに公開
    env_file: .env                    # 認証情報はここから読む（.env は .gitignore 済みであること）
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: docker.io/library/postgres:<版>
    env_file: .env                    # POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB を定義する
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 10s
    restart: unless-stopped
    # ports は公開しない。ホストのツールから接続する必要があるときだけ "127.0.0.1:5432:5432"

  cache:
    image: docker.io/library/redis:<版>
    volumes:
      - cache-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 5s
    restart: unless-stopped

volumes:
  db-data:
  cache-data:
```

`.env.example`（値は空のまま配る）:

```dotenv
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=
DATABASE_URL=
REDIS_URL=redis://cache:6379/0
```

## compose.override.yaml — 開発専用

```yaml
services:
  web:
    build:
      target: build                   # ソースを含むステージで動かす
    volumes:
      - ./src:/src/src                # ソースの同期は開発時だけ
    ports:
      - "127.0.0.1:9229:9229"         # デバッガ
    environment:
      LOG_LEVEL: debug
```

## シェルの無いイメージのヘルスチェック（サイドカー）

```yaml
services:
  api:
    build:
      context: .
      target: runtime                 # distroless 等。シェル・curl を持たない
    ports:
      - "127.0.0.1:8080:8080"

  api-health:
    image: docker.io/curlimages/curl:<版>
    network_mode: "service:api"       # api と localhost を共有する
    entrypoint: ["sleep", "infinity"] # ヘルスチェックを実行するため常駐させる
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 45s

  worker:
    build:
      context: .
      target: runtime
    depends_on:
      api-health:                     # api ではなくサイドカーの健全性を待つ
        condition: service_healthy
```
