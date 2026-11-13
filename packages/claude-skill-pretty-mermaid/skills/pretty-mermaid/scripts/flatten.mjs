#!/usr/bin/env node

// flatten.mjs — 本リポジトリでの追加スクリプト（原典にはない）。
//
// beautiful-mermaid が出力する SVG は次の 2 つに依存しており、そのままでは
// 限定的な SVG レンダラー（Word / PowerPoint の図として取り込む場合、
// PyMuPDF・librsvg・cairosvg 等の変換ツール）で色が失われて黒く潰れる。
//
//   1. CSS カスタムプロパティ（--_node-fill 等）と color-mix(in srgb, ...)
//   2. Google Fonts への @import（外部リクエスト。CSP・オフライン環境で失敗する）
//
// このスクリプトは両者を解決し、色を実値（#RRGGBB）に、フォントを属性に
// 展開した「自己完結 SVG」を書き出す。design/ の正本から dist/ の納品物へ
// 図を焼き込む経路では必ずこれを通す。

import { readFileSync, writeFileSync } from 'fs';

// 日本語を含む図の既定フォントスタック。Google Fonts に依存せず、
// Windows / macOS / Linux のいずれでも和文グリフを持つフォントに解決される。
const DEFAULT_FONT =
  "'Yu Gothic UI','Yu Gothic','Hiragino Kaku Gothic ProN','Noto Sans JP','Meiryo',system-ui,sans-serif";

function parseArgs() {
  const argv = process.argv.slice(2);
  const opts = { input: null, output: null, font: DEFAULT_FONT, background: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--input' || a === '-i') opts.input = argv[++i];
    else if (a === '--output' || a === '-o') opts.output = argv[++i];
    else if (a === '--font') opts.font = argv[++i];
    else if (a === '--no-background') opts.background = false;
    else if (a === '--help' || a === '-h') opts.help = true;
  }
  return opts;
}

function usage() {
  console.log(`使い方: node flatten.mjs --input <入力>.svg --output <出力>.svg [オプション]

  --font "<フォントスタック>"  text 要素に付与するフォント（既定は和文対応スタック）
  --no-background             背景の矩形を挿入しない（透過のまま残す）

CSS 変数と color-mix() を実値に展開し、Google Fonts への @import を除去する。`);
}

