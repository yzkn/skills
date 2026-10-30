# /vnl — マニュアル

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
| `skills/vnl/SKILL.md` | 8.4 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/vnl/eval/trigger.json` | 5.5 KB | データ・設定 |
| `skills/vnl/references/verification.md` | 7.0 KB | — |
| `skills/vnl/scripts/_common.py` | 3.1 KB | Python スクリプト |
| `skills/vnl/scripts/checkdigit.py` | 8.3 KB | Python スクリプト |
| `skills/vnl/scripts/clockcalc.py` | 8.6 KB | Python スクリプト |
| `skills/vnl/scripts/color.py` | 9.0 KB | Python スクリプト |
| `skills/vnl/scripts/cronparse.py` | 8.5 KB | Python スクリプト |
| `skills/vnl/scripts/qrcodes.py` | 13.4 KB | Python スクリプト |
| `skills/vnl/scripts/security.py` | 8.8 KB | Python スクリプト |
| `skills/vnl/scripts/sqliteq.py` | 8.6 KB | Python スクリプト |
| `skills/vnl/scripts/testdata.py` | 5.8 KB | Python スクリプト |
| `skills/vnl/scripts/textconv.py` | 7.0 KB | Python スクリプト |
| `skills/vnl/scripts/vnl.py` | 2.8 KB | Python スクリプト |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/vnl .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/vnl/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/vnl` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/vnl`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/vnl` を名指しする。

## 4. 内容の構成

本体（`skills/vnl/SKILL.md`）の見出し構成:

- 使わない場面（隣接スキルとの境界）
- 実行方法
- 安全上の制約（このスキル固有）
- 値の確かさ（断定してよい範囲）
- 初回のみ: 実行許可の追加
- 完了条件
- 関連

## 5. 導入後の検証

```sh
python -m py_compile skills/vnl/scripts/_common.py skills/vnl/scripts/checkdigit.py skills/vnl/scripts/clockcalc.py skills/vnl/scripts/color.py skills/vnl/scripts/cronparse.py skills/vnl/scripts/qrcodes.py skills/vnl/scripts/security.py skills/vnl/scripts/sqliteq.py skills/vnl/scripts/testdata.py skills/vnl/scripts/textconv.py skills/vnl/scripts/vnl.py
echo "exit=$?"
```
- `/vnl` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/vnl/` |
| 元の格納先 | `.claude/skills/vnl/` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

**動機は「便利だから」ではない。** Claude が記憶や暗算で答えると誤り、しかも**読み手が検証なしに見分けられない**値が存在するため、機械的に潰す目的で導入（ADR-033）。フェーズ 2 で cron / clock / sqlite（ADR-036）、フェーズ 3 で QR（ADR-037）を追加。**QR は新規パッケージを導入せず**、導入済み OpenCV の `QRCodeEncoder` / `QRCodeDetector` に載せた（「導入するツールは必要なものだけ」というユーザー制約に対し、導入の必要性そのものを再検証した結果）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
