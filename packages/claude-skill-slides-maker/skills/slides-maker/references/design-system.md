# スライドメーカー デザインシステム

`write_pptx_design.py` が実装する視覚デザインの仕様。JSON 生成時にこの仕様に従うこと。

> **テーマ外部化**: 本書のカラートークン・フォントは既定テーマ `royal-navy` の値。正本は `../themes/royal-navy.json` にあり、レンダラーの `--theme` で別テーマに切り替えられる（本書のレイアウト・構成ルールはテーマ非依存）。

---

## カラートークン

| トークン名 | HEX | 用途 |
|---|---|---|
| `NAVY_DARK` | `#1B3A6B` | タイトルバー・section ストライプ・テーブルヘッダー |
| `NAVY_MID` | `#3D6098` | 2カラム見出し・セカンダリ強調 |
| `BLUE_LIGHT` | `#7A9CC6` | アクセントライン・グラフ系列2 |
| `BLUE_PALE` | `#B8CCE4` | 仕切り線・グラフ系列3 |
| `BLUE_ULTRA_PALE` | `#D9E5F2` | 薄い背景帯 |
| `WHITE` | `#FFFFFF` | スライド背景・タイトルバー文字 |
| `TEXT_DARK` | `#1A1A1A` | 本文テキスト |
| `TEXT_GRAY` | `#767676` | サブテキスト・レベル2箇条書き |
| `GRAY_LIGHT` | `#F5F7FA` | テーブル偶数行の背景 |
| `ACCENT_RED` | `#C0392B` | 警告・マイナス値の強調（JSON `color:"red"` で指定可） |
| `ACCENT_GREEN` | `#27AE60` | ポジティブ・達成の強調（JSON `color:"green"` で指定可） |

---

## タイポグラフィ

| 用途 | フォント | サイズ | ウェイト |
|---|---|---|---|
| タイトルスライド 大見出し | 游明朝 | 36pt | Bold |
| アクションタイトルバー | 游明朝 | 22pt | Bold |
| section 番号 | Calibri | 52pt | Bold |
| section タイトル | 游明朝 | 30pt | Bold |
| 2カラム列見出し | 游明朝 | 16pt | Bold |
| 本文 level 0 箇条書き | 游ゴシック | 18pt | Regular |
| 本文 level 1 箇条書き | 游ゴシック | 15pt | Regular |
| テーブルヘッダー | 游ゴシック | 14pt | Bold |
| テーブルボディ | 游ゴシック | 13pt | Regular |
| サブタイトル・補足 | 游ゴシック | 20pt | Regular |
| メタ情報（日付・著者） | 游ゴシック | 13pt | Regular |

**日本語最適化ルール:**
- 日本語テキストは英語より 1–2pt 大きく設定すること（上記は既に調整済み）
- テキストボックスの幅は文字列が折り返される余裕を持たせること
- 英数字・数値・単位は Calibri で記述するとプロ品質になる（bullets 内で混在可）

---

## スライド寸法

- **サイズ**: 16:9 ワイドスクリーン（13.333 × 7.5 インチ）
- **マージン（推奨）**: 左右 0.4 インチ、上下（タイトルバー以下）1.25 インチ～

---

## レイアウト別 JSON 構造

### `title`（タイトルスライド）
```json
{
  "layout": "title",
  "title": "メインタイトル",
  "subtitle": "サブタイトル（省略可）",
  "date": "2026年6月",
  "author": "組織名・著者名（省略可）"
}
```

### `section`（セクション区切り）
```json
{
  "layout": "section",
  "section_number": "01",
  "title": "セクションタイトル",
  "subtitle": "説明文（省略可）"
}
```

### `content`（本文スライド — 最頻出）
```json
{
  "layout": "content",
  "action_title": "この施策により売上が30%向上する",
  "bullets": [
    {"text": "主要ポイント", "level": 0},
    {"text": "詳細説明（インデント）", "level": 1},
    {"text": "次のポイント", "level": 0}
  ]
}
```
> **action_title は洞察を述べる文にすること**。「〇〇について」のようなトピックラベルは避ける。

