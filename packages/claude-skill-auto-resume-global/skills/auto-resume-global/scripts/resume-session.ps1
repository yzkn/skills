<#
.SYNOPSIS
  止まったセッションを、新しいターミナルのウィンドウで続きから再開する (auto-resume.ps1 が起動する)。
.DESCRIPTION
  - --fork-session で新しいセッション ID に分けて再開する (止まったときのウィンドウが開いたままでも、同じ記録に二重に書き込まない)。
    分岐先の ID は auto-resume.ps1 が決めて -NewSessionId で渡す (--session-id)。
  - --remote-control <名前> で Remote Control を有効にして起動する (config.json の remoteControl。既定 true)。
    再開すると別のセッションになり、元のセッションのリモート接続は切れるため、スマートフォンから接続し直せるようにする。
  - 再開した claude が終わるまで、PC がスリープしないようにする (PowerCreateRequest の要求と SetThreadExecutionState)
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

# スリープさせない要求 (PowerCreateRequest / PowerSetRequest(PowerRequestSystemRequired))。auto-resume.ps1 と同じもの。
# 要求はプロセスが持つハンドルに付き、スレッドに依らない。SetThreadExecutionState も併せて使う。どちらも claude が終われば解く
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ClaudeAutoResume {
    public static class Power {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct REASON_CONTEXT {
            public uint Version;
            public uint Flags;
            [MarshalAs(UnmanagedType.LPWStr)] public string SimpleReasonString;
        }
        [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr PowerCreateRequest(ref REASON_CONTEXT context);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerSetRequest(IntPtr handle, int requestType);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool PowerClearRequest(IntPtr handle, int requestType);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
        // PowerRequestSystemRequired (1) の要求を作って有効にする。できなければ IntPtr.Zero
        public static IntPtr Request(string reason) {
            REASON_CONTEXT c = new REASON_CONTEXT();
            c.Version = 0;   // POWER_REQUEST_CONTEXT_VERSION
            c.Flags = 1;     // POWER_REQUEST_CONTEXT_SIMPLE_STRING
            c.SimpleReasonString = reason;
            IntPtr h = PowerCreateRequest(ref c);
            if (h == IntPtr.Zero || h == new IntPtr(-1)) return IntPtr.Zero;
            if (!PowerSetRequest(h, 1)) { CloseHandle(h); return IntPtr.Zero; }
            return h;
        }
        public static void Release(IntPtr h) {
            if (h == IntPtr.Zero) return;
            PowerClearRequest(h, 1);
            CloseHandle(h);
        }
    }
}
'@
$powerRequest = [ClaudeAutoResume.Power]::Request("Claude Code の自動再開: 再開したセッション ($SessionId) が動いている")
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
# Remote Control を有効にして起動する (/remote-control と同じ)。再開すると別のセッションになり、
# 元のセッションのリモート接続は切れるので、スマートフォンなどから新しいセッションへ接続し直せるようにする。
# --remote-control の名前は省略できる引数なので、後ろの指示を名前と取り違えないよう、常に名前を渡す
if (-not $cfg.PSObject.Properties['remoteControl'] -or $cfg.remoteControl) {
    $rcName = if ($cfg.PSObject.Properties['remoteControlName'] -and $cfg.remoteControlName) { [string]$cfg.remoteControlName } else {
        $kind = if ($Reason -eq 'reboot') { '再起動後の再開' } else { '上限後の再開' }
        "$(Split-Path -Leaf $Cwd) ($kind $(Get-Date -Format 'MM/dd HH:mm'))"
    }
    $claudeArgs += @('--remote-control', $rcName)
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
    [ClaudeAutoResume.Power]::Release($powerRequest)
    [ClaudeAutoResume.Power]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null   # スリープ抑止を解除
}
