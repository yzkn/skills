# /split-pr — マニュアル

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
| `skills/split-pr/LICENSE` | 10.1 KB | ライセンス |
| `skills/split-pr/SKILL.md` | 13.4 KB | スキル本体（frontmatter の `description` で自動適用される） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/split-pr .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/split-pr/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/split-pr` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/split-pr`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/split-pr` を名指しする。

## 4. 内容の構成

本体（`skills/split-pr/SKILL.md`）の見出し構成:

- この作業における禁止事項【重要】
- 分割の原則
  - 1 PR の大きさ
  - 先頭はスケルトン PR にする
  - 後続 PR は 1 つの機能とそのテストをまとめる
  - PR を鎖状につなぐ
- 実行手順
  - Step 1: 現状の把握
  - Step 2: 分割の設計
  - Step 3: 計画の提示と承認
  - Step 4: 取り込み元を固定する
  - Step 5: PR を 1 本ずつ作る（作成 → 再編 → コミットの繰り返し）
  - Step 6: push と PR 作成のコマンドを提示する
- 完了条件

## 5. 導入後の検証

- `/split-pr` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/split-pr/` |
| 元の格納先 | `.claude/skills/split-pr/` |
| 出典 | liam-hq/liam の `.claude/commands/split-pr.md`, Apache-2.0 |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**方法論のみ採り、実行手順は本リポジトリの Git 規約に合わせて書き直した**（ADR-019）。`git push` と `gh pr create` はユーザーが実行する

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
