# TypeScript / JavaScript のリファクタリング（code-refactor 補助ファイル・常時ロードしない）

`/code-refactor` の Step 1 で対象が `.ts` / `.tsx` / `.js` / `.jsx` / `.mjs` / `.cjs` のときに Read する。汎用の手順・承認ゲート・対象外の定義は `SKILL.md` が正。

## 1. 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| 変数・関数・メソッド | camelCase | `getUserById`、`retryCount` |
| クラス・型・インターフェース・enum | PascalCase。**`I` 接頭は付けない**（C# とは異なる TS の慣習） | `UserRepository`、`ApiResponse` |
| 定数（モジュールスコープの不変値） | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| ファイル名 | kebab-case | `user-service.ts` |
| React コンポーネント | PascalCase（ファイル名も PascalCase.tsx） | `OrderTable.tsx` |
| React カスタムフック | `use` 接頭 + camelCase | `useOrderList` |
| boolean | `is` / `has` / `should` / `can` 接頭 | `isLoading`、`hasPermission` |
| 型パラメータ | 単一大文字または PascalCase | `T`、`TItem` |
| 非公開クラスメンバ | `private` 修飾子（`#field` は挙動が異なるため既存方針に合わせる） | `private repo` |

- ディレクトリ・ファイルの命名がプロジェクトで既に統一されている場合は**そちらを優先**する（`PascalCase.ts` 統一のリポジトリで 1 ファイルだけ kebab-case にしない）
- 略語は 2 文字までは大文字（`ID`・`URL` は `userId`・`baseUrl` のように camelCase 側の慣習に従う）

## 2. まず機械で直す（手作業より安全）

```
npx --no-install eslint --fix <対象>      # 自動修正（設定がある場合のみ）
npx --no-install prettier --write <対象>  # 整形
npx --no-install tsc --noEmit             # 型検査（振る舞いを変えずに検証できる）
```

- `npx *` は `settings.json` で **deny** されている。実行が必要な場合は `package.json` の scripts 経由（`npm run lint`・`npm run typecheck`）を使う。scripts が無ければ追加を提案し、承認を得る
- ESLint / Prettier の設定ファイル（`eslint.config.js`・`.prettierrc`）がある場合は**その設定を正**とし、好みで上書きしない
- 設定が無いプロジェクトに新規導入するのは依存の追加にあたる（`.claude/rules/external-resources.md`・【要指示】）

## 3. 振る舞い保持の検証

| 手段 | コマンド |
|---|---|
| 型 | `npm run typecheck` または `tsc --noEmit` |
| テスト | `npm test`（Vitest / Jest） |
| ビルド | `npm run build`（副作用の少ない最終確認） |

`tsc --noEmit` は**実行前にリグレッションを検出できる**最も費用対効果の高い検証。リファクタリング後に必ず通す。

## 4. TS / JS 固有のリファクタリング手法

| 症状 | 対応 | 根拠 |
|---|---|---|
| `any` の使用 | `unknown` + 型ガードで絞る、または具体型を定義 | 型安全性（`.claude/rules/code-quality.md`） |
| 型アサーション `as Foo` の多用 | 型ガード関数（`function isFoo(x: unknown): x is Foo`） | 実行時の裏付けを持たせる |
| `x && x.y && x.y.z` | オプショナルチェーン `x?.y?.z` | 可読性 |
| `a !== undefined ? a : b` | `a ?? b`（`\|\|` は 0・空文字も falsy になるため使い分ける） | 意図の明確化 |
| `enum` | union literal（`type Status = 'open' \| 'closed'`）または `as const` オブジェクト | バンドルサイズ・型の扱いやすさ（下記【禁止】も参照） |
| Promise チェーンのネスト | `async` / `await` | 可読性 |
| `try { } catch { }` の握りつぶし | 具体的な処理・ログ・再送出 | Fail Fast |
| 巨大な props / 引数オブジェクト | 責務単位に分割、コンポジション | 単一責任 |
| 同一ロジックの重複した型定義 | `Pick` / `Omit` / `Partial` で派生させる | DRY |
| バレルファイル（`index.ts`）経由の循環参照 | 直接 import に変更、または依存方向を整理 | 依存方向の維持 |
| CommonJS と ESM の混在（`require` と `import`） | プロジェクトの `type` 設定に合わせて統一 | ビルド設定との整合 |
| マジックナンバー・文字列リテラルの散在 | `as const` オブジェクトまたは定数モジュールに集約 | 保守性 |

### React 固有

| 症状 | 対応 |
|---|---|
| `useState` で保持している派生値 | レンダー時の計算に変える（必要なら `useMemo`） |
| `useEffect` での状態同期 | 依存配列を正しくするか、そもそも不要な effect を削除する |
| `key={index}` | 安定した ID を使う（並び替え時の再利用バグを防ぐ） |
| インラインの巨大 JSX | 子コンポーネントへ抽出（**表示結果を変えないこと**を確認） |
| `useCallback` / `useMemo` の無条件付与 | 計測に基づかない最適化は外す（YAGNI） |

## 5. 【禁止】振る舞いが変わるため実施しない変換

以下は振る舞い保持を超えるため、指摘に留めてユーザーの判断を仰ぐ。

- **逐次 `await` を `Promise.all` に変える**（実行順序・同時実行数・エラー発生時の挙動が変わる）
- `==` → `===` の一括置換（`null` / `undefined` の同時判定など、意図的な緩い比較を壊す）
- `||` → `??` の一括置換（`0`・`''`・`false` の扱いが変わる）
- `enum` → union / `as const` への変換（数値 enum の逆引き・宣言のマージ・実行時オブジェクトが失われる。公開 API に含まれる場合は破壊的変更）
- 公開 API（`package.json` の `exports`・`.d.ts` に現れる名前）の改名
- `sort` の比較関数変更、浮動小数の計算順序変更
- 動的アクセス（`obj[key]`・`JSON.parse` 由来のプロパティ名・DI コンテナのトークン文字列）に晒される名前の改名
- `strict` / `noUncheckedIndexedAccess` 等の tsconfig 変更（型エラーが大量に出るため、対応計画をユーザーと合意してから）
- モジュールのトップレベル副作用（副作用付き import）の順序変更

## 6. このリポジトリ固有

- `src/**` の REST エンドポイント・エラーレスポンス形式は `.claude/rules/api-conventions.md`（`/api-guide`）が正。命名改善の対象に含めない
- UI コンポーネントの見た目に関わる変更は本スキルの範囲外（`/ux-review`・`ui-designer` の担当）
