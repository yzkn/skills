# スライドメーカー デザインシステム（PptxGenJS 版）

`render_slides.mjs`（PptxGenJS エンジン）が実装する視覚デザインの仕様。
python-pptx 版（`design-system.md`）とは**別デザイン**であり、モダンでリッチな体裁を標準とする。
共通コアの slides.json（8 レイアウト）を解釈し、`ext.pptxgenjs` の拡張を追加適用する。

> **テーマ外部化**: 本書のカラートークン・フォントは既定テーマ `royal-navy` の値。正本は `../themes/royal-navy.json` にあり、レンダラーの `--theme` で別テーマに切り替えられる（本書のレイアウト・構成ルールはテーマ非依存）。

> **PptxGenJS の実仕様に関する注意（重要）**
> - **グラデーションは色帯の段階積層で近似**する（PptxGenJS はネイティブなグラデーション塗りに非対応）。`addGradientBand()` が担当。
> - **スライドトランジションは非対応**（PptxGenJS に API がないため実装しない）。`ext.pptxgenjs.transition` は受理するが無視する（前方互換のための予約）。
> - フォントは名称指定のみで、実表示は閲覧環境のフォント有無に依存する。

---

## カラートークン（"#" なし HEX）

| トークン | 値 | 用途 |
|---|---|---|
| `NAVY_DARK` | `1B3A6B` | タイトル/セクション/クロージング背景（グラデ起点）・テーブルヘッダー |
| `NAVY_MID` | `3D6098` | グラデ終点・2カラム見出し |
| `BLUE_LIGHT` | `7A9CC6` | メタ情報・チャート系列 |
| `BLUE_PALE` | `B8CCE4` | カード枠線・仕切り・グラフ系列 |
| `BLUE_ULTRA_PALE` | `D9E5F2` | セクションのゴースト番号 |
| `WHITE` | `FFFFFF` | カード背景・白抜き文字 |
| `TEXT_DARK` | `1A1A1A` | 本文 |
| `TEXT_GRAY` | `767676` | サブテキスト・レベル1箇条書き・スライド番号 |
| `GRAY_LIGHT` | `F5F7FA` | テーブル偶数行 |
| `ACCENT_CYAN` | `2EC4C6` | アクセントライン・チャート強調系列 |
| `ACCENT_RED` / `ACCENT_GREEN` | `C0392B` / `27AE60` | 警告 / ポジティブ |

**カード表現**: `content` / `two-column` は角丸（rectRadius 0.1）＋ドロップシャドウ（`outer` / blur 8 / offset 3 / opacity 0.2）＋淡色枠線。

---

## タイポグラフィ

| 用途 | フォント | サイズ | ウェイト |
|---|---|---|---|
| タイトル大見出し | 游ゴシック | 40pt | Bold |
| アクションタイトルバー | 游ゴシック | 24pt | Bold |
| セクション番号（ゴースト） | Calibri | 130pt | Bold |
| セクションタイトル | 游ゴシック | 32pt | Bold |
| 2カラム見出し | 游ゴシック | 16pt | Bold |
| 本文 level 0 / level 1 | 游ゴシック | 18 / 15pt | Regular |
| テーブルヘッダー / ボディ | 游ゴシック | 14 / 13pt | Bold / Regular |
| 数値・英数字 | Calibri | — | — |
| スライド番号 | Calibri | 9pt | Regular |

**代替フォント**: 游ゴシック不在環境では Noto Sans JP を推奨（実装の `F.FALLBACK`）。

---

## スライド寸法

- 16:9 ワイド（`defineLayout` で 13.333 × 7.5 インチ）
- アクションタイトルバー高さ: 1.1 インチ

---

## レイアウト別の表現（共通コア 8 種）

JSON の共通コア構造は `design-system.md`「レイアウト別 JSON 構造」と同一。以下は PptxGenJS 版の描画差分。

