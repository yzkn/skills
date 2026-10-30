---
name: bulk-ops
description: "多数ファイル（目安 10 件以上）の一括解析・一括改名・一括置換をスクリプトで完結させ、要約だけをコンテキストに載せる。「まとめてリネームして」「一括削除して」で自動適用。/bulk-ops <サブコマンド>。書き込みは dry-run→承認→--apply の順。"
---

# /bulk-ops スキル — 一括操作をローカルで完結させる

**引数:** `$ARGUMENTS`

10 件以上のファイルにまたがる解析・変更を、**Read/Edit の反復ではなくローカルスクリプト 1 回の実行**で処理し、**要約 JSON だけ**をコンテキストに載せる。50 ファイルの一括改名で 25K トークン → 1K トークン程度に収まる。

> 出典: [mhattingpete/claude-skills-marketplace](https://github.com/mhattingpete/claude-skills-marketplace) の `execution-runtime`（Apache License 2.0、`LICENSE` 参照）。原典は pip でパッケージを導入する方式だが、①`python3`/`pip3` 前提でこの端末では動作しない ②依存 4 パッケージが MCP サーバ用で本用途に不要 ③`git_push()` を含む git API が `settings.json` の `Bash(git push*)` deny を迂回できる、の 3 点により**移植方式を変更した**。Python 標準ライブラリのみの単体スクリプト（`scripts/bulk_ops.py`）として再実装し、git 操作 API は移植していない。

## いつ使うか

| 使う | 使わない |
|---|---|
| 10 件以上のファイルにまたがる識別子の改名・文字列置換 | 1〜数ファイルの編集（Read + Edit を使う。差分の意図が見えるほうが安全） |
| リポジトリ全体の規模・複雑度・未使用 import の集計 | 正式な保守性診断（`complexity-analyzer` サブエージェント） |
| 関数・クラスの所在を本文なしで把握する | 実装内容の理解（Read または `Explore` エージェント） |
| ログ・出力に含まれる機密情報のマスキング | コミット前の機密チェック（gitleaks／`.githooks/pre-commit` が正） |
| 大量ファイルの機密情報スキャン | 脆弱性診断（`owasp-check`・`riss-ioqeo`） |

数時間かかる規模なら、このスキルの実行自体を `/long-run` の detach ジョブに載せる。

## 実行方法

```
python .claude/skills/bulk-ops/scripts/bulk_ops.py <サブコマンド> [オプション]
```

スクリプト側で stdout / stderr を UTF-8 に固定しているため、`PYTHONUTF8=1` 等の前置は不要（前置すると下記の allow パターンに一致せず承認ダイアログが出る）。Python の呼び出し方は `~/.claude/CLAUDE.md`「端末環境」または `/tool-environment` に従う。

| サブコマンド | 内容 | 書き込み |
|---|---|---|
| `analyze` | Python の行数・関数数・クラス数・複雑度（近似）・未使用 import 候補を集計し、閾値超過のホットスポットを上位から返す | なし |
| `find --kind function\|class` | 関数・クラスの位置と署名（**本文は返さない**）を列挙。`--name-pattern` で正規表現フィルタ | なし |
| `rename --old --new` | 識別子を単語境界付きで一括改名（部分一致の誤爆を防ぐ） | **あり** |
| `replace --search --replace [--regex]` | 任意文字列・正規表現の一括置換 | **あり** |
| `strip-debug` | `print` / `console.log` / `debugger` / `pdb` 等の行を削除 | **あり** |
| `scan-secrets` | 機密情報らしい記述を検出（**種別と行番号のみ。値は出力しない**） | なし |
| `mask --file --out-file` | ファイル内の機密情報をマスクして別ファイルへ書き出す（入力は変更しない） | 出力先のみ |

共通オプション: `--path`（対象）・`--glob`（既定 `**/*.py`）・`--root`（既定カレント）・`--top`（stdout に載せる件数）・`--out`（詳細 JSON の退避先）・`--max-bytes`。変更系は `--apply`・`--force`・`--diff-out`。

## 手順（変更系は必ずこの順序）

### Step 1: dry-run で影響範囲を出す

```
python .claude/skills/bulk-ops/scripts/bulk_ops.py rename --path src --old getUserData --new fetchUserData --glob "**/*.ts" --diff-out report/bulk/rename.diff
```

`--apply` を付けない限り**1 バイトも書き込まない**。差分は `--diff-out` でファイルへ出し、**全文をコンテキストに読み込まない**（必要な箇所だけ抜粋して確認する）。

### Step 2: ユーザーに提示して承認を得る

変更ファイル数・置換総数・上位ファイル・差分ファイルのパスを提示する。これは `.claude/rules/safe-file-ops.md` の「編集前のスコープ明示」に相当する。**承認なしに Step 3 へ進んではならない。**

### Step 3: `--apply` で適用する

対象ファイルに未コミットの変更・未追跡ファイルがあると**スクリプトが中断する**（git 履歴を唯一の復元手段にするため）。中断したら、コミットまたは退避を**ユーザーに依頼**する。`--force` は復元手段を失う操作なので、原則使わず、使う場合はその旨を明示して承認を得る。

### Step 4: 機械的に検証する

```
git diff --stat
```

事前に提示した変更量と一致するか（`.claude/rules/safe-file-ops.md`「編集後の diff 検証」）、0 バイト化がないかを確認する。コードの場合はビルド・テスト・lint を実行し、結果を根拠として報告する（`.claude/rules/code-quality.md`「完了の証拠主義」）。

## 安全上の制約（このスキル固有）

- 【絶対禁止】**git の書き込み操作をスクリプトで代替しない**。原典の `git_operations.py`（`git_add`・`git_commit`・`git_push`・`create_branch`）は**意図的に移植していない**。`git push` は `.claude/rules/git-safety.md` の【絶対禁止】であり、Python の `subprocess` 経由なら通るという抜け道を作らない。コミットは【要指示】であり、通常の `Bash` から明示的な指示のもとで行う
- **走査対象から常に除外される**（スクリプト内で固定）: `doc/prompt`・`doc/thought`・`doc/adr`（証跡・不変）、`guide/for-human`（参照禁止）、`.claude/skills/anthropics`（第三者由来・書き換え禁止）、`.git`・`node_modules`・`.venv`・`__pycache__`・ビルド生成物
- `--root` の外は対象にできない（シンボリックリンク経由の脱出も拒否する）
- **BOM と改行（CRLF/LF）は原文どおり保持**する。書き込み結果が 0 バイトになる場合は書き込まずに中断する
- `scan-secrets` は**一致した値を出力しない**（種別と行番号のみ）。ヒットした値をコンテキストへ読み込まず、ユーザーに報告して対処を仰ぐ
- `strip-debug` は行単位の判定のため、**複数行にまたがる `print(...)` を検出できない**。dry-run の差分確認を省略しない
- `analyze` の複雑度・`analyze` の未使用 import は**近似・候補**である。`__all__` 経由の使用や型アノテーション文字列内の参照は追えないため、削除の判断は必ず人が行う

## 初回のみ: 実行許可の追加

`.claude/settings.json` の `permissions.allow` に以下が無い場合、実行のたびに承認ダイアログが出る。**この追加は防御設定の変更にあたるため、ユーザーの明示的な指示を得てから行う**（`.claude/rules/external-resources.md`）。Claude Code が独断で追加してはならない。

```json
"Bash(python .claude/skills/bulk-ops/scripts/bulk_ops.py *)"
```

## 完了条件

- [ ] 変更系は dry-run → 影響範囲の提示 → 承認 → `--apply` の順を守った
- [ ] `git diff --stat` の結果が事前提示の変更量と一致している
- [ ] 詳細・差分はファイルに退避し、コンテキストには要約のみを載せた
- [ ] 機密情報の値をコンテキストに読み込んでいない
- [ ] コードを変更した場合、ビルド・テスト・lint の結果を根拠として報告した

## 関連

- 長時間処理の detach 実行: `/long-run`
- 保守性の正式診断: `complexity-analyzer` サブエージェント
- 振る舞いを変えない構造改善: `/code-refactor`
- コミット前の機密チェック: gitleaks（`SETUP.md` 手順 2）
- ファイル操作の安全規則: `.claude/rules/safe-file-ops.md`（本スキルはこれを機械的に強制する実装）
