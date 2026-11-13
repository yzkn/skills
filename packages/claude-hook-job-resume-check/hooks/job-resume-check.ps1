# job-resume-check.ps1 — SessionStart フック: 未回収の long-run ジョブを検知して再開を促す
#
# .jobs/ 配下で「完了マーカー exit.code があり、回収済みマーカー collected が無い」ジョブを
# 列挙し、1 件以上ある場合にだけ再開の指示を stdout へ出力する（stdout はセッションの
# コンテキストへ注入される）。該当が無ければ何も出力しない。
#
# セッションリミット（429）で中断した作業を、ユーザーが「続けてください」と打たなくても
# 再開できるようにするための機構。Claude Code を起動したまま待機する場合は /long-run が
# 登録する cron が拾い、閉じて開き直した場合はこのフックが拾う（両者は独立・冗長）。
#
# 発火する source: startup / resume（--continue も resume）で実測済み。clear / compact は
# 未実測だが、未回収ジョブが無ければ出力しないため実害はない。
# fail-open 設計: フック自体の障害時は exit 0 とし、stderr にのみ記録する。

try {
    # stdin には SessionStart の JSON（session_id / transcript_path / cwd / source）が渡る。
    # リダイレクトされていない手動実行でブロックしないよう、渡されている場合だけ読む。
    $stdin = ''
    if ([Console]::IsInputRedirected) {
        try { $stdin = [Console]::In.ReadToEnd() } catch { $stdin = '' }
    }
    $source = 'unknown'
    if ($stdin -match '"source"\s*:\s*"([a-zA-Z]+)"') { $source = $Matches[1] }

    $root = '.jobs'
    if (-not (Test-Path -LiteralPath $root)) { exit 0 }

    $pending = @()
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
        $exitFile = Join-Path $d.FullName 'exit.code'
        $claimed  = Join-Path $d.FullName 'collected'
        if ((Test-Path -LiteralPath $exitFile) -and (-not (Test-Path -LiteralPath $claimed))) {
            $code = '?'
            try { $code = (Get-Content -Raw -LiteralPath $exitFile).Trim() } catch {}
            $pending += ('{0} (exit={1})' -f $d.Name, $code)
        }
    }
    if ($pending.Count -eq 0) { exit 0 }

    $lines = @()
    $lines += ('未回収の long-run ジョブが {0} 件あります（処理は完了しているが、結果をまだユーザーへ報告していないジョブ）:' -f $pending.Count)
    foreach ($p in $pending) { $lines += ('  - .jobs/' + $p) }
    if ($source -eq 'resume') {
        $lines += 'このセッションには中断前の会話履歴があります。中断していた作業の続きとして、各ジョブの check.ps1 で状態を確認し、成果物を集計してユーザーへ報告してください。'
    } else {
        $lines += 'このセッションに中断前の会話履歴はありません。各ジョブの resume-intent.md（ジョブ完了後にやること）と README.md を先に読み、check.ps1 で状態を確認してから、成果物を集計してユーザーへ報告してください。'
    }
    $lines += '報告が済んだジョブは powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/long-run.ps1 claim -Id <ジョブID> で回収済みにしてください（この通知が毎回繰り返されるのを防ぎます）。回収済みにするのは報告した後です。'
    $lines += 'ユーザーが最初のメッセージで別の作業を指示している場合は、そちらを優先し、未回収ジョブがある事実だけを 1 行で伝えてください。'

    $msg = [string]::Join("`n", $lines)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
    exit 0
} catch {
    [Console]::Error.WriteLine("job-resume-check.ps1 error: $_")
    exit 0
}
