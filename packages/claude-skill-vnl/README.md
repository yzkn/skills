# /vnl

ハッシュ・Base64・UUID・JWT・コントラスト比・検査数字・形式変換・テストデータ・cron の次回実行時刻・営業日計算をローカルのスクリプトで算出する。「ハッシュ値を出して」「3 営業日後はいつ」で自動適用。/vnl <群> <サブコマンド>。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/vnl/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット b065e6b） |

## これは何か

ハッシュ・Base64・UUID・JWT・コントラスト比・検査数字・形式変換・テストデータ・cron の次回実行時刻・営業日計算・QR をローカルスクリプトで算出する（8 群）

## なぜ作られたか

**動機は「便利だから」ではない。** Claude が記憶や暗算で答えると誤り、しかも**読み手が検証なしに見分けられない**値が存在するため、機械的に潰す目的で導入（ADR-033）。フェーズ 2 で cron / clock / sqlite（ADR-036）、フェーズ 3 で QR（ADR-037）を追加。**QR は新規パッケージを導入せず**、導入済み OpenCV の `QRCodeEncoder` / `QRCodeDetector` に載せた（「導入するツールは必要なものだけ」というユーザー制約に対し、導入の必要性そのものを再検証した結果）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/vnl .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/vnl/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/vnl` での呼び出しもできない。

## 使い方

`/vnl` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/vnl/SKILL.md`（8.4 KB）
- `skills/vnl/eval/trigger.json`（5.5 KB）
- `skills/vnl/references/verification.md`（7.0 KB）
- `skills/vnl/scripts/_common.py`（3.1 KB）
- `skills/vnl/scripts/checkdigit.py`（8.3 KB）
- `skills/vnl/scripts/clockcalc.py`（8.6 KB）
- `skills/vnl/scripts/color.py`（9.0 KB）
- `skills/vnl/scripts/cronparse.py`（8.5 KB）
- `skills/vnl/scripts/qrcodes.py`（13.4 KB）
- `skills/vnl/scripts/security.py`（8.8 KB）
- `skills/vnl/scripts/sqliteq.py`（8.6 KB）
- `skills/vnl/scripts/testdata.py`（5.8 KB）
- `skills/vnl/scripts/textconv.py`（7.0 KB）
- `skills/vnl/scripts/vnl.py`（2.8 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/image-reading.md` — 未同梱（別パッケージ `claude-rule-image-reading` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）
- `.claude/rules/wbs-tasks.md` — 未同梱（別パッケージ `claude-rule-wbs-tasks` に収録）
- `.claude/scripts/skill-eval/fixtures/app.db` — 未同梱（別パッケージ `claude-script-skill-eval` に収録）
- `.claude/scripts/skill-eval/fixtures/qr.png` — 未同梱（別パッケージ `claude-script-skill-eval` に収録）
- `.claude/scripts/skill-eval/fixtures/token.txt` — 未同梱（別パッケージ `claude-script-skill-eval` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/bulk-ops` `/ui-ux-pro-max`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
