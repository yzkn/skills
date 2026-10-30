# /container — マニュアル

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
| `skills/container/LICENSE` | 11.3 KB | ライセンス |
| `skills/container/SKILL.md` | 10.4 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/container/eval/trigger.json` | 1.9 KB | データ・設定 |
| `skills/container/references/templates.md` | 5.4 KB | — |
| `skills/container/references/upstream.md` | 1.2 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/container .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/container/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/container` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/container`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/container` を名指しする。

## 4. 内容の構成

本体（`skills/container/SKILL.md`）の見出し構成:

- 隣接スキル・エージェントとの棲み分け
- Podman で実測した差異【先に読む】
- 1. 雛形を作る（コンテナ定義が無いとき）
- 2. Containerfile の規約
- 3. compose.yaml の規約
- 4. 消すコマンドは実行前に確認する
- 5. 検証
- 完了条件

## 5. 導入後の検証

- `/container` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/container/` |
| 元の格納先 | `.claude/skills/container/` |
| 出典 | docker/skills, Apache-2.0 |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

外部 3 リポジトリを評価した際に、docker/skills（Apache-2.0）の汎用スキル 3 件（project-foundations・build-strategies・compose-patterns）を 1 スキルに統合し、日本語で書き下ろして取り込んだ（ADR-057）。原典の同梱スクリプトは `docker` を呼び、Docker CLI を deny しているこの端末では動かないため取り込まず、`docker` を `podman` に読み替えてPodman 5.8.5 での実測差異（OCI 形式では `HEALTHCHECK` が無視される・`--secret` が失敗する等）を表にまとめた。Docker 製品専用の 7 件は取り込んでいない。改変点は `references/upstream.md` にある。

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
