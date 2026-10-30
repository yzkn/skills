# /wizard

人間にしか実行できない手順（認証情報の発行・CI シークレット設定・外部ポータル操作・一度きりの移行）を、画面を追って進む対話式スクリプトに書き起こす。「セットアップ手順をスクリプト化して」で自動適用。/wizard [対象]。Claude 自身が実行できる手順には使わない。

> このリポジトリは、Claude Code 用のプロジェクトテンプレート `claudecode-pm-starter-kit`（非公開）の資産を **1 項目 = 1 リポジトリ**の形に切り出したものである。切り出しは機械的に行っており、**本文中の相互参照は元リポジトリのパスのまま残っている場合がある**（下記「単体利用時の注意」を参照）。元リポジトリは公開していないため、本文が挙げる ADR・コミットなどの記録は参照できない。

| | |
|---|---|
| 種別 | Claude Code スキル |
| 導入先 | `.claude/skills/wizard/` |
| 公開区分 | 🟢 公開可（第三者由来・permissive。帰属表示が必要） |
| 出典 | 同上 |
| 切り出し元 | `claudecode-pm-starter-kit`（この資産の最終変更コミット 518ae8e） |

## これは何か

人間にしか実行できない手順（認証情報の発行・CI シークレット設定・外部ポータル操作・一度きりの移行）を対話式 bash スクリプトに落とす

## なぜ作られたか

**改行コードの失敗が記録されている**（ADR-049）: 同梱した `template.sh` は上流を `core.autocrlf=true` の環境で clone した経路により**全 204 行が CRLF** で、Git Bash から実行できない状態だった。`bash -n` は CRLF でも終了コード 0 を返すため唯一の検証手段では検出できず、**`git commit` の警告で偶然気づいた**。SKILL.md に「改行コードは LF にする【最重要】」節を新設した。**トリガー精度は名指しで改善した**（1/8 → 7/8 → 追試 6/8。ADR-051・ADR-053）

## 導入

```sh
# 導入先のプロジェクトルートで実行する
mkdir -p .claude/skills
cp -r skills/wizard .claude/skills/
```

**スキルは必ずディレクトリ形式（`.claude/skills/wizard/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/wizard` での呼び出しもできない。

## 使い方

`/wizard` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

## 収録ファイル

- `skills/wizard/LICENSE`（1.1 KB）
- `skills/wizard/SKILL.md`（10.5 KB）
- `skills/wizard/eval/trigger.json`（2.6 KB）
- `skills/wizard/template.sh`（8.4 KB）

## 単体利用時の注意

本文中で、元リポジトリの次のパスを参照している。**同梱していないものは、導入先の事情に合わせて読み替えるか削除する必要がある。**

- `.claude/rules/code-quality.md` — 未同梱（別パッケージ `claude-rule-code-quality` に収録）
- `.claude/rules/environment-safety.md` — 未同梱（別パッケージ `claude-rule-environment-safety` に収録）
- `.claude/rules/external-resources.md` — 未同梱（別パッケージ `claude-rule-external-resources` に収録）
- `.claude/rules/git-safety.md` — 未同梱（別パッケージ `claude-rule-git-safety` に収録）
- `.claude/rules/security-hardstops.md` — 未同梱（別パッケージ `claude-rule-security-hardstops` に収録）
- `.claude/scripts/check-encoding.py` — 未同梱（別パッケージ `claude-script-check-encoding` に収録）

また、次のスキル・コマンドを名前で参照している（別リポジトリとして切り出してある。導入しない場合は該当箇所が機能しない）: `/deploy-guide` `/deprecation-migration` `/grill` `/long-run` `/to-questionnaire`

## ライセンス

同梱の `skills/wizard/LICENSE` が原典のライセンスである。**原典の著作権表示とライセンス全文を削除してはならない。** 本パッケージで加えた日本語化・改変部分は、切り出し元リポジトリと同じ Apache-2.0 で提供する（`LICENSE-KIT` を同梱。著作権表示は **Copyright 2026 YA**）。

> 出典: 同上

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