### `two-column`（2カラム比較）
```json
{
  "layout": "two-column",
  "action_title": "現状と目指す姿の比較",
  "left":  {"heading": "現状 (AS-IS)", "bullets": ["課題A", "課題B"]},
  "right": {"heading": "目指す姿 (TO-BE)", "bullets": ["改善後A", "改善後B"]}
}
```

### `table`（テーブルスライド）
```json
{
  "layout": "table",
  "action_title": "施策の優先度評価マトリクス",
  "headers": ["施策", "効果", "コスト", "優先度"],
  "rows": [
    ["施策A", "大", "小", "高"],
    ["施策B", "中", "中", "中"]
  ]
}
```

### `chart`（グラフスライド）
```json
{
  "layout": "chart",
  "action_title": "売上は3年間で50%成長した",
  "chart_type": "bar",
  "categories": ["2022年", "2023年", "2024年"],
  "series": [
    {"name": "売上（百万円）", "values": [100, 130, 150]}
  ]
}
```
> `chart_type`: `"bar"` (縦棒) / `"bar_horizontal"` (横棒) / `"line"` (折れ線) / `"pie"` (円グラフ)

### `image`（画像スライド）

アクションタイトルバーの下に画像を中央フィット配置する。キャプション付き・なしに対応。

```json
{
  "layout": "image",
  "action_title": "システム構成図：3層アーキテクチャで可用性99.9%を実現する",
  "image": {
    "src": "https://example.com/architecture.png"
  },
  "caption": "図1: 本番環境アーキテクチャ概要（2026年6月時点）"
}
```

**`image.src` に指定できる形式:**

| 形式 | 例 |
|---|---|
| URL | `"https://example.com/image.png"` |
| Base64 data URI | `"data:image/png;base64,iVBORw0KGgo..."` |
| ローカルファイルパス | `"./design/03_basic_design/diagram.png"` |

**`content` レイアウトへの `image` 埋め込み（右側配置）:**

`content` レイアウトに `image` キーを追加すると、左 60% に箇条書き・右 38% に画像を分割配置する。

```json
{
  "layout": "content",
  "action_title": "マイクロサービス化により開発速度が2倍向上する",
  "bullets": [
    {"text": "サービス単位の独立デプロイが可能になる", "level": 0},
    {"text": "障害の局所化でシステム全体の可用性が向上する", "level": 0}
  ],
  "image": {
    "src": "data:image/png;base64,iVBORw0KGgo..."
  }
}
```

**注意事項:**
- URL 画像はスクリプト実行時にダウンロードされる。ネットワーク非接続環境では Base64 またはファイルパスを使用すること
- Base64 文字列は JSON ファイルが大きくなる（1MB 画像 ≈ 1.3MB のテキスト）。大量使用は避けること
- 画像のアスペクト比は自動維持され、タイトルバー以下の領域内にフィットされる
- 読み込みに失敗した場合は WARNING を出力して画像なしでスライドを生成する

### `closing`（クロージング）
```json
{
  "layout": "closing",
  "title": "ご清聴ありがとうございました",
  "contact": "contact@example.com（省略可）",
  "note": "本資料の内容は社外秘です。（省略可）"
}
```

---

## 標準デッキ構成（コンサルティングスタイル）

| 枚数目安 | レイアウト | 役割 |
|---|---|---|
| 1 | `title` | 表紙 |
| 1 | `content` | エグゼクティブサマリー（3点以内） |
| 1 | `section` | 課題・背景セクション開始 |
| 1–2 | `content` / `two-column` | 現状分析 |
| 1 | `section` | 提言セクション開始 |
| 2–4 | `content` / `table` / `chart` | 分析・提言スライド |
| 1 | `content` | まとめ・次のアクション |
| 1 | `closing` | 表紙裏 |

**スライド枚数の目安**: 30分プレゼン→12–15枚、10分→6–8枚、5分→4–5枚
