# session-resume-check.ps1 — SessionStart フック: セッションリミット(429)の自動再開
#
# 役割は 2 つ。
#   1. 未回収の再開通知（.resume/pending.json）があれば、中断していた作業の続きを
#      コンテキストへ注入する（stdout がセッションへ渡る）
#   2. このセッション用の常駐ウォッチャーを起動する（既に動いていれば何もしない）
#
# 既存の job-resume-check.ps1 が「/long-run のジョブ」に限定されるのに対し、こちらは
# セッション全般が対象。両者は独立のフックエントリとして登録し、互いを変更しない。
#
# fail-open 設計: フック自体の障害時は exit 0 とし、stderr にのみ記録する。

try {
    $stdin = ''
    if ([Console]::IsInputRedirected) {
        try { $stdin = [Console]::In.ReadToEnd() } catch { $stdin = '' }
    }
    $source = 'unknown'; $sessionId = ''; $transcript = ''
    if ($stdin -match '"source"\s*:\s*"([a-zA-Z]+)"') { $source = $Matches[1] }
    if ($stdin -match '"session_id"\s*:\s*"([^"]+)"') { $sessionId = $Matches[1] }
    if ($stdin -match '"transcript_path"\s*:\s*"([^"]+)"') { $transcript = $Matches[1] -replace '\\\\', '\' }

    $stateRoot   = '.resume'
    $pendingFile = Join-Path $stateRoot 'pending.json'
    $disabled    = Test-Path -LiteralPath (Join-Path $stateRoot 'disabled')
    $cli         = '.claude/scripts/resume-watch.ps1'

    # --- 1. 未回収の再開通知をコンテキストへ注入する
    $lines = @()
    if (Test-Path -LiteralPath $pendingFile) {
        $p = $null
        try { $p = Get-Content -Raw -LiteralPath $pendingFile -Encoding UTF8 | ConvertFrom-Json } catch {}
        if ($p) {
            $lines += ('セッションリミット（{0}）で中断した作業があります。リミットは {1} に解除済みです。' -f $p.rateLimitType, $p.resetsAtLocal)
            if ($p.intent) {
                $lines += '中断前にユーザーが出していた指示は次のとおりです:'
                $lines += '---'
                $lines += [string]$p.intent
                $lines += '---'
            }
            if ($p.headless) {
                $lines += ('この中断に対しては無人 headless セッションでの再開を既に起動しています。その出力は .resume/headless/ に残っているため、重複作業を避けるため先に最新のログを確認してください。')
            }
            if ($source -eq 'resume') {
                $lines += 'このセッションには中断前の会話履歴があります。上の指示の続きから作業を再開してください。'
            } else {
                $lines += 'このセッションに中断前の会話履歴はありません。上の指示を起点に、関係するファイルを読み直してから再開してください。'
            }
            $lines += '再開した内容をユーザーへ報告したら powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/resume-watch.ps1 claim を実行してください（この通知が毎回繰り返されるのを防ぎます）。回収済みにするのは報告した後です。'
            $lines += 'ユーザーが最初のメッセージで別の作業を指示している場合は、そちらを優先し、中断した作業がある事実だけを 1 行で伝えてください。'
        }
    }

    # --- 2. ウォッチャーを起動する（無人再開で起動した子セッションでは起動しない）
    if (-not $disabled -and $env:CLAUDE_AUTO_RESUME -ne '1' -and $sessionId -and $transcript -and (Test-Path -LiteralPath $cli)) {
        try {
            $cliArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $cli, 'start',
                         '-SessionId', $sessionId, '-TranscriptPath', $transcript)
            Start-Process -FilePath 'powershell.exe' -ArgumentList $cliArgs -WindowStyle Hidden | Out-Null
        } catch {
            [Console]::Error.WriteLine("session-resume-check.ps1 watcher start failed: $_")
        }
    }

    if ($lines.Count -eq 0) { exit 0 }

    $msg = [string]::Join("`n", $lines)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
    exit 0
} catch {
    [Console]::Error.WriteLine("session-resume-check.ps1 error: $_")
    exit 0
}
