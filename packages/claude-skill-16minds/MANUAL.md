# /16minds — マニュアル

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
| `skills/16minds/LICENSE` | 1.1 KB | ライセンス |
| `skills/16minds/SKILL.md` | 15.1 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/16minds/agents/enfj.md` | 3.1 KB | — |
| `skills/16minds/agents/enfp.md` | 3.0 KB | — |
| `skills/16minds/agents/entj.md` | 3.1 KB | — |
| `skills/16minds/agents/entp.md` | 3.0 KB | — |
| `skills/16minds/agents/esfj.md` | 3.1 KB | — |
| `skills/16minds/agents/esfp.md` | 3.0 KB | — |
| `skills/16minds/agents/estj.md` | 3.0 KB | — |
| `skills/16minds/agents/estp.md` | 2.8 KB | — |
| `skills/16minds/agents/infj.md` | 3.0 KB | — |
| `skills/16minds/agents/infp.md` | 3.0 KB | — |
| `skills/16minds/agents/intj.md` | 3.5 KB | — |
| `skills/16minds/agents/intp.md` | 3.2 KB | — |
| `skills/16minds/agents/isfj.md` | 3.0 KB | — |
| `skills/16minds/agents/isfp.md` | 3.0 KB | — |
| `skills/16minds/agents/istj.md` | 3.0 KB | — |
| `skills/16minds/agents/istp.md` | 2.9 KB | — |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/16minds .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/16minds/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/16minds` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/16minds`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/16minds` を名指しする。

## 4. 内容の構成

本体（`skills/16minds/SKILL.md`）の見出し構成:

- 【重要】このスキルの起動条件
- 利用可能なタイプ（一覧順）
- サブコマンド
  - 共通オプション
- 【要指示】並列起動の事前確認
- エラー処理
- 人格エージェントの起動方法
- 出力フォーマット指定（エージェントに渡す本文）
  - light
  - middle
  - heavy
- 実行フロー
  - `mind`
  - `pair`

## 5. 導入後の検証

- `/16minds` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/16minds/` |
| 元の格納先 | `.claude/skills/16minds/` |
| 出典 | yukurash/16minds-plugin, MIT |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**「明示的に呼び出したときだけ読み込まれる」という条件を満たす置き場所が問題になった**（ADR-018）。`.claude/agents/` に置くと `description` がセッション開始時に載り、16 件 × 約 350 字 = 約 5,600 字が使わないセッションでも固定費になる。原典の "Invoke ONLY when explicitly requested" は**発動の抑制であって読み込みの抑制ではない**。解決として登録機構に載らない `.claude/skills/16minds/agents/*.md` へ原典無改変で収録し、必要なタイプだけを Read して `general-purpose` に注入する形にした

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
