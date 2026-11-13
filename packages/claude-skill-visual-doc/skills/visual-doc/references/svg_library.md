# インライン SVG 実装リファレンス（visual-doc 補助ファイル・常時ロードしない）

`/visual-doc` の Step 3 で、必要な記法が出てきた時点で Read する。図の型の選択は [`diagram_patterns.md`](diagram_patterns.md)。

> 出典: mhattingpete/claude-skills-marketplace の `visual-documentation-plugin`（Apache-2.0）の `svg_library.md`。4 スキルに重複していた同一ファイルを 1 本に統合し、要点を圧縮して日本語化した。コード例は原文の記法を維持し、コメントのみ和訳している。

---

## 1. 座標計算の手順（先にこれをやる）

SVG の破綻はほぼ座標の場当たり計算が原因。**書く前に決める。**

1. `viewBox` を決める（下表）。ピクセルではなく「論理座標」として扱う
2. 余白（padding）を 40〜50 取る。図要素はその内側に置く
3. 要素の**幅・高さ・間隔を定数化**して、位置は `開始 + (幅 + 間隔) * index` で算出する
4. テキストは要素の中心（`x = 矩形x + 幅/2`、`y = 矩形y + 高さ/2`）に置き、`text-anchor="middle" dominant-baseline="middle"` を付ける

| 図の種類 | 推奨 viewBox |
|---|---|
| 横フロー・データフロー | `0 0 800 400` |
| 縦フロー（5〜8 ノード） | `0 0 600 700` |
| チャート（単体） | `0 0 400 300` |
| ガント・タイムライン | `0 0 1000 <行数×40+80>` |

<!-- profile:standard-only SVG 座標系・viewBox の一般知識 -->
`viewBox="minX minY width height"` は「この矩形の内容を、要素の表示領域に合わせて拡縮する」指定。`width`/`height` 属性を書かず CSS で `max-width: 100%` を当てれば、レスポンシブに縮小される（`base_template.html` の既定 SVG スタイルがこれを行う）。座標原点は左上、y は下方向に増える。
<!-- /profile:standard-only -->

```html
<svg viewBox="0 0 800 400" role="img">
  <title>データフロー: 受注データの取り込みから帳票出力まで</title>
  <defs><!-- marker・gradient・symbol はここに --></defs>
  <!-- 図要素 -->
</svg>
```

## 2. 基本図形

```html
<!-- 矩形（処理ノード）。rx で角丸 -->
<rect x="50" y="150" width="120" height="80" rx="4" class="node-info"/>

<!-- 角丸矩形（開始・終了）。rx = 高さ/2 で完全な丸端 -->
<rect x="350" y="50" width="120" height="50" rx="25" class="node-ok"/>

<!-- 円・楕円 -->
<circle cx="400" cy="200" r="40" fill="var(--c-warn-fill)"/>
<ellipse cx="400" cy="200" rx="60" ry="35" fill="var(--c-proc-fill)"/>
```

## 3. パス図形（フローチャート用）

中心 `(cx, cy)`、半幅 `w`、半高 `h` で定義すると再利用しやすい。

```html
<!-- 菱形（判断）: 上→右→下→左 -->
<path d="M400,250 L460,290 L400,330 L340,290 Z" class="node-warn"/>

<!-- 六角形（準備・ループ端） -->
<path d="M360,150 L440,150 L465,190 L440,230 L360,230 L335,190 Z" fill="var(--c-proc-fill)"/>

<!-- 平行四辺形（入出力・データ） -->
<path d="M360,150 L480,150 L450,210 L330,210 Z" fill="var(--c-muted)"/>

<!-- 円柱（データストア）: 上面の楕円 + 側面 -->
<path d="M340,160 a60,12 0 0 1 120,0 v70 a60,12 0 0 1 -120,0 Z" fill="var(--c-info-fill)"/>
<ellipse cx="400" cy="160" rx="60" ry="12" fill="var(--c-info-fill)"/>
```

## 4. 線と矢印

矢印は `<defs>` に `marker` を 1 つ定義して使い回す。**`marker` の色は `fill` で決まり、線の `stroke` を継承しない**（色を変えるなら marker を色別に複数定義する）。

