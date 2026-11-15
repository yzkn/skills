<#
.SYNOPSIS
  再開する前のセッションに付いていた Remote Control のセッションを archive する (resume-session.ps1 が裏で起動する)。
.DESCRIPTION
  再開は別のセッション (--fork-session) になり、新しい Remote Control のセッションができる。
  前のセッションのものは、claude が正常に終わったときにしか archive されない (上限で止まったウィンドウが開いたまま・再起動で強制終了)。
  そのままだと、スマートフォンの一覧に前のセッションが残って紛らわしいので、新しい方が立ち上がってから前の方を archive する。

  - 前のセッションの記録 (<ProjectsDir>/*/<SessionId>.jsonl) の bridge-session の行から、ブリッジのセッション ID (cse_...) を読む
  - -NewSessionId があれば、新しいセッションの記録に bridge-session の行が出る (Remote Control がつながる) まで、-WaitSeconds 秒まで待つ。
    つながらなければ archive しない (前のセッションへの接続だけが残る方がまし)
  - Claude Code 自身が終了時に使うのと同じ API (POST /v1/code/sessions/<cse_...>/archive。無ければ /v1/sessions/<session_...>/archive) を、
    Claude Code のログイン情報 (.credentials.json の claudeAiOauth) で呼ぶ。トークンは読むだけで、更新はしない
    (期限が切れていれば、新しい claude が更新するのを待つ)
  - archive は claude.ai の画面から元に戻せる。失敗しても再開には影響しない (ログに残すだけ)
.PARAMETER DryRun
  API を呼ばずに、archive する ID と呼ぶ URL を表示する
#>
param(
    [Parameter(Mandatory)][string]$SessionId,
    [string]$NewSessionId,
    [int]$WaitSeconds = 300,
    [string]$ProjectsDir,
    [string]$CredentialsPath,
    [string]$BaseUrl = 'https://api.anthropic.com',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
if (-not $ProjectsDir) { $ProjectsDir = Join-Path $configDir 'projects' }
if (-not $CredentialsPath) { $CredentialsPath = Join-Path $configDir '.credentials.json' }
$LogDir = Join-Path $PSScriptRoot 'logs'

function Write-Log([string]$Message) {
    $line = '{0} archive-remote: {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message
    if ($DryRun) { Write-Host $line; return }
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        [IO.File]::AppendAllText((Join-Path $LogDir 'auto-resume.log'), $line + "`r`n", (New-Object Text.UTF8Encoding $false))
    } catch { }
}

# 記録の中の、そのセッション自身の最後の bridge-session の行 ({ bridgeSessionId, ownerOrganizationUuid })。無ければ $null
function Get-BridgeSession([string]$Id) {
    $file = Get-ChildItem -LiteralPath $ProjectsDir -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "$Id.jsonl" } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $file) { return $null }
    $last = $null
    # 書き込み中の claude と取り合わないよう、共有で読む
    $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite,Delete')
    try {
        $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
        while ($null -ne ($line = $sr.ReadLine())) {
            if (-not $line.Contains('"type":"bridge-session"')) { continue }
            try { $o = $line | ConvertFrom-Json } catch { continue }
            if ($o.sessionId -eq $Id -and $o.bridgeSessionId) { $last = $o }
        }
    } finally { $fs.Dispose() }
    return $last
}

function Get-AccessToken {
    if (-not (Test-Path -LiteralPath $CredentialsPath)) { return $null }
    try { $c = Get-Content -LiteralPath $CredentialsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
    $o = $c.claudeAiOauth
    if (-not $o -or -not $o.accessToken) { return $null }
    if ($o.expiresAt -and [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$o.expiresAt) -lt [DateTimeOffset]::Now.AddMinutes(1)) { return $null }
    return [string]$o.accessToken
}

try {
    $old = Get-BridgeSession $SessionId
    if (-not $old) { Write-Log "skip: $SessionId の記録に Remote Control のセッションが無い"; exit 0 }
    $cse = [string]$old.bridgeSessionId
    $legacy = if ($cse.StartsWith('cse_')) { 'session_' + $cse.Substring(4) } else { $cse }
    $v2 = if ($cse.StartsWith('session_')) { 'cse_' + $cse.Substring(8) } else { $cse }

    # 新しいセッションの Remote Control がつながるのを待つ (つながってから前のものを片付ける)
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    if ($NewSessionId) {
        $new = $null
        while ($true) {
            $new = Get-BridgeSession $NewSessionId
            if ($new -or (Get-Date) -ge $deadline -or $DryRun) { break }
            Start-Sleep -Seconds 5
        }
        if (-not $new) {
            if (-not $DryRun) { Write-Log "skip: 新しいセッション $NewSessionId の Remote Control が $WaitSeconds 秒でつながらない ($v2 は残す)"; exit 0 }
        } elseif ($new.bridgeSessionId -eq $cse) { Write-Log "skip: 新しいセッションが同じ $cse を使っている"; exit 0 }
    }

    $urls = @("$BaseUrl/v1/code/sessions/$v2/archive", "$BaseUrl/v1/sessions/$legacy/archive")
    if ($DryRun) { Write-Log "dry-run: $SessionId の $v2 を archive する: $($urls -join ' / ')"; exit 0 }

    $token = $null
    while (-not ($token = Get-AccessToken)) {
        if ((Get-Date) -ge $deadline.AddSeconds(120)) { Write-Log "skip: ログイン情報が無いか期限切れ ($v2 は残す)"; exit 0 }
        Start-Sleep -Seconds 10
    }
    $headers = @{
        Authorization       = "Bearer $token"
        'anthropic-version' = '2023-06-01'
        'anthropic-beta'    = 'environments-2025-11-01'
    }
    if ($old.ownerOrganizationUuid) { $headers['x-organization-uuid'] = [string]$old.ownerOrganizationUuid }
    $result = @()
    foreach ($u in $urls) {
        # 4xx は例外になる (Windows PowerShell 5.1 には -SkipHttpErrorCheck が無い)。状態コードだけ取り出す
        try {
            $code = [int](Invoke-WebRequest -Method Post -Uri $u -Headers $headers -ContentType 'application/json' -Body '{}' -TimeoutSec 15 -UseBasicParsing).StatusCode
        } catch {
            $resp = $_.Exception.Response
            if (-not $resp) { throw }
            $code = [int]$resp.StatusCode
        }
        $result += "$code $u"
        # 409 は「もう archive されている」
        if ($code -in 200, 204, 409) { Write-Log "archived: $SessionId の $v2 ($code)"; exit 0 }
        if ($code -ne 404) { break }   # 404 のときだけ、旧形式の URL を試す
    }
    Write-Log "failed: $SessionId の $v2 を archive できない ($($result -join ', '))"
} catch {
    Write-Log "failed: $SessionId : $($_.Exception.Message)"
}
exit 0
