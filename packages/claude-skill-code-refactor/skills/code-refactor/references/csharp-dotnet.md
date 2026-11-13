# C#（.NET / Dataverse プラグイン）のリファクタリング（code-refactor 補助ファイル・常時ロードしない）

`/code-refactor` の Step 1 で対象が `.cs` のときに Read する。汎用の手順・承認ゲート・対象外の定義は `SKILL.md` が正。

## 1. 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| クラス・メソッド・プロパティ | PascalCase | `UserRepository`、`GetUserById` |
| private フィールド | `_` + camelCase | `_userRepository`、`_tracingService` |
| インターフェース | `I` + PascalCase | `IUserRepository`、`IPlugin` |
| 定数（`const` / `static readonly`） | **PascalCase**（`SKILL.md` の汎用表の UPPER_SNAKE_CASE は適用しない） | `MaxRetryCount`、`DefaultTimeout` |
| 非同期メソッド | PascalCase + `Async` 接尾 | `GetUserAsync` |
| ローカル変数・引数 | camelCase | `userId`、`entityReference` |
| 型パラメータ | `T` + PascalCase | `TEntity` |
| Dataverse プラグインのクラス | `<テーブル><メッセージ><ステージ>` 形式が慣例。既存プロジェクトの命名を優先する | `AccountPreCreatePlugin` |
| Dataverse のスキーマ名 | `<publisherprefix>_<PascalCase>`（論理名は自動的に小文字化される） | スキーマ名 `ya_AccountNumber` → 論理名 `ya_accountnumber` |

- 【要指示】**Dataverse のスキーマ名は改名しない**。禁止の根拠と範囲は `SKILL.md`「Power Platform 案件での注意」を参照
- `.editorconfig` がある場合は**その設定を正**とする（命名規則も含めて Roslyn アナライザが強制する）

## 2. まず機械で直す（手作業より安全）

```
dotnet format <sln またはプロジェクト>                  # 空白・スタイル・アナライザ修正
dotnet format --verify-no-changes                       # 差分が出るかの確認のみ（CI 向け）
dotnet build -warnaserror                               # 警告を落とし切る
```

- `.editorconfig` が無いプロジェクトに `dotnet format` をかけると既定スタイルで広範囲に整形される。**まず `--verify-no-changes` で影響量を確認**し、`SKILL.md` Step 3 のプレビューとして提示する
- アナライザパッケージ（StyleCop・SonarAnalyzer 等）の新規導入は依存追加にあたる（【要指示】・`.claude/rules/third-party-licenses.md`）
- `dotnet` の呼び出し可否は `/tool-environment` に従う

## 3. 振る舞い保持の検証

| 手段 | コマンド・方法 |
|---|---|
| ビルド | `dotnet build -c Release`（最低限の回帰検出） |
| テスト | `dotnet test`（xUnit / NUnit / MSTest） |
| 公開 API の差分 | アセンブリの public メンバに変更が無いか確認（NuGet 提供物では破壊的変更になる） |

- Dataverse プラグインのユニットテストには `IPlugin` のモックが必要になる。**FakeXrmEasy は v2 以降でライセンス条件が変わる**（商用利用に条件がある）ため、導入は `.claude/rules/third-party-licenses.md` に従い確認・承認を得る。導入しない場合は検証手段が「サンドボックス環境での手動実行」に限られることをユーザーに伝える

## 4. C# 固有のリファクタリング手法

