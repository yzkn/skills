# /ux-writing — マニュアル

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
| `skills/ux-writing/LICENSE` | 1.0 KB | ライセンス |
| `skills/ux-writing/SKILL.md` | 3.3 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/ux-writing/i18n-rtl.md` | 3.3 KB | — |
| `skills/ux-writing/voice-tone.md` | 6.3 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/ux-writing .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/ux-writing/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/ux-writing` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/ux-writing`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/ux-writing` を名指しする。

## 4. 内容の構成

本体（`skills/ux-writing/SKILL.md`）の見出し構成:

- 手順
- 日本語 UI 特有の補足
- 出力・検証

## 5. 導入後の検証

- `/ux-writing` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/ux-writing/` |
| 元の格納先 | `.claude/skills/ux-writing/` |
| 出典 | plugin87/ux-ui-agent-skills, MIT（Copyright (c) 2026 Thientan Soparat。def84a7） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

エラーは「何が起きた → なぜ → どうすれば」公式、破壊的操作は type-to-confirm

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
