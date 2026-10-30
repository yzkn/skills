# owasp-check リファレンス — 詳細チェック観点・レポートフォーマット

owasp-check エージェントから参照されるリファレンス。エージェント定義本体は `.claude/agents/owasp-check.md`。

---

## A01〜A10 詳細チェック観点

各カテゴリの診断を実施する際は、以下の検査パターンに従って対象ファイルを Read・Grep で分析する。

### A01:2021 - Broken Access Control（アクセス制御の不備）

| チェック観点 | 検査パターン |
|---|---|
| 認証なし公開エンドポイント | `@app.route`, `router.get/post/put/delete` に認証デコレータ・ミドルウェアなし |
| 水平権限昇格 | ユーザーID をリクエストから直接受け取り、DB 照合なしに使用 |
| IDOR（オブジェクト参照） | `/api/items/{id}` でアクセス制御なし |
| ディレクトリトラバーサル | ファイルパスにユーザー入力をそのまま使用 |
| 管理機能への無制限アクセス | `/admin`, `/internal`, `/manage` 等へのアクセス制御なし |

### A02:2021 - Cryptographic Failures（暗号化の失敗）

| チェック観点 | 検査パターン |
|---|---|
| 平文での機密データ送受信 | HTTP（非 HTTPS）の使用、`http://` ハードコーディング |
| 脆弱な暗号アルゴリズム | MD5, SHA1, DES, RC4, ECB モード |
| 暗号化されていないデータ保存 | パスワード・クレデンシャルの平文保存 |
| 弱いランダム生成 | `Math.random()`, `random.random()` をセキュリティ目的で使用 |
| ハードコードされた秘密鍵 | `secret_key`, `private_key`, `password` 等の変数に直値 |

### A03:2021 - Injection（インジェクション）

| チェック観点 | 検査パターン |
|---|---|
| SQL インジェクション | 文字列結合・f-string での SQL 構築、プレースホルダ未使用 |
| OS コマンドインジェクション | `subprocess`, `os.system`, `exec`, `eval` にユーザー入力 |
| LDAP インジェクション | LDAP フィルタへの未サニタイズ入力 |
| XSS（反射型・格納型） | `innerHTML`, `dangerouslySetInnerHTML`, `document.write` へのユーザー入力 |
| テンプレートインジェクション | `render_template_string`, Jinja2/Twig にユーザー入力を直接渡す |

### A04:2021 - Insecure Design（安全でない設計）

| チェック観点 | 検査パターン |
|---|---|
| レート制限なし | ログイン・パスワードリセット等のエンドポイントにレート制限なし |
| ビジネスロジックの欠陥 | 価格・数量などのバリデーションをクライアント側のみで実施 |
| 安全でない直接オブジェクト公開 | 内部 ID・ファイルパスを直接 API レスポンスに含める |

### A05:2021 - Security Misconfiguration（セキュリティの設定ミス）

| チェック観点 | 検査パターン |
|---|---|
| デバッグモード有効化 | `DEBUG=True`, `debug=true` を本番設定に含む |
| デフォルト認証情報 | `admin/admin`, `root/root`, `password` 等のデフォルト値 |
| 不必要な機能の有効化 | 使用されていないポート・サービス・エンドポイント |
| セキュリティヘッダ未設定 | CORS の `*` 許可、CSP ヘッダなし |
| エラー情報の漏洩 | スタックトレースのユーザー向け表示 |

### A06:2021 - Vulnerable and Outdated Components（脆弱で古いコンポーネント）

| チェック観点 | 検査パターン |
|---|---|
| 依存関係ファイルの確認 | `package.json`, `requirements.txt`, `*.csproj`, `go.mod`, `pom.xml` を読み込み、明らかに古いバージョン（EOL）を記録 |
| バージョン固定なし | `*`, `latest` などのバージョン指定 |

### A07:2021 - Identification and Authentication Failures（識別と認証の失敗）

