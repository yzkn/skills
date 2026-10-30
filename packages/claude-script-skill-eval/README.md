# skill-eval

スキルの `description` によるトリガー精度（発動すべき / すべきでない依頼文での発動率）を `claude -p` で実測するハーネス

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | 共有スクリプト |
| 導入先 | `.claude/scripts/` |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |
| 出典 | 本リポジトリ独自 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 466734d） |

## これは何か

スキルの `description` によるトリガー精度（発動すべき / すべきでない依頼文での発動率）を `claude -p` で実測するハーネス

## なぜ作られたか

スキル劣化防止の第 1 段階として評価資産を集約（2026-08-25、ADR-031）。**このハーネス自身のバグが実測を歪めた**: 最初の `message_stop` で「不発動」を確定して子プロセスを kill していたため、ツール呼び出し前に短い前置きテキストを返すケースを取りこぼし、発動すべきケース 1/20 という異常値を出していた（ADR-038）。判定根拠を「別のツールが実際に選ばれたとき」と「`result` イベント / ストリーム終了」だけに限定して修正した

## 導入

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 収録ファイル

- `scripts/skill-eval/fixtures/app.db`（12.0 KB）
- `scripts/skill-eval/fixtures/qr.png`（4.0 KB）
- `scripts/skill-eval/fixtures/token.txt`（181 B）
- `scripts/skill-eval/handoff-protocol.md`（6.6 KB）
- `scripts/skill-eval/handoff_eval.py`（13.1 KB）
- `scripts/skill-eval/make_fixtures.py`（4.9 KB）
- `scripts/skill-eval/trigger_eval.py`（13.3 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/docs/authoring-guide.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/docs/windows-python-tooling.md` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）
- `.claude/scripts/skill-eval/fixtures/` — 未同梱（別パッケージ `claude-script-skill-eval` に収録）
- `.claude/scripts/skill-eval/handoff_eval.py` — **同梱**
- `.claude/scripts/skill-eval/trigger_eval.py` — **同梱**
- `.claude/skills/newcomer-guide-workspace/trigger-eval.json` — 未同梱（切り出しの対象外。読み替えか削除が必要）
- `.claude/skills/skill-optimizer/scripts/handoff_eval.py` — **同梱**
- `.claude/skills/vnl/eval/trigger.json` — 未同梱（別パッケージ `claude-skill-vnl` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/vnl`

## ライセンス

切り出し元リポジトリのライセンス（Apache-2.0）を継承する。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
