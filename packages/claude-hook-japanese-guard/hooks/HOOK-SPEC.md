# .claude/hooks — フックの仕様（保守用リファレンス）

`auto-record.ps1`・`japanese-guard.ps1`（Stop）・`safety-net.ps1`（PreToolUse）を保守・デバッグする際に参照する技術仕様。運用ルールは `MANUAL.md` §6.1、コンポーネント連携の概要は `.claude/CLAUDE.md` を参照。

## Stop フックが受け取る stdin JSON

トランスクリプトファイルのパス: `~/.claude/projects/<encoded-cwd>/<session_id>.jsonl`
`<encoded-cwd>` はワーキングディレクトリのパス区切り `\`/`/` を `-`、`:` を `--` に変換した文字列。

```json
{
  "session_id": "<UUID>",
  "transcript_path": "<encoded-cwd から組み立てた絶対パス>",
  "cwd": "<起動時のワーキングディレクトリ>",
  "stop_hook_active": false
}
```

`stop_hook_active` は、Stop フックが `decision: block` を返して Claude が応答を続けた後、再び Stop が発火した場合に `true` になる（本リポジトリでは `japanese-guard.ps1` の差し戻し後）。`japanese-guard.ps1` はこの値が `true` なら差し戻さずに通し、無限ループを防ぐ。`auto-record.ps1` は block を返さないため再帰は起きず、**書き直した回答を証跡に残すためにスキップせず記録する**（差し戻しがあったターンは記録ファイルが 2 つになる）。

- **stdin は UTF-8 の `StreamReader` で明示的に読む**（safety-net.ps1 と同じ理由）。`[Console]::In` はコンソールコードページ（cp932 等）で読むため、`cwd` / `transcript_path` に非 ASCII を含むプロジェクトでは JSON が壊れて解析に失敗する。**この読み方を変更してはならない**
- 早期終了（空 stdin・JSON 解析失敗）はいずれも `Write-Trace` で `doc/log/error/auto-record-trace.log` に理由を追記する。**無言で終了する経路を追加しないこと**。trace ログの出力先は `$PSScriptRoot` 起点で、`$cwd` が確定する前（および `$cwd` が誤っている場合）でも書けるようにしてある

## トランスクリプト `.jsonl` の構造

各行の主な `type` 値: `user` / `assistant` / `system` / `attachment` / `queue-operation`。
`auto-record.ps1` は `user` と `assistant` のみを処理する。

- **ユーザー発言の `message.content` の形は起動経路で異なる**: VS Code 拡張（`entrypoint: claude-vscode`）は `[{type:"text",...}]` の配列、CLI（`entrypoint: cli`。`claude -p` を含む）は文字列。両方を扱わないと CLI で発言を取り逃がす（2026-10-20 に判明）
- `isMeta: true`（スキル起動時に差し込まれる本文・サブエージェントの報告）と `queueTranscriptOnly: true`（タスク完了通知）も `type: "user"` で届くが、ユーザーの発言ではない

## Stop フック（japanese-guard.ps1）の仕様

そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら、`{"decision":"block","reason":"..."}` を stdout に返して終了させず、英語の箇所だけを日本語で書き直させる。出典は minorun365/claude-code-japanese-guard（Apache-2.0。Python 版を PowerShell へ移植・改変。帰属はスクリプト冒頭）。

- **判定**: コードブロック・インラインコード・URL・メールアドレス・Markdown リンクを除いた本文で、英字 25 字以上かつ「英字数 > 日本語字数 × 3」。閾値は環境変数 `JAPANESE_GUARD_MIN_LATIN` / `JAPANESE_GUARD_RATIO` で変えられる
- **待機**: Stop は最終回答が `.jsonl` へ書き込まれる前に発火することがあるため、本文で終わるまで最大 3 秒待つ（`JAPANESE_GUARD_WAIT`）
- **読み方**: `.jsonl` を末尾から読み、最後のユーザー発言より後の行だけを JSON 解析する（大きなトランスクリプトで遅くならないようにするため）
- **差し戻しは 1 ターン 1 回**: `stop_hook_active` が `true` なら通す
- **fail-open**: 例外時は何も出力せず exit 0。差し戻しと障害は `doc/log/error/japanese-guard-trace.log` に追記する
- 出力は `[Console]::OpenStandardOutput()` に UTF-8 バイトを直接書く（safety-net.ps1 と同じ）

## PreToolUse フック（safety-net.ps1）の仕様

`.claude/rules/` の【絶対禁止】/【要指示】ルールのうち機械的に判定できるものを、ツール実行前に deny / ask する多層防御の一層（プロンプト記述・`permissions.deny` を補完する）。判定ロジックは本リポジトリ独自実装。

### stdin JSON

```json
{
  "session_id": "<UUID>",
  "cwd": "<起動時のワーキングディレクトリ>",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash | Edit | Write | MultiEdit | NotebookEdit | Read",
  "tool_input": { "command": "...", "file_path": "..." }
}
```

### 出力

ブロック・確認要求時のみ stdout に以下を UTF-8 で返す（許可時は無出力・exit 0）。

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask","permissionDecisionReason":"<理由と出典ルール>"}}
```

