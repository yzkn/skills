# explainer-html コンポーネント一覧（必要時に Read する）

[`../assets/template.html`](../assets/template.html) の `<style>` に定義済みのクラスと、その正しいマークアップ。**ここにないクラスを新規に作らない**。ページ固有の `<style>` は図の配置調整など最小限にとどめる。

## ページ骨格

```html
<div class="mb-page">
  <h1>タイトル</h1>
  <p class="mb-lede">リード文（この文書が何を説明するか 1〜3 文）</p>
  <p class="mb-meta-line">2026-08-03</p>
  <nav class="mb-toc" aria-label="目次"><ol><li><a href="#s1">見出し</a></li></ol></nav>
  <div class="mb-wrap">
    <main class="mb-main"> ... 本文 ... </main>
    <aside class="mb-glossary"> ... 用語表 ... </aside>
  </div>
  <p class="mb-footer">出典・作成日</p>
</div>
```

- `.mb-wrap` は本文 + 用語サイドバーの 2 カラム。幅 1000px 以下で 1 カラムに落ちる
- `h2` には目次から参照する `id` を必ず付ける

## 用語表（サイドバー）

```html
<aside class="mb-glossary">
  <h2>用語</h2>
  <table>
    <thead><tr><th>用語</th><th>説明</th></tr></thead>
    <tbody>
      <tr><td class="mb-rowlabel">冪等性</td><td>同じ操作を複数回実行しても結果が変わらない性質。</td></tr>
    </tbody>
  </table>
</aside>
```

- `.mb-rowlabel` は語中で折り返さない。用語列に必ず付ける

## カード・グリッド・要点ボックス

```html
<div class="mb-card">
  <div class="mb-card-title">見出し付きカード</div>
  <p>本文</p>
</div>

<div class="mb-grid-2">
  <div class="mb-card"><p class="mb-card-label">案 A</p><p>…</p></div>
  <div class="mb-card"><p class="mb-card-label">案 B</p><p>…</p></div>
</div>

<div class="mb-summary">
  <p>「要点」の見出しは CSS が自動で付ける。ここには本文だけ書く。</p>
</div>
```

- `.mb-grid-3` は 3 列。幅 1000px 以下で 1 列に落ちる

## 引用

```html
<blockquote class="mb-quote">
  <p class="mb-quote-original">The system SHALL retain audit logs for a minimum of 90 days.</p>
  <p class="mb-quote-ja">システムは監査ログを最低 90 日間保持しなければならない。</p>
  <p class="mb-quote-source">[ACME-SEC-STD (2026/03), Section 4.1]</p>
</blockquote>
```

- 原文と訳文は同じ文字サイズ・色で上下に並べる（`.mb-quote-ja` が罫線で区切る）
- 原典が日本語なら `.mb-quote-ja` は省略する
- 典拠参照の形式は [`/citation-format`](../../citation-format/SKILL.md) に従う

## チップ

```html
<span class="mb-chip">Azure AD</span> <span class="mb-chip">Entra ID</span>
```

- **並列の固有名・分類名の列挙にだけ使う**。強調や装飾に使わない

## 表

```html
<div class="mb-table-scroll">
  <table>
    <thead><tr><th>列 1</th><th>列 2</th></tr></thead>
    <tbody><tr><td class="mb-rowlabel">行見出し</td><td>値</td></tr></tbody>
  </table>
</div>
```

- 表は短い対応関係に使い、**3 列までを基本**とする
- 横に長くなる場合は `.mb-table-scroll` で囲む。ページ本体を横スクロールさせない

## コード

ハイライト不要な場合:

```html
<pre><code>plain text here</code></pre>
```

ハイライトする場合は pandoc の出力（`<span class="kw">` 等）をそのまま埋め込む。生成方法は SKILL.md の「コード」節を参照。独自の色付けを `<style>` で足さない。

## コード差分

```html
<pre class="mb-diff"><span class="ctx">function apply(config) {</span><span class="del">  return config.value;</span><span class="add">  return config.value ?? DEFAULT;</span><span class="ctx">}</span></pre>
```

- `+` / `-` の行頭記号は CSS が付ける。テキストに書かない
- **差分を示す前に、何をなぜ変えたかを散文で説明する**

## 図

```html
<figure class="mb-figure">
  <div class="mb-figure-frame">
    <svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="構成の概要">
      <!-- 黒一色の線画。stroke="currentColor" を使うとダーク時に自動反転する -->
      <rect x="10" y="10" width="120" height="50" fill="none" stroke="currentColor" stroke-width="1.5" rx="8"/>
    </svg>
  </div>
  <figcaption>図 1: 構成の概要</figcaption>
</figure>
```

- 自作図は**インライン SVG**。アスキーアート・絵文字・矢印文字を図記号として使わない
- 線色は `currentColor` を使う（`.mb-figure-frame svg` が `--mb-ink` を渡すためダークでも消えない）
- 原典に重要な図がある場合は模倣図を作らず、出所を明示して画像を引用する（切り出しは SKILL.md の「原典の図表を引用する」節）
- ノードが多い場合は縦方向を優先し、矢印が交差する構成を避ける

## 数式（MathML）

```html
<div class="mb-math-block" data-latex="E = mc^2">
  <math display="block" xmlns="http://www.w3.org/1998/Math/MathML">
    <mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup>
  </math>
</div>

<span class="mb-math-inline" data-latex="\alpha + \beta">
  <math xmlns="http://www.w3.org/1998/Math/MathML"><mi>α</mi><mo>+</mo><mi>β</mi></math>
</span>
```

- `data-latex` に LaTeX 原文を入れると、コピーボタンがテンプレートの JS によって自動で付く
- ベクトル・行列は太字（`<mi mathvariant="bold">`）、スカラー・添字・集合名は装飾しない
