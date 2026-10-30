# 原典からの改変点（`/container`）

出典: [docker/skills](https://github.com/docker/skills)（Apache License 2.0、`../LICENSE`。commit `f791727`）。採否の経緯は ADR-057。

| # | 改変 | 理由 |
|---|---|---|
| 1 | 4 スキルを 1 スキルに統合し、日本語で書き下ろした | 常時ロードされる `description` の固定費を 1 件分に抑えるため |
| 2 | `docker` を `podman` に読み替え、実測した差異の表を追加した | この端末は Docker CLI を deny しているため |
| 3 | 同梱スクリプト（`verify-*.sh`）・assets を取り込まず、§5 のコマンドと `references/templates.md` に置き換えた | スクリプトが `docker` を呼ぶため動かない |
| 4 | ビルド時の秘密（`--secret`・`--ssh`）の手順を外した | この端末で `--secret` が失敗したため |
| 5 | イメージ名を完全修飾にし、公開ポートの既定を `127.0.0.1` にした | Podman の短縮名解決の差異と、原典の bootstrap checklist の方針に合わせるため |
| 6 | Docker Agent 系 3 件・Docker Sandboxes 系 4 件は取り込んでいない | Docker 製品専用で Podman では使えないため（ADR-057） |