| レイアウト | PptxGenJS 版の描画 |
|---|---|
| `title` | 全面グラデーション（NAVY_DARK→NAVY_MID）＋シアンのアクセントライン＋左寄せ大見出し |
| `section` | 左 1.5in グラデ帯＋大型ゴースト番号（BLUE_ULTRA_PALE・130pt）＋タイトル |
| `content` | アクションバー＋箇条書きを白カード（角丸・シャドウ・枠線）に配置。`image` があれば右にコンテインフィット |
| `two-column` | 左右を白カード化。各カードに見出し＋箇条書き |
| `table` | ヘッダーグラデ相当（NAVY_DARK 塗り・白抜き）＋交互ストライプ＋淡色ボーダー |
| `chart` | 拡張チャート種別対応・凡例下・ネイビー系パレット |
| `image` | コンテインフィット＋任意キャプション |
| `closing` | title に準じた全面グラデーション |
| 全レイアウト共通 | 右下にスライド番号（title/section/closing を除く）。`ext.pptxgenjs.speaker_notes` でノート付与 |

---

## `ext.pptxgenjs` 拡張フィールド

各スライドに任意付与。python-pptx 版は無視する。

| フィールド | 型 | 効果 |
|---|---|---|
| `card_style` | bool | `content` のカード表現の有効/無効（既定 true） |
| `shadow` | bool | カードのドロップシャドウの有効/無効（既定 true） |
| `speaker_notes` | string | スピーカーノートを付与 |
| `chart_type` | string | 拡張チャート種別を優先指定（`doughnut`/`area`/`radar`/`scatter`/`bubble`）。無ければコアの `chart_type` にフォールバック |
| `background` | object | 予約（現状は未適用）。将来のカード背景色指定用 |
| `transition` | string | **予約・無視**（PptxGenJS 非対応） |

### チャート種別（`chart_type`）

| コア（両エンジン） | 拡張（PptxGenJS のみ・`ext.pptxgenjs.chart_type`） |
|---|---|
| `bar` / `bar_horizontal` / `line` / `pie` | `doughnut` / `area` / `radar` / `scatter` / `bubble` |

---

## OOXML スキーマ補正（PptxGenJS バグ対策）

PptxGenJS（4.x）は PowerPoint の「修復」ダイアログを招くスキーマ生成バグを複数持つ。`render_slides.mjs` の `savePresentation()` が生成後に zip（jszip）を開いて以下を補正する。レンダラー経由での生成が必須（`pptx.writeFile()` を直接使わない）。

| 補正 | 内容 |
|---|---|
| **notesMaster テーマ分離**（修復の主因） | PptxGenJS は notesMaster と slideMaster に同一 `theme1.xml` を共有参照させるが、PowerPoint は各マスターが固有 theme を持つことを要求する。notesMaster 用に theme を複製し（`theme2.xml`）参照を張り替える |
| cNvPr id 重複 | テーブル（addTable）とシェイプ（addShape）の採番衝突で同一スライド内に重複 id が出る → 出現順に一意再採番 |
| Content_Types | 実体の無い `slideMaster` Override を除去（[#1449](https://github.com/gitbrent/PptxGenJS/issues/1449)） |
| presentation.xml | `notesMasterIdLst` を `sldIdLst` の前へ移動（要素順序） |
| チャート | 未定義の余分な `axId` 除去・`lineChart` への `grouping` 補完・bar/bubble 以外からの `invertIfNegative` 除去・`marker`/`dPt` を `dLbls` の前へ移動 |
| 影 | カードの `shadow` は毎回新規オブジェクトを渡す（PptxGenJS が破壊的変更するため使い回すと値が膨張し不正化） |

> **重要**: notesMaster のテーマ共有・cNvPr id 重複はパッケージの意味制約であり、Microsoft Open XML SDK の `OpenXmlValidator`（Office2019 スキーマ）では検出されない（スキーマ検証 0 エラーでも PowerPoint が「修復」を要求する）。実機の PowerPoint で開けることを確認済み。

## 実装との対応

本仕様は `.claude/scripts/office/node/render_slides.mjs` の定数（`C` / `F` / `CHART_TYPE_MAP` / レイアウトレンダラー）および `savePresentation()` の補正ロジックと一致させること。仕様変更時は両方を更新する。
