# /db-review — マニュアル

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
| `skills/db-review/LICENSE` | 1.0 KB | ライセンス |
| `skills/db-review/SKILL.md` | 11.1 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/db-review/references/full-checks.md` | 9.1 KB | — |
| `skills/db-review/references/schema-checks.md` | 20.1 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/db-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/db-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/db-review` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/db-review`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/db-review` を名指しする。

## 4. 内容の構成

本体（`skills/db-review/SKILL.md`）の見出し構成:

- 関連スキルとの棲み分け
- このスキルの基本姿勢（最重要）
- ワークフロー
  - ステップ1: モード選択
  - ステップ2: スキーマファイルの自動検出
  - ステップ3: クエリディレクトリの指定（全体モードのみ）
  - ステップ4: チェックファイルを読んでレビュー実行
  - ステップ5: 結果出力
  - ステップ6: 深掘り
- 出力フォーマット
- CRITICAL — データ不整合・データ消失リスク
- HIGH — パフォーマンス劣化・保守困難
- MEDIUM — 将来的な技術的負債
  - 各指摘に含める情報

## 5. 導入後の検証

- `/db-review` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/db-review/` |
| 元の格納先 | `.claude/skills/db-review/` |
| 出典 | takuya-38/claude-skills, MIT（Copyright (c) 2026 takuya-38。c6f0e8b） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 2026-07-04。改善案作成は `data-modeler`、性能解析は `perf-analyzer` に引き継ぐ

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
