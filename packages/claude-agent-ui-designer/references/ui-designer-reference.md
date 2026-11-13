# ui-designer リファレンス — タスク種別ごとの詳細実施内容

ui-designer エージェントから参照されるリファレンス。エージェント定義本体は `.claude/agents/ui-designer.md`。
各タスク種別の作業を開始する前に、該当セクションを Read してから作業すること。

---

#### `design-system` — デザインシステム設計

プロジェクト共通のデザイントークンとコンポーネントカタログを作成する。

**DESIGN.md の形式は `/design-md` スキルが正本を持つ。** 独自の見出し構成で書かず、着手前に [`.claude/skills/design-md/SKILL.md`](../skills/design-md/SKILL.md) と [`references/spec-summary.md`](../skills/design-md/references/spec-summary.md) を Read し、そこにある雛形と手順に従う。要点だけ再掲する。

- 出力先は **`design/03_basic_design/DESIGN.md` の 1 つだけ**（詳細設計側にコピーを置かない）
- 形式は Google Labs の DESIGN.md 仕様（YAML front matter のトークン ＋ 本文 8 セクション）。**セクション見出しは英語の正式名を順序どおりに**使い、散文は日本語で書く
- 値が未確定なら `"==検討中（顧客確認待ち）=="` と書く。空欄・`TBD` で放置しない
- 書かないと決めたセクションは front matter の `omitted` に列挙する
- 従来この節にあった独自表（カラーパレット・スペーシング・シャドウ・ラジウス・ブレークポイントの各表）で書いていた値は、仕様側の `colors` / `spacing` / `rounded` / `components` トークンと `Layout`・`Shapes`・`Elevation & Depth` の各セクションへ収める。**ブレークポイントは仕様に専用キーが無いため `Layout` セクションの散文と表で定義する**
- 作成後に必ず構造検証を通し、ERROR が 0 であることを確認してから完了報告する

```sh
python .claude/skills/design-md/scripts/validate_design_md.py design/03_basic_design/DESIGN.md
```

**コンポーネントカタログ** (`design/04_detailed_design/ui/catalog.md`)

主要コンポーネントをリストし、各コンポーネントについて使用するトークン・状態・バリアントを記述する。

---

#### `mockup` — 高精度 HTML モックアップ

ux-designer のプロトタイプ（スケルトン）またはプロンプトの指示を基に、開発者ハンドオフ用の高精度モックアップを生成する。

**生成ルール**:
- `<style>` タグ内に CSS カスタムプロパティでトークンを定義する
- 外部 CDN・外部フォント・外部画像は使用しない（CSP 制約のため完全自己完結）
- フォントはシステムフォントスタックまたは `@font-face` base64 埋め込みを使用する
- 実際のコンテンツに近いダミーデータを使用する（PII 禁止）
- レスポンシブ対応：375px（モバイル）・768px（タブレット）・1280px（デスクトップ）を media query で実装する
- アクセシビリティ属性（`aria-*`・`role`・`alt`）は ux-designer のスケルトンから引き継ぎ、削除しない

**ファイル名**: `report/ui/YYYYMMDD_HHMMSS_mockup_<画面名>.html`

生成後、Artifact ツールでブラウザプレビューを公開する。

---

#### `visual-audit` — ビジュアル品質監査

既存の HTML/CSS・コンポーネントファイルを対象にビジュアル品質を診断する。

**監査観点**:

| 観点 | 確認内容 | 重要度 |
|---|---|---|
| 色の一貫性 | カラートークン未使用のハードコードカラー | 🟡 中 |
| コントラスト比 | WCAG AA 違反のテキスト・ボタン配色 | 🔴 高 |
| タイポグラフィ | フォントサイズ・ウェイト・行高の一貫性 | 🟡 中 |
| スペーシング | 8px グリッドから外れた余白・パディング | 🟢 低 |
| ボーダーラジウス | コンポーネント間の不一致 | 🟢 低 |
| シャドウ | 深度・方向・ぼかしの不整合 | 🟢 低 |
| アイコン・画像 | サイズ・スタイルの不統一 | 🟡 中 |
| 状態の欠落 | hover/focus/disabled/error 状態が未定義 | 🔴 高 |
| 空状態 | データなし・ロード中状態の未定義 | 🟡 中 |
| レスポンシブ崩れ | 固定幅・不適切な vw/vh 使用 | 🔴 高 |

重要度付与基準:

| 重要度 | 定義 |
|---|---|
| 🔴 高 | 開発者ハンドオフのブロッカー（一貫性破綻・アクセシビリティ違反） |
| 🟡 中 | 品質低下だが進行は可能（ユーザーへの違和感・ブランド不整合） |
| 🟢 低 | 改善提案（ベストプラクティス・細部の精度向上） |

成果物: `report/ui/YYYYMMDD_HHMMSS_visual-audit_<対象>.md`

---

#### `component` — コンポーネント視覚仕様

個別コンポーネントの全状態・バリアントの視覚仕様を作成する。

**コンポーネント仕様書の構造** (`design/04_detailed_design/ui/components/<コンポーネント名>.md`):

```markdown
# [コンポーネント名] 視覚仕様

## バリアント
| バリアント | 用途 |
|---|---|
| primary | メインアクション（1画面に1つ） |
| secondary | サブアクション |

## 状態マトリクス
| 状態 | 背景色トークン | テキスト色トークン | ボーダー | カーソル |
|---|---|---|---|---|
| default  | --color-primary-500 | white | なし | pointer |
| hover    | --color-primary-600 | white | なし | pointer |
| focus    | --color-primary-500 | white | 2px solid --color-focus-ring | pointer |
| active   | --color-primary-700 | white | なし | pointer |
| disabled | --color-gray-300    | --color-gray-500 | なし | not-allowed |
| loading  | --color-primary-500 | white（+ スピナー） | なし | wait |
| error    | --color-error       | white | なし | pointer |

## サイズバリアント
| サイズ | パディング | フォントサイズ | 行高 | ボーダーラジウス |
|---|---|---|---|---|
| sm | 8px 12px  | 14px | 1.25 | --radius-sm |
| md | 10px 16px | 16px | 1.5  | --radius-sm |
| lg | 12px 24px | 18px | 1.75 | --radius-md |
```

さらに、全状態をデモする自己完結 HTML を Artifact で公開する。

---

#### `brand-token` — ブランドトークン抽出

指定されたブランド資料（既存 CSS・カラー指定・テキスト説明）からデザイントークンを抽出し、`DESIGN.md` を生成する。

入力として受け取れるもの:
- カラーコード（hex・RGB・HSL）の一覧
- 既存 CSS ファイルのパス
- ブランドガイドラインのテキスト説明

出力: `design/03_basic_design/DESIGN.md`（形式と手順は `/design-md` の `import` モードに従う）

既存の `DESIGN.md` がある場合は上書きせず、差分をユーザーに提示してから統合方針を確認する。

【要指示】**外部サイトが配布するデザインシステム集（実在プロダクトから抽出したもの・ライセンス表記のないライブラリ）をブランドトークンの入力にしない。** 判断基準は `/design-md` SKILL.md「外部のデザインシステム集を取り込む場合」にある。

