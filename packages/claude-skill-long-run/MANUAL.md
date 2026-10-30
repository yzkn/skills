# /long-run — マニュアル

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
| `skills/long-run/SKILL.md` | 13.1 KB | スキル本体（frontmatter の `description` で自動適用される） |
| `skills/long-run/templates/README.sh.md` | 1006 B | — |
| `skills/long-run/templates/README.win.md` | 1.5 KB | — |
| `skills/long-run/templates/check.ps1` | 1.9 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `skills/long-run/templates/check.sh` | 1.2 KB | シェルスクリプト（BOM 禁止・改行 LF） |
| `skills/long-run/templates/resume-intent.md` | 711 B | — |
| `skills/long-run/templates/run.ps1` | 1.9 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `skills/long-run/templates/run.sh` | 1.1 KB | シェルスクリプト（BOM 禁止・改行 LF） |
| `skills/long-run/templates/worker.ps1` | 1.7 KB | PowerShell スクリプト（UTF-8 BOM 必須） |
| `skills/long-run/templates/worker.sh` | 702 B | シェルスクリプト（BOM 禁止・改行 LF） |

## 3. 導入手順

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/long-run .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/long-run/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/long-run` での呼び出しもできない。

### 3-1. 呼び出し方

- 自動適用: frontmatter の `description` に一致する依頼があったとき
- 明示呼び出し: `/long-run`

**自動適用は `description` だけでは安定しない。** 元リポジトリでの実測では、発動を左右するのは説明文の充実度より**常時適用ルールからスキル名を名指しすること**だった。確実に使いたい場合は、導入先の `CLAUDE.md` かルールから `/long-run` を名指しする。

## 4. 内容の構成

本体（`skills/long-run/SKILL.md`）の見出し構成:

- いつ使うか
- 仕組み
- 実行手順（Claude Code 向け）
  - 1. ジョブを生成・起動する
  - 2. 自動再開を仕掛ける
  - 3. ユーザーへ伝える
  - 4. 状態を確認する
  - 5. セッションが切れたときの再合流
  - 6. 報告したら回収済みにする
- 遵守事項
- 制約

## 5. 導入後の検証

```sh
# 文字コード・改行・BOM の検査（切り出し元の check-encoding.py を使う）
python check-encoding.py <パス...>
```
- `.ps1` は BOM 必須、`.sh` は BOM 禁止・LF。**`bash -n` は CRLF を通すため構文検査では検出できない**
- `/long-run` で明示呼び出しできるか（できない場合はディレクトリ形式・frontmatter の `name` を確認する）
- 自動適用されるか（`description` に一致する依頼文で試す）

## 6. 既知の制約

- **Windows / PowerShell 専用**（PowerShell 5.1 と 7.x で動くよう書かれている）
- 本文が切り出し元のディレクトリ構成（`design/`・`report/`・`task/` 等）を前提にしている箇所がある

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/skills/long-run/` |
| 元の格納先 | `.claude/skills/long-run/` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

セッションリミット・途中中断の影響が大きい処理への備え（コミット `dbf542b`、2026-07-22）。**ジョブ化を禁止事項の回避手段にしない**旨を明記している。cron 周期は当初 15 分だったが、**待機中に同じプロンプトが 9 回積み上がる**実測を受けて 1 時間に改めた（ADR-042）

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
