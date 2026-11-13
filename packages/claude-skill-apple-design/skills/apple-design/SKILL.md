---
name: apple-design
description: "Apple のインターフェースデザインと物理的なモーションを Web に翻案した実装・レビュー指針。「Apple 風の UI を設計して」「モーションを診断して」で自動適用。/apple-design [対象]。"
---

# Apple Design

Apple が「コンピュータらしさ」を消し、まるで自分の身体の延長のように感じさせるインターフェースをどう作っているか。この知見は Apple の WWDC デザインセッション——主に *Designing Fluid Interfaces*（WWDC 2018）——を出典とし、Web プラットフォーム（CSS、Pointer Events、`requestAnimationFrame`、Motion/Framer Motion のような spring ライブラリ）向けに翻案したものである。

一貫したテーマはこうだ。**インターフェースが生きているように感じられるのは、モーションが画面上の現在値（current on-screen value）から始まり、ユーザーの velocity を引き継ぎ、momentum を前方へ投影し、いつでも掴んで反転できるときである。** Spring はこれらすべてを自然に実現するための道具であり、それは本質的に中断可能（interruptible）かつ velocity を意識した仕組みだからだ。

## 核となる考え方

> 「インターフェースを人間の思考や動きに合わせたとき、不思議なことが起こる——それはコンピュータらしさを失い、自分自身のシームレスな延長のように感じられ始める。」

インターフェースが流動的（fluid）であるとは、それが物理世界のように振る舞うということだ。瞬時に反応し、連続的に動き、momentum を保持し、境界では抵抗し、動作の途中でも方向転換できる。以下のすべては、その状態に近づくための手段である。

Apple はデザインを、人間の 4 つのニーズ——**安心・予測可能性（safety/predictability）、理解（understanding）、達成感（achievement）、喜び（joy）**——に応えるものと位置づけている。ここに挙げるすべてのルールは、そのいずれかに資するものだ。

## 1. Response — レイテンシーを排除する

わずかでもラグが生じた瞬間、直接操作している感覚は「崖から落ちるように」失われる。Response はそれ以外すべての土台となる原則である。

- **release ではなく pointer-down で反応する。** ボタンは押された瞬間にハイライトする。`click` やタッチアップまでフィードバックを待つと、反応が死んでいるように感じられる。
- **あらゆるレイテンシーに目を光らせる。** debounce、人為的なタイマー、トランジションの待ち時間、約 300ms のタップ遅延を洗い出す。入力経路上にあって本質的でないものはすべて劣化要因である。
- **フィードバックは操作の完了時だけでなく、操作の「最中」ずっと継続していなければならない。** drag・slider・drawer では、ジェスチャーの間ずっと 1:1 でポインターに追従して UI を更新する。ジェスチャーが完了したときだけアニメーションさせてはならない。

```css
/* Feedback lives on the press, and it's instant */
.button:active {
  transform: scale(0.97);
  transition: transform 100ms ease-out;
}
```

## 2. Direct manipulation — 1:1 の追従

> 「タッチとコンテンツは一緒に動かなければならない。」

ユーザーが何かをドラッグするとき、それは指に貼り付いたように動き続けなければならず、かつ「どこを掴んだか」というオフセットを尊重しなければならない。掴んだ瞬間に要素の中心にスナップしてしまうと、この錯覚は即座に壊れる。

- `setPointerCapture` を伴う Pointer Events を使い、ポインターが要素の範囲外に出てもトラッキングが継続するようにする。
- 現在のポイントだけでなく、直近数回の `pointermove` イベントによる**velocity/position の履歴**を追跡する。release 時に velocity が必要になるためだ。

```js
el.addEventListener('pointerdown', (e) => {
  el.setPointerCapture(e.pointerId);
  const grabOffset = e.clientY - el.getBoundingClientRect().top; // respect where they grabbed
  // ...track position + timestamp history for velocity
});
```

## 3. Interruptibility — 最も重要な単一の原則

