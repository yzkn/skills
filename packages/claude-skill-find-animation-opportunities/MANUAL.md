# /find-animation-opportunities — マニュアル

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
| `skills/find-animation-opportunities/LICENSE` | 1.4 KB | ライセンス |
| `skills/find-animation-opportunities/SKILL.md` | 13.8 KB | スキル本体（frontmatter の `description` で自動適用される） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/find-animation-opportunities .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/find-animation-opportunities/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/find-animation-opportunities` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/find-animation-opportunities`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/find-animation-opportunities` を名指しする。

## 4. 内容の構成

本体（`skills/find-animation-opportunities/SKILL.md`）の見出し構成:

- 基本姿勢
- 厳守事項
- Gate（関門）
  - 1. Frequency（頻度） — ユーザーはこれをどれくらいの頻度で目にするか
  - 2. Purpose（目的） — なぜこれをアニメーションさせるのか
  - 3. Speed（速度） — budget（予算）内に収まるか
  - 4. Function（機能性） — ここで motion は助けになるか、妨げになるか
- 探索すべき場所
- 進め方
- 必須の出力形式
  - Part 1 — 機会一覧表
  - Part 2 — 却下した候補（必須）
  - Part 3 — 総評
- トーン

## 5. 導入後の検証

- `/find-animation-opportunities` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 切り出し元では `.claude/skills/_disabled/` に退避されていた（トークン削減のため無効化中。機能自体は動く）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/_disabled/find-animation-opportunities/` |
| 元の格納先 | `.claude/skills/_disabled/find-animation-opportunities/` |
| 出典 | emilkowalski/skills, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

emilkowalski/skills（MIT）のアニメーション系スキル 4 件を日本語化して導入した際の 1 件（ADR-004）。既存の UI/UX 系スキル（`ui-ux-pro-max`・`ux-review`・`ui-designer`・`ux-designer`）がアニメーション / モーションを深く扱っておらず、この領域が明確な空白だったことが動機である。その後、トークン削減のため `.claude/skills/_disabled/` へ退避した（`description` はセッション開始時にまとめてコンテキストへ載るため、使わない定義が毎セッションの固定費になる。ADR-021 の計測）。

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
