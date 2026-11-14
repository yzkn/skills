# /auto-loop

ループエンジニアリング（長時間・複数案件の作業を、**指令リポジトリ**の Markdown で状態管理しながら進める）の手順。依頼の起票、着手前の確認（認証・push 先・本流のリモート）、担当の主張、区切りごとの状態の記録、上限・再起動のあとの再開、サブエージェントへの委任、完了の報告までを扱う。複数の PC・複数のエージェント（Claude と Copilot など）・複数の GitHub / GitLab アカウントをまたぐ。`/auto-loop <setup|status|intake|start|preflight|checkpoint|resume|delegate|finish>`。技術スタックには依存しない。

|            |                                                                    |
| ---------- | ------------------------------------------------------------------ |
| 種別       | Claude Code スキル（スクリプト・ひな形同梱）                       |
| 導入先     | `~/.claude/skills/auto-loop/`（`install.ps1` が写す）              |
| 公開区分   | 🟢 公開可（本リポジトリ独自）                                       |
| 出典       | 本リポジトリ独自（正本は https://github.com/aiyzkn/auto-loop-engineering の `skills/auto-loop/`） |

## これは何か

作業の**指令と状態の正本**を、会話の外の git リポジトリ（指令リポジトリ）に置く。上限・再起動・セッションの分岐で会話が切れても、別の PC・別のエージェントに替わっても、タスクファイルを読めば続けられるようにする。

- **指令リポジトリ**（ひな形は `skills/auto-loop/assets/control-repo/`）: 受付 `inbox.md`（人が見出し 1 行で依頼を足す）、名簿 `roster.md`、承認の境界 `policy.md`、エージェント向けの決まり `AGENTS.md`、案件ごとの `projects/<案件>/project.md`（ホスト・リポジトリ・アカウント・本流のリモート・検証の方法）と、1 タスク 1 ファイルの状態ファイル `tasks/<日付>-<名前>.md`
- **担当の調停**: 同じタスクに 2 つのエージェントが着手しないよう、git の push の先着で担当を決める（`claim.ps1`）。印が古くても自動では引き継がない（上限の解除待ちと区別できないため）
- **段階**: 依頼ごとに「提案だけ / 実装まで（PR・MR の作成）/ マージまで」を明示する。指定が無ければ提案だけ
- **着手前の確認**（`preflight.ps1`）: `gh` / `glab` の認証と有効なアカウント、push 先の権限・アーカイブ・削除予定（GitLab）、本流のリモートの向き先、ローカルの基準ブランチの遅れ、作業ツリーに残った変更（止まった委任の置き土産）

## なぜ作られたか

長時間の作業で、次のことが実際に起きた。

- 作業の状態が会話の中にしかなく、上限で止まって再開するたびに会話の記録を読み直した。scratchpad の補助ファイルはセッションの分岐で失われた
- 認証切れ・push 先の削除予定・ローカルの main の大きな遅れを、作業の最後で知った
- セッションが分岐（`--fork-session`）すると、止まったサブエージェントに続きを頼めなかった
- サブエージェントの push・PR 作成が、権限の確認で止められた
- 作業が GitHub / GitLab の複数のアカウント・リポジトリに分かれ、案件を横断して状態を見る場所が無かった

[`claude-skill-auto-resume-global`](../claude-skill-auto-resume-global/) が「上限の解除時刻に PC を起こしてセッションを再開する」のに対し、こちらは「再開したセッションが**何を読んで続けるか**」を受け持つ。`install.ps1 -LinkAutoResume` で、`auto-resume-global` の再開の指示に「`/auto-loop resume` を実行する」案内を足せる。

## 導入

```powershell
# 1. スキルを導入する（~/.claude/skills/auto-loop/ に写し、~/.claude/auto-loop/ に設定とフォルダを作る）
pwsh -NoProfile -File packages/claude-skill-auto-loop/skills/auto-loop/scripts/install.ps1

# 2. 指令リポジトリを手元に作る（GitHub には触れない。最後に、非公開で作って送るコマンドを示す）
pwsh -NoProfile -File $HOME/.claude/skills/auto-loop/scripts/new-control-repo.ps1 -Path <場所>/loop-control

# 3. エージェントの ID（<PC>-<道具>[-<アカウントや用途>]）と指令リポジトリを登録する
pwsh -NoProfile -File $HOME/.claude/skills/auto-loop/scripts/install.ps1 -NoCopy -AgentId pc1-claude -ControlRepoPath <場所>/loop-control

# 4. 確かめる
pwsh -NoProfile -File $HOME/.claude/skills/auto-loop/scripts/preflight.ps1
```

あとは Claude Code で `/auto-loop setup` を実行する（案件の登録、名簿への追加、`auto-resume-global` との連携）。2 台目以降の PC では、指令リポジトリを clone して 3 から行う。

**スキルは必ずディレクトリ形式（`~/.claude/skills/auto-loop/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/auto-loop` での呼び出しもできない。

## 使い方

`/auto-loop <サブコマンド>` で呼び出す。「ループの状態を見せて」「受付を整理して」「次のタスクに着手して」「着手前の確認をして」「状態を記録して」「中断したところから再開して」などでも自動適用される。複数ステップに及ぶ作業を直接頼まれたときも、着手の前に起票する。

| サブコマンド | 行うこと |
|---|---|
| `setup` | この PC の登録（ID・指令リポジトリ・自動再開との連携）、案件の追加 |
| `status` | 全案件の状態の要約（人の対応が要るものを先に） |
| `intake` | 起票（受付の整理、直接の依頼の反映） |
| `start [タスク ID]` | 担当の主張 → 着手前の確認 → 計画・承認が要る操作の洗い出し |
| `preflight [案件]` | 着手前の確認だけ |
| `checkpoint` | 状態の記録（区切りごと） |
| `resume` | 中断からの再開（状態ファイル・作業ツリー・前提を確かめ直す。止まった委任の仕上げ） |
| `delegate` | サブエージェントへの委任（指示書の型・作業ツリー・禁止事項） |
| `finish` | 完了の報告・解放・片付け |

人は、指令リポジトリの `inbox.md` に `## <案件>: <件名>` を足すだけで依頼できる（GitHub の画面・スマートフォンからでも）。判断待ち（`status: waiting`）のタスクには、タスクファイルに直接答えを書ける。

## 収録ファイル

- `skills/auto-loop/SKILL.md`
- `skills/auto-loop/references/`（`setup.md`・`status.md`・`intake.md`・`start.md`・`preflight.md`・`checkpoint.md`・`resume.md`・`delegate.md`・`finish.md`）
- `skills/auto-loop/scripts/`（`install.ps1`・`new-control-repo.ps1`・`preflight.ps1`・`status.ps1`・`new-task.ps1`・`claim.ps1`・`sync.ps1`・`lib/AutoLoop.psm1`）
- `skills/auto-loop/assets/control-repo/`（指令リポジトリのひな形）

## 単体利用時の注意

他のパッケージ・元リポジトリのパスへの参照は無い（単体で動く）。`auto-resume-global` との連携は任意（入っていなければ `-LinkAutoResume` は何もしない）。

設計の根拠・運用の手引き・通し試験（`tests/smoke.ps1`）・実地確認の記録は、正本のリポジトリ https://github.com/aiyzkn/auto-loop-engineering にある。

## ライセンス

本リポジトリのライセンス（Apache-2.0）。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