> 「思考とジェスチャーは並行して起こる。」

すべてのアニメーションは、いかなる瞬間にも中断・方向転換が可能でなければならない。ユーザーは、アニメーションの完了を待たずに、動いている最中の要素を掴んで反転できなければならない。ユーザーが再び掴んだ閉じかけのモーダルは、閉じきってから開き直すのではなく、その場で指に追従すべきである。

- **トランジション中に入力をロックアウトしてはならない。**
- **アニメーションは常に「表示中（presentation）」の現在値から始め、目標値（target value）から始めてはならない。** 中断が起きたら、要素の画面上の transform を実際に読み取り、その値から新しいアニメーションを開始する。論理値／目標値から始めると、目に見えるジャンプが発生する。
- **gesture 駆動の要素には CSS transitions や `@keyframes` を避ける。** これらは動作中に滑らかに掴んで反転させることができない。Spring はデフォルトで現在値からアニメーションするため、中断にはまさに適している。
- **ジェスチャーが反転するとき、velocity は打ち切らずブレンドする。** 反転時にあるアニメーションを別のアニメーションに置き換えると、velocity の不連続——「レンガの壁」のような感触——が生まれる。re-target 時に現在の velocity を引き継ぐ spring ライブラリはこれを回避する（これは iOS ネイティブの *additive animations* が行っていることであり、Web では現在の velocity から re-target できる spring ライブラリを選ぶ）。
- **2D のモーションは独立した X と Y の spring に分解する。** 2D の距離に対して単一の spring を使うと、X と Y の velocity が異なる場合に同期が崩れる。

## 4. Behavior over animation — spring を使う

> 「アニメーションを、インターフェースによって規定されたものではなく、あなたとオブジェクトの間の会話だと考えよ。」

あらかじめ決められた固定 duration のアニメーションは、新しい入力に反応できない。Spring はそれができる——新しい入力は単に target を変えるだけで、モーションは連続したまま保たれる。ユーザーが触れられるものにはすべて spring を使う。

Apple は物理学的な三要素（mass/stiffness/damping）を意図的に廃し、デザイナー向けの 2 つのパラメータに置き換えた。以下のように考える。

- **Damping ratio** — overshoot（行き過ぎ）を制御する。`1.0` = critically damped、overshoot なしで滑らかに収束する。`1.0` 未満 = overshoot して振動する。低いほど弾む。
- **Response** — 値が target に到達するまでの速さを秒で表す。低いほどキビキビする。**これは「duration」ではない**——spring に固定の duration はなく、収束までの時間はパラメータから創発的に決まる。

**デフォルト:**
- ほとんどの UI は **damping `1.0`**（critically damped）から始める——上品で気を散らさない。
- bounce（damping `0.8` 前後）を加えるのは、**ジェスチャー自体に momentum があった場合のみ**（flick、投げる動作、ドラッグのリリース）。フェードインしただけのメニューが overshoot するのは違和感があるが、flick したカードが overshoot するのは自然に感じる。

**Apple が実際に採用している具体値:**

| Interaction | Damping | Response |
| --- | --- | --- |
| Move / reposition（例: PiP） | `1.0` | `0.4` |
| Rotation | `0.8` | `0.4` |
| Drawer / sheet | `0.8` | `0.3` |

**Web での対応（Motion / Framer Motion）:** `bounce` + `duration` の spring API は、Apple の damping + response と近い形でマッピングできる。安全なハウススタイルとしては、デフォルトはどこでも `damping: 1.0` の spring とし、bounce は momentum 駆動の物理的なインタラクションのために温存する。

```js
import { animate } from 'motion';

// Critically damped default (no overshoot)
animate(el, { y: 0 }, { type: 'spring', bounce: 0, duration: 0.4 });

// Momentum interaction — a little bounce, only because a flick preceded it
animate(el, { y: target }, { type: 'spring', bounce: 0.2, duration: 0.4 });
```

