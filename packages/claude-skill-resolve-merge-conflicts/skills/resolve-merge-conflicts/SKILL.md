---
name: resolve-merge-conflicts
description: "進行中の git merge / rebase / cherry-pick のコンフリクトを解消する。「コンフリクトを解消して」「マージが衝突した」「rebase が止まった」で自動適用。/resolve-merge-conflicts。"
---

# /resolve-merge-conflicts スキル — マージコンフリクトの解消

進行中の merge / rebase のコンフリクトを、双方の変更意図を理解した上で解消する。

> 出典: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT License）の resolving-merge-conflicts スキルを本リポジトリ向けに適応（コミット・push は `.claude/rules/git-safety.md` に従う）。

## 手順

1. **現状を把握する**: `git status` で merge / rebase の進行状態と衝突ファイルを確認し、`git log --oneline --graph` で双方のブランチの履歴を確認する

2. **各衝突の一次情報を探す**: それぞれの変更が「なぜ」行われたか、元の意図を深く理解する。コミットメッセージ・関連 PR（`gh pr view`）・元の課題やチケット・`doc/adr/` を読む

3. **ハンクを 1 つずつ解消する**: 可能な限り**双方の意図を保持**する。両立できない場合は、マージの目的（何を取り込もうとしているか）に合致する側を採用し、捨てた側のトレードオフを記録してユーザーに報告する。**新しい振る舞いを発明しない**。独断で `--abort` しない（中止はユーザーの指示があった場合のみ）

4. **自動チェックを実行する**: プロジェクトの検証手段（型チェック → テスト → フォーマッタの順が典型）を探して実行し、マージ起因の破壊があれば修正する。テスト実行は `/unit-test-run` の要領に従う

5. **完了処理（git-safety 準拠）**: 解消したファイルをステージングし、コミット前の機密情報チェック（`.claude/rules/git-safety.md`）を行う。**merge / rebase を完結させるコミット（`git commit` / `git rebase --continue`）は【要指示】** — 実行前にユーザーへ確認する。`git push` は【絶対禁止】であり、必要な場合はコマンドを提示してユーザー自身の実行を依頼する

## 注意

- 解消結果の要約（各衝突で何を採用し何を捨てたか・その理由）を必ず報告する
- 衝突ファイルに `doc/prompt/`・`doc/thought/`・`doc/adr/` 配下（不変の証跡）が含まれる場合は、独断で解消せずユーザーに判断を仰ぐ
- rebase の場合、コミットごとに衝突が繰り返されることがある。各回とも上記手順を適用する
