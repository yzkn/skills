# Slop テスト — 全ゲートチェックリスト

[Hallmark](https://github.com/Nutlope/hallmark)（MIT）の `slop-test`（58 ゲート）を日本語へ翻案。**各ゲートは「答えが『はい』なら不合格」**。監査時にこの一覧を上から照合する。

一部のゲートは **普遍的**（全ジャンルに適用）、一部は **ジャンル限定**（editorial / atmospheric / modern-minimal / playful のいずれか）。ジャンル注記のないものは普遍と見なす。

---

## Visual（視覚）

1. ディスプレイフォントが Inter / Roboto / Open Sans / Poppins / Lato / システムデフォルトのいずれかになっていないか。
2. 紫→青（またはシアン→マゼンタ）のグラデがどこかにないか（`background-clip: text` のグラデ見出しを含む）。*atmospheric は背景の放射グラデのみ可。テキスト・ピルボタンには不可。テキストグラデはどのジャンルでも不可。*
3. アイコン上・見出しの 3 等分カードグリッドになっていないか。
4. カードが別のカードに入れ子になっていないか。
5. 片側に太い色付きストライプボーダーのカードがないか。
6. **ヒーロー形状 — 全中央寄せ。** `min-height:100vh` で全要素中央、または eyebrow・タイトル・リード・CTA が同一の中央縦軸に積まれていないか。中央寄せは最大 2 要素まで、残りは軸を外す。*atmospheric / playful はキャンバス自体がデザインの場合に中央可。editorial / atelier は narrow 中央可だが eyebrow か CTA は軸外し。*
7. 純 `#000` / 純 `#fff` をベース色に使っていないか。*modern-minimal は純白紙を許容。*

## Structural（構造）

8. 使うべきでない構造を再利用していないか。汎用 AI テンプレ（Hero→3 features→CTA→footer）、または同一プロジェクトの前ページと同じ構造的指紋/マクロ構造。`.hallmark/log.json` や CSS のマクロ構造スタンプがあれば、今回のマクロ構造は前回と変えること。
9. セクション区切りが均等な余白のみで、罫線・装飾・色変化がなく、全セクションが同一リズムになっていないか。

## Microinteractions（マイクロインタラクション）

10. `transition-all`（`transition: all`）を使っていないか（プロパティを明示せよ）。
11. `hover:scale-105`（一律の hover 拡大）を無関係な複数要素に適用していないか。
12. 弾む/オーバーシュート easing（`cubic-bezier(0.34, 1.56, ...)` 等）を UI 状態変化（ボタン・モーダル・ツールチップ）に使っていないか。オーバーシュートは物理操作のみ。
13. 1 要素に同時 2 つ以上の hover 効果（translate＋scale＋shadow＋color＋rotate）がないか。
14. `width` / `height` / `top` / `left` / `margin` / `padding` をアニメーションさせていないか。
15. フォーカスリングがフェードインしていないか（フォーカスリングは即時表示。キーボード利用者には即座のインジケータが必要）。
16. ユーザーに効果が既に見えているアクションに祝祭的な成功トーストを出していないか（無音成功が上品。トーストは失敗・不可視効果向け）。
17. ツールチップの hover 遅延と focus 遅延が同じになっていないか（hover は 800〜1000ms、focus は 0ms）。
18. 自動回転コンテンツ（カルーセル・バナー・stats）に hover/focus での一時停止がないか（WCAG 2.2.2）。
19. プレースホルダ名「Jane Doe / John Smith」やスタートアップ常套句（Acme, Nexus, Seamless, Unleash）がないか。

## Variety（多様性）

20. CSS 冒頭のマクロ構造スタンプ（`/* Hallmark · macrostructure: <name> ... */` 相当）が欠けていないか。
21. ブリーフが editorial / foundry / specimen を明示していないのに Specimen マクロ構造（左マージン連番＋巨大セリフ＋非対称スパン＋タイポのみ CTA）に既定していないか。*atmospheric / modern-minimal / playful は Specimen に既定しない。*

## Implementation gates（実装）

22. ニュートラル/サーフェス色に `oklch(... 0 ...)`（彩度ゼロ）がないか。純グレーは平坦。アンカー色へ最低 0.005 の彩度でティント。*modern-minimal は彩度ゼロ許容。*
23. アクセント色が単一ビューポートの約 5% 超を占めていないか（面積で計算）。超えるなら退く。*atmospheric はアクセントの放射ブルームで最大 20% まで可。*
24. パディング/ギャップ/マージンが命名スペーシングスケール（4px の倍数）外の値になっていないか。`padding: 17px` のような恣意値は tell。
25. 本文コンテナの `max-width` が 45〜75ch の範囲外になっていないか。
26. インタラクティブ要素に `:focus-visible` / `:active` / `:disabled` のいずれかが欠けていないか（8 状態が原則。最低でも default + hover + focus-visible + active + disabled）。
27. `@media (prefers-reduced-motion: reduce)` フォールバックに含まれない `transform`/`animation` キーフレームがないか。

## Hero enrichment gates（ヒーロー加飾）

28. デモ動画が音声付き autoplay／`poster` 欠如／`fetchpriority="high"` 欠如／LCP 要素に `loading="lazy"` になっていないか（LCP キラー）。
29. 抽象背景が 1 色超・約 5% 超・全面メッシュグラデアニメになっていないか。*atmospheric は暖色の放射ブルーム 2 つまで・約 20〜30%・固定・非アニメで可。*
30. **アイコンの tell。** (a) 2 つ以上のアイコンライブラリ混在、または (b) 絵文字（✨🚀⚡🔥🎯✅）をフィーチャー/価値/ステップ/価格帯アイコンに使っていないか。→ 1 ライブラリに統一／カスタム SVG／タイポで主導。
31. イラストで、手描き SVG や純 CSS 図形で足りるのに Lottie ライブラリに既定していないか。

## Diversification gates（多様化）

32. 前出力と同じアーキタイプを使った場合、少なくとも 1 つ別の variation knob を選んだか。
33. 装飾的な `<svg>` / カスタムアート `<div>` / `<canvas>` / 装飾図に `aria-label` か `aria-hidden="true"` が欠けていないか。

## Layout-safety gates（レイアウト安全）

34. 320〜1920px のいずれかで横スクロールが発生しないか。修正は `html` と `body` **双方**に `overflow-x: clip`（`hidden` ではなく `clip`。`clip` は子孫の `sticky`/`fixed` を保持）。全出力必須。
35. テキストの装飾効果（ハイライタ `<mark>`／`<em>` バンド／アクセントストローク／下線）の位置とサイズを目視確認したか。ハイライタは x-height の背後（ベースラインではない）。下線は 1〜2px でベースラインから 1〜2px オフセット。
36. インタラクティブバー（ナビ・ツールバー・コマンドバー・ヒーロー CTA 行・フッターリンク帯）を明示的に垂直中央寄せしたか。高さの異なる要素を混ぜる flex 行は `align-items: center` と、固有高を持つ項目に `line-height: 1`。

## Typography discipline gates（タイポグラフィ規律）

37. `font-family` が 4 種以上になっていないか（`--font-display` + `--font-body` + 例外 1 つまで＝上限 3）。
38. 例外書体（outlier）が 3 スロット以上で使われていないか（レジスタであって第 3 の本文面ではない）。
38a. **見出し/ディスプレイ書体が斜体になっていないか**（`h1`–`h6`・各種タイトル・ワードマーク・stat・フッター声明・見出し内 `<em>`/`<i>`）。斜体見出し（特にローマン見出し内の一語だけ斜体）は最上位の AI tell。見出しはローマン。斜体は本文中の強調のみ。

## Input-state gate（入力状態）

39. input / textarea / select が全状態を正しく扱っているか。以下いずれかに該当したら不合格：
    - 状態間で `border-width` が変わる（default/hover/focus/error で 1px 維持。変化は background/outline/box-shadow/border-color へ）。
    - フォーカスリングを `outline` でなく `border` で作っている（`outline: 2px solid var(--color-focus)` ＋ `outline-offset: 1px`。静止時に透明 outline を予約）。
    - 入力高さ ≠ 隣接ボタン高さ（同一フォームで 44px 基準を共有）。
    - ヘルパーテキスト枠が空で潰れる（`min-height: 1lh` を予約）。
    - 無効化を `opacity` だけで表現（`opacity: 0.55` ＋ `cursor: not-allowed` ＋ ネイティブ `disabled`/`aria-disabled` の 3 チャネル）。

## Contrast & readability（コントラスト・可読性）— 普遍

コントラスト計算: 各 `(color, background-color)` ペアに APCA Lc または WCAG 2.1 比を適用。OKLCH の明度差 `< 50%` は要精査。

40. **コントラスト閾値。** テキスト・アイコン・`:focus-visible` リングが計算上の背景に対し閾値を割っていないか。本文（24px 未満 regular / 18px 未満 bold）は WCAG 4.5:1 / APCA Lc≥60。大テキスト・アイコン・フォーカスリングは WCAG 3:1 / APCA Lc≥45。見落とし頻出：カード内で `color` を継承したまま地色が変わったケース、`--color-muted` on `--color-paper-3`、ページ地に対して 3:1 を割るフォーカスリング。
41. **最も頻繁に出荷される破綻。** いずれか該当で不合格：
    - **ボタン文字 ≒ ボタン地色**（OKLCH で明度差 5%・彩度差 0.05 以内は不合格。黒地に黒文字バグ）。
    - **`--color-accent-ink` 未定義/未使用**（アクセント地にテキストを載せる時は前景色を定義し、対アクセントで Lc≥60 / 4.5:1 を検証して適用）。
    - **暗色セクションのインク・オン・インク**（OKLCH 明度 <50% の地は同一ルールで文字色も反転し、子孫に継承）。

## Nav · footer · hero の構造 slop — 普遍

42. **ナビの指紋。** `<nav>` が AI デフォルト（ワードマーク左＋インライン 4〜5 リンク中央/右＋ボタン右＋全幅＋下ヘアライン＋白背景）になっていないか。→ ページの遷移先が真に 2 つでルーティング表が許す場合を除き回避。
43. **フッターの指紋。** `<footer>` が AI デフォルト（Product/Company/Resources/Legal の 4 カラム＋ソーシャル行＋極小コピーライト＋上ヘアライン＋グレー背景）になっていないか。→ 真の docs ルート/ハブを除き回避。
44. **ヒーローの収まり。** (a) `padding-block-end` が `padding-block-start` の 1.3 倍以上か。(b) 1280×800 でヒーローの要点（eyebrow・見出し・リード・**主 CTA**・ビジュアル焦点）がスクロールせず収まるか。オーバーフロー時はディスプレイ `clamp()` 上限を下げ、line-height 1.0〜1.1、リードを約 2 行に。
45. **無意味な装飾。** ヒーローに、コンテンツ上の意味的アンカーを持たない装飾要素（カーソル・スキャンライン・グラデ blob・抽象形状・バッジ・ステッカー）がないか。装飾には動機が必要。

## Honest copy · 捏造禁止 — 普遍

46. **捏造メトリクス。** ユーザー未提供・出典なしの定量主張（「10倍高速」「50,000+ チーム」「99.9% 稼働」「+47% CVR」等）を stat 枠を埋めるために創作していないか。→ `—` ＋ラベル付きグレーブロック／ユーザーに確認／stat 枠のない構成へ。**stat を単独でヒーロー見出しにしない**（数字は必ず意味を述べる語と対に）。

## 描き直した UI クローム — 普遍

47. **描き直しクローム。** 偽ブラウザバー・偽スマホフレーム・偽コードウィンドウ・偽ターミナル・偽 IDE を HTML/CSS/SVG で自作していないか。→ 実スクショを `<figure>` に、またはクロームを省く。

## トークン規律 — 普遍

48. **レンダリング途中のトークン即興。** `:root` / `[data-theme]` のトークン外で色値（hex/oklch/rgb/hsl）や `font-family` を導入していないか。全色・全フォントは命名トークン（`var(--color-accent)` 等）参照。必要な値はトークンブロックに追加してから参照。

## Responsive — クリック可能アフォーダンス — 普遍

49. **クリック要素の 2 行折り返し。** ボタンラベル・主ナビリンク・フッターリンク・タブ・パンくず・CTA が 320〜1920px のいずれかで 2 行以上に折り返していないか。→ ラベル短縮（最良）／`white-space: nowrap`＋親でリフロー／狭幅で非必須項目を `hidden=until-found`／閾値以下でシート/メニューに集約。主 CTA・ナビリンクは決して折り返さない。

## Mobile-responsiveness の必須項目 — 普遍

320 / 375 / 414 / 768px で完璧にレンダリングされること。各ビューポートを目視で確認する。

50. **画像を含むグリッドトラックが `minmax(0, 1fr)` でない。** `1fr` を含む `grid-template-columns/rows` のトラックに `<img>`/`<picture>` があるなら `minmax(0, 1fr)` にする（素の `1fr` は `minmax(auto, 1fr)` で画像の固有幅が最小になりオーバーフロー）。
51. **ディスプレイ見出しに長語折り返しがない。** ディスプレイサイズ要素に `overflow-wrap: anywhere; min-width: 0` が欠けていないか（「AI-generated」等のハイフン複合語がオーバーフロー）。
52. **テーマ別セクション見出しのモバイル崩れ。** `.section__head` を `1fr` 以外に上書きするテーマが、モバイル折り畳みルール（`@media (max-width: 48rem)` で `1fr` へ）を伴っていないか。
53. **CSS-only ラジオタブのスクロールジャンプ。** `<input type="radio">` ＋ `:checked` のタブで、ラジオが通常フロー（サイズ 0・opacity 0）か、JS で `preventDefault`＋`preventScroll` を伴っているか。`position: absolute; top: 0` で JS ガードなしは不合格。
54. **タグ左・見出し右の 2 カラムセクション見出し。** eyebrow/番号/モノラベルを見出しの左（または右）に同一行で置いていないか。**自動不合格。** eyebrow を使う時は見出しをその直下・同一カラムに縦積みのみ。eyebrow＋見出しを含むラッパは単一カラム（`block` / `flex-direction: column` / `grid-template-columns: 1fr`）に。**「構造の踏襲/参照の再現」指示でも解除されない**——参照側が禁止パターンでも新規側は静かに平坦化する。
55. **全大文字ディスプレイ見出し × line-height < 1.0 のキャップ衝突。** ディスプレイ要素に `text-transform: uppercase` かつ `line-height`（`--lh-tight`）< 1.0 がないか。全大文字の下限は 1.0、推奨 1.02〜1.08。
56. **sticky ページナビ直下の `top: 0` sticky 要素のブリード。** ページ最上位ナビ以外の要素に `position: sticky; top: 0;` があり、かつ sticky な `<header>`/`<nav>` も `top: 0` にある（top-0 の sticky が 2 つ）状態になっていないか。→ `--banner-height` トークンを定義し二次 sticky を `top: var(--banner-height)` に。ナビの z-index を高く。
57. **study で抽出した DNA を破棄してカタログテーマに戻していないか**（`design-dna` 併用時）。会話中に DNA 診断が出ているのに、ユーザーの明示的な方針転換なしにカタログテーマ名を採用していないか。

---

判定：いずれかが「はい」なら修正対象。slop を出荷しない。