## 5. Velocity handoff — drag とアニメーションの継ぎ目

ジェスチャーが終わるとき、アニメーションは**指の正確な velocity のまま継続**しなければならない。そうすることで、ドラッグとアニメーションの間に目に見える継ぎ目が生じない。これは「fluid」と「fine（精巧）」を最も分ける細部である。

ポインターの release 時の velocity を spring の初期 velocity として渡す。spring API によっては**相対的な**velocity を要求するものがあり、その場合は target までの残り距離で正規化する。

```
relativeVelocity = gestureVelocity / (targetValue − currentValue)
```

例: 要素が `y=50`、target が `y=150`（残り 100px）、指の速度が 50px/s → spring の初期 velocity = `50 / 100 = 0.5`。Framer Motion / Motion は絶対値の px/s velocity をそのまま扱う（`velocity` オプション）ため、通常は生の値をそのまま渡せばよい。

## 6. Momentum projection — ジェスチャーの「行き先」へアニメーションする

> 「小さな入力から大きな出力を作る。」

release した位置から最も近い境界にスナップしてはならない。velocity を使って**静止位置を投影（project）**する——ちょうどスクロールの減速のように——そのうえで、投影された地点に最も近い target にスナップする。これこそが、flick が要素を「放り投げた」ように感じさせる仕組みである。

Apple の正確な投影関数（*Designing Fluid Interfaces* のサンプルコードより）:

```js
// decelerationRate ≈ 0.998 for normal scroll feel; 0.99 for snappier
function project(initialVelocity /* px/s */, decelerationRate = 0.998) {
  return (initialVelocity / 1000) * decelerationRate / (1 - decelerationRate);
}

const projectedEndpoint = currentPosition + project(releaseVelocity);
const target = nearestSnapPoint(projectedEndpoint);   // choose target from the projection
animateSpringTo(target, { velocity: releaseVelocity }); // then hand off velocity (§5)
```

注意: 物理の教科書に出てくる `v²/(2·decel)` は Apple が採用している式では**ない**——上記の指数関数的減衰（exponential-decay）の形を使うこと。これは優れた bottom-sheet や carousel（Vaul、Embla）における標準的な振る舞いである。

## 7. Spatial consistency — 対称な経路、アンカーされた原点

> 「何かが一方向に消えたなら、それは元の場所から現れることを期待する。」

- **入場と退場は同じ経路をたどる。** 右からスライドインしたパネルは、右へ向かって dismiss されなければならない。右から入って下から出る、という動きは分断された印象を与え、混乱を招く。
- **インタラクションをその発生源にアンカーする。** メニュー・ポップオーバー・シートは、それをトリガーした要素から発生しているように見せる。`transform-origin` をトリガー要素に設定し、ボタンとコンテンツの空間的な関係を明確にする（これは、ポップオーバーが中心からではなくトリガーから scale するのと同じ、原点への意識の話である）。
- **可逆的なトランジションでは easing を鏡合わせにする。** 往路と復路の経路が一致するよう、双方向で逆の cubic-bézier コントロールポイントを使う。

## 8. ジェスチャーの方向をヒントとして示す

人間はある軌道から最終状態を予測する。途中のモーションは、単に盲目的に補間するのではなく、行き先を示唆（telegraph）すべきである。Control Center のモジュールは「指に向かって成長し、外へ広がる」。中間フレームが結果を指し示すようにする。

## 9. Rubber-banding — 柔らかな境界

境界では、ハードに止めるのではなく、段階的に抵抗する。ハードストップは「フリーズした」ように読めるが、連続的な抵抗は「反応はしているが、これ以上は何もない」と読める。境界を越えて引っ張られるほど damping が強くなるようにする。

```js
// The further past the bound, the less the element follows — real things slow before they stop
function rubberband(overshoot, dimension, constant = 0.55) {
  return (overshoot * dimension * constant) / (dimension + constant * Math.abs(overshoot));
}
```

