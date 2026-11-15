#requires -Version 7.0
<#
.SYNOPSIS
  kick.ps1 が新しいウィンドウで起動する。指令リポジトリで claude を起動し、/auto-loop next を実行させる。
.DESCRIPTION
  - claude が動いている間は、PC をスリープさせない（終われば解く）
  - 動いている間は state/kick-running.json を置く（kick.ps1 が、二重に起こさないために見る）
  - セッションの記録が kick.idleCloseMinutes 分のあいだ書かれなければ、claude を終わらせる（0 なら終わらせない）。
    対話のセッションは自分では終わらないので、終わらせないと PC が眠れず、次の起動時・スリープ解除時にも起こせない。
    状態はタスクファイルにあるので、続きは次のセッションが読んで行う
  - claudePath などは auto-resume-global の config.json を使う（無ければ PATH の claude）
#>
param(
    [Parameter(Mandatory)][string]$SessionId,
    [ValidateSet('work', 'idle')][string]$Kind = 'work'
)
$ErrorActionPreference = 'Stop'

# Claude Code の中から起動された場合に引き継いだ、親セッションの環境変数を外す
# （CLAUDE_CODE_CHILD_SESSION が残っていると、子セッションとみなされて記録を保存しない）
foreach ($n in @('CLAUDECODE', 'CLAUDE_PID', 'CLAUDE_CODE_CHILD_SESSION', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_BRIDGE_SESSION_ID',
        'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_CODE_MESSAGING_TOKEN', 'CLAUDE_CODE_SESSION_ATTENDED', 'CLAUDE_CODE_ENTRYPOINT')) {
    Remove-Item -LiteralPath "Env:$n" -ErrorAction SilentlyContinue
}

Import-Module (Join-Path $PSScriptRoot 'lib/AutoLoop.psm1') -Force
$cfg = Get-LoopConfig
$kick = Get-KickConfig $cfg
$utf8 = [Text.UTF8Encoding]::new($false)
$repo = [string]$cfg.controlRepoPath
$arHome = if ($env:AUTO_LOOP_AUTO_RESUME_HOME) { $env:AUTO_LOOP_AUTO_RESUME_HOME } else { Join-Path $HOME '.claude/auto-resume-global' }
$projects = if ($env:AUTO_LOOP_CLAUDE_PROJECTS) { $env:AUTO_LOOP_CLAUDE_PROJECTS } else { Join-Path $HOME '.claude/projects' }
$arCfg = $null
try { $arCfg = [IO.File]::ReadAllText((Join-Path $arHome 'config.json'), $utf8) | ConvertFrom-Json } catch { }

$claude = ''
if ($arCfg -and $arCfg.PSObject.Properties['claudePath'] -and $arCfg.claudePath -and (Test-Path -LiteralPath $arCfg.claudePath)) { $claude = [string]$arCfg.claudePath }
else { $c = Get-Command claude -ErrorAction SilentlyContinue; if ($c) { $claude = $c.Source } }
if (-not $claude) { Write-LoopLog 'kick' 'claude が見つからない（auto-resume-global の claudePath も PATH も無い）'; Write-Host 'claude が見つかりません'; exit 1 }