/** "#rgb" / "#rrggbb" → [r,g,b] */
function parseHex(c) {
  const s = c.trim().replace(/^#/, '');
  if (s.length === 3) return [...s].map(ch => parseInt(ch + ch, 16));
  if (s.length === 6) return [0, 2, 4].map(i => parseInt(s.slice(i, i + 2), 16));
  return null;
}

const toHex = rgb =>
  '#' + rgb.map(v => Math.round(Math.min(255, Math.max(0, v))).toString(16).padStart(2, '0')).join('');

/** color-mix(in srgb, <色> N%, <色>) を線形補間で畳み込む */
function mix(colorA, pct, colorB) {
  const a = parseHex(colorA);
  const b = parseHex(colorB);
  if (!a || !b) return null;
  const w = pct / 100;
  return toHex([0, 1, 2].map(i => a[i] * w + b[i] * (1 - w)));
}

/**
 * var(--name, fallback) と color-mix() を含む式を、実際の色に解決する。
 * 未定義の変数はフォールバックへ、フォールバックもなければ null を返す。
 */
function resolve(expr, vars, depth = 0) {
  if (expr == null || depth > 12) return null;
  let s = String(expr).trim();
  if (s.startsWith('#')) return s;

  const varMatch = /^var\(\s*(--[\w-]+)\s*(?:,\s*([\s\S]+))?\)$/.exec(s);
  if (varMatch) {
    const [, name, fallback] = varMatch;
    if (Object.prototype.hasOwnProperty.call(vars, name)) {
      const resolved = resolve(vars[name], vars, depth + 1);
      if (resolved) return resolved;
    }
    return fallback ? resolve(fallback, vars, depth + 1) : null;
  }

  const mixMatch = /^color-mix\(\s*in\s+srgb\s*,\s*([\s\S]+?)\s+([\d.]+)%\s*,\s*([\s\S]+?)\s*\)$/.exec(s);
  if (mixMatch) {
    const a = resolve(mixMatch[1], vars, depth + 1);
    const b = resolve(mixMatch[3], vars, depth + 1);
    if (!a || !b) return null;
    return mix(a, parseFloat(mixMatch[2]), b);
  }

  // 名前付き色などはそのまま通す（レンダラー側で解決できる）
  return s === 'none' ? s : s;
}

/** "--a: x; --b: y" 形式の宣言列を辞書にする */
function parseDeclarations(text, into) {
  // 値に含まれる括弧の対応を見ながら宣言を切り出す（color-mix の "," で切らないため）
  const re = /(--[\w-]+)\s*:/g;
  let m;
  while ((m = re.exec(text))) {
    const name = m[1];
    let i = re.lastIndex;
    let depth = 0;
    let value = '';
    for (; i < text.length; i++) {
      const ch = text[i];
      if (ch === '(') depth++;
      else if (ch === ')') depth--;
      else if ((ch === ';' || ch === '}') && depth === 0) break;
      value += ch;
    }
    into[name] = value.replace(/\/\*[\s\S]*?\*\//g, '').trim();
  }
  return into;
}

function main() {
  const opts = parseArgs();
  if (opts.help || !opts.input) {
    usage();
    process.exit(opts.help ? 0 : 1);
  }

  let svg = readFileSync(opts.input, 'utf8');
  const vars = {};

  // 1) ルート <svg> の style 属性（--bg / --fg / --line / --accent / --muted）
  const rootStyle = /<svg[^>]*\sstyle="([^"]*)"/.exec(svg);
  let background = null;
  if (rootStyle) {
    parseDeclarations(rootStyle[1], vars);
    const bg = /background\s*:\s*([^;"]+)/.exec(rootStyle[1]);
    if (bg) background = bg[1].trim();
  }

  // 2) <style> 内の svg { ... } で定義される派生変数（--_node-fill 等）
  const styleBlock = /<style>([\s\S]*?)<\/style>/.exec(svg);
  if (styleBlock) parseDeclarations(styleBlock[1], vars);

  // 3) fill / stroke / stop-color の var(...) を実値へ置換
  let unresolved = 0;
  svg = svg.replace(/(fill|stroke|stop-color)="((?:var|color-mix)\([^"]*\))"/g, (whole, attr, expr) => {
    const value = resolve(expr, vars);
    if (!value || value.includes('var(') || value.includes('color-mix(')) {
      unresolved++;
      return whole;
    }
    return `${attr}="${value}"`;
  });

  // 4) <style> ブロックを除去（@import による外部リクエストをここで断つ）
  const hadImport = styleBlock ? /@import/.test(styleBlock[1]) : false;
  svg = svg.replace(/<style>[\s\S]*?<\/style>/g, '');

  // 5) フォントを text 要素の属性として明示
  svg = svg.replace(/<text\s/g, `<text font-family="${opts.font}" `);

  // 6) ルートの style 属性から CSS 変数を落とす（background だけ残す意味はないため全削除）
  svg = svg.replace(/(<svg[^>]*?)\sstyle="[^"]*"/, '$1');

  // 7) 背景の矩形を最初の子として挿入
  const resolvedBg = background ? resolve(background, vars) : null;
  if (opts.background && resolvedBg && resolvedBg !== 'none') {
    svg = svg.replace(/(<svg[^>]*>)/, `$1<rect x="0" y="0" width="100%" height="100%" fill="${resolvedBg}" />`);
  }

  const out = opts.output || opts.input.replace(/\.svg$/i, '.flat.svg');
  writeFileSync(out, svg);

  console.log(`自己完結 SVG を書き出しました: ${out}`);
  console.log(`  CSS 変数の展開: ${Object.keys(vars).length} 件を解決${unresolved ? `（未解決 ${unresolved} 件・要確認）` : ''}`);
  console.log(`  Google Fonts への @import: ${hadImport ? '除去した' : 'なし'}`);
  console.log(`  背景: ${opts.background && resolvedBg ? resolvedBg : '挿入なし（透過）'}`);
  if (unresolved) process.exitCode = 1;
}

main();