## 10. ジェスチャー設計の細部（「手触り」チェックリスト）

- **Tap:** タッチ「ダウン」の瞬間（即座に）ハイライトし、タッチ「アップ」でコミットする。ターゲット周辺に約 10px の hysteresis／ヒットパディングを設け、ドラッグして離れることによるキャンセルと復帰を許容する。
- **Drag/swipe:** 方向をコミットする前にわずかな移動しきい値（hysteresis、約 10px）を要求し、その後は 1:1 で追従する。
- **最初の動きから、起こりうるすべてのジェスチャーを並行して検出**し、意図が明確になった時点で負けたものを自信を持ってキャンセルする。最終状態のみを報告する認識器（`swipeleft` 型のイベント）は避ける——フィードバックに必要な連続的なトラッキングを捨ててしまうためだ。
- **判別の遅延を最小化する。** ダブルタップの検出は、避けようもなくシングルタップを遅延させる。その代償は、本当にダブルタップが存在する場面だけに払うべきである。

## 11. フレームレベルの滑らかさ

滑らかさとは、単なるフレームレートの問題ではなく「フレームの中に何があるか」の問題である。

- フレームごとの位置変化量を知覚しきい値以下に保ち、ストロービング（ちらつき）を避ける。
- 非常に速いモーションには、わずかな**モーションブラー／ストレッチ**を加えると速度感が伝わり、硬くシャープな残像よりも自然に見える。
- `requestAnimationFrame` は Web における画面同期クロックである（Apple では `CADisplayLink`）。compositor フレンドリーなプロパティ——`transform` と `opacity`——だけをアニメーションし、モーションが差し迫っている箇所には `will-change` でヒントを与える。

## 12. Materials & depth — 半透明が階層を伝える

Apple は半透明マテリアルを、注目を奪うことなく構造をもたらす「浮遊する機能レイヤー」として使う。Web では `backdrop-filter` で近似する。

- **nav／toolbar／sheet は半透明レイヤーとして構築する**（`backdrop-filter: blur()` + 半透明の背景）。コンテンツはその下をスクロールする——固定幅の帯を占有する不透明なバーにしない。
- **マテリアルの「重さ」が階層を伝える:** より暗く／重いマテリアルは構造的な領域（サイドバー等）を分離し、より軽いマテリアルはインタラクティブな要素（ボタン等）に注目を集める。**軽い半透明サーフェスを別の半透明サーフェスの上に重ねてはならない**——可読性が崩壊する。
- **大きなサーフェスほど「厚く」見せる:** 小さなチップよりも強い blur と深い shadow を使う。文脈に応じた shadow を検討する——テキストが多い/煩雑な背景の上ではより重く、プレーンな背景の上ではより軽く。
- **フォーカスさせるなら dim（暗転）、フローを保つなら分離する。** モーダルなタスクは、サーフェスと dimming scrim を組み合わせ、背景を奥／下へ押しやる。並行する非ブロッキングのパネルは、フローを壊さないよう scrim なしで半透明とオフセットを使う。sheet が積み重なる場合は、親レイヤーを段階的に dim して押し下げる。
- **Vibrancy が、変化する背景の上でもテキストの可読性を保つ。** ブラー／半透明サーフェスの上では、フラットなグレーのテキストを使わない——より高いコントラスト、やや太いウェイト、わずかな letter-spacing の増加を使う。色は半透明の前景ではなく、不透明なレイヤーに置く。
- **ハードな区切り線ではなく、スクロールエッジエフェクトを使う。** 固定ヘッダーの下に 1px のボーダーを引くのではなく、浮遊する chrome がコンテンツと実際に重なる箇所だけに、小さな blur／グラデーションマスクをフェードさせる。
- **フェードではなく「マテリアライズ（物質化）」させる。** glass／blur サーフェスの enter/exit では、blur の半径と scale を同時にアニメーションさせ、単なる opacity のフェードではなく、実在するマテリアルが現れたように見せる。