```html
<defs>
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--c-muted)"/>
  </marker>
</defs>

<!-- 直線 -->
<line x1="170" y1="190" x2="340" y2="190" stroke="var(--c-muted)" stroke-width="2" marker-end="url(#arrow)"/>

<!-- 直角に曲げる（H=水平, V=垂直の絶対移動） -->
<path d="M400,330 V370 H620 V190" fill="none" stroke="var(--c-muted)" stroke-width="2" marker-end="url(#arrow)"/>

<!-- 曲線（Q=2次ベジエ。制御点1つで滑らかに繋ぐ） -->
<path d="M170,190 Q255,120 340,190" fill="none" stroke="var(--c-muted)" stroke-width="2" marker-end="url(#arrow)"/>

<!-- 点線（外部システム・非同期の表現） -->
<line x1="170" y1="260" x2="340" y2="260" stroke="var(--c-muted)" stroke-width="2"
      stroke-dasharray="6 4" marker-end="url(#arrow)"/>
```

- **`fill="none"` を忘れると `path` の内側が黒く塗られる**（最頻出のミス）
- 矢印の終点は接続先の矩形に**触れる直前**で止める（`refX` の分だけ重なるため、ノード境界から 2〜3 手前）
- ラベルは線の中点に置き、線と重なる場合は文字の背後に背景色の `rect` を敷く

## 5. テキスト

```html
<!-- 中央揃え（矩形の中心に置く定石） -->
<text x="400" y="190" text-anchor="middle" dominant-baseline="middle"
      font-size="14" class="on-fill">受注データ取込</text>

<!-- 複数行は tspan で行送り（dy は行間） -->
<text x="400" y="180" text-anchor="middle" font-size="13" fill="var(--text)">
  <tspan x="400" dy="0">受注データ</tspan>
  <tspan x="400" dy="18">取込バッチ</tspan>
</text>
```

- `text-anchor`: `start`（左寄せ・既定）/ `middle`（中央）/ `end`（右寄せ）
- **日本語は 1 文字 ≒ font-size と同幅**で見積もる（英字の約 2 倍）。`font-size="14"` の 8 文字は約 112px 必要。矩形幅 120 に 8 文字は入るが 10 文字は溢れる → 溢れるなら `tspan` で改行するか矩形を広げる
- SVG 内テキストは折り返さない。長文は SVG の外（HTML 側）に書く
- 塗り面上の文字は `class="on-fill"`、白背景上は本文色。**淡色面（`#e6f2ff` 等）に白文字を置かない**

## 6. グループ・再利用・変形

```html
<!-- 座標をまとめて移動: 中身は相対位置で書ける -->
<g transform="translate(50,150)">
  <rect width="120" height="80" fill="var(--c-info-fill)"/>
  <text x="60" y="40" text-anchor="middle" fill="#fff">ノード</text>
</g>

<!-- 同じ図形を再利用 -->
<defs>
  <symbol id="node" viewBox="0 0 120 80">
    <rect width="120" height="80" rx="4" fill="var(--c-info-fill)"/>
  </symbol>
</defs>
<use href="#node" x="50" y="150" width="120" height="80"/>
<use href="#node" x="290" y="150" width="120" height="80"/>
```

`transform` は `translate(x,y)`・`rotate(deg, cx, cy)`・`scale(k)` を**この順で連結**（`transform="translate(...) rotate(...)"`）。回転の中心を省略すると原点基準で回るため、必ず中心を指定する。

## 7. チャート部品

### 棒グラフ

y 軸は上下反転する。**バーの `y` は「グラフ下端 − バー高さ」**。

```html
<!-- グラフ領域: x=50..380, y=20..260（下端 260）。最大値 max に対する高さ = 値/max*240 -->
<rect x="60" y="110" width="40" height="150" fill="var(--c-info-fill)"/>   <!-- 値の高さ150 -->
<line x1="50" y1="260" x2="380" y2="260" stroke="var(--border)"/>      <!-- x 軸 -->
<line x1="50" y1="20"  x2="50"  y2="260" stroke="var(--border)"/>      <!-- y 軸 -->
<text x="80" y="278" text-anchor="middle" font-size="12">4月</text>
<text x="80" y="102" text-anchor="middle" font-size="12">150</text> <!-- 値を直接ラベル -->
```

