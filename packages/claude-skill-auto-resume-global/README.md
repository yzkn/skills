# /auto-resume-global

Claude Code の利用上限（5 時間・週）で止まった対話セッションを、この PC の全プロジェクトについて見張り、**解除時刻に Windows をスリープから復帰させ、新しいターミナルのウィンドウで `claude --resume --fork-session` を起動して続きから再開する**（既定 `action: resume`。再開した claude が動いている間はスリープさせない）。設定 `action` を `wake` にすると、PC を起こしておくだけで再開はしない（Claude Code は上限の解除後に止まったターンを自分では続けないので、別の仕組みが再開する場合だけに使う）。終了していた場合は次のログオン時に処理する。任意で、上限で止まったら確認 (既定 120 秒。キャンセル可) のうえ Windows をスリープする (`-EnableSleepOnLimit`。Claude Code の StopFailure フック)。Windows 専用。

|            |                                                                            |
| ---------- | -------------------------------------------------------------------------- |
| 種別       | Claude Code スキル（スクリプト同梱）                                       |
| 導入先     | `.claude/skills/auto-resume-global/` または `~/.claude/skills/auto-resume-global/` |
| 公開区分   | 🟢 公開可（本リポジトリ独自）                                               |
| 出典       | 本リポジトリ独自                                                           |

## これは何か

上限で止まったセッションの記録（`~/.claude/projects/*/*.jsonl`）に残る `usage_limit_reached` と解除時刻（`resetsAt`）を、タスク スケジューラが 10 分ごと・ログオン時・スリープ復帰時に調べ、解除時刻に PC をスリープから起こすタスク（WakeToRun）を登録する。起こされた PC は無操作だと 2 分ほどでまた眠る。既定の `action: resume` では、新しいウィンドウを開いて再開し、その claude が終わるまでスリープを抑止する（`resume-session.ps1`）。`action: wake` は `keep-awake.ps1` が `keepAwakeMinutes`（既定 20 分）の間スリープを抑止するだけで、再開はしない。

## なぜ作られたか

[`claude-skill-auto-resume`](../claude-skill-auto-resume/) はプロジェクト単位の仕組みで、別パッケージのフック・スクリプトを前提にし、既定は通知（次に開いたときに提示）だけである。次の要望に合わせて、別の形で作った。

- **どのリポジトリの作業でも再開したい**（プロジェクトごとの導入をしない）
- **人が見ていなくても続けたい**
- **PC のスリープ・終了をまたいでも続けたい**（Claude Code 自体が上限の解除後に続きを進められても、PC が寝ていれば進まない）

| | `auto-resume` | `auto-resume-global`（これ） |
|---|---|---|
| 対象 | 導入したプロジェクト | PC の全プロジェクト |
| 前提 | SessionStart フック・`resume-watch.ps1`（別パッケージ） | 同梱のスクリプトだけ |
| 検出 | 自セッションを常駐ウォッチャーが追尾 | タスク スケジューラが全セッションを巡回（常駐なし） |
| 解除後 | 通知（既定）/ headless 再開（optin） | 新しいウィンドウで再開（既定 `resume`、`--fork-session`）/ PC を起こしておくだけ（`wake`） |
| スリープ・終了 | 復帰後・次回起動時に実行 | 解除時刻にスリープから復帰（WakeToRun）/ 次回ログオン時 |
| 再開後の再起動 | — | 再開したセッションが Windows Update などの再起動で作業の途中に終わったら、次回ログオン時にもう一度再開する |

`action: wake` は claude を起動しないので、`auto-resume` と併用できる（`auto-resume` の再開を、スリープ中の解除時刻にも間に合わせる）。既定の `action: resume` で両方を導入すると、上限のたびに通知と再開の両方が起きる。その場合はどちらか一方を使う。

## 導入

