<#
.SYNOPSIS
  止まったセッションを、新しいターミナルのウィンドウで続きから再開する (auto-resume.ps1 が起動する)。
.DESCRIPTION
  - --fork-session で新しいセッション ID に分けて再開する (止まったときのウィンドウが開いたままでも、同じ記録に二重に書き込まない)。
    分岐先の ID は auto-resume.ps1 が決めて -NewSessionId で渡す (--session-id)。
  - 再開した claude が終わるまで、PC がスリープしないようにする (SetThreadExecutionState)
  - 動いている間は state/running/<分岐先の ID>.json を置き、claude が終われば消す。
    PC の再起動 (Windows Update など) で claude ごと終わると、この印が残る。auto-resume.ps1 は、次の起動 (ログオン時) に
    「印が残っていて、印より後に OS が起動した」セッションを、作業の途中で中断したものとして、もう一度再開する。
.PARAMETER Reason
  limit: 利用上限の解除後の再開 (resumePrompt) / reboot: 再起動で中断したものの再開 (rebootResumePrompt)
#>
param(
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$Cwd,
    [string]$Mode = 'auto',
    [string]$NewSessionId,
    [ValidateSet('limit', 'reboot')][string]$Reason = 'limit',
    [int]$Attempt = 1
)
$ErrorActionPreference = 'Stop'

# Claude Code の中から起動された場合 (フック経由・手動) に引き継いだ、親セッションの環境変数を外す。
# CLAUDE_CODE_CHILD_SESSION が残っていると、再開した claude は子セッションとみなされて記録 (jsonl) を保存しない
# (そうなると、また上限・再起動で止まっても再開できない)
foreach ($n in @('CLAUDECODE', 'CLAUDE_PID', 'CLAUDE_CODE_CHILD_SESSION', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_BRIDGE_SESSION_ID',
        'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_CODE_MESSAGING_TOKEN', 'CLAUDE_CODE_SESSION_ATTENDED', 'CLAUDE_CODE_ENTRYPOINT')) {
    Remove-Item -LiteralPath "Env:$n" -ErrorAction SilentlyContinue
}

$cfg = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Type -Namespace ClaudeAutoResume -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
[ClaudeAutoResume.Power]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

Set-Location -LiteralPath $Cwd
$Host.UI.RawUI.WindowTitle = "Claude 再開 $SessionId"
if ($Reason -eq 'reboot') {
    Write-Host "PC の再起動で中断したセッション $SessionId を続きから再開します (mode=$Mode)" -ForegroundColor Cyan
} else {
    Write-Host "利用上限が解除されたため、セッション $SessionId を続きから再開します (mode=$Mode)" -ForegroundColor Cyan
    Write-Host "元のウィンドウが開いたままなら閉じてください (このウィンドウは分岐した新しいセッションです)" -ForegroundColor DarkGray
}

$prompt = $cfg.resumePrompt
if ($Reason -eq 'reboot') {
    $prompt = if ($cfg.PSObject.Properties['rebootResumePrompt'] -and $cfg.rebootResumePrompt) { $cfg.rebootResumePrompt } else {
        'PC の再起動 (Windows Update など) で、作業の途中で中断していました。中断する直前の作業を、中断したところから続けてください。最初に、中断時点で何をしていたかを 1〜2 文で述べてから再開してください。'
    }
}

$claudeArgs = @('--resume', $SessionId)
$runningId = $SessionId
if ($cfg.forkSession) {
    $claudeArgs += '--fork-session'
    if ($NewSessionId) { $claudeArgs += @('--session-id', $NewSessionId); $runningId = $NewSessionId }
    else { $runningId = $null }   # 分岐先の ID が分からないので、再起動からの再開は扱えない
}
$claudeArgs += @('--permission-mode', $Mode, $prompt)

# 動いている印 (再起動で中断したかを、auto-resume.ps1 が次の起動で判断する)
$marker = $null
if ($runningId) {
    $runDir = Join-Path $PSScriptRoot 'state\running'
    if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }
    $marker = Join-Path $runDir "$runningId.json"
    $info = [ordered]@{
        sessionId = $runningId; parentSessionId = $SessionId; cwd = $Cwd; mode = $Mode
        reason = $Reason; attempt = $Attempt; startedAt = (Get-Date).ToString('o'); pid = $PID
    }
    [IO.File]::WriteAllText($marker, ($info | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
}
try {
    & $cfg.claudePath @claudeArgs
}
finally {
    # 正常に終わった (利用者が閉じた・終了した) ときだけ消える。再起動で強制終了されたときは残る
    if ($marker -and (Test-Path $marker)) { Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue }
    [ClaudeAutoResume.Power]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null   # スリープ抑止を解除
}
