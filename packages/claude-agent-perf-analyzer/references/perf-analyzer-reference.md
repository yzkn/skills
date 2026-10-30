# perf-analyzer リファレンス — 診断観点カタログ・改善案テンプレート・レポートフォーマット

perf-analyzer エージェントから参照されるリファレンス。エージェント定義本体は `.claude/agents/perf-analyzer.md`。

---

## 診断観点カタログ（3-1〜3-7）

各観点の診断前に該当セクションを Read し、記載の Grep パターン・確認方法に従うこと。

#### 3-1: N+1 クエリ問題

ループ内でクエリを実行しているパターンを検出する。

| パターン | Grep 対象 |
|---|---|
| ループ内 ORM 呼び出し（Python/Django） | `for .* in .*:` の直後に `.objects.` / `.filter(` / `.get(` |
| ループ内 ORM 呼び出し（Ruby/Rails） | `each do` / `.each {` の直後に `find` / `where` / `.first` |
| ループ内 ORM 呼び出し（JS/TypeScript） | `for (` / `forEach(` / `.map(` の直後に `await.*find` / `await.*query` |
| ループ内 ORM 呼び出し（Java/Hibernate） | `for (` / `.forEach(` の直後に `findBy` / `repository.` |
| ループ内 Raw SQL | `for` ループ内に `execute(` / `query(` / `SELECT` |

改善方向: `select_related` / `prefetch_related`（Django）・`include`（Rails）・JOIN クエリへの統合。

---

#### 3-2: インデックス設計の問題

クエリで頻繁に使用されるカラムにインデックスが設定されていない可能性を検出する。

| パターン | 確認方法 |
|---|---|
| WHERE 句に使用されるカラム | SQL ファイル・ORM の `filter(` / `where(` / `WHERE` を Grep し、対象カラムを抽出する |
| ORDER BY に使用されるカラム | `order_by(` / `ORDER BY` を Grep |
| JOIN 結合カラム | `JOIN` の `ON` 句を Grep |
| マイグレーションファイルのインデックス定義 | `*migration*` ファイルを Read し、`index: true` / `CREATE INDEX` の有無を確認 |

SQL ファイルがない場合は ORM の `filter` / `where` 呼び出しからカラム名を抽出し、スキーマ定義（`models.py`・`schema.rb`・`*.entity.ts` 等）でインデックス有無を確認する。

---

#### 3-3: 同期ブロッキング処理

非同期が期待される文脈で同期処理が実行されているパターンを検出する。

| パターン | Grep 対象 |
|---|---|
| Node.js: 同期ファイルI/O | `readFileSync` / `writeFileSync` / `existsSync` |
| Node.js: await なし非同期呼び出し | `async` 関数内の `fetch(` / `axios.` / DB クライアント呼び出しで `await` なし |
| Python: 同期HTTP呼び出し（async文脈） | `async def` 内の `requests.get(` / `requests.post(` |
| Python: `time.sleep` 本番コード | `time.sleep(` が本番パス（テストコード以外）に存在 |
| C#: `.Result` / `.Wait()` の使用 | `\.Result` / `\.Wait()` の呼び出し（デッドロックリスク） |
| Go: goroutine なし連続外部呼び出し | ループ内で並列化されていない複数の HTTP クライアント呼び出し |

---

#### 3-4: 大量データのメモリロード

ページネーション・ストリーミングなしに大量データを一括取得するパターンを検出する。

| パターン | Grep 対象 |
|---|---|
| ORM 全件取得 | `.all()` / `findAll()` / `SELECT *` （WHERE句・LIMIT なし） |
| ページネーションなし API | コントローラーで `limit` / `offset` / `page` パラメータなしに一覧を返す |
| ファイル全読み込み | `open(f).read()` / `fs.readFileSync` （サイズチェックなし） |
| 無制限ループ | `while True:` / `while (true)` にループカウント制限なし |

---

#### 3-5: キャッシュ欠如

繰り返し実行される高コスト処理にキャッシュが適用されていないパターンを検出する。

