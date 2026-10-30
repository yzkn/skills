#!/usr/bin/env node

// rasterize.mjs — 本リポジトリでの追加スクリプト（原典にはない）。
//
// flatten.mjs で自己完結にした SVG を PNG に変換する。
//
// なぜ必要か: pandoc は SVG を docx / pptx に埋め込む際、ラスタのフォールバック
// 画像を作るために rsvg-convert を必要とする。未導入の環境では
// 「Could not convert image」と警告しつつ **exit 0 で完了し**、ラスタを持たない
// 壊れた図が docx に入る。Word は画像を表示できないことがある。
// PNG を渡せばこの経路を丸ごと回避できる。
//
// 変換にはインストール済みの Chrome / Edge のヘッドレスモードを使う。
// 追加の npm パッケージを導入せず、システムの日本語フォントで正しく描画できる
// （PyMuPDF 等の簡易レンダラーは長音符「ー」などを落とすことがある）。
// 外部通信は --host-resolver-rules で遮断した状態で実行する。

import { execFileSync } from 'child_process';
import { readFileSync, existsSync, statSync } from 'fs';
import { resolve as resolvePath } from 'path';

const BROWSER_CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
];

function parseArgs() {
  const argv = process.argv.slice(2);
  const opts = { input: null, output: null, scale: 2, browser: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--input' || a === '-i') opts.input = argv[++i];
    else if (a === '--output' || a === '-o') opts.output = argv[++i];
    else if (a === '--scale') opts.scale = Number(argv[++i]);
    else if (a === '--browser') opts.browser = argv[++i];
    else if (a === '--help' || a === '-h') opts.help = true;
  }
  return opts;
}

function findBrowser(explicit) {
  if (explicit) {
    if (!existsSync(explicit)) {
      console.error(`指定されたブラウザが見つかりません: ${explicit}`);
      process.exit(1);
    }
    return explicit;
  }
  const found = BROWSER_CANDIDATES.find(p => existsSync(p));
  if (!found) {
    console.error('Chrome / Edge が見つかりませんでした。--browser <実行ファイルのパス> で指定してください。');
    console.error('候補として探した場所:');
    BROWSER_CANDIDATES.forEach(p => console.error(`  ${p}`));
    process.exit(1);
  }
  return found;
}

/** SVG のルート要素から CSS ピクセル単位の幅・高さを読む */
function readSize(svgPath) {
  const svg = readFileSync(svgPath, 'utf8');
  const root = /<svg[^>]*>/.exec(svg);
  if (!root) {
    console.error('SVG のルート要素が見つかりません。');
    process.exit(1);
  }
  const attr = name => {
    const m = new RegExp(`\\s${name}="([\\d.]+)"`).exec(root[0]);
    return m ? parseFloat(m[1]) : null;
  };
  let w = attr('width');
  let h = attr('height');
  if (!w || !h) {
    const vb = /viewBox="([\d.\s-]+)"/.exec(root[0]);
    if (vb) {
      const p = vb[1].trim().split(/\s+/).map(Number);
      w = w || p[2];
      h = h || p[3];
    }
  }
  if (!w || !h) {
    console.error('SVG から width / height を判定できません。');
    process.exit(1);
  }
  // 外部参照が残っていれば、ここでヘッドレスブラウザが取りに行こうとする。
  // xmlns / xmlns:xlink の名前空間 URI は参照ではないので除外する。
  const externalRef = /@import|\burl\(\s*['"]?https?:|(?:xlink:)?href\s*=\s*"https?:/i;
  if (externalRef.test(svg)) {
    console.error('警告: SVG に外部参照が残っています。先に flatten.mjs を通してください。');
  }
  return { w: Math.ceil(w), h: Math.ceil(h) };
}

function main() {
  const opts = parseArgs();
  if (opts.help || !opts.input) {
    console.log(`使い方: node rasterize.mjs --input <入力>.svg --output <出力>.png [オプション]

  --scale <倍率>    解像度の倍率（既定 2。印刷用は 3 以上を推奨）
  --browser <パス>  Chrome / Edge の実行ファイルを明示指定する

flatten.mjs を通した自己完結 SVG を入力にすること。`);
    process.exit(opts.help ? 0 : 1);
  }

  const input = resolvePath(opts.input);
  if (!existsSync(input)) {
    console.error(`入力ファイルが見つかりません: ${input}`);
    process.exit(1);
  }
  const output = resolvePath(opts.output || opts.input.replace(/\.svg$/i, '.png'));
  const browser = findBrowser(opts.browser);
  const { w, h } = readSize(input);

  execFileSync(
    browser,
    [
      '--headless',
      '--disable-gpu',
      '--no-sandbox',
      // 外部通信を遮断した状態で描画する（外部参照が残っていても取りに行かせない）
      '--host-resolver-rules=MAP * ~NOTFOUND',
      '--hide-scrollbars',
      '--default-background-color=FFFFFFFF',
      `--window-size=${w},${h}`,
      `--force-device-scale-factor=${opts.scale}`,
      `--screenshot=${output}`,
      `file:///${input.replace(/\\/g, '/')}`,
    ],
    { stdio: ['ignore', 'ignore', 'pipe'], timeout: 120000 }
  );

  if (!existsSync(output)) {
    console.error('PNG が生成されませんでした。--browser でパスを明示するか、ブラウザのバージョンを確認してください。');
    process.exit(1);
  }
  const bytes = statSync(output).size;
  console.log(`PNG を書き出しました: ${output}`);
  console.log(`  使用ブラウザ: ${browser}`);
  console.log(`  寸法: ${w} x ${h} CSS px × 倍率 ${opts.scale} = ${w * opts.scale} x ${h * opts.scale} px（${bytes} バイト）`);
}

main();
