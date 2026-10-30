# complexity-analyzer — マニュアル

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
| `agents/complexity-analyzer.md` | 8.5 KB | — |

## 3. 導入手順

```sh
mkdir -p .claude/agents
cp agents/complexity-analyzer.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 4. 内容の構成

本体（`agents/complexity-analyzer.md`）の見出し構成:

- 入力
- 手順
  - Step 1: 作業計画の作成
  - Step 2: 対象ファイルの収集
  - Step 3: 循環的複雑度（Cyclomatic Complexity）の測定
  - Step 4: 認知的複雑度・ネスト深度の測定
  - Step 5: クラス・ファイルサイズの測定
  - Step 6: 変更頻度との掛け合わせ分析
  - Step 7: 改善案の作成
  - 🔴 Critical — 循環的複雑度 45: src/services/payment_service.py:process_payment()
  - Step 8: レポートの生成と保存
- サマリー
- リファクタリング優先度一覧
- 詳細診断結果

## 5. 導入後の検証

- Agent ツールの `subagent_type: "complexity-analyzer"` で起動できるか
- `tools` の指定が意図どおりか（**省略すると全ツールを継承する**）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/agents/complexity-analyzer.md` |
| 元の格納先 | `.claude/agents/complexity-analyzer.md` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

同上（記録なし）。`perf-analyzer` の性能リスクに対し**保守性リスク**を担う役割分担

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
