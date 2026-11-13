# observability-designer リファレンス — タスク種別ごとの詳細設計定義

observability-designer エージェントから参照されるリファレンス。エージェント定義本体は `.claude/agents/observability-designer.md`。
各タスク種別の設計を開始する前に、該当セクションを Read してから作業すること。

---

#### `log-design` — ログ設計書

**ログ設計の原則**

| 原則 | 内容 |
|---|---|
| 構造化ログ | JSON 形式で機械可読にする（テキストログは検索・集計が困難） |
| 相関 ID | リクエスト単位で一意の `trace_id` / `correlation_id` を全ログに付与する |
| 個人情報保護 | PII（氏名・メールアドレス・電話番号）をログに出力しない。必要な場合はマスキングする |
| 適切なレベル | ERROR はオペレーターが対応すべき事象のみ。INFO の乱用を避ける |

**ログレベル定義**

| レベル | 用途 | 例 |
|---|---|---|
| ERROR | サービスに影響するエラー。対応が必要 | DB 接続失敗・外部 API エラー |
| WARN | 正常動作だが注意が必要な事象 | 非推奨 API の使用・リトライ発生 |
| INFO | 正常な業務イベント | リクエスト受信・ユーザー認証成功 |
| DEBUG | 開発・調査用の詳細情報（本番では出力しない） | SQL クエリ内容・変数の値 |

**必須ログフィールド（構造化ログ）**

```json
{
  "timestamp": "2024-06-24T03:15:00.000Z",
  "level": "ERROR",
  "service": "order-service",
  "trace_id": "abc123def456",
  "span_id": "789xyz",
  "message": "Payment API timeout",
  "error_code": "E_PAYMENT_TIMEOUT",
  "duration_ms": 30000,
  "user_id": "usr_***masked***"
}
```

**保存・保持ポリシー**

| ログ種別 | 保持期間 | ストレージ |
|---|---|---|
| アクセスログ | 90日 | コールドストレージ |
| アプリケーションログ（INFO以上） | 30日 | ウォームストレージ |
| エラーログ（ERROR以上） | 1年 | ウォームストレージ |
| 監査ログ | 5年（法令対応） | アーカイブ |

成果物: `design/08_operations/YYYYMMDD_log-design_<テーマ>.md`

---

#### `metrics-design` — メトリクス設計書

**RED メソッド**（リクエスト型サービスの基本指標）

| 指標 | 説明 | 収集方法 |
|---|---|---|
| Rate（リクエスト率） | 秒あたりのリクエスト数（RPS） | カウンター |
| Errors（エラー率） | エラーレスポンスの割合（%） | カウンター |
| Duration（レイテンシ） | リクエスト処理時間（p50/p95/p99） | ヒストグラム |

**USE メソッド**（リソース型の基本指標）

| 指標 | 説明 |
|---|---|
| Utilization（使用率） | CPU・メモリ・ディスクの使用率（%） |
| Saturation（飽和度） | キュー長・接続プール使用率 |
| Errors（エラー数） | ハードウェアエラー・OS エラー |

**カスタムビジネスメトリクス**（プロジェクトに応じて設計）

```
例:
- orders_created_total（注文作成数）
- payment_success_rate（決済成功率）
- active_users_gauge（アクティブユーザー数）
```

**メトリクスの命名規則**（Prometheus 標準）

```
<namespace>_<subsystem>_<name>_<unit>
例: app_http_request_duration_seconds
    app_db_query_total
    app_cache_hit_ratio
```

成果物: `design/08_operations/YYYYMMDD_metrics-design_<テーマ>.md`

---

#### `alert-design` — アラートルール定義書

**アラート設計の原則**

| 原則 | 内容 |
|---|---|
| 症状ベース | 原因（CPU高騰）ではなく症状（レスポンス遅延）でアラートする |
| アクション可能 | アラートを受けたオペレーターが取るべきアクションが明確 |
| 適切な閾値 | 誤報（False Positive）が多すぎるとアラート疲れを引き起こす |
| エスカレーション | 重大度に応じた通知先・対応時間の定義 |

**重大度定義**

| 重大度 | 定義 | 対応時間の目安 | 通知手段 |
|---|---|---|---|
| P1 Critical | サービス全体の停止・データ損失リスク | 15分以内 | 電話・PagerDuty |
| P2 High | 主要機能の重大な劣化 | 30分以内 | Slack（緊急チャンネル）・メール |
| P3 Medium | 一部機能の劣化・将来的リスク | 営業時間内 | Slack |
| P4 Low | 改善推奨・情報提供 | 次回スプリント | チケット登録 |

**標準アラートルール（Prometheus/Grafana 形式）**

```yaml
groups:
  - name: api_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 2m
        labels:
          severity: P2
        annotations:
          summary: "エラーレート 5% 超過"
          description: "{{ $labels.service }} のエラーレートが {{ $value | humanizePercentage }} です"
          runbook: "https://wiki/runbook/high-error-rate"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: P2
        annotations:
          summary: "p95 レイテンシ 2秒超過"
```

**ランブックの必須記載事項**

アラートごとに Runbook を用意する。最低限以下を記載する。

1. アラートの意味（何が起きているか）
2. 確認すべきダッシュボード・ログクエリ
3. 一般的な原因と確認手順
4. 暫定対応（スケールアウト・サービス再起動等）
5. エスカレーション先

成果物: `design/08_operations/YYYYMMDD_alert-design_<テーマ>.md`

---

#### `trace-design` — 分散トレーシング設計書

マイクロサービス構成の場合に適用する。モノリスの場合は「ログ内での trace_id 伝播」として設計する。

**スパン設計の観点**

| 観点 | 内容 |
|---|---|
| スパン粒度 | 外部 I/O（DB・外部API・キュー）単位でスパンを作成する |
| 属性（Attributes） | `http.method`・`db.statement`（クエリ概要のみ）・`error` 等を付与 |
| イベント | エラー発生時刻・リトライ回数等の重要な時点を Event として記録 |
| バゲッジ | サービス間で伝播すべきコンテキスト（テナントID・ユーザーID等） |

**サンプリング方針**

| 方式 | 適用場面 |
|---|---|
| Head-based（固定率） | 開発・ステージング環境（100%）、本番低トラフィック（10%） |
| Tail-based（結果ベース） | 本番高トラフィック環境。エラー・高レイテンシのみ 100% 収集 |
| Always-on for errors | エラーが発生したトレースは必ず収集 |

**OpenTelemetry 計装方針**（ツール非依存の標準）

```
計装レイヤー:
1. 自動計装（Auto-instrumentation）: HTTP・DB・キューの計装は SDK の自動計装を使用
2. 手動計装（Manual instrumentation）: ビジネスロジックの重要箇所に手動でスパンを追加
3. カスタム属性: ビジネス固有の情報（order_id・tenant_id 等）を属性として付与
```

成果物: `design/08_operations/YYYYMMDD_trace-design_<テーマ>.md`