| パターン | 確認方法 |
|---|---|
| 外部 API 呼び出しのキャッシュなし | `requests.get` / `fetch(` / `HttpClient` が頻繁呼び出しパスにあり、キャッシュ層（Redis・Memcached・インメモリ）の参照がない |
| 設定・マスタデータの毎回 DB 取得 | 変更頻度の低いデータ（設定テーブル・コードマスタ等）を毎回クエリしている |
| 計算コストの高い関数の未メモ化 | 再帰関数・フィボナッチ等の計算で memoize / lru_cache / `@cache` がない |

---

#### 3-6: アルゴリズム・データ構造の問題

計算量が明らかに改善できるパターンを検出する。

| パターン | 確認方法 |
|---|---|
| ネストループで O(n²) 以上 | `for` ループの入れ子が 3 段以上で、内側でコレクション全体を走査 |
| リストでの線形検索 | `if x in list` / `list.index()` が頻繁呼び出しパスにある（set への変換を推奨） |
| 文字列結合ループ | ループ内での `+=` による文字列結合（Python: `join` / JS: `Array.join` を推奨） |
| 不必要なソート | ループ内での毎回ソート（`sorted()` / `.sort()` の位置が不適切） |

---

#### 3-7: フロントエンド固有の問題（UI を持つプロジェクトのみ）

| パターン | 確認方法 |
|---|---|
| React: 不必要な再レンダリング | `useMemo` / `useCallback` / `React.memo` が未適用の重いコンポーネント |
| React: useEffect 依存配列漏れ | `useEffect(` の第二引数が `[]` または欠如し、無限ループが発生する可能性 |
| バンドルサイズ | `import * as` による全量インポート（tree shaking が効かない） |
| 画像最適化 | `<img>` タグに `loading="lazy"` / `srcset` がない |


---

## 改善案の形式

#### 改善案の形式

```
### 🔴 High — N+1 クエリ: <ファイルパス>

**対象ファイル:** `src/services/order_service.py:45-52`

**問題のあるコード:**
```python
orders = Order.objects.all()
for order in orders:
    user = User.objects.get(id=order.user_id)  # N+1: ループ内クエリ
    print(user.name)
```

**改善後のコード:**
```python
orders = Order.objects.select_related('user').all()  # JOIN で一括取得
for order in orders:
    print(order.user.name)
```

**根拠:** `orders` が N 件の場合、現在は N+1 回のクエリが実行される。
`select_related` を使用することで 1 回の JOIN クエリに削減できる。
**推定効果:** N=100 の場合、クエリ数を 101 → 1 に削減。
```


---

## レポートフォーマット

#### レポートフォーマット

```markdown
# パフォーマンス診断レポート

**診断対象:** <パス>
**診断日時:** YYYY-MM-DD HH:MM
**診断方式:** 静的解析
**総合リスクレベル:** High / Medium / Low / 問題なし

---

## エグゼクティブサマリー

<2〜3文で最重要リスクを要約>

### 検出サマリー

| 診断観点 | 検出数 | 最高重要度 |
|---|---|---|
| N+1 クエリ | N | 🔴 High |
| インデックス設計 | N | - |
| 同期ブロッキング | N | - |
| 大量メモリロード | N | - |
| キャッシュ欠如 | N | - |
| アルゴリズム・データ構造 | N | - |
| フロントエンド | N | - |

---

## N+1 クエリ

> 検出なし

または

### 🔴 High — N+1 クエリ
（改善案の形式に従って記載）

---

（各診断観点を繰り返す）

---

## 次のアクション

| 優先度 | 対応内容 | 推定効果 |
|---|---|---|
| 即時対応 (High) | <対応事項> | <推定効果> |
| 優先対応 (Medium) | <対応事項> | <推定効果> |
| 計画対応 (Low) | <対応事項> | <推定効果> |

---

*本レポートは静的解析による診断です。実際のパフォーマンスは負荷条件・データ量・実行環境により異なります。本番環境での計測・プロファイリングを別途実施してください。*
```
