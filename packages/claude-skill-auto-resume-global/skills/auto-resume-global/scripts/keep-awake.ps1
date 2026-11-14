<#
.SYNOPSIS
  指定した分だけ、PC がスリープしないようにする (auto-resume.ps1 が action=wake のときに、ウィンドウを出さずに起動する)。
.DESCRIPTION
  解除時刻にスリープ解除タイマー (ClaudeAutoResumeGlobal-Wake) で起こされた PC は、操作が無いと 2 分ほどで
  またスリープする (無人のスリープのタイムアウト)。その間に別の仕組み (/auto-resume のタスクなど) の再開が
  進むよう、SetThreadExecutionState で起きたままにする。画面は消えたままでよい。
  Claude Code は上限の解除後に止まったターンを自分では続けないので、これだけでは作業は進まない (既定の action=resume は使わない)。
  終わるか、このプロセスを止めると、スリープ抑止は解ける。
.PARAMETER Minutes
  起こしておく分 (1〜240)。
#>
param([ValidateRange(1, 240)][int]$Minutes = 20)
$ErrorActionPreference = 'Stop'

# 同時に 1 つだけ。後から起動されたほうに置き換える (auto-resume.ps1 は、待つセッションの一番遅い時刻で起動し直す)
$mutex = New-Object Threading.Mutex($false, 'Local\ClaudeAutoResumeGlobal-KeepAwake')
$owned = $false
try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
if (-not $owned) {
    $others = Get-CimInstance Win32_Process -Filter "Name like 'p%sh%.exe'" | Where-Object { $_.CommandLine -like '*keep-awake.ps1*' -and $_.ProcessId -ne $PID }
    foreach ($p in $others) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    try { if (-not $mutex.WaitOne(5000)) { exit 0 } } catch [Threading.AbandonedMutexException] { }   # 止めたプロセスが持っていた
}

Add-Type -Namespace ClaudeAutoResumeGlobal -Name KeepAwake -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
try {
    [ClaudeAutoResumeGlobal.KeepAwake]::SetThreadExecutionState([uint32]'0x80000001') | Out-Null   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
    Start-Sleep -Seconds ($Minutes * 60)
}
finally {
    [ClaudeAutoResumeGlobal.KeepAwake]::SetThreadExecutionState([uint32]'0x80000000') | Out-Null   # スリープ抑止を解除
    $mutex.ReleaseMutex()
}
