# _resume-watcher.ps1 — セッションリミット(429)の常駐ウォッチャー本体（detach 起動される）
#
# 役割は 3 つ。
#   1. 自セッションのトランスクリプト .jsonl を追尾し、quotaLimits.status = "rejected" を検出する
#   2. 検出したら解除時刻 resetsAt を state.json へ記録し、中断された指示を intent.md へ写し取り、
#      W2（タスクスケジューラのワンショットタスク）を登録する
#   3. 自分でも解除時刻まで待ち（W1）、到達したら resume-watch.ps1 fire を呼ぶ
#
# W1 と W2 はどちらが先に到達しても構わない（fire 側が排他ロックで二重発火を防ぐ）。
#
# 検出は「行を JSON として解釈し、トップレベルに quotaLimits があるか」で判定する。
# 文字列一致だけで判定すると、会話の中に 429 レコードの文字列が引用されたときに誤検出する
# （実際に本リポジトリの調査ログがトランスクリプトへ埋め込まれた）。
#
# 直接呼び出さず、resume-watch.ps1 start から起動する。

param(
    [Parameter(Mandatory = $true)][string]$SessionId,
    [Parameter(Mandatory = $true)][string]$TranscriptPath,
    [int]$MaxIdleMinutes = 90,
    [int]$PollSeconds = 15
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateRoot  = Join-Path $RepoRoot '.resume'
$LogFile    = Join-Path $StateRoot 'watch.log'
$StateFile  = Join-Path $StateRoot 'state.json'
$IntentFile = Join-Path $StateRoot 'intent.md'
$StopFile   = Join-Path $StateRoot 'stop'
$PidFile    = Join-Path $StateRoot ('watchers\' + $SessionId + '.pid')
$Cli        = Join-Path $PSScriptRoot 'resume-watch.ps1'

function Write-Log([string]$Message) {
    try {
        $line = '{0} [{1}] watcher: {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $PID, $Message
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    } catch {}
}

function Invoke-Cli([string[]]$CliArgs) {
    try {
        $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Cli) + $CliArgs
        $result = & 'powershell.exe' $all 2>&1
        foreach ($r in $result) { Write-Log ('cli> ' + $r) }
    } catch { Write-Log ('cli 実行に失敗: ' + $_.Exception.Message) }
}

# ファイル末尾から新規バイトだけを読む（Claude Code が書き込み中でも共有読み取りする）
function Read-Delta([string]$Path, [long]$Offset, [ref]$NewOffset) {
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($Offset -gt $fs.Length) { $Offset = 0 }
        $len = $fs.Length - $Offset
        if ($len -le 0) { $NewOffset.Value = $Offset; return '' }
        if ($len -gt 8MB) { $Offset = $fs.Length - 8MB; $len = 8MB }  # 初回など巨大な差分は末尾のみ
        [void]$fs.Seek($Offset, [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] $len
        $read = $fs.Read($buf, 0, $buf.Length)
        $NewOffset.Value = $Offset + $read
        return [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
    } catch {
        $NewOffset.Value = $Offset
        return ''
    } finally { if ($fs) { $fs.Dispose() } }
}

# 中断された指示（最後のユーザー発話）を取り出す
function Get-LastUserPrompt([string]$Path) {
    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        $take = [Math]::Min([long]$fi.Length, 512KB)
        $off = $fi.Length - $take
        $dummy = [long]0
        $text = Read-Delta $Path $off ([ref]$dummy)
        $lines = $text -split "`n"
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            $l = $lines[$i].Trim()
            if (-not $l.StartsWith('{')) { continue }
            if ($l -notmatch '"type"\s*:\s*"user"') { continue }
            $o = $null
            try { $o = ConvertFrom-Json $l } catch { continue }
            if (-not $o -or $o.type -ne 'user' -or $o.isMeta) { continue }
            $content = $o.message.content
            $s = $null
            if ($content -is [string]) { $s = $content }
            elseif ($content) {
                foreach ($block in $content) {
                    if ($block.type -eq 'text' -and $block.text) { $s = [string]$block.text; break }
                }
            }
            if (-not $s) { continue }
            $s = $s.Trim()
            # フックやシステムが注入した擬似ユーザー発話は除外する
            if ($s.StartsWith('<')) { continue }
            if ($s.Length -gt 1200) { $s = $s.Substring(0, 1200) + ' …（以下略）' }
            return $s
        }
    } catch { Write-Log ('中断前の指示の抽出に失敗: ' + $_.Exception.Message) }
    return $null
}

$StartedAt = Get-Date