| チェック観点 | 検査パターン |
|---|---|
| 脆弱なパスワードポリシー | 最小長・複雑性の要件なし |
| セッション固定攻撃 | ログイン後のセッション ID 再生成なし |
| 多要素認証なし | 管理者アカウントに MFA なし（設計上明示されている場合） |
| JWT 実装の不備 | `alg: none` 許容、シークレット未検証 |
| セッションタイムアウトなし | 長時間有効なセッション・トークン |

### A08:2021 - Software and Data Integrity Failures（ソフトウェアとデータの整合性の不備）

| チェック観点 | 検査パターン |
|---|---|
| 整合性検証なし | 外部ファイル・パッケージのチェックサム検証なし |
| 安全でない逆シリアル化 | `pickle.loads`, `yaml.load` （SafeLoader 未使用）, `unserialize` にユーザー入力 |
| CI/CD パイプライン保護 | ビルドスクリプト・設定への外部入力 |

### A09:2021 - Security Logging and Monitoring Failures（セキュリティログとモニタリングの失敗）

| チェック観点 | 検査パターン |
|---|---|
| 認証イベントの未記録 | ログイン成功・失敗のログなし |
| 機密情報のログ出力 | パスワード・トークン・PII をログに記録 |
| エラーの握りつぶし | `except: pass`, `catch(e) {}` でエラーをログなしで無視 |

### A10:2021 - Server-Side Request Forgery（SSRF）

| チェック観点 | 検査パターン |
|---|---|
| ユーザー指定 URL へのリクエスト | `requests.get(user_input)`, `fetch(url)` でユーザー入力を URL に使用 |
| 内部 IP・メタデータエンドポイント | 169.254.169.254 等への無制限アクセス |
| URL バリデーションなし | ホワイトリスト検証なし |

---

## レポートフォーマット

レポート生成時（Step 4）は以下のフォーマットに従う。

```markdown
# OWASP Top 10 2021 脆弱性診断レポート

**診断対象:** <パス>
**診断日時:** YYYY-MM-DD HH:MM
**OWASP バージョン:** OWASP Top 10 2021
**診断方式:** 静的解析
**総合リスクレベル:** Critical / High / Medium / Low / 問題なし

---

## エグゼクティブサマリー

<2〜3文で最重要リスクを要約>

### 検出サマリー

| カテゴリ | 検出数 | 最高 CVSS |
|---|---|---|
| A01 Broken Access Control | N | x.x |
| A02 Cryptographic Failures | N | x.x |
| A03 Injection | N | x.x |
| A04 Insecure Design | N | x.x |
| A05 Security Misconfiguration | N | x.x |
| A06 Vulnerable and Outdated Components | N | x.x |
| A07 Identification and Authentication Failures | N | x.x |
| A08 Software and Data Integrity Failures | N | x.x |
| A09 Security Logging and Monitoring Failures | N | x.x |
| A10 Server-Side Request Forgery (SSRF) | N | x.x |

---

## A01:2021 - Broken Access Control

> 検出なし — このカテゴリに該当する問題は見つかりませんでした。

または

### 🔴 Critical (CVSS 9.1) — 認証なし管理エンドポイント

- **ファイル:** `src/api/admin.py:42`
- **コード:** `@app.route('/admin/users', methods=['GET'])`
- **内容:** `/admin/users` エンドポイントに認証ミドルウェアが適用されていない。未認証の攻撃者がすべてのユーザー情報を取得できる。
- **修正方針:** `@require_auth` デコレータを追加し、管理者ロールを確認する

...（各カテゴリを繰り返す）

---

## 診断除外事項

<診断対象外としたファイル・ディレクトリがあれば記載>

---

## 次のアクション

| 優先度 | 対応内容 |
|---|---|
| 即時対応 (Critical) | <対応事項> |
| 優先対応 (High) | <対応事項> |
| 計画対応 (Medium) | <対応事項> |

---

*本レポートは OWASP Top 10 2021 に基づく静的解析による自動診断です。動的テストや専門家によるペネトレーションテストは別途実施してください。*
```