横棒は x と y の役割を入れ替える（バーの `x` は固定、`width` が値）。

### 折れ線

```html
<polyline points="60,200 130,170 200,180 270,120 340,90"
          fill="none" stroke="var(--c-info-fill)" stroke-width="2.5"/>
<circle cx="60" cy="200" r="4" fill="var(--c-info-fill)"/><!-- データ点は必ずマーカーで示す -->
```

値 → 座標の変換: `x = 左端 + (index / (件数-1)) * 幅`、`y = 下端 - (値 - 最小) / (最大 - 最小) * 高さ`

### ドーナツ・進捗リング

`stroke-dasharray` に「見せる長さ」と「隠す長さ」を渡す。円周 = `2πr`。

```html
<!-- r=70 → 円周 ≒ 440。65% なら 286 / 154 -->
<circle cx="150" cy="150" r="70" fill="none" stroke="var(--border)" stroke-width="24"/>
<circle cx="150" cy="150" r="70" fill="none" stroke="var(--c-info-fill)" stroke-width="24"
        stroke-dasharray="286 154" transform="rotate(-90 150 150)"/>
<text x="150" y="150" text-anchor="middle" dominant-baseline="middle" font-size="28">65%</text>
```

`rotate(-90 cx cy)` で 12 時方向を起点にする。複数区分の円は、前の区分の合計分だけ `stroke-dashoffset` を負方向にずらして重ねる。

### 進捗バー・ゲージ

```html
<rect x="0" y="0" width="300" height="16" rx="8" fill="var(--border)"/>
<rect x="0" y="0" width="195" height="16" rx="8" fill="var(--c-ok-fill)"/> <!-- 65% -->
```

半円ゲージは `path` の円弧（`A rx ry 0 0 1 x y`）で描き、角度 → 座標を `cx + r*cos(θ)`, `cy + r*sin(θ)`（θ はラジアン）で求める。

## 8. アイコン（テキスト記号で足りるなら使わない）

```html
<!-- チェック -->
<path d="M4,10 L8,14 L16,5" fill="none" stroke="var(--c-ok-fill)" stroke-width="2.5" stroke-linecap="round"/>
<!-- ×  -->
<path d="M5,5 L15,15 M15,5 L5,15" stroke="var(--c-err-fill)" stroke-width="2.5" stroke-linecap="round"/>
<!-- 警告（三角＋感嘆符） -->
<path d="M10,3 L18,17 L2,17 Z" fill="var(--c-warn-fill)"/>
<path d="M10,8 V12 M10,14 v0.5" stroke="#fff" stroke-width="2" stroke-linecap="round"/>
```

## 9. よくある破綻と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| 図が見えない | `viewBox` の範囲外に要素がある | 座標が `viewBox` の幅・高さ内か確認 |
| パスの内側が黒い | `fill` 既定値が黒 | `fill="none"` を付ける |
| 矢印が出ない | `marker` の `id` 不一致・`<defs>` 未定義 | `url(#id)` と定義を照合 |
| 矢印の色が変わらない | `marker` は `stroke` を継承しない | 色ごとに `marker` を定義 |
| 文字が矩形から溢れる | 日本語の文字幅を英字で見積もった | 1 文字 ≒ font-size で再計算 |
| ダークテーマで線が見えない | 色をハードコードした | `stroke="currentColor"` か CSS 変数を使う |

**ダーク対応の要点**: SVG 内の色をハードコードせず、`fill="var(--c-info)"`・`stroke="currentColor"` を使う。`base_template.html` は SVG 用に `--c-*` 変数と `stroke-linejoin: round` の既定を定義済み。

## 10. 仕上げ

- 要素数が 15 を超えたら図を分割する（1 枚に詰め込まない）
- 座標は整数に丸める（小数は差分が読みにくくなる）
- 同じ図形が 3 回以上出るなら `symbol` + `use` にする
- 生成後、`viewBox` の幅を 375 に縮めた想定で「文字が読めるか」を確認する（モバイル幅）