```css
.toolbar {
  background: rgba(255, 255, 255, 0.6);
  backdrop-filter: blur(20px) saturate(180%);
  border-top: 1px solid rgba(255, 255, 255, 0.4); /* bright top edge = light catching the material */
}
```

## 13. Multimodal feedback — motion + sound + haptics

複数の感覚を組み合わせるための 3 つのルール（*Designing Audio-Haptic Experiences* より）:

1. **Causality（因果関係）** — 何がそのフィードバックを引き起こしたかが明白でなければならない。実際の因果イベント（トグルが切り替わった瞬間、アイテムがスナップして収まった瞬間）でトリガーし、その性質を動作の物理性に合わせる。
2. **Harmony（調和）** — 視覚・音・haptic は**同一フレーム**で発火しなければならない。それらの間のレイテンシーは錯覚を壊す。CSS transition が音／haptic（Vibration API）に対して遅延しないようにする。
3. **Utility（実用性）** — フィードバックは、その価値に見合う場所にのみ追加する。haptics／sound は意味のある瞬間（成功・エラー・commit・snap）に限定する。過剰なフィードバックは、ユーザーにすべてを無視させるよう学習させてしまう。

## 14. Reduced motion とアクセシビリティ

Reduced motion は「フィードバックをなくす」ことを意味しない——より穏やかで、非前庭系（non-vestibular）な等価物を意味する。以下の 3 つの独立したシグナルに応答し、コンポーネントに組み込む。

- **`prefers-reduced-motion: reduce`** — slide／spring／parallax を、短い opacity の**クロスフェードまたは静的なトランジション**に置き換える。elastic／overshoot は取り除く。理解を助ける opacity／色の変化は残す。
- **`prefers-reduced-transparency: reduce`** — 半透明サーフェスをより不透明・フロスト状にする（背景の opacity を上げ、blur を下げる）。
- **`prefers-contrast: more`** — ほぼ不透明な背景に、明確でコントラストの効いたボーダーを付ける。

その他: 全画面の動く背景、遅いループのオシレーション（0.2Hz 前後、5 秒に 1 サイクル程度）、急激な輝度変化（ダーク⇔ライトのテーマ切り替え）を避ける。大きく動くオブジェクトは移動中は半透明にし、大きなサーフェスは大きく位置を変える間はフェードアウトさせ、収まったらフェードインさせる。

```css
@media (prefers-reduced-motion: reduce) {
  .sheet { transition: opacity 200ms ease; transform: none !important; }
}
@media (prefers-reduced-transparency: reduce) {
  .toolbar { background: white; backdrop-filter: none; }
}
```

## 15. Typography — optical sizing・tracking・leading

Apple は文字の形がサイズによって変化するようデザインしている。Web でも同じ規律を適用する（*The Details of UI Typography*、WWDC 2020 より）。

- **Tracking（letter-spacing）はサイズ依存であり、すべてのサイズに単一の値を使ってはならない。** 大きな display text は*負の* tracking を求める（サイズが大きくなると文字間が開きすぎて読める）。小さいテキストはわずかに*正の* tracking を求める（可読性のため）。固定の `letter-spacing` はどこかで間違っている。見出しは詰め、本文は `0` 付近にする。
- **Leading（line-height）はサイズと逆相関する。** 大きな見出しではタイトに、本文コピーではゆったりと。上下に長いアセンダー／ディセンダーを持つ文字体系では広げ、密度の高い情報中心の UI では詰める。
- **階層は weight + size + leading をひとまとまりとして作る。** サイズだけに頼らない。強調には weight を使う——スペースを増やさずに存在感を加えられる。
- **ユーザーの文字サイズ設定（Dynamic Type）を尊重する。** レイアウトをテキストと一緒にスケールさせる——spacing は固定 px ではなく `rem`／`em` で——大きなフォントでレイアウトが崩れないようにする。
- **カスタムフォントより先に、プラットフォームのシステムフォントをデフォルトにする。** システムフォントにはすでに optical sizing・tracking のテーブル・可読性の調整が組み込まれている。上書きするなら理由があるときだけにする。

