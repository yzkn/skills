# アニメーション標準リファレンス

レビューの根拠となる正確な数値・カーブ・ルール集。指摘事項ではおおよその値で済ませず、これらを引用すること。Emil Kowalski のデザインエンジニアリング哲学から抽出したもの。

## アニメーションすべきか（頻度テーブル）

| 頻度 | 判断 |
| --- | --- |
| 1 日 100 回以上（キーボードショートカット、コマンドパレットのトグル） | アニメーションは付けない。例外なし |
| 1 日数十回（hover エフェクト、リストナビゲーション） | 削除するか大幅に縮小する |
| たまに発生（モーダル、ドロワー、トースト） | 標準的なアニメーション |
| まれ／初回限定（オンボーディング、フィードバック、祝福演出） | 遊び心を加えてもよい |

**キーボード操作で発生するアクションには、決してアニメーションを付けない**——1 日に何百回も繰り返される操作であり、アニメーションを付けると遅く・つながりのない印象を与えてしまう（Raycast には開閉アニメーションがない——1 日に何百回も使われるものとして、これは正しい判断である）。

モーションが正当化される目的: 空間的な一貫性、状態の提示、説明、フィードバック、唐突な変化の回避。頻繁に目にする要素で「かっこいいから」は正当な理由にならない。

## イージング

判断の優先順位:
- 出現・消失する場合 → **`ease-out`**（速く始まり、応答性が高く感じられる）
- 画面上を移動・変形する場合 → **`ease-in-out`**
- hover・色の変化 → **`ease`**
- 一定速度の動き（マーキー、プログレスバー） → **`linear`**
- デフォルト → **`ease-out`**

**UI に `ease-in` は決して使わない。** ゆっくり始まるため、ユーザーがまさに注視している瞬間を遅らせてしまう。200ms の `ease-out` は、200ms の `ease-in` よりも速く**感じられる**。

CSS 組み込みのイージングは弱すぎる。強めのカスタムカーブを使うこと。

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);        /* strong ease-out for UI */
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);    /* strong ease-in-out for on-screen movement */
--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);     /* iOS-like drawer curve (Ionic) */
```

カーブは [easing.dev](https://easing.dev/) や [easings.co](https://easings.co/) から探すこと——ゼロから手作りしない。

## Duration

| 要素 | Duration |
| --- | --- |
| ボタン押下のフィードバック | 100–160ms |
| ツールチップ、小さなポップオーバー | 125–200ms |
| ドロップダウン、セレクト | 150–250ms |
| モーダル、ドロワー | 200–500ms |
| マーケティング／説明用途 | より長くてもよい |

**ルール: UI アニメーションは 300ms 未満に収める。** 180ms のドロップダウンは 400ms のものよりも応答性が高く感じられる。スピナーを速くすると、実際の時間は同じでも読み込みが速く感じられる。2 回目以降のツールチップを即時表示にする（delay とアニメーションをスキップする）と、ツールバーが速く感じられる。

## 物理的な妥当性

- **`scale(0)` は決して使わない。** `scale(0.9〜0.97)` + `opacity: 0` から開始する。現実世界で、何もない状態から突然現れるものはない。
- **起点を意識したポップオーバー。** 中央ではなくトリガー要素から拡大する。
  ```css
  .popover { transform-origin: var(--radix-popover-content-transform-origin); } /* Radix */
  .popover { transform-origin: var(--transform-origin); }                       /* Base UI */
  ```
  **モーダルは例外**——ビューポート中央に表示されるため、`transform-origin: center` のままでよい。
- **ボタン押下のフィードバック。** `:active` に `transform: scale(0.97)`、`transition: transform 160ms ease-out`。控えめに（0.95〜0.98）。押下可能な要素全般に適用できる。

## Spring

物理シミュレーションに基づくため自然に感じられる。固定の duration はなく、パラメータに応じて収束する。以下の用途に使う: 慣性を伴うドラッグ、「生きている」ように見せる要素（Dynamic Island）、中断可能なジェスチャー、装飾的なマウス追従。

```js
// Apple-style (easier to reason about) — recommended
{ type: "spring", duration: 0.5, bounce: 0.2 }

