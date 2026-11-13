---
description: RESTful API の設計規約（エンドポイント命名・HTTP ステータスコード・エラーレスポンス形式・バージョニング）。src/・design/04_detailed_design/ 配下のファイルを扱う際に自動ロードされる。
paths:
  - "src/**"
  - "design/04_detailed_design/**"
---

# API 設計規約（パス条件付き適用）

API コードまたは API 仕様書を書く・修正するすべての場面で、明示的な依頼がなくても遵守する。上記パス以外で API を設計する場合は `/api-guide` スキルで呼び出す。

## エンドポイント命名

- URL はリソース名（**名詞**）で表す。動詞は使わない
  - ✓ `GET /users/{id}`
  - ✗ `GET /getUser/{id}`
- URL は**小文字・ケバブケース**（例: `/user-profiles`）
- コレクションには**複数形**（例: `/users`、`/orders`）

## HTTP ステータスコード

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

## エラーレスポンス形式

プロジェクト全体で統一する。

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

## バージョニング

- URL パスにバージョンを含める（例: `/api/v1/users`）
- 後方互換性のない変更はメジャーバージョンを上げる