### 判定ルール一覧

| 対象ツール | 条件 | 決定 | 出典ルール |
|---|---|---|---|
| Bash | `git push`（`-C` 付き・連結後段含む全形態） | deny | `git-safety.md`【絶対禁止】 |
| Bash | `mkfs` / `diskpart` / `Format-Volume` / `Clear-Disk` | deny | Safety Net 固有 |
| Bash | `.env` の内容表示（`.env.example` 除く） | deny | `security-hardstops.md` |
| Bash | 外部送信コマンドの別経路（`Invoke-WebRequest`/`iwr`/`irm`/`curl.exe` 等。コマンド位置＝先頭または `;&\|` 直後に限定） | deny | `external-resources.md` |
| Bash | .NET クラス経由の外部通信（`New-Object Net.WebClient`・`[System.Net.Http` 等。引用文字列内も検知） | deny | `external-resources.md` |
| Bash | `python -c/-m` × 外部通信系モジュール（urllib/requests/socket 等） | ask | `external-resources.md`【要指示】 |
| Bash | 破壊的 SQL（`DROP`/`TRUNCATE`/`DELETE FROM`） | ask | `environment-safety.md`【要指示】 |
| Bash | 防御設定ファイル（`.claude/settings*.json`・`.claude/hooks/`・`.mcp.json`・`.githooks/`）へのリダイレクト・`Set-Content` 等による書込 | ask | `external-resources.md`【要指示】 |
| Bash | `rm -rf` / `Remove-Item -Recurse -Force` | ask | `safe-file-ops.md`【要指示】 |
| Bash | `git reset --hard` / `git clean -f` | ask | `safe-file-ops.md` |
| Bash | compose（`podman compose`・`podman-compose`・`docker compose`・`docker-compose`）の `down` / `rm` に `-v`・`--volumes`・`--rmi`（コマンド位置に限定） | ask | `container` スキル §4（ADR-057） |
| Bash | `podman` / `docker` の `system prune\|reset`・`volume\|image\|network\|container\|builder\|buildx\|pod` の `prune\|rm`・`machine rm\|reset`・`rmi`・`kill`・`rm -f`（コマンド位置に限定） | ask | `container` スキル §4（ADR-057） |
| Bash | `--no-verify` | ask | `git-safety.md`【要指示】 |
| Bash | `production/prod/prd` × デプロイ系コマンドの組合せ | ask | `environment-safety.md`【要指示】 |
| Edit 系 | `doc/prompt/`・`doc/thought/`・`doc/adr/` の編集 | deny | 証跡の不変性【絶対禁止】 |
| Edit 系 | `.claude/skills/anthropics/` 配下（第三者由来スキルの改変） | deny | `.claude/CLAUDE.md`「構成・拡張の保守」【絶対禁止】 |
| Edit 系 / Write | 防御設定ファイル（`.claude/settings*.json`・`.claude/hooks/*.ps1`・`.mcp.json`・`.githooks/`） | ask | `external-resources.md`【要指示】 |
| Write | 上記ディレクトリの**既存ファイル**上書き（新規作成は許可） | deny | 証跡の不変性【絶対禁止】 |
| Edit 系 / Read | `guide/for-human/` | deny | `guide-access.md`【絶対禁止】 |
| Read | `.env`・`.env.*`（`.env.example` 除く） | deny | `security-hardstops.md` |

- **fail-open 設計**: stdin の解析失敗などフック自体の障害時は許可（exit 0）とし、stderr（`doc/log/error/safety-net-stderr.log`）にのみ記録する。フック障害でセッションを止めないため
- 出力は `[Console]::OpenStandardOutput()` に UTF-8 バイトを直接書く（PowerShell 5.1 のリダイレクト時コードページ問題の回避）
- **stdin も UTF-8 の `StreamReader` で明示的に読む**: `[Console]::In` はコンソールコードページ（cp932 等）で読むため、日本語を含む `tool_input` で JSON が壊れて解析失敗 → fail-open（検査素通り）になる。この読み方を変更してはならない

## 保守時の注意

- `auto-record.ps1`・`japanese-guard.ps1`・`safety-net.ps1` は **UTF-8 BOM 必須**（PowerShell 5.1 が BOM 無しを cp932 として読むため）。Write / Edit ツールで変更した後は `python .claude/scripts/check-encoding.py .claude/hooks --fix` で BOM を付与し直し、再実行して ERROR 0 件を確認すること（BOM の付与だけなら `fix-bom.py` でもよい。要件は [`../docs/text-encoding.md`](../docs/text-encoding.md)）
- stderr は `.claude/settings.json` の設定により `doc/log/error/auto-record-stderr.log` へリダイレクトされる。`doc/log/error/` が存在しないとフック自体が起動しない
- **stderr ログの更新時刻・存在はフックの成否を示さない**。`2>` はフック起動のたびにファイルを truncate するため、スクリプトが 1 行も実行されなくても mtime は更新され 0 バイトのままになる。成否の判定には `auto-record-trace.log`（追記式）を使う
- 記録されないときの確認手順は `MANUAL.md` §6.1 を参照
