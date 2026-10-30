# /wizard — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x・gitleaks |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `skills/wizard/LICENSE` | 1.1 KB | ライセンス |
| `skills/wizard/SKILL.md` | 10.5 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/wizard/eval/trigger.json` | 2.6 KB | データ・設定 |
| `skills/wizard/template.sh` | 8.4 KB | シェルスクリプト（BOM 禁止・改行 LF） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/wizard .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/wizard/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/wizard` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/wizard`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/wizard` を名指しする。

## 4. 内容の構成

本体（`skills/wizard/SKILL.md`）の見出し構成:

- この作業における禁止事項【重要】
- Windows での実行【重要】
  - 改行コードは LF にする【最重要】
  - そのほか
- 手順
  - Step 1: 手順の範囲を決める
  - Step 2: 各段の道筋を書く
  - Step 3: ウィザードを書く
  - Step 4: 検証して引き渡す
- 完了条件
- 関連

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**
- `/wizard` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/wizard/` |
| 元の格納先 | `.claude/skills/wizard/` |
| 出典 | 同上 |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |

### 作成の経緯（切り出し元の記録より）

**改行コードの失敗が記録されている**（ADR-049）: 同梱した `template.sh` は上流を `core.autocrlf=true` の環境で clone した経路により**全 204 行が CRLF** で、Git Bash から実行できない状態だった。`bash -n` は CRLF でも終了コード 0 を返すため唯一の検証手段では検出できず、**`git commit` の警告で偶然気づいた**。SKILL.md に「改行コードは LF にする【最重要】」節を新設した。**トリガー精度は名指しで改善した**（1/8 → 7/8 → 追試 6/8。ADR-051・ADR-053）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
