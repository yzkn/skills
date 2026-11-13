#!/usr/bin/env node

import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const skillRoot = join(__dirname, '..');

// 本リポジトリでの改変: 原典はここで npm install を自動実行していたが、
// .claude/rules/external-resources.md【要指示】「ツールのインストールは
// 無断で実行しない」に反するため削除した。未導入なら手順を示して終了する。
async function loadBeautifulMermaid() {
  try {
    return await import('beautiful-mermaid');
  } catch {}

  try {
    const pkgPath = join(skillRoot, 'node_modules', 'beautiful-mermaid', 'dist', 'index.js');
    return await import(pkgPath);
  } catch {}

  console.error('[beautiful-mermaid] 依存パッケージが未導入です。自動インストールは行いません。');
  console.error(`次のコマンドをユーザー自身が実行してください: cd "${skillRoot}" && npm install`);
  process.exit(1);
}

async function main() {
  const { THEMES } = await loadBeautifulMermaid();
  const themes = Object.keys(THEMES);

  console.log('Available Beautiful-Mermaid Themes:\n');
  themes.forEach((theme, i) => {
    console.log(`${String(i + 1).padStart(2)}. ${theme}`);
  });

  console.log(`\nTotal: ${themes.length} themes`);
  console.log('\nUsage:');
  console.log('  node scripts/render.mjs --input diagram.mmd --theme <theme-name> --output output.svg');
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
