# Python のリファクタリング（code-refactor 補助ファイル・常時ロードしない）

`/code-refactor` の Step 1 で対象が `.py` のときに Read する。汎用の手順・承認ゲート・対象外の定義は `SKILL.md` が正。ここには Python 固有の判断材料だけを置く。

## 1. 命名規則（PEP 8）

| 対象 | 規則 | 例 |
|---|---|---|
| モジュール・パッケージ | snake_case（パッケージは短く、アンダースコアを避ける） | `user_service.py`、`billing` |
| クラス・型エイリアス・例外 | PascalCase（例外は `Error` 接尾） | `UserRepository`、`ValidationError` |
| 関数・メソッド・変数・引数 | snake_case | `get_user_by_id`、`retry_count` |
| 定数（モジュールレベル） | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 非公開（内部実装） | `_` 接頭 | `_build_query` |
| 型変数・ジェネリック | PascalCase（短く） | `T`、`UserT` |
| boolean を返す関数 | `is_` / `has_` / `can_` 接頭 | `is_active`、`has_permission` |

- `__double_leading` は名前マングリングが発生するため、単なる「非公開」の意図で使わない
- 予約語との衝突は末尾アンダースコア（`class_`、`id_`）。`l`・`O`・`I` 単独は使わない

## 2. まず機械で直す（手作業より安全）

```
python -m ruff format <対象>          # 整形（black 互換）
python -m ruff check --fix <対象>     # 自動修正可能な指摘のみ修正
python -m mypy <対象>                 # 型検査（設定があれば）
```

- **未導入のツールを無断で入れない**（`.claude/rules/external-resources.md`）。呼び出し方は `/tool-environment` に従う。導入が必要なら承認を得る
- `ruff check --fix` は安全な修正のみ適用される。**`--unsafe-fixes` は使わない**（振る舞いが変わり得る）
- プロジェクトに `pyproject.toml` の `[tool.ruff]` / `[tool.black]` 設定がある場合は**その設定を正**とし、行長・引用符の好みで上書きしない

## 3. 振る舞い保持の検証

| 手段 | コマンド |
|---|---|
| テスト | `python -m pytest -q`（`unittest` なら `python -m unittest discover`） |
| 型 | `python -m mypy` / `pyright` |
| 構文の同一性確認 | `python -m compileall -q <対象>`（少なくとも構文破壊を検出できる） |

テストが無い場合の扱いは `SKILL.md`「テストに関する注意」に従う（`/unit-test-gen` を先に提案する）。

## 4. Python 固有のリファクタリング手法

| 症状 | 対応 | 根拠 |
|---|---|---|
| `def f(items=[])` の可変デフォルト引数 | `items=None` にして関数内で初期化 | 呼び出し間で状態が共有される罠 |
| `except: pass` / `except Exception: pass` | 具体的な例外型に絞り、ログまたは再送出を入れる | Fail Fast（握りつぶし禁止） |
| ループ内の文字列連結 `s += x` | `"".join(parts)` | O(n²) の回避 |
| `type(x) == Foo` | `isinstance(x, Foo)` | 継承への対応 |
| `dict` を辞書アクセスで持ち回す | `dataclass` / `TypedDict` / `NamedTuple` | 型安全性・IDE 補完 |
| `open()` / `lock()` の手動解放 | `with` 文（コンテキストマネージャ） | リーク防止 |
| `os.path.join` の多用 | `pathlib.Path` | 可読性・OS 差異 |
| `%` 書式 / `.format()` | f-string | 可読性（ログの遅延評価が必要な箇所は除く） |
| 長い `if/elif` チェーン | dict ディスパッチ、または `match`（3.10+） | 開放閉鎖の原則 |
| 3 重以上の内包表記 | ジェネレータ関数に分解 | 可読性 |
| `global` による状態共有 | 引数・クラス属性・DI に置換 | テスタビリティ |
| 実行時検証に `assert` を使用 | 明示的な `raise ValueError` 等 | `-O` 実行で `assert` は消える |
| 循環 import | 依存方向を整理（`TYPE_CHECKING` での回避は暫定策として記録する） | 依存方向の維持 |

- ロギングは `logging.info("x=%s", x)` の遅延評価形式を保つ（f-string に変えると常に文字列化される）

## 5. 【禁止】振る舞いが変わるため実施しない変換

以下はリファクタリング（振る舞い保持）ではなく**バグ修正・仕様変更**にあたる。検出したら指摘に留め、対応はユーザーの判断を仰ぐ（`SKILL.md`「対象外とする変更」）。

- **可変デフォルト引数の修正**: 既存コードが状態の共有に依存している可能性がある
- **例外型の絞り込み**: 捕捉範囲が変わり、これまで飲み込んでいた例外が伝播する
- `is` ↔ `==` の置換（同一性と等価性は別物。`is None` は正しい用法なので変えない）
- 浮動小数の計算順序の変更、`sort` の比較キー変更
- ジェネレータ ↔ リストの相互変換（評価タイミング・メモリ・再利用可否が変わる）
- `getattr` / `globals()` / `__all__` / 文字列で参照される名前の改名（静的解析で追えないため、grep で全参照を確認できない限り行わない）
- モジュールトップレベルの副作用コードの移動（import 順序に依存する）
- デコレータの順序変更

## 6. フレームワーク固有

| 対象 | 注意点 |
|---|---|
| Django | モデルの `Meta`・フィールド名の変更はマイグレーションを伴う（リファクタリングの範囲外）。`select_related` / `prefetch_related` の追加は N+1 解消だが**クエリが変わる**ため `perf-analyzer` の指摘として扱う |
| Flask / FastAPI | ルートのパス・HTTP メソッド・レスポンス形式は公開 API。変更は破壊的（`/api-guide` の規約に従い、変更は要指示） |
| Pydantic | `BaseModel` のフィールド名・エイリアスは入出力仕様。改名は API 互換性を壊す |
| 非同期（asyncio） | 同期関数の `async` 化・`await` の並列化（`asyncio.gather`）は実行順序と同時実行数が変わるため対象外 |
