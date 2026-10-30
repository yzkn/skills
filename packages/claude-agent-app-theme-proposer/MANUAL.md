# app-theme-proposer — マニュアル

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
| `agents/app-theme-proposer.md` | 8.0 KB | — |

## 3. 導入手順

```sh
mkdir -p .claude/agents
cp agents/app-theme-proposer.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 4. 内容の構成

本体（`agents/app-theme-proposer.md`）の見出し構成:

- Step 1: 作業計画（TodoWrite）
- Step 2: ヒアリング（5問）
- Step 3: themes.md 読み込みとテーマ候補抽出
  - フィルタリング（除外ルール）
  - スコアリング（優先度加点）
  - 多様性確保
- Step 4: 比較表 Artifact の生成
  - Artifact に含める情報
  - Artifact レイアウト仕様
- Step 5: 詳細仕様書の生成
  - 5-1: 前提条件・制約事項
  - 5-2: 機能一覧
  - 5-3: データモデル概要
  - 5-4: 画面設計

## 5. 導入後の検証

- Agent ツールの `subagent_type: "app-theme-proposer"` で起動できるか
- `tools` の指定が意図どおりか（**省略すると全ツールを継承する**）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/agents/app-theme-proposer.md` |
| 元の格納先 | `.claude/agents/app-theme-proposer.md` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

2026-06-25 追加（記録なし）。「何を作るか決まっていない」利用者向け。ADR-008・ADR-010 の教育系パターン検討で補完対象として言及されている

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
