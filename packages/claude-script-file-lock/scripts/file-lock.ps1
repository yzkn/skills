# file-lock.ps1 — Claude Code が編集・削除すべきでないファイルを OS レベルでロックする
#
# 仕組み:
#   常駐プロセス（hold アクション）が対象ファイルを
#   FileMode.Open / FileAccess.Read / FileShare.Read で開いたまま保持する。
#   FileShare.Read により、他プロセスには「読み取りのみ」が許可され、
#   書き込み・削除・リネームは OS レベルで拒否される（Edit/Write ツールも失敗する）。
#
# 使い方:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 lock <パス> [<パス>...]
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 unlock
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/file-lock.ps1 status
#
#   hold は lock が内部的に起動する常駐用アクション（直接実行しない）。
#
# 状態ファイル: .claude/scripts/file-lock.state.json（git 管理外）

param(
    [Parameter(Position = 0)]
    [ValidateSet('lock', 'unlock', 'status', 'hold')]
    [string]$Action = 'status',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = 'Stop'
# Git Bash 等のリダイレクト先でも日本語が化けないよう UTF-8 で出力する
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$StateFile = Join-Path $PSScriptRoot 'file-lock.state.json'

function Read-State {
    if (Test-Path -LiteralPath $StateFile) {
        return Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    return $null
}

function Write-State([int]$HolderPid, [string[]]$Files) {
    $state = [pscustomobject]@{ pid = $HolderPid; files = @($Files) }
    $state | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

# 状態ファイルの PID が生きているロック常駐プロセスなら返す（PID 再利用の誤検出を避けるためプロセス名も確認）
function Get-HolderProcess {
    $state = Read-State
    if ($null -eq $state -or -not $state.pid) { return $null }
    $proc = Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -match '^(powershell|pwsh)$') { return $proc }
    return $null
}

# 書き込みアクセスで開けなければロック中と判定する
function Test-Locked([string]$Path) {
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $fs.Dispose()
        return $false
    }
    catch [System.IO.IOException] {
        return $true
    }
}

function Stop-Holder {
    $proc = Get-HolderProcess
    if ($proc) {
        Stop-Process -Id $proc.Id -Force
        # ハンドル解放を待つ
        Start-Sleep -Milliseconds 500
        return $true
    }
    return $false
}

switch ($Action) {

    # ---- 常駐（lock から内部起動される）--------------------------------------
    'hold' {
        $state = Read-State
        if ($null -eq $state -or @($state.files).Count -eq 0) { exit 1 }
        $handles = @()
        foreach ($f in $state.files) {
            try {
                $handles += [System.IO.File]::Open($f, [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            }
            catch {
                # 開けなかったファイルはスキップ（lock 側の検証で失敗として報告される）
            }
        }
        if ($handles.Count -eq 0) { exit 1 }
        while ($true) { Start-Sleep -Seconds 3600 }
    }

    # ---- ロック ---------------------------------------------------------------
    'lock' {
        if (-not $Paths -or $Paths.Count -eq 0) {
            Write-Error 'lock にはロック対象のファイルパスを 1 つ以上指定してください。'
            exit 1
        }

        # パス検証（存在しない・ディレクトリはエラーとして即報告）
        $resolved = @()
        $invalid = @()
        foreach ($p in $Paths) {
            $item = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
            if ($null -eq $item) { $invalid += "$p (存在しません)" }
            elseif ($item.PSIsContainer) { $invalid += "$p (ディレクトリは対象外です)" }
            else { $resolved += $item.FullName }
        }
        if ($invalid.Count -gt 0) {
            Write-Error ("ロックできないパスがあります:`n  " + ($invalid -join "`n  "))
            exit 1
        }

        # 既存ロックとマージして常駐プロセスを再起動する
        $current = @()
        if (Get-HolderProcess) {
            $current = @((Read-State).files)
        }
        $merged = @($current + $resolved | Sort-Object -Unique)
        [void](Stop-Holder)

        Write-State 0 $merged

        # 現在の PowerShell と同じホストで常駐プロセスを起動する
        $psExe = (Get-Process -Id $PID).Path
        $proc = Start-Process -FilePath $psExe -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $PSCommandPath, 'hold'
        )
        Write-State $proc.Id $merged
        Start-Sleep -Seconds 2

        # 検証: 各ファイルが実際に書き込み不可になったか確認する
        $failed = @()
        foreach ($f in $merged) {
            if (-not (Test-Locked $f)) { $failed += $f }
        }
        if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $StateFile -ErrorAction SilentlyContinue
            Write-Error '常駐プロセスが起動直後に終了しました。ロックは有効になっていません。'
            exit 1
        }
        Write-Output "ロック常駐プロセス起動: PID $($proc.Id)"
        foreach ($f in $merged) {
            $mark = if ($failed -contains $f) { '[失敗]' } else { '[ロック]' }
            Write-Output "  $mark $f"
        }
        if ($failed.Count -gt 0) {
            Write-Error "$($failed.Count) 件のファイルをロックできませんでした。"
            exit 1
        }
    }

    # ---- 解除 -----------------------------------------------------------------
    'unlock' {
        $state = Read-State
        if (Stop-Holder) {
            Write-Output "ロック常駐プロセス (PID $($state.pid)) を停止しました。全ファイルのロックを解除しました。"
        }
        else {
            Write-Output 'ロック常駐プロセスは動作していません（解除対象なし）。'
        }
        Remove-Item -LiteralPath $StateFile -ErrorAction SilentlyContinue
    }

    # ---- 状態確認 -------------------------------------------------------------
    'status' {
        $proc = Get-HolderProcess
        if ($null -eq $proc) {
            Write-Output 'ロックなし（常駐プロセスは動作していません）。'
            exit 0
        }
        $state = Read-State
        Write-Output "ロック常駐プロセス: PID $($proc.Id)"
        foreach ($f in $state.files) {
            $mark = if (Test-Locked $f) { '[ロック]' } else { '[未ロック]' }
            Write-Output "  $mark $f"
        }
    }
}
