# japanese-guard.ps1
# Stop hook から呼び出される日本語応答ガード。
# そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら
# {"decision":"block","reason":...} を返し、終了させずに日本語で書き直させる。
#
# 出典: minorun365/claude-code-japanese-guard（Apache License 2.0）
#   Copyright 2026 Minoru Onda
#   hooks/japanese-guard.py の判定ロジックを PowerShell へ移植し、以下を変更した。
#   - トランスクリプトを末尾から読み、今回のターンの行だけを JSON 解析する（大きな .jsonl で遅くならないように）
#   - 障害時は fail-open（何も出力せず exit 0）とし、trace ログにだけ理由を残す
#   ライセンス全文: https://www.apache.org/licenses/LICENSE-2.0
#
# 判定: コードブロック・インラインコード・URL・メールアドレス・Markdown リンクを除いたうえで、
#   英字が MIN_LATIN 字以上、かつ 英字数 > 日本語字数 × RATIO なら英語主体とみなす。
# 差し戻しは 1 ターン 1 回だけ（stop_hook_active が true なら通す）。無限ループを防ぐため。
# 閾値は環境変数 JAPANESE_GUARD_MIN_LATIN / JAPANESE_GUARD_RATIO / JAPANESE_GUARD_WAIT で変えられる。

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$traceLog = Join-Path $repoRoot "doc\log\error\japanese-guard-trace.log"
function Write-Trace([string]$msg) {
    [Console]::Error.WriteLine("japanese-guard: $msg")
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::AppendAllText($traceLog,
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" + [System.Environment]::NewLine, $utf8NoBom)
    } catch { }
}

function Get-EnvNumber([string]$name, [double]$default) {
    $v = [Environment]::GetEnvironmentVariable($name)
    $n = 0.0
    if ($v -and [double]::TryParse($v, [ref]$n)) { return $n }
    return $default
}

$MinLatin    = Get-EnvNumber 'JAPANESE_GUARD_MIN_LATIN' 25
$Ratio       = Get-EnvNumber 'JAPANESE_GUARD_RATIO' 3
$WaitSeconds = Get-EnvNumber 'JAPANESE_GUARD_WAIT' 3

$JaPattern    = '[ぁ-んァ-ヶ一-龥]'
$LatinPattern = '[A-Za-z]'
$IgnorePatterns = @(
    '(?s)```.*?```',
    '`[^`\n]*`',
    'https?://\S+',
    '[\w.+-]+@[\w-]+\.[\w.-]+',
    '\[[^\]]*\]\([^)]*\)'
)

function Test-English([string]$text) {
    foreach ($p in $IgnorePatterns) { $text = [regex]::Replace($text, $p, '') }
    $latin = [regex]::Matches($text, $LatinPattern).Count
    $ja    = [regex]::Matches($text, $JaPattern).Count
    return ($latin -ge $MinLatin -and $latin -gt $ja * $Ratio)
}

# ユーザーが入力した発言か（ツール結果・メタ情報の user エントリを除く）
function Test-UserTurn($entry) {
    if ($entry.type -ne 'user' -or $entry.isMeta -eq $true) { return $false }
    $content = $entry.message.content
    if ($content -is [string]) { return $true }
    if ($null -eq $content) { return $false }
    foreach ($c in @($content)) { if ($c.type -eq 'tool_result') { return $false } }
    return $true
}

# 今回のターン（最後のユーザー発言より後）のエントリを古い順で返す。
# 末尾から 1 行ずつ解析し、ユーザー発言に当たったら止める。
function Get-TurnEntries([string]$path) {
    $lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
    $turn = New-Object System.Collections.ArrayList
    for ($i = $lines.Length - 1; $i -ge 0; $i--) {
        if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
        try { $e = $lines[$i] | ConvertFrom-Json } catch { continue }
        if (Test-UserTurn $e) { break }
        [void]$turn.Insert(0, $e)
    }
    return ,$turn
}

# このターンの最新エントリが assistant の本文で終わっているか
function Test-EndedInText($turn) {
    for ($i = $turn.Count - 1; $i -ge 0; $i--) {
        $e = $turn[$i]
        if ($e.type -eq 'assistant') {
            $blocks = @($e.message.content)
            if ($blocks.Count -eq 0) { return $false }
            return ($blocks[$blocks.Count - 1].type -eq 'text')
        }
        if ($e.type -eq 'user') { return $false }  # ツール結果が最後 = 最終回答がまだ書き込まれていない
    }
    return $false
}

# Stop hook は最終回答が .jsonl へ書き込まれる前に呼ばれることがあるため、最大 WaitSeconds 秒待つ
function Wait-FinalAnswer([string]$path) {
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    $turn = Get-TurnEntries $path
    while (-not (Test-EndedInText $turn) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        $turn = Get-TurnEntries $path
    }
    return ,$turn
}

# 最終回答 = 最後のツール呼び出しより後の本文。tool_use が出るたびに集め直す
function Get-EnglishPassages($turn) {
    $final = New-Object System.Collections.ArrayList
    foreach ($e in $turn) {
        if ($e.type -ne 'assistant') { continue }
        foreach ($b in @($e.message.content)) {
            if ($b.type -eq 'tool_use') { $final.Clear() }
            elseif ($b.type -eq 'text') { [void]$final.Add([string]$b.text) }
        }
    }
    $hits = @()
    foreach ($t in $final) {
        if (Test-English $t) {
            $first = ($t.Trim() -split "`r?`n")[0]
            if ($first.Length -gt 80) { $first = $first.Substring(0, 80) }
            $hits += $first
        }
    }
    return ,$hits
}

try {
    $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $hookInput = $raw | ConvertFrom-Json

    if ($hookInput.stop_hook_active -eq $true) { exit 0 }
    $path = $hookInput.transcript_path
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { exit 0 }

    $hits = Get-EnglishPassages (Wait-FinalAnswer $path)
    if ($hits.Count -eq 0) { exit 0 }

    $quoted = (@($hits | Select-Object -First 5) | ForEach-Object { "- $_" }) -join "`n"
    $reason = "このターンの本文に、英語で書いた箇所があります。`n$quoted`n" +
        "ユーザーは日本語での応答を求めています。上に挙げた英語の箇所だけを、日本語に書き直して出してください。" +
        "日本語で書けていた部分は、すでにユーザーに届いているので再掲しないこと。" +
        "言い訳や原因の説明は書かず、以降の応答もすべて日本語で書くこと。"

    # リダイレクト時もコンソールコードページの影響を受けないよう UTF-8 バイトを直接書く（safety-net.ps1 と同じ）
    $json  = @{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $out   = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
    Write-Trace "BLOCK: 英語主体の本文 $($hits.Count) 件"
    exit 0
} catch {
    Write-Trace "FAIL-OPEN: $($_.Exception.Message)"
    exit 0
}
