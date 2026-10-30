# /ui-ux-pro-max — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/ui-ux-pro-max/LICENSE.txt` | 1.1 KB | ライセンス |
| `skills/ui-ux-pro-max/SKILL.md` | 47.5 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/ui-ux-pro-max/data/app-interface.csv` | 9.5 KB | — |
| `skills/ui-ux-pro-max/data/charts.csv` | 18.9 KB | — |
| `skills/ui-ux-pro-max/data/colors.csv` | 37.9 KB | — |
| `skills/ui-ux-pro-max/data/google-fonts.csv` | 727.7 KB | — |
| `skills/ui-ux-pro-max/data/icons.csv` | 20.3 KB | — |
| `skills/ui-ux-pro-max/data/landing.csv` | 16.3 KB | — |
| `skills/ui-ux-pro-max/data/motion.csv` | 10.3 KB | — |
| `skills/ui-ux-pro-max/data/products.csv` | 72.0 KB | — |
| `skills/ui-ux-pro-max/data/react-performance.csv` | 14.5 KB | — |
| `skills/ui-ux-pro-max/data/stacks/angular.csv` | 17.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/astro.csv` | 11.6 KB | — |
| `skills/ui-ux-pro-max/data/stacks/avalonia.csv` | 25.1 KB | — |
| `skills/ui-ux-pro-max/data/stacks/flutter.csv` | 10.2 KB | — |
| `skills/ui-ux-pro-max/data/stacks/html-tailwind.csv` | 11.1 KB | — |
| `skills/ui-ux-pro-max/data/stacks/javafx.csv` | 30.2 KB | — |
| `skills/ui-ux-pro-max/data/stacks/jetpack-compose.csv` | 8.1 KB | — |
| `skills/ui-ux-pro-max/data/stacks/laravel.csv` | 18.1 KB | — |
| `skills/ui-ux-pro-max/data/stacks/nextjs.csv` | 12.3 KB | — |
| `skills/ui-ux-pro-max/data/stacks/nuxt-ui.csv` | 20.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/nuxtjs.csv` | 16.2 KB | — |
| `skills/ui-ux-pro-max/data/stacks/react-native.csv` | 9.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/react.csv` | 12.7 KB | — |
| `skills/ui-ux-pro-max/data/stacks/shadcn.csv` | 15.6 KB | — |
| `skills/ui-ux-pro-max/data/stacks/svelte.csv` | 10.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/swiftui.csv` | 10.6 KB | — |
| `skills/ui-ux-pro-max/data/stacks/threejs.csv` | 43.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/uno.csv` | 26.9 KB | — |
| `skills/ui-ux-pro-max/data/stacks/uwp.csv` | 22.4 KB | — |
| `skills/ui-ux-pro-max/data/stacks/vue.csv` | 10.8 KB | — |
| `skills/ui-ux-pro-max/data/stacks/winui.csv` | 24.6 KB | — |
| `skills/ui-ux-pro-max/data/stacks/wpf.csv` | 22.1 KB | — |
| `skills/ui-ux-pro-max/data/styles.csv` | 139.3 KB | — |
| `skills/ui-ux-pro-max/data/typography.csv` | 48.7 KB | — |
| `skills/ui-ux-pro-max/data/ui-reasoning.csv` | 51.8 KB | — |
| `skills/ui-ux-pro-max/data/ux-guidelines.csv` | 18.3 KB | — |
| `skills/ui-ux-pro-max/scripts/core.py` | 13.2 KB | Python スクリプト |
| `skills/ui-ux-pro-max/scripts/design_system.py` | 57.4 KB | Python スクリプト |
| `skills/ui-ux-pro-max/scripts/search.py` | 6.7 KB | Python スクリプト |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/ui-ux-pro-max .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/ui-ux-pro-max/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/ui-ux-pro-max` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/ui-ux-pro-max`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/ui-ux-pro-max` を名指しする。

## 4. 内容の構成

本体（`skills/ui-ux-pro-max/SKILL.md`）の見出し構成:

- When to Apply
  - Must Use
  - Recommended
  - Skip
- Rule Categories by Priority
- Quick Reference
  - 1. Accessibility (CRITICAL)
  - 2. Touch & Interaction (CRITICAL)
  - 3. Performance (HIGH)
  - 4. Style Selection (HIGH)
  - 5. Layout & Responsive (HIGH)
  - 6. Typography & Color (MEDIUM)
  - 7. Animation (MEDIUM)
  - 8. Forms & Feedback (MEDIUM)

## 5. 導入後の検証

```sh
python -m py_compile skills/ui-ux-pro-max/scripts/core.py skills/ui-ux-pro-max/scripts/design_system.py skills/ui-ux-pro-max/scripts/search.py
echo "exit=$?"
```
- `/ui-ux-pro-max` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/ui-ux-pro-max/` |
| 元の格納先 | `.claude/skills/ui-ux-pro-max/` |
| 出典 | 同上 |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

Python 標準ライブラリのみで動作

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