// Traditional physics (more control)
{ type: "spring", mass: 1, stiffness: 100, damping: 10 }
```

bounce は控えめに保つ（0.1〜0.3）。ほとんどの UI では bounce を避け、drag-to-dismiss や遊び心のあるインタラクションのために取っておく。Spring は中断された際も velocity（速度）を維持する（keyframes はゼロから再生し直す）ため、ユーザーが動作の途中で反転させ得るジェスチャーに適している。

マウスによるインタラクション: マウス位置に値を直接紐づける（人工的で慣性がない）のではなく、`useSpring` で補間する。ただし、このモーションが装飾的な場合に限る。

## 中断可能性

CSS の **transition** は途中で中断・再ターゲットできるが、**keyframes** はゼロから再生し直す。素早く連続して発火するもの（追加されるトースト、トグル）には transition の方が滑らかである。

```css
/* Interruptible — good for dynamic UI */
.toast { transition: transform 400ms ease; }

/* Not interruptible — avoid for dynamic UI */
@keyframes slideIn { from { transform: translateY(100%); } to { transform: translateY(0); } }
```

JS を使わない出現には `@starting-style` を使う。

```css
.toast {
  opacity: 1; transform: translateY(0);
  transition: opacity 400ms ease, transform 400ms ease;
  @starting-style { opacity: 0; transform: translateY(100%); }
}
```

レガシー環境向けの代替手段: `useEffect(() => setMounted(true), [])` + `data-mounted` 属性。

## 非対称な timing

ユーザーが判断している間はゆっくりと、システムが応答する間は素早く。

```css
.overlay { transition: clip-path 200ms ease-out; }            /* release: fast */
.button:active .overlay { transition: clip-path 2s linear; }  /* press: slow, deliberate */
```

## パフォーマンス

- **アニメーションさせるのは `transform` と `opacity` のみ**——これらは layout／paint をスキップし、GPU 上で処理される。`padding`/`margin`/`height`/`width`/`top`/`left` は、レンダリングの 3 ステップすべてを引き起こす。
- **親要素の CSS 変数で子要素の transform を駆動しない**——すべての子要素のスタイル再計算を引き起こす。`transform` は対象要素に直接設定すること。
  ```js
  element.style.setProperty('--swipe-amount', `${d}px`); // bad: recalc on all children
  element.style.transform = `translateY(${d}px)`;        // good: only this element
  ```
- **Framer Motion のショートハンドはハードウェアアクセラレーションの対象外である。** `x`/`y`/`scale` は rAF を介してメインスレッド上で動作し、負荷がかかるとフレームを落とす。完全な transform 文字列を使うこと。
  ```jsx
  <motion.div animate={{ x: 100 }} />                          // drops frames under load
  <motion.div animate={{ transform: "translateX(100px)" }} />  // hardware accelerated
  ```
- **負荷時は CSS アニメーションが JS アニメーションに勝る**——CSS アニメーションはメインスレッド外で動作するのに対し、rAF ベースのアニメーションはブラウザが読み込み・スクリプト実行・描画を行っている間にカクつく。あらかじめ決まったモーションには CSS を、動的・中断可能なモーションには JS を使うこと。
- **WAAPI** は、CSS 相当のパフォーマンス（ハードウェアアクセラレーション対応・中断可能・ライブラリ不要）を JS から制御できる。
  ```js
  element.animate([{ clipPath: 'inset(0 0 100% 0)' }, { clipPath: 'inset(0 0 0 0)' }],
    { duration: 1000, fill: 'forwards', easing: 'cubic-bezier(0.77, 0, 0.175, 1)' });
  ```

## Transform と clip-path

- **`translate` のパーセント値**は要素自身のサイズに対する相対値である——`translateY(100%)` は、実際の寸法に関わらず要素自身の高さ分だけ移動する（Sonner や Vaul がトースト／ドロワーを配置する際の方法）。固定の px 値よりもこちらを優先すること。
- **`scale()` は子要素もスケーリングする**（フォント・アイコン・コンテンツ）——押下フィードバックにおいてはこれが有用な特性となる。
- **3D**: 奥行き・軌道・反転を JS なしで表現するには `rotateX/Y` + `transform-style: preserve-3d` を使う。
- **`clip-path: inset(t r b l)`** は強力なアニメーション手段である。各値がその辺から内側に食い込む。用途: スクロール連動の出現（`inset(0 0 100% 0)` → `inset(0 0 0 0)`）、hold-to-delete のオーバーレイ、シームレスなタブの色遷移（アクティブなコピーを複製して clip する）、比較スライダー。

## ジェスチャーとドラッグ

- **慣性による dismiss（消去）**: 移動距離のしきい値を課すのではなく、velocity（速度）を計算する（`Math.abs(distance)/elapsedMs`）。`> 約 0.11` であれば dismiss する。フリック動作だけで十分とする。
- **境界での減衰（damping）**: 自然な端を超えてドラッグするほど、移動量を小さくする（現実のものは止まる前に減速する）。
- **ポインタキャプチャ**: ドラッグ開始後はポインタキャプチャを行い、ポインタが範囲外に出ても継続できるようにする。
- **マルチタッチ対策**: ドラッグ開始後に追加されたタッチポイントは無視する（`if (isDragging) return`）——ジャンプを防止する。
- **ハードストップよりも摩擦（friction）を優先する**——見えない壁ではなく、抵抗が徐々に強まる形での over-drag を許容する。

## 不完全なクロスフェードを馴染ませる

イージングと duration を調整しても、クロスフェードで 2 つの状態が重なって見えてしまう場合は、遷移中に軽い `filter: blur(2px)` を加え、1 つの変化として知覚されるように馴染ませる。blur は 20px 未満に抑えること（強い blur は負荷が高く、特に Safari で顕著である）。

## Stagger

グループの出現には stagger（ずらし）を付け、要素間は 30〜80ms とする。それより長い delay は遅く感じられる。stagger は装飾的な演出であり、再生中にインタラクションをブロックしてはならない。

```css
.item { opacity: 0; transform: translateY(8px); animation: fadeIn 300ms ease-out forwards; }
.item:nth-child(2) { animation-delay: 50ms; }
.item:nth-child(3) { animation-delay: 100ms; }
@keyframes fadeIn { to { opacity: 1; transform: translateY(0); } }
```

## アクセシビリティ

```css
@media (prefers-reduced-motion: reduce) {
  .element { animation: fade 0.2s ease; } /* keep opacity/color, drop transform-based motion */
}
@media (hover: hover) and (pointer: fine) {
  .element:hover { transform: scale(1.05); } /* gate hover motion — touch fires false hovers on tap */
}
```

```jsx
const reduce = useReducedMotion();
const closedX = reduce ? 0 : '-100%';
```

reduced motion とは、アニメーションをゼロにすることではなく、より少なく・より穏やかにすることを意味する——理解を助ける transition は残し、movement／position の変化を取り除く。

## デバッグ（感触に確信が持てない場合、レビューで推奨する）

- **スローモーション**: duration を 2〜5 倍に伸ばすか、DevTools のアニメーションインスペクタを使う。色のクロスフェードが滑らかか、イージングが不自然に止まらないか、`transform-origin` が正しいか、連動するプロパティが同期しているかを確認する。
- **コマ送り**: Chrome DevTools の Animations パネルで、連動するプロパティ間の timing のずれを可視化できる。
- **実機での確認**: ジェスチャー（ドロワー、スワイプ）は実機で確認する——スマートフォンを接続し、IP 経由で開発サーバーにアクセスし、Safari のリモート devtools を使う。
- **翌日、新鮮な目で見直す**——開発中は気づかなかった不備が後になって見えてくる。

## 一貫性（Cohesion）

モーションはコンポーネントの個性に合わせる。遊び心のあるプロダクトはより弾む動きでよく、業務用ダッシュボードはきびきびと素早い動きを保つべきである。Sonner が「しっくりくる」と感じられるのは、イージング・duration・デザイン、さらには名前までもが調和しているからである——エレガントに感じさせるため、`ease-out` ではなくやや遅めの `ease` を用いている。出現・消失するリストにおける opacity と height の組み合わせは試行錯誤の産物であり、決まった公式はない——しっくりくるまで調整すること。
