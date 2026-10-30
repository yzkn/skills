# design-docs — マニュアル

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
| `LICENSE` | 1.0 KB | ライセンス |
| `rules/design-docs.md` | 5.2 KB | — |

## 3. 導入手順

```sh
mkdir -p .claude/rules
cp rules/design-docs.md .claude/rules/
```

常時適用したい場合は `CLAUDE.md` に `@.claude/rules/design-docs.md` の行を追加する。frontmatter に `paths:` があるルールは `@` 行に**加えない**（加えると常時ロードになり、条件付きの意味が失われる）。

## 4. 内容の構成

本体（`rules/design-docs.md`）の見出し構成:

- 正本と派生物の定義（Single Source of Truth）
- 未確定情報の表記規約
- 日付・データ表記
- Mermaid 図の記述規約
- フェーズ別フォルダの対応（システム開発案件）

## 5. 導入後の検証

- `/status` か新規セッションで、意図どおりロードされているか

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/rules/design-docs.md` |
| 元の格納先 | `.claude/rules/design-docs.md` |
| 出典 | mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

姉妹キット `ppf-pm-kit` との比較調査で、**正本と派生物の定義がなく Markdown 設計書と Office 納品物の二重管理ドリフトを防げない**ことが判明したため新設（ADR-003）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
