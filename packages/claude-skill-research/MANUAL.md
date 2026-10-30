# /research — マニュアル

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
| `skills/research/LICENSE-imozuru` | 1.0 KB | ライセンス |
| `skills/research/LICENSE-mathbullet-skills` | 1.0 KB | ライセンス |
| `skills/research/SKILL.md` | 12.6 KB | スキル本体（frontmatter の `description` で自動適用される） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/research .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/research/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/research` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/research`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/research` を名指しする。

## 4. 内容の構成

本体（`skills/research/SKILL.md`）の見出し構成:

- Phase 1: クエリ設計
- Phase 2: 情報収集
- Phase 3: 信頼性評価
- Phase 4: レポート作成
- 目次
- エグゼクティブサマリー
- 詳細調査結果
  - <サブテーマ 1>
  - <サブテーマ 2>
- 注意事項・不確実性
- 情報源一覧
  - Phase 4 の記述規約
- Phase 5: ファイル保存と表示
- 信頼性評価の補足ガイドライン

## 5. 導入後の検証

- `/research` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/research/` |
| 元の格納先 | `.claude/skills/research/` |
| 出典 | mathbullet/skills, MIT（Copyright (c) 2026 mathbullet。3b03971） / MaryCache/imozuru, MIT（Copyright (c) 2026 MaryCache。659f46c） |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**作成の経緯は記録されていない。** この項目はキット初期構成（2026-06-02〜06-25）に含まれ、追加コミットのメッセージが 1 行のため動機が残っていない。失敗や不具合が契機だったという記録もない。

補足（切り出し元の記録より）: 2026-06-22。後に DeepTutor 由来の 4 段パイプライン（問い直し → 分解 → 調査 → 報告）を採用する方針が決まった（ADR-008）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
