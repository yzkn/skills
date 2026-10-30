# /tool-environment — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・Node.js + npm・pandoc・gitleaks |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/tool-environment/SKILL.md` | 12.9 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/tool-environment/references/cache_schema.md` | 8.0 KB | — |
| `skills/tool-environment/references/official_install.md` | 2.2 KB | — |
| `skills/tool-environment/references/official_install_unix.md` | 2.1 KB | — |
| `skills/tool-environment/references/package_manager_ids.md` | 3.2 KB | — |
| `skills/tool-environment/references/tool_catalog.md` | 21.1 KB | — |
| `skills/tool-environment/references/typical_install_paths.md` | 3.7 KB | — |
| `skills/tool-environment/references/winget_ids.md` | 3.8 KB | — |
| `skills/tool-environment/scripts/detect_unix.sh` | 4.9 KB | シェルスクリプト（BOM 禁止・改行 LF） |
| `skills/tool-environment/scripts/detect_windows.ps1` | 12.8 KB | PowerShell スクリプト（UTF-8 BOM 必須） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/tool-environment .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/tool-environment/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/tool-environment` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/tool-environment`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/tool-environment` を名指しする。

## 4. 内容の構成

本体（`skills/tool-environment/SKILL.md`）の見出し構成:

- 全体フロー
- ステップ1: キャッシュ確認
  - キャッシュを無効化(再検出)すべき条件
- ステップ2: 環境検出(キャッシュが無い場合のみ)
  - Windows で WSL が有効な場合は WSL 上のコマンドも候補にする
- ステップ3: 文字コードの扱い
- ステップ4: ツール未検出時のインストール優先順位
  - ① 公式が推奨する手順(最優先)
  - ② パッケージマネージャ
  - ③ 手動対応(フォールバック)
- ステップ5: インストール後のパス解決とキャッシュ更新
- 参照ファイル一覧

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**
- `/tool-environment` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- **Windows / PowerShell 専用**（PowerShell 5.1 と 7.x で動くよう書かれている）
- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/tool-environment/` |
| 元の格納先 | `.claude/skills/tool-environment/` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

**毎セッションの再調査を省くため**（2026-07-27）。参照序列（`~/.claude/CLAUDE.md` の記録 → キャッシュ → 検出スクリプト）を定め、インストールは【要指示】とした

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
