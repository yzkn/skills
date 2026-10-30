# incident-responder — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | gitleaks |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `agents/incident-responder.md` | 11.5 KB | — |
| `references/incident-responder-reference.md` | 4.4 KB | 参照知識（本体から必要時に Read される） |

## 3. 導入手順

```sh
mkdir -p .claude/agents
cp agents/incident-responder.md .claude/agents/
```

**`.claude/agents/` はフラットに置く**（サブディレクトリを作っても登録機構は再帰的に走査するため、無効化の目的では使えない）。

## 4. 内容の構成

本体（`agents/incident-responder.md`）の見出し構成:

- 入力
- 情報漏えい（認証情報の混入・リポジトリの誤公開）の場合
- 手順
  - Step 1: 作業計画の作成
  - Step 2: ログ・情報の収集
  - Step 3: タイムラインの整理
  - Step 4: 影響範囲の特定
  - Step 5: 根本原因の分析（RCA）
  - Step 6: ポストモーテム文書の作成
  - Step 7: レポートの保存
  - Step 8: 標準出力への要約表示
- 注意事項

## 5. 導入後の検証

- Agent ツールの `subagent_type: "incident-responder"` で起動できるか
- `tools` の指定が意図どおりか（**省略すると全ツールを継承する**）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/agents/incident-responder.md` |
| 元の格納先 | `.claude/agents/incident-responder.md` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

2026-06-24 の一括追加（記録なし）。`debugger` の開発中バグ修正に対し**本番障害の事後分析**を担う

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
