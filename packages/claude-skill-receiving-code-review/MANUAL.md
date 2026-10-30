# /receiving-code-review — マニュアル

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
| `skills/receiving-code-review/LICENSE` | 1.1 KB | ライセンス |
| `skills/receiving-code-review/SKILL.md` | 8.1 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/receiving-code-review/eval/trigger.json` | 2.5 KB | データ・設定 |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/receiving-code-review .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/receiving-code-review/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/receiving-code-review` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/receiving-code-review`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/receiving-code-review` を名指しする。

## 4. 内容の構成

本体（`skills/receiving-code-review/SKILL.md`）の見出し構成:

- 応答の型
- 使ってはいけない応答
- 不明な項目があるとき
- 指摘元ごとの扱い
  - ユーザー本人から
  - 外部レビュアー（顧客・他ベンダー・PR コメント）から
  - 診断エージェント（`code-reviewer`・`owasp-check`・`riss-ioqeo`・`perf-analyzer` 等）から
- YAGNI の確認
- 実装の順序
- 反論すべき場面
- 本リポジトリ固有の注意【重要】
- よくある失敗
- 完了条件
- 関連

## 5. 導入後の検証

- `/receiving-code-review` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/receiving-code-review/` |
| 元の格納先 | `.claude/skills/receiving-code-review/` |
| 出典 | obra/superpowers, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**自動適用の断念が実測に基づいて記録されている稀な例。** 発動すべき依頼文 8 件での発動は 3 回の実測で 0/8 → 2/8 → 0/8 だった（各 3〜5 試行）。同じ改善策（常時適用ルールからの名指し）は `wizard` では有効だったため、施策の無効ではなくこのスキル固有の結果と判定し、**明示呼び出し専用に位置づけを変更した**（ADR-051・ADR-053・ADR-054）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
