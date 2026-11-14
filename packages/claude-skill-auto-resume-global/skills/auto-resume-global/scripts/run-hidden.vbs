' 使っていない (2026-11-14 から、タスクは conhost.exe --headless で auto-resume.ps1 を起動する。VBScript は Windows から外されていくため)。
' 前の版で登録したタスクがこのファイルを指していることがあるので、残している。install.ps1 を実行し直せば、タスクは conhost.exe に替わる。
' タスク スケジューラから auto-resume.ps1 をウィンドウを出さずに起動する (10 分ごとに画面がちらつかないように)
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
shellPath = "pwsh.exe"
If Not fso.FileExists("C:\Program Files\PowerShell\7\pwsh.exe") Then shellPath = "powershell.exe"
CreateObject("WScript.Shell").Run shellPath & " -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\auto-resume.ps1""", 0, False