function Test-StopRequested {
    if (Test-Path -LiteralPath $StopFile) { return $true }
    # pid ファイルが消えている＝ stop 済みとみなす。ただし pid ファイルは Start-Process の
    # 直後に親が書くため、起動直後は「まだ書かれていない」状態と区別がつかない。
    # 60 秒の猶予を置き、自分自身を即座に終了させてしまう競合を避ける。
    if (((Get-Date) - $StartedAt).TotalSeconds -gt 60 -and -not (Test-Path -LiteralPath $PidFile)) { return $true }
    return $false
}

function Invoke-Detected([long]$ResetsAt, [string]$LimitType) {
    $local = [System.DateTimeOffset]::FromUnixTimeSeconds($ResetsAt).ToLocalTime().DateTime
    Write-Log ('429 を検出: resetsAt={0} ({1}) type={2}' -f $ResetsAt, $local.ToString('yyyy-MM-dd HH:mm:ss'), $LimitType)

    [ordered]@{
        sessionId      = $SessionId
        resetsAt       = $ResetsAt
        resetsAtLocal  = $local.ToString('yyyy-MM-dd HH:mm:ss')
        rateLimitType  = $LimitType
        detectedAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        transcriptPath = $TranscriptPath
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StateFile -Encoding UTF8

    # 明示的な intent が無ければ、中断前の指示を写し取る
    if (-not (Test-Path -LiteralPath $IntentFile)) {
        $prompt = Get-LastUserPrompt $TranscriptPath
        if ($prompt) {
            Set-Content -LiteralPath $IntentFile -Value $prompt -Encoding UTF8
            Write-Log '中断前の指示を intent.md へ記録した'
        } else {
            Write-Log '中断前の指示を抽出できなかった（intent なしで続行）'
        }
    }

    # W2: 解除時刻にワンショットタスクを起動する
    Invoke-Cli @('arm', '-ResetsAt', "$ResetsAt", '-SessionId', $SessionId)

    # W1: 自分でも待つ
    while ($true) {
        if (Test-StopRequested) { Write-Log '待機中に stop を検出したため終了'; return $false }
        if ((Get-Date) -ge $local) { break }
        Start-Sleep -Seconds 30
    }
    Invoke-Cli @('fire', '-ResetsAt', "$ResetsAt", '-SessionId', $SessionId)
    return $true
}

# ------------------------------------------------------------------ メインループ

Write-Log ('起動 session={0} transcript={1}' -f $SessionId, $TranscriptPath)

$offset = 0
$carry = ''
$lastChange = Get-Date
$handledResetsAt = 0
$initialized = $false

try {
    while ($true) {
        if (Test-StopRequested) { Write-Log 'stop を検出したため終了'; break }

        if (Test-Path -LiteralPath $TranscriptPath) {
            if (-not $initialized) {
                # 起動時点の内容は既読扱いにする（過去の 429 を掘り返さない）
                try { $offset = (Get-Item -LiteralPath $TranscriptPath).Length } catch { $offset = 0 }
                $initialized = $true
                Write-Log ('追尾開始 offset={0}' -f $offset)
            }

            $newOffset = $offset
            $delta = Read-Delta $TranscriptPath $offset ([ref]$newOffset)
            if ($newOffset -ne $offset) {
                $offset = $newOffset
                $lastChange = Get-Date
                $buffer = $carry + $delta
                $lines = $buffer -split "`n"
                $carry = $lines[$lines.Count - 1]   # 最終行は途中かもしれないので持ち越す

                for ($i = 0; $i -lt $lines.Count - 1; $i++) {
                    $line = $lines[$i].Trim()
                    if ($line.Length -lt 2) { continue }
                    if ($line -notmatch '"quotaLimits"') { continue }
                    $o = $null
                    try { $o = ConvertFrom-Json $line } catch { continue }
                    if (-not $o -or -not $o.quotaLimits) { continue }
                    if ($o.quotaLimits.status -ne 'rejected') { continue }
                    $resets = 0
                    try { $resets = [long]$o.quotaLimits.resetsAt } catch { $resets = 0 }
                    if ($resets -le 0 -or $resets -eq $handledResetsAt) { continue }
                    $handledResetsAt = $resets
                    $type = if ($o.quotaLimits.rateLimitType) { [string]$o.quotaLimits.rateLimitType } else { 'unknown' }
                    [void](Invoke-Detected $resets $type)
                    $lastChange = Get-Date
                }
            }
        }

        if (((Get-Date) - $lastChange).TotalMinutes -ge $MaxIdleMinutes) {
            Write-Log ('{0} 分間トランスクリプトの更新が無いため終了' -f $MaxIdleMinutes)
            break
        }
        Start-Sleep -Seconds $PollSeconds
    }
} catch {
    Write-Log ('異常終了: ' + $_.Exception.Message)
} finally {
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Log '終了'
}
