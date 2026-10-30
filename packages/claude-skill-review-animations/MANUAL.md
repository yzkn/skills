# /review-animations — マニュアル

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
| `skills/review-animations/LICENSE` | 1.4 KB | ライセンス |
| `skills/review-animations/SKILL.md` | 13.0 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/review-animations/STANDARDS.md` | 13.9 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/review-animations .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/review-animations/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/review-animations` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/review-animations`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/review-animations` を名指しする。

## 4. 内容の構成

本体（`skills/review-animations/SKILL.md`）の見出し構成:

- 基本姿勢
- 10 の譲れない基準
- 積極的にエスカレーションすべきトリガー
- 是正における優先順位
- 求められる出力形式
  - Part 1 — 指摘事項テーブル（必須）
  - Part 2 — 判定（必須）
- ガイドライン
- 出典

## 5. 導入後の検証

- `/review-animations` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 切り出し元では `.claude/skills/_disabled/` に退避されていた（トークン削減のため無効化中。機能自体は動く）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/_disabled/review-animations/` |
| 元の格納先 | `.claude/skills/_disabled/review-animations/` |
| 出典 | emilkowalski/skills, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

同上（ADR-004・ADR-021）。原典は `disable-model-invocation: true` を維持しており、自動適用ではなく直接呼び出し専用として導入した。

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
