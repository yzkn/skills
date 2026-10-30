# Claude Code カスタム資産パッケージ

[Claude Code](https://docs.claude.com/ja/docs/claude-code/overview) で使うカスタム資産（スキル・サブエージェント・ルール・フック・スクリプト・Git フック）を、**1 項目 = 1 パッケージ**の形でまとめたものです。必要なパッケージだけを選んで、自分のプロジェクトの `.claude/` に取り込めます。

- パッケージの一覧と概要: [INDEX.md](INDEX.md)
- 各パッケージの導入手順・使い方: `packages/<パッケージ名>/README.md`
- 設定・検証手順・既知の制約: `packages/<パッケージ名>/MANUAL.md`

## 収録物の種類

| 種別 | パッケージ名の形 | 導入先 |
|---|---|---|
| スキル | `claude-skill-<名前>` | `.claude/skills/<名前>/` |
| サブエージェント | `claude-agent-<名前>` | `.claude/agents/` |
| ルール | `claude-rule-<名前>` | `.claude/rules/`（`CLAUDE.md` から読み込む） |
| フック | `claude-hook-<名前>` | `.claude/hooks/` と `.claude/settings.json` |
| スクリプト | `claude-script-<名前>` | `.claude/scripts/` |
| Git フック | `claude-githook-pre-commit` | `.githooks/` |

## 使い方（例: スキルを 1 つ導入する）

```sh
# このリポジトリを取得する
git clone <このリポジトリの URL>

# 導入先のプロジェクトルートで、必要なパッケージの資産だけをコピーする
mkdir -p .claude/skills
cp -r <取得先>/packages/claude-skill-<名前>/skills/<名前> .claude/skills/
```

種別ごとの正確な手順（フックの `settings.json` へのマージ、ルールの読み込み設定など）は、各パッケージの `README.md` の「導入」にあります。

## 利用上の注意

- **このパッケージ群は、非公開のプロジェクトテンプレートから機械的に切り出したものです。** 本文中に元テンプレートのディレクトリ構成（`design/`・`task/`・`doc/` など）や、他のパッケージ・元リポジトリのパスへの参照が残っている場合があります。各パッケージの README の「単体利用時の注意」に、参照先の一覧と同梱の有無を載せています
- 本文が挙げる ADR・コミットなどの記録は元リポジトリにあり、公開していません
- 日本語環境・Windows（PowerShell 5.1 / 7.x、Git Bash）で作成・検証しています。PowerShell のフック・スクリプトは Windows 専用です
- **文字コードはすべて UTF-8 です。** `.ps1` は BOM 付き、`.sh` は BOM なし・改行 LF で保存してください（崩れると PowerShell 5.1 で構文エラー、Git Bash で `$'\r': command not found` になります）
- フック・ルールは安全装置ですが、すべての操作を止められるわけではありません。導入前に内容を読み、自分の環境に合うかを確認してください
- 現状のまま（AS IS）提供します。動作の保証やサポートはありません

## ライセンス

- このリポジトリが独自に作成した部分は **Apache License 2.0** です（[LICENSE](LICENSE)。Copyright 2026 YA）
- 第三者由来の資産（MIT・Apache-2.0）は、原典のライセンスファイルを各パッケージ内に同梱しており、そちらが優先します。改変部分の許諾は各パッケージの `LICENSE-KIT` にあります。出典は各パッケージの README の「ライセンス」に記載しています
- パッケージを再配布するときは、同梱の `LICENSE`・`LICENSE-KIT`・`NOTICE` を削除しないでください