```powershell
# スキルを置く (プロジェクトに置いても、~/.claude/skills に置いてもよい。動作は PC 全体に効く)
mkdir -Force ~/.claude/skills
Copy-Item -Recurse packages/claude-skill-auto-resume-global/skills/auto-resume-global ~/.claude/skills/

# 設定する (スクリプトを ~/.claude/auto-resume にコピーし、タスクを登録する)
pwsh -File ~/.claude/skills/auto-resume-global/scripts/install.ps1 -EnableWakeTimers
```

**スキルは必ずディレクトリ形式（`.claude/skills/auto-resume-global/SKILL.md`）で置く。** フラットな `.md` として置くとスキル登録機構に載らず、自動適用も `/auto-resume-global` での呼び出しもできない。

`-EnableWakeTimers` は、電源接続時の「スリープ解除タイマーの許可」を「有効」にする（元の値は記録し、`uninstall.ps1 -RestoreWakeTimers` で戻す）。付けないと、スリープ中に解除時刻が来ても PC が寝たままで、次に起こしたときに再開する。

上限で止まったら PC をスリープさせたいときは、`-EnableSleepOnLimit` を付ける (`-EnableWakeTimers` と一緒に)。`~/.claude/settings.json` の `StopFailure` (matcher: `rate_limit`) にフックを足す (元のファイルは `~/.claude/auto-resume/state/settings.json.bak` に控える)。上限の記録を確かめ、解除時刻の復帰タスクを登録してから、確認の画面を出す。「キャンセル」でスリープしない。外すには `install.ps1 -DisableSleepOnLimit` か `uninstall.ps1`。

```powershell
pwsh -File ~/.claude/skills/auto-resume-global/scripts/install.ps1 -EnableWakeTimers -EnableSleepOnLimit
```

Windows の「しばらく操作しなかった場合に、もう一度 Windows へのサインインを求めるタイミング」（設定 > アカウント > サインイン オプション）は**変えなくてよい**。解除時刻に復帰した PC はロック画面のままだが、タスクはサインイン中の利用者として動き（`InteractiveToken`）、再開のウィンドウもロックの裏で開いて作業を進める（2026-11-09 に、ロックのまま 21:02 に復帰し、21:03 にタスクが動いたことを確かめた）。「常にオフ」にすると、離席中に誰でも操作できるようになるので勧めない。ただし、サインアウトしている間・PC の電源を切っている間は動かない（次のログオン時に処理する）。

前の版（既定が `wake`）で導入していた場合は、`install.ps1 -Action resume` で切り替える。`wake` のままだと、解除時刻に PC は起きるが、止まったセッションは再開しない（Claude Code は上限の解除後に止まったターンを自分では続けない）。

## 使い方

`/auto-resume-global` で明示的に呼び出す。frontmatter の `description` に一致する依頼で自動適用もされる。

```powershell
pwsh -File ~/.claude/auto-resume/auto-resume.ps1 -DryRun     # 待機中・再開予定のセッションを見る (何もしない)
New-Item ~/.claude/auto-resume/disabled                       # 一時停止 (Remove-Item で再開)
pwsh -File ~/.claude/auto-resume/uninstall.ps1 -RestoreWakeTimers   # やめる
```

## 収録ファイル

- `skills/auto-resume-global/SKILL.md`
- `skills/auto-resume-global/scripts/install.ps1`
- `skills/auto-resume-global/scripts/auto-resume.ps1`
- `skills/auto-resume-global/scripts/keep-awake.ps1`
- `skills/auto-resume-global/scripts/sleep-on-limit.ps1`
- `skills/auto-resume-global/scripts/sleep-prompt.ps1`
- `skills/auto-resume-global/scripts/resume-session.ps1`
- `skills/auto-resume-global/scripts/run-hidden.vbs`
- `skills/auto-resume-global/scripts/uninstall.ps1`

## 単体利用時の注意

他のパッケージ・元リポジトリのパスへの参照は無い（単体で動く）。

## ライセンス

本リポジトリのライセンス（Apache-2.0）。同梱の `LICENSE` を参照。

著作権表示: **Copyright 2026 YA**（記入済み）

## 詳細

導入・設定・検証の手順は [MANUAL.md](MANUAL.md) にある。
