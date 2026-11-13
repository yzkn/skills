---
name: security-review
description: "現在のブランチの変更差分にセキュリティレビューを実施する。「セキュリティレビューして」「脆弱性チェックして」で自動適用。OWASP Top 10 2021 の診断は owasp-check に委任する。"
---

# /security-review スキル — セキュリティレビュー

現在のブランチの変更差分（または指定パス）に対してセキュリティレビューを実施する。
OWASP Top 10 2021 の診断は `owasp-check` サブエージェントに委任し、結果を統合して報告する。

## 呼び出し方

```
/security-review              # 現在のブランチの変更差分をレビュー
/security-review <パス>       # 指定パスをレビュー
```

---

## 実行手順

### Step 1: 対象の特定

引数 `$ARGUMENTS` を確認する。

- **引数あり（パス指定）**: 指定パスを診断対象とする
- **引数なし**: `git diff --name-only main...HEAD` で変更ファイルの一覧を取得する
  - 変更ファイルが存在しない場合は `git diff --name-only HEAD~1 HEAD` を試みる
  - それでも取得できない場合はユーザーに診断対象パスを確認する

### Step 2: 機密情報の即時チェック（コミット前ガード）

変更ファイルに対して以下のパターンを Grep で確認する。
これは OWASP 診断より先に実施し、重大な漏洩があれば即座に報告する。

```
(password|passwd|secret|api[_\-]?key|token|client[_\-]?secret|bearer|private[_\-]?key|AKIA[0-9A-Z]{16})
```

発見した場合:
1. ファイル名・行番号・該当行をチャットに表示する（実値はマスキング）
2. 「コミット前に除去することを強く推奨します」と警告する
3. その後の Step 3 も続行する（他の診断を止めない）

### Step 3: 診断サブエージェントの並列実行

Agent ツールを使用して `owasp-check` と `riss-ioqeo` を**並列で**呼び出す。
並列呼び出しに失敗した場合・並列実行できない環境の場合は、`owasp-check` → `riss-ioqeo` の順で**順次実行**してよい（両方を必ず実行すること）。

```
// 並列実行（同一メッセージで両方を呼び出す）
Agent({
  subagent_type: 'owasp-check',
  prompt: '<診断対象パスまたはファイル一覧> を診断してください'
})

Agent({
  subagent_type: 'riss-ioqeo',
  prompt: '<診断対象パスまたはファイル一覧> を診断してください'
})
```

- `owasp-check`: OWASP Top 10（A01〜A10）の観点でコード・設定を診断 → `./report/owasp/` に保存
- `riss-ioqeo`: SC-01〜SC-07（セッション管理・CSRF・クリックジャッキング・ヘッダインジェクション・STRIDE・テスト網羅性・インフラ）を診断 → `./report/riss-ioqeo/` に保存
- 各エージェントがそれぞれレポート保存と git コミットを行う（`.claude/rules/git-safety.md` の例外2に基づく）

**条件付き: 依存関係診断（SCA）**

診断対象に依存関係定義ファイル（`package.json` / `requirements.txt` / `pyproject.toml` / `*.csproj` / `pom.xml` / `go.mod` 等）が含まれる場合は、`dependency-auditor` も同一メッセージで並列に呼び出す。

```
Agent({
  subagent_type: 'dependency-auditor',
  prompt: '<依存関係定義ファイルの一覧> を診断してください'
})
```

- `dependency-auditor`: 既知 CVE・ライセンスリスク・EOL パッケージを診断 → `./report/dependency/` に保存

### Step 4: 結果の統合と報告

Step 2・3 の結果をチャット上にまとめて報告する。

```markdown
# セキュリティレビュー結果

**対象:** <パスまたはブランチ差分>
**日時:** YYYY-MM-DD HH:MM

## 機密情報チェック
<問題なし または 発見した項目>

## OWASP Top 10 診断結果（サマリー）
<owasp-check サブエージェントの出力サマリーをここに転記>

## SC診断結果（サマリー）
<riss-ioqeo サブエージェントの出力サマリーをここに転記>

## SCA 診断結果（サマリー）※ dependency-auditor を実行した場合のみ
<dependency-auditor サブエージェントの出力サマリーをここに転記>

## 診断レポート
- OWASP: <./report/owasp/... のファイルパス>
- SC診断: <./report/riss-ioqeo/... のファイルパス>
- SCA: <./report/dependency/... のファイルパス>（実行した場合のみ）

## 推奨アクション
- [ ] <Critical/High の指摘事項への対応>
- [ ] <機密情報が検出された場合の除去>
```

---

## 注意事項

- OWASP Top 10 の観点は `owasp-check` が、SC-01〜SC-07 の観点は `riss-ioqeo` が、依存ライブラリの観点は `dependency-auditor` が担当する。このスキルでは重複した診断を行わない
- `./doc/prompt/`・`./doc/thought/`・`./doc/adr/` は証跡のため診断対象外とする
- 本スキルは静的解析のみを行う。実際の悪用可能性の確認には動的テスト・ペネトレーションテストを別途実施すること
