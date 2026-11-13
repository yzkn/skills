' タスク スケジューラから auto-resume.ps1 をウィンドウを出さずに起動する (10 分ごとに画面がちらつかないように)
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
shellPath = "pwsh.exe"
If Not fso.FileExists("C:\Program Files\PowerShell\7\pwsh.exe") Then shellPath = "powershell.exe"
CreateObject("WScript.Shell").Run shellPath & " -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\auto-resume.ps1""", 0, False