# スリープさせない要求（プロセスが持つハンドルに付く。claude が終われば解く）
$power = [IntPtr]::Zero
if ($IsWindows) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AutoLoopKick {
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
        public static IntPtr Request(string reason) {
            REASON_CONTEXT c = new REASON_CONTEXT();
            c.Version = 0;
            c.Flags = 1;
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
    $power = [AutoLoopKick.Power]::Request("auto-loop: 起動時・スリープ解除時に起こしたセッション ($SessionId) が動いている")
    [AutoLoopKick.Power]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
}

Set-Location -LiteralPath $repo
$Host.UI.RawUI.WindowTitle = "auto-loop $Kind $SessionId"
Write-Host "auto-loop: 起動時・スリープ解除時の確認で、セッションを起こします（$Kind、mode=$($kick.permissionMode)）" -ForegroundColor Cyan
if ($kick.idleCloseMinutes -gt 0) { Write-Host "記録が $($kick.idleCloseMinutes) 分のあいだ書かれなければ、このセッションを終わらせます（状態はタスクファイルに残ります）" -ForegroundColor DarkGray }

$prompt = [string]$kick.prompt
if (-not $prompt) {
    $prompt = 'auto-loop の自動起動です（起動時・スリープ解除時）。auto-loop スキルの next（/auto-loop next）を実行してください。人が見ていない前提で進め、承認が要る操作は行わず、タスクファイルの「承認が要る操作」「利用者への質問と回答」に書いて待ってください。区切りごとに状態を記録し、やることが無くなったら、何をしたかを 1〜2 文で述べて止まってください。'
    if ($Kind -eq 'idle') { $prompt += ' 事前の確認では、着手できる通常のタスクはありませんでした。手が空いたときの作業（指令リポジトリの AGENTS.md 7.5）を 1 件だけ、小さな範囲で行ってください。' }
}
$claudeArgs = @('--session-id', $SessionId)
if ($kick.remoteControl) { $claudeArgs += @('--remote-control', "auto-loop ($(if ($Kind -eq 'idle') { '手が空いたとき' } else { '自動起動' }) $(Get-Date -Format 'MM/dd HH:mm'))") }
$claudeArgs += @('--permission-mode', [string]$kick.permissionMode, $prompt)

$runFile = Join-Path (Get-LoopHome) 'state/kick-running.json'
[IO.File]::WriteAllText($runFile, ([ordered]@{ sessionId = $SessionId; kind = $Kind; pid = $PID; startedAt = (Get-NowIso) } | ConvertTo-Json), $utf8)
Write-LoopLog 'kick' "セッションを起動: $Kind session=$SessionId pid=$PID"

# 記録が書かれなくなったら終わらせる見張り
$watch = $null
if ($kick.idleCloseMinutes -gt 0 -and $IsWindows) {
    $watch = Start-ThreadJob -ArgumentList $PID, $SessionId, $projects, ([double]$kick.idleCloseMinutes) -ScriptBlock {
        param($parent, $sid, $projects, $minutes)
        $last = Get-Date
        while ($true) {
            Start-Sleep -Seconds 60
            $files = @()
            foreach ($d in @(Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue)) {
                $f = Join-Path $d.FullName "$sid.jsonl"
                if (Test-Path -LiteralPath $f) {
                    $files += Get-Item -LiteralPath $f
                    $sub = Join-Path $d.FullName $sid      # サブエージェントの記録
                    if (Test-Path -LiteralPath $sub) { $files += @(Get-ChildItem -LiteralPath $sub -Recurse -File -ErrorAction SilentlyContinue) }
                    break
                }
            }
            foreach ($f in $files) { if ($f.LastWriteTime -gt $last) { $last = $f.LastWriteTime } }
            if (((Get-Date) - $last).TotalMinutes -ge $minutes) {
                $kids = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$parent" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'conhost.exe' })
                foreach ($k in $kids) { & taskkill.exe /PID $k.ProcessId /T /F 2>&1 | Out-Null }
                return "idle-close（記録が $minutes 分のあいだ書かれなかった）"
            }
        }
    }
}

$code = $null
try {
    & $claude @claudeArgs
    $code = $LASTEXITCODE
}
finally {
    $why = ''
    if ($watch) {
        if ($watch.State -eq 'Completed') { $why = [string](Receive-Job $watch -ErrorAction SilentlyContinue) }
        Stop-Job $watch -ErrorAction SilentlyContinue; Remove-Job $watch -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $runFile) { Remove-Item -LiteralPath $runFile -Force -ErrorAction SilentlyContinue }
    if ($IsWindows) {
        [AutoLoopKick.Power]::Release($power)
        [AutoLoopKick.Power]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null
    }
    Write-LoopLog 'kick' "セッションが終わった: session=$SessionId 終了コード=$code $why"
}