| 症状 | 対応 | 根拠 |
|---|---|---|
| `if (x != null)` の深いネスト | 早期 return、`is not null`、パターンマッチング | ネスト深度 3 以内 |
| ループ内の文字列連結 | `StringBuilder` | O(n²) の回避 |
| LINQ の結果を複数回列挙 | 変数に受ける（`.ToList()` は 1 回だけ） | 多重列挙による再クエリの回避 |
| `IDisposable` の手動 `Dispose` | `using` 宣言（C# 8+） | リーク防止 |
| `catch (Exception) { }` | 具体的な例外型に絞り、ログまたは再送出（プラグインでは `InvalidPluginExecutionException`） | Fail Fast |
| マジック文字列（Dataverse の論理名・属性名） | 定数化、または早期バインドの生成クラス | 保守性 |
| 巨大な `Execute` / コントローラーメソッド | ロジックを別クラス（サービス）へ抽出 | 単一責任 |
| `readonly` を付け忘れたフィールド | `readonly` を付与 | 不変性の明示 |
| 冗長な `get; set;` の DTO | `record` / `init` アクセサ（対象フレームワークが対応する場合） | 可読性 |
| 未使用の `using` ディレクティブ・変数 | 削除（`dotnet format` が自動処理） | デッドコード削除 |
| 同一の null チェック・検証の重複 | ガード節メソッドに抽出 | DRY |

### Dataverse プラグイン固有

- **`IPlugin` の実装はステートレスでなければならない**。プラグインのインスタンスは Dataverse 側で再利用・並行実行されるため、**インスタンスフィールドに状態を持たせる「共通化」は競合状態を生む**（重大なバグになる）。共通化は引数渡し・ローカル変数・静的な不変値に留める
- `IOrganizationServiceFactory` / `ITracingService` の取得は `Execute` 内で行う（コンストラクタに移動しない）
- 無限ループ防止の `context.Depth` チェック・`SharedVariables` による重複実行防止は**削除しない**（保護ロジックであり冗長コードではない）
- サンドボックス（分離モード）ではファイル I/O・一部のネットワーク・リフレクションが使えない。「共通設定をファイルから読む」等の抽象化に置き換えない
- クラス名・名前空間はプラグイン登録（ステップ定義）から参照される。**改名すると登録の再設定が必要**になるため、改名は破壊的変更として扱う（提案に留める）

## 5. 【禁止】振る舞いが変わるため実施しない変換

以下は振る舞い保持を超えるため、指摘に留めてユーザーの判断を仰ぐ（`SKILL.md`「対象外とする変更」）。

- **`async void` → `async Task`** の一括変換（イベントハンドラでは意味が変わり、例外の扱いも変わる）
- **`.Result` / `.Wait()` → `await`** への変換（呼び出し元のシグネチャ変更に波及し、公開 API とデッドロック挙動が変わる）
- `IEnumerable<T>` → `List<T>` の materialize、およびその逆（評価タイミング・メモリ・再列挙可否が変わる）
- LINQ の `AsParallel()` 化・`Task.WhenAll` による並列化（実行順序と同時実行数が変わる）
- 例外型の変更、`catch` の範囲を狭める変更（伝播する例外が変わる）
- `DateTime` ↔ `DateTimeOffset`、`float` ↔ `decimal` の置換（精度・タイムゾーン挙動が変わる）
- `struct` ↔ `class` の変更（値/参照セマンティクスが変わる）
- DI 登録のライフタイム変更（`AddScoped` ↔ `AddSingleton`）
- public API・アセンブリ名・名前空間・プラグインクラス名の改名
- `<Nullable>enable</Nullable>` の有効化（大量の警告が出るため、対応計画を合意してから）
- リフレクション・DI コンテナ・シリアライズ属性（`JsonPropertyName` 等）から文字列で参照される名前の改名

## 6. フレームワーク固有

| 対象 | 注意点 |
|---|---|
| ASP.NET Core | ルート・HTTP メソッド・DTO のプロパティ名は公開 API。変更は破壊的で `.claude/rules/api-conventions.md`（`/api-guide`）の規約に従う。ミドルウェアの登録順は振る舞いそのもの |
| EF Core | LINQ 式の変更はクエリを変える。`AsNoTracking` の追加・`Include` の増減は性能改善であり `perf-analyzer` の担当。マイグレーションを伴うモデル変更は本スキルの範囲外 |
| Power Automate カスタムコネクタ | 定義（Swagger）の操作 ID・パラメータ名は利用側のフローから参照される。改名は破壊的 |
