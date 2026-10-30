# /systematic-debugging — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | なし（Claude Code のみ） |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/systematic-debugging/LICENSE` | 1.1 KB | ライセンス |
| `skills/systematic-debugging/SKILL.md` | 11.5 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/systematic-debugging/references/condition-based-waiting-example.ts` | 4.9 KB | — |
| `skills/systematic-debugging/references/condition-based-waiting.md` | 3.4 KB | — |
| `skills/systematic-debugging/references/defense-in-depth.md` | 3.6 KB | — |
| `skills/systematic-debugging/references/root-cause-tracing.md` | 5.2 KB | — |
| `skills/systematic-debugging/scripts/find-polluter.sh` | 1.9 KB | シェルスクリプト（BOM 禁止・改行 LF） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/systematic-debugging .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/systematic-debugging/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/systematic-debugging` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/systematic-debugging`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/systematic-debugging` を名指しする。

## 4. 内容の構成

本体（`skills/systematic-debugging/SKILL.md`）の見出し構成:

- 鉄則
- 適用範囲
- 4 つのフェーズ
  - フェーズ 1: 根本原因の調査
  - フェーズ 2: パターン分析
  - フェーズ 3: 仮説と検証
  - フェーズ 4: 実装
  - 3 回失敗したらアーキテクチャを疑う
- 止まるべきサイン
- よくある言い訳と実際
- クイックリファレンス
- 「根本原因が存在しない」と判断する場合
- 補助テクニック（`references/` — 原典無改変・英語）
- 関連（本キットでの使い分け）

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**
- `/systematic-debugging` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/systematic-debugging/` |
| 元の格納先 | `.claude/skills/systematic-debugging/` |
| 出典 | obra/superpowers, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

SKILL.md のみ日本語化し、補助 3 文書と `find-polluter.sh` は原典無改変（英語）で同梱（ADR-026）。同リポジトリの `verification-before-completion` は ADR-009 で既に規約化していたため重複を避けた

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