```css
:root { font: 100%/1.5 system-ui, sans-serif; } /* body: system font, comfortable leading */

.display {
  font-size: clamp(2rem, 5vw, 4rem);
  line-height: 1.05;        /* tight leading for large text */
  letter-spacing: -0.02em;  /* negative tracking as it grows */
  font-optical-sizing: auto;
}
```

## 16. デザインの基盤 — 8 つの原則

上記のモーションとクラフトは、Apple の 8 つのデザイン原則（*Principles of Great Design*、WWDC 2026）に資するものである。ここでは、思考の際に用いる名前としてこれらを使う。

1. **Purpose（目的）。** 意図をもって作る。何を作ら「ない」かを決める。すべての機能はユーザーの時間・注意・信頼を求めるものであり、その予算は見合う場所にだけ使う。
2. **Agency（主体性）。** 人々を主導権のある状態に保つ——選択肢を提示し、単一の経路を強制しない。ミスへの寛容さ（forgiveness）で裏打ちする——ちょっとした失敗には簡単な undo を、本当に破壊的で不可逆な操作にのみ確認ダイアログを（多用は禁物——多用すると人々はクリックし続けることを学習してしまう）。
3. **Responsibility（責任）。** ユーザーの利益になるように振る舞う。プライバシー: 適切なタイミングで、必要なものだけを、透明性を持って尋ねる。安全性: 誤用や害を先回りして想定する——特に AI において（アレルギーに配慮したレシピアプリが有害な材料を提案してはならない）。プレビュー・確認・disclaimer を加え、リスクが価値を上回る機能は削る。
4. **Familiarity（親しみやすさ）。** 人々がすでに知っていることの上に築く。文字通りすぎず抽象的すぎないメタファーを使い（ゴミ箱は削除を意味する）、その物理法則を尊重する。一貫性を保つ——同じに見えるものは同じように振る舞い、同じ場所にある（macOS では close は常に左上）ことで、人々は次に何が起きるか予測できる。使い慣れたパターンを破るのは、それがより優れていると証明できる場合のみにし、そのうえでテストする（仮定しない）。
5. **Flexibility（柔軟性）。** さまざまな文脈・デバイス・能力の幅に合わせて設計する。プラットフォーム（iPhone は素早いタッチ操作、デスクトップは精密なポインター制御を伴う深いワークフロー）と状況の両方に適応する。年齢・言語・熟練度・アクセシビリティを考慮してインクルーシブに設計する。単一のレイアウトが全員に合わない場合は、コントロールの並べ替えや不要な要素の非表示など、パーソナライズを許容する。
6. **Simplicity（単純さ）——ミニマリズムではない。** 核となる目的が輝くよう不要なものを削ぎ落とす。すべてを一箇所に埋め込むのはミニマルに見えるが単純ではない。簡潔であること（平易な言葉、専門用語なし、少ないステップ）とクリアであること（順序・間隔・コントラストという階層を使い、最も重要なものを最も明白にする）の両方を満たす。すべての要素はその存在理由を持つ。時には文脈を「追加する」ことが単純化になる（残り時間を示すビデオスクラバー等）。よく使う経路を先に示し、高度なオプションは一段深いところに置く。
7. **Craft（クラフト）。** 妥協のないディテールへのこだわりが信頼を築く。美しいタイポグラフィ、ライト/ダークに適応する色、明確なアイコン、即座かつ自然なフィードバックを返すレスポンシブなアニメーション。何ひとつ偶然ではなく、すべての spacing・timing・alignment の値は、説明できる意図的な選択である。ぎこちないスクロール、ずれたアイコン、回転で崩れるレイアウトは、雑さとして読まれる。クラフトには反復と持続性が必要であり、機能やハードウェアの変化に合わせてデザインを進化させ続ける。
8. **Delight（喜び）。** 他の 7 つを正しく実現した結果であり、上に取って付けた紙吹雪ではない。人々に感じてほしい感情（穏やかさ・自信・興奮）を決め、あらゆる判断でそれを強化する。

