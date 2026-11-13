---
name: api-guide
description: RESTful API の設計規約を参照するスキル。API 設計・実装・レビュー時に呼び出す。
---

# /api-guide スキル — API 設計規約

RESTful API を設計・実装・レビューする際の共通規約。GraphQL 等を採用する場合は本スキルを適宜読み替える。

**規約の正本は [`.claude/rules/api-conventions.md`](../../rules/api-conventions.md)（`src/**`・`design/04_detailed_design/**` でパス条件付きロード）** であり、本スキルはその参照ビューである。以下「エンドポイント設計」〜「エラーレスポンス形式」は正本と同内容のため、正本が既にロードされているセッションでは再読不要（`.claude/rules/model-profile.md`）。

## 適用方法

`/api-guide` で直接呼び出せるほか、API の設計・実装・レビュー時に Claude Code が自動参照し、「API 設計規約を参照して」のような依頼でも適用される。

---

<!-- profile:standard-only 以下 3 節は .claude/rules/api-conventions.md（常時適用）と同内容の再掲 -->

## エンドポイント設計

- URL はリソース名（名詞）で表す（動詞は使わない）
  - ✓ `GET /users/{id}`
  - ✗ `GET /getUser/{id}`
- URL は小文字・ケバブケースを使用する（例: `/user-profiles`）
- コレクションには複数形を使用する（例: `/users`、`/orders`）

---

## HTTP ステータスコードの使い分け

| コード | 用途 |
|---|---|
| 200 OK | 正常取得・更新 |
| 201 Created | リソース新規作成 |
| 204 No Content | 削除成功（レスポンスボディなし） |
| 400 Bad Request | リクエスト内容の不備 |
| 401 Unauthorized | 未認証 |
| 403 Forbidden | 認可エラー（認証済みだが権限なし） |
| 404 Not Found | リソース不存在 |
| 409 Conflict | 競合（重複登録等） |
| 500 Internal Server Error | サーバー内部エラー |

---

## エラーレスポンス形式

エラーレスポンスはプロジェクト全体で統一した形式とする（例）:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力内容に誤りがあります",
    "details": [
      { "field": "email", "message": "メールアドレスの形式が正しくありません" }
    ]
  }
}
```

<!-- /profile:standard-only -->

---

## API バージョニング

- URL パスにバージョンを含める（例: `/api/v1/users`）
- 後方互換性のない変更はメジャーバージョンを上げる（`/release-guide` のセマンティックバージョニングに準拠）
