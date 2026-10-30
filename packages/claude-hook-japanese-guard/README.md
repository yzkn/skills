# japanese-guard.ps1

Stop フック。そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら`decision: block` を返して終了させず、英語の箇所だけを日本語で書き直させる。差し戻しは 1 ターン 1 回（`stop_hook_active` が true なら通す）。障害時は fail-open。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code フック |
| 導入先 | `.claude/hooks/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | minorun365/claude-code-japanese-guard, Apache-2.0（Copyright 2026 Minoru Onda） |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 882bd6b） |

## これは何か

Stop フック。そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら`decision: block` を返して終了させず、英語の箇所だけを日本語で書き直させる。差し戻しは 1 ターン 1 回（`stop_hook_active` が true なら通す）。障害時は fail-open。

## なぜ作られたか

外部の資料 15 件を評価した際に採用した唯一のコード移植である（ADR-055）。minorun365/claude-code-japanese-guard（Apache-2.0）の Python 版の判定ロジックをPowerShell へ移植し、トランスクリプトを末尾から読んで今回のターンだけを解析する変更（大きな .jsonl で遅くならないように）と、障害時の fail-open を加えた。導入にあわせて `auto-record.ps1` を修正し、差し戻し後の停止でも記録して書き直した回答を証跡に残すようにした（証跡は実際の応答と一致していることが第一、という判断）。判定ロジックは合成したトランスクリプト 7 ケースで確認したが、実セッションでの動作は未検証である。

## 導入

```sh
mkdir -p .claude/hooks doc/log/error
cp hooks/japanese-guard.ps1 .claude/hooks/
```

その後 `.claude/settings.json` に同梱の `settings.snippet.json` の内容をマージする。
**`.ps1` は UTF-8 BOM 付きで保存する**（BOM が無いと PowerShell 5.1 が cp932 として読み、日本語を含む行で構文エラーになる）。

## 収録ファイル

- `hooks/HOOK-SPEC.md`（9.7 KB）
- `hooks/japanese-guard.ps1`（7.1 KB）
- `settings.snippet.json`（282 B）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）
- `.claude/skills/anthropics/` — 未同梱（切り出しの対象外。読み替えか削除が必要）

## ライセンス

原典のライセンスは Apache-2.0 である。全文を `LICENSE` として同梱した。原典の `NOTICE` を同梱した。著作権表示・ライセンスの参照・変更点は `hooks/japanese-guard.ps1` の冒頭コメントにもある。**`NOTICE` と冒頭コメントを削除・改変してはならない。**本パッケージで加えた移植・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: minorun365/claude-code-japanese-guard, Apache-2.0（Copyright 2026 Minoru Onda）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