これらに資する実践的なルール:

- **フィードバックには 4 種類ある:** status（状況）、completion（完了）、warning（警告）、error（エラー）。意味のある操作は確認し、進行中の状況を提示し、問題が起きる前に警告し、送信時ではなくインラインで検証する。
- **Wayfinding（道標）。** すべての画面は次に答えるべきである——自分はどこにいるか？ どこへ行けるか？ そこには何があるか？ どうやって出るか？ ユーザーを決して閉じ込めない。
- **Grouping & mapping（グルーピングとマッピング）。** 近接は関係性を暗示する。コントロールはそれが影響するものの近くに配置し、コントロールの配置はそれが変えるものを反映させる。コントロールを説明するためにラベルが必要なら、マッピングが弱い証拠である。
- **直接的で具体的なラベルは、無難で一般的なラベルに勝る。** ナビ項目は中身を表す名前にする（「Home」のような曖昧な総称ではなく「Progress」「Library」）。具体性が予測可能性を生む。

## 17. プロセス

- **インタラクティブにプロトタイピングする——動作するデモは「100万枚の静的デザイン」に匹敵する価値がある。** インターフェースは、実際に作って触ってみることで発見するものである。動くプロトタイプは、最終実装が中途半端な水準に落ち着くことを防ぐ具体的な基準にもなる。
- **インタラクションとビジュアルを一緒にデザインする。** 「どこまでがインタラクションで、どこからがビジュアルかが分からない」状態を目指す。モーションは、ピクセルの後に追加するレイヤーではない。
- **実際の人々を実際の文脈でテストする**。モーションのレビューも新鮮な目で行う——スローモーション／コマ送りで再生し、通常速度では見えないものを捉える。

## クイックリファレンス

| 必要なこと | 手法 | 具体的な値 |
| --- | --- | --- |
| デフォルトの UI spring | Critically damped、overshoot なし | `damping 1.0`、`response 0.3–0.4` |
| Momentum／flick 用の spring | Under-damped、わずかな bounce | `damping ~0.8`、`response 0.3–0.4` |
| ジェスチャー → spring の velocity | release 時の velocity を引き継ぐ | 正規化する場合は `gestureVelocity / (target − current)` |
| Flick の着地点 | Momentum を投影する | `current + (v/1000)·d/(1−d)`、`d ≈ 0.998` |
| 中断をクリーンに処理する | Presentation（表示中）の現在値から開始する | 画面上の transform を読み取る |
| 反転時の「レンガの壁」を避ける | Re-target を通じて velocity を引き継ぐ | velocity をブレンドする spring |
| 可逆的なトランジション | Easing カーブを鏡合わせにする | 逆の cubic-bézier |
| 反転かコミットかを判定する | 位置ではなく velocity の**符号**を使う | release 時に判定 |
| 1:1 のドラッグ | Pointer Events + capture | 掴んだオフセットを尊重する |
| フィードバック | pointer-down で、かつ継続的に | 完了時だけにしない |
| 境界 | ハードストップではなく rubber-band | 段階的な抵抗 |
| 半透明の chrome | `backdrop-filter` レイヤー | コンテンツはその下をスクロール |
| タイポグラフィの tracking | サイズ依存にし、固定値にしない | 大きなテキストは詰める（`-0.02em`）、本文は `0` 付近 |
| Reduced motion | slide／spring ではなくクロスフェード | `@media (prefers-reduced-motion)` |

## 出典

本スキルは Emil Kowalski 氏の skills リポジトリ（https://github.com/emilkowalski/skills, MIT License）を日本語化・翻案したものです。
