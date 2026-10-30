# auto-record.ps1
# Stop hookから呼び出される自動記録スクリプト。
# 各会話ターン終了時に ./doc/prompt/ へ基本的な記録を残す。
# 思考過程の詳細記録は /record スキルを手動で呼び出すこと。

param()

# 診断ログ: $cwd 確定前でも書ける固定パス（$PSScriptRoot = <repo>\.claude\hooks）
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$traceLog = Join-Path $repoRoot "doc\log\error\auto-record-trace.log"
function Write-Trace([string]$msg) {
    [Console]::Error.WriteLine("auto-record: $msg")
    try {
        $dir = Split-Path $traceLog -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::AppendAllText($traceLog,
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" + [System.Environment]::NewLine, $utf8NoBom)
    } catch { }
}

# stdin はコンソールコードページ（cp932 等）ではなく UTF-8 で明示的に読む。
# [Console]::In だと cwd / transcript_path に非 ASCII を含む場合に JSON が壊れて
# 解析失敗 → 無言終了する（safety-net.ps1 と同じ理由・同じ実装）。
$reader       = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
$stdinContent = $reader.ReadToEnd()

if ([string]::IsNullOrWhiteSpace($stdinContent)) {
    Write-Trace "SKIP: stdin が空"
    exit 0
}

try {
    $hookInput = $stdinContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Trace "SKIP: stdin JSON 解析失敗 len=$($stdinContent.Length) msg=$($_.Exception.Message)"
    exit 0
}

# stop_hook_active=true は、別の Stop フック（japanese-guard.ps1）の差し戻し後の停止を表す。
# 本スクリプトは block を返さないため再帰は起きない。書き直した回答を証跡に残すため、スキップせず記録する。
if ($hookInput.stop_hook_active -eq $true) {
    Write-Trace "INFO: stop_hook_active=true（差し戻し後の停止を記録する）"
}

$sessionId      = $hookInput.session_id
$transcriptPath = $hookInput.transcript_path
$cwd            = if ($hookInput.cwd) { $hookInput.cwd } else { (Get-Location).Path }

$errorLogDir = Join-Path $cwd "doc\log\error"
$debugLog    = Join-Path $errorLogDir "auto-record-error.log"

# スクリプト全体を包むtry/catchで、いかなる例外でもファイルを生成する
try {

if (-not (Test-Path $errorLogDir)) {
    New-Item -ItemType Directory -Path $errorLogDir -Force | Out-Null
}

# ./doc/prompt/ ディレクトリを作成
$docsDir = Join-Path $cwd "doc\prompt"
if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
}

$userContent     = "(取得不可)"
$conversationLog = "(取得不可)"
$scriptError     = $null

if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $lines    = Get-Content -Path $transcriptPath -Encoding UTF8 -ErrorAction Stop
        $messages = @()

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $msg = $line | ConvertFrom-Json -ErrorAction Stop
                # type:"user" / type:"assistant" かつ message プロパティを持つものだけ収集
                if ($msg.type -in @('user', 'assistant') -and $null -ne $msg.message) {
                    $messages += $msg
                }
            } catch { continue }
        }

        # user メッセージの本文。content の形は起動経路で異なる: VS Code 拡張は text ブロックの配列、
        # CLI（claude / claude -p）は文字列で記録する。配列だけを想定すると CLI では発言が見つからず、
        # 全記録が「(取得不可)」になる（2026-10-20 に判明。7 月から潜在していた）。
        # 配列の場合は ide タグ等を含むすべての text ブロックを結合する。
        function Get-UserText($entry) {
            $c = $entry.message.content
            if ($c -is [string]) { return $c }
            return (@($c | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n")
        }

        # 最後の「実際のユーザー発言」のインデックスを探す（japanese-guard.ps1 の Test-UserTurn と同じ基準）。
        # ツール呼び出し結果も type:"user" で届くが、content が tool_result のみなので本文が空になり除外される。
        # isMeta（スキル起動時に差し込まれる本文・サブエージェントの報告等）と
        # queueTranscriptOnly（タスク完了通知等）はシステムが差し込んだものなので発言として扱わない。
        $lastUserIndex = -1
        for ($i = $messages.Count - 1; $i -ge 0; $i--) {
            $m = $messages[$i]
            if ($m.type -ne 'user' -or $m.isMeta -eq $true -or $m.queueTranscriptOnly -eq $true) { continue }
            if (-not [string]::IsNullOrWhiteSpace((Get-UserText $m))) {
                $lastUserIndex = $i
                break
            }
        }

        if ($lastUserIndex -ge 0) {
            $lastUserMsg = $messages[$lastUserIndex]

            $userContent = Get-UserText $lastUserMsg
            if ([string]::IsNullOrWhiteSpace($userContent)) { $userContent = "(取得不可)" }

            # そのユーザー発言以降の全メッセージ（1:複数の応答・ツール呼び出し・ツール結果）を収集してログ化
            $sb            = New-Object System.Text.StringBuilder
            $responseCount = 0

            for ($i = $lastUserIndex + 1; $i -lt $messages.Count; $i++) {
                $msg = $messages[$i]

                if ($msg.type -eq 'assistant') {
                    $textBlocks    = @($msg.message.content | Where-Object { $_.type -eq 'text' })
                    $toolUseBlocks = @($msg.message.content | Where-Object { $_.type -eq 'tool_use' })

                    # アシスタントのテキスト応答（thinking のみのエントリはスキップ）
                    if ($textBlocks.Count -gt 0) {
                        $responseCount++
                        [void]$sb.AppendLine("")
                        [void]$sb.AppendLine("### 応答 $responseCount")
                        [void]$sb.AppendLine("")
                        foreach ($blk in $textBlocks) {
                            [void]$sb.AppendLine($blk.text)
                        }
                    }

                    # ツール呼び出し（入力を 200 文字に要約）
                    foreach ($tool in $toolUseBlocks) {
                        $inputSummary = ""
                        if ($null -ne $tool.input) {
                            try {
                                $inputJson = $tool.input | ConvertTo-Json -Compress -Depth 2 -ErrorAction Stop
                                $inputSummary = ": " + $inputJson
                                if ($inputSummary.Length -gt 200) {
                                    $inputSummary = $inputSummary.Substring(0, 200) + "..."
                                }
                            } catch {
                                $inputSummary = ": (シリアライズ失敗)"
                            }
                        }
                        [void]$sb.AppendLine("")
                        [void]$sb.AppendLine("> **ツール呼び出し:** $($tool.name)$inputSummary")
                    }

                } elseif ($msg.type -eq 'user') {
                    # ツール実行結果（ツール呼び出しへの返値として type:"user" で届く）
                    $toolResults = @($msg.message.content | Where-Object { $_.type -eq 'tool_result' })
                    foreach ($result in $toolResults) {
                        $resultText = ""
                        if ($result.content -is [string]) {
                            $resultText = $result.content
                        } elseif ($result.content -is [System.Array]) {
                            $resultText = ($result.content |
                                Where-Object { $_.type -eq 'text' } |
                                ForEach-Object { $_.text }) -join "`n"
                        }
                        # 長大なツール結果は 400 文字で切り捨て（1 記録あたりのファイルサイズを抑える。
                        # 全文はセッションのトランスクリプト .jsonl に残る）
                        if ($resultText.Length -gt 400) {
                            $resultText = $resultText.Substring(0, 400) + "`n...(省略: 全 $($resultText.Length) 文字)"
                        }
                        [void]$sb.AppendLine("")
                        [void]$sb.AppendLine("> **ツール結果:**")
                        foreach ($resultLine in ($resultText -split [System.Environment]::NewLine)) {
                            [void]$sb.AppendLine("> $resultLine")
                        }
                    }
                }
            }

            $conversationLog = $sb.ToString().Trim()
            if ([string]::IsNullOrWhiteSpace($conversationLog)) { $conversationLog = "(記録なし)" }

            # 1 記録あたりの上限（30,000 文字）。ツール呼び出しが極端に多いターンでも
            # doc/prompt/ が肥大化してリポジトリ検索を汚染しないようにする。全文は .jsonl に残る。
            $maxLogChars = 30000
            if ($conversationLog.Length -gt $maxLogChars) {
                $omitted = $conversationLog.Length - $maxLogChars
                $conversationLog = $conversationLog.Substring(0, $maxLogChars) +
                    "`n`n...(記録上限 $maxLogChars 文字を超えたため以降 $omitted 文字を省略。全文はトランスクリプト $transcriptPath を参照)"
            }
        }
    } catch {
        $scriptError = "エラー: $($_.Exception.Message) (行: $($_.InvocationInfo.ScriptLineNumber))"
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$date      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileName  = Join-Path $docsDir "${timestamp}_auto.proof.md"

# 同名ファイルが存在する場合はサフィックスを付けて回避（証跡の上書き防止）
$suffix = 2
while (Test-Path $fileName) {
    $fileName = Join-Path $docsDir "${timestamp}_auto_${suffix}.proof.md"
    $suffix++
}

$lines = @(
    "# 自動記録",
    "",
    "**日時:** $date",
    "**記録種別:** 自動（Stopフック）",
    "**セッションID:** $sessionId",
    "**トランスクリプト:** $transcriptPath"
)
if ($scriptError) {
    $lines += ""
    $lines += "## スクリプトエラー"
    $lines += ""
    $lines += $scriptError
}
$lines += ""
$lines += "## ユーザープロンプト"
$lines += ""
$lines += $userContent
$lines += ""
$lines += "## Claude Codeの応答"
$lines += ""
$lines += $conversationLog
$lines += ""
$lines += "---"
$lines += "*思考過程の詳細記録は ``/record`` スキルで行ってください。*"

$content = $lines -join [System.Environment]::NewLine

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($fileName, $content, $utf8NoBom)

# ファイル生成後に git add && git commit（失敗しても致命的エラーとしない）
# commit には必ずパス指定（-- $fileName）を付ける。省略するとインデックス全体をコミットし、
# フック起動前にステージされていた無関係な変更まで record: コミットに巻き込む
# （git-safety.md の自動コミット例外 1「対象ディレクトリ配下のみ」に反する。ADR-023）。
# パス指定時は他パスのステージはインデックスに残るため、ユーザーの作業を壊さない。
# merge / rebase 中は部分コミットが禁止され失敗するので、理由を trace に残して手動コミットできるようにする。
try {
    $shortPrompt = ($userContent -replace '[\r\n].*', '').Trim()
    if ($shortPrompt.Length -gt 60) { $shortPrompt = $shortPrompt.Substring(0, 60) }
    $commitMsg = "record: $shortPrompt"
    # add の失敗を握りつぶさない。握りつぶすと commit 側に
    # 「pathspec ... did not match any file(s) known to git」だけが残り、
    # 真因（index.lock 競合等）が追えなくなる（2026-09-03 に実際に発生。ADR-052）。
    $addOut = & git -C $cwd add $fileName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Trace "WARN: git add 失敗 (exit=$LASTEXITCODE): $($addOut -join ' / ')"
    } else {
        $commitOut = & git -C $cwd commit -m $commitMsg -- $fileName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Trace "WARN: 自動コミット失敗 (exit=$LASTEXITCODE): $($commitOut -join ' / ')"
        }
    }
} catch { }

} catch {
    # 最終手段: エラー情報をデバッグログに書き出す
    $errMsg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') FATAL: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)`n"
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::AppendAllText($debugLog, $errMsg, $utf8NoBom)
    } catch { }
    exit 1
}

exit 0
