# キャッシュJSONスキーマ

## マシン単位: `~/.claude/tool-environment.json`

```json
{
  "detected_at": "2026-07-27",
  "os": "windows",
  "shell": "powershell",
  "default_console_encoding": "cp932",
  "utf8_override_works": true,
  "package_manager": "winget",
  "python": {
    "invocation": "py -m pip",
    "version": "3.12.4",
    "resolved_path": "C:\\Users\\yu\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
    "install_method": "official_installer",
    "in_path": true,
    "has_py_launcher": true,
    "has_python3_alias": false
  },
  "node": {
    "invocation": "node",
    "resolved_path": "C:\\Program Files\\nodejs\\node.exe",
    "install_method": "official_installer",
    "in_path": true
  },
  "npm": {
    "invocation": "npm",
    "resolved_path": "C:\\Program Files\\nodejs\\npm.cmd",
    "install_method": "official_installer",
    "in_path": true
  },
  "git": {
    "invocation": "git",
    "resolved_path": "C:\\Program Files\\Git\\cmd\\git.exe",
    "install_method": "winget",
    "in_path": true
  },
  "powershell": {
    "windows_powershell": {
      "invocation": "powershell -NoProfile",
      "edition": "Desktop",
      "version": "5.1.26100.8655",
      "resolved_path": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
      "install_method": "os_bundled",
      "in_path": true
    },
    "powershell_core": {
      "invocation": "pwsh -NoProfile",
      "edition": "Core",
      "version": "7.6.1",
      "resolved_path": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
      "install_method": "winget",
      "in_path": true
    },
    "default": "windows_powershell",
    "note": "同居する別ランタイム。?? / ForEach-Object -Parallel / ConvertFrom-Json -AsHashtable は 7.x 専用。5.x の -Encoding utf8 は BOM 付き"
  },
  "rust": {
    "invocation": "C:\\Users\\yu\\.cargo\\bin\\cargo.exe",
    "version": "1.97.1",
    "rustc_version": "1.97.1",
    "rustup_version": "1.29.0",
    "active_toolchain": "stable-x86_64-pc-windows-msvc",
    "cargo_bin_dir": "C:\\Users\\yu\\.cargo\\bin",
    "rustup_home": "C:\\Users\\yu\\.rustup",
    "install_method": "rustup",
    "in_path": false,
    "note": "~/.cargo/bin が PATH 未登録のためフルパスで呼ぶ。msvc toolchain はリンクに VS の C++ ビルドツールを要する"
  },
  "tools": {
    "pandoc": {
      "invocation": "pandoc",
      "version": "3.10",
      "kind": "native-cli",
      "resolved_path": "C:\\Users\\yu\\AppData\\Local\\Microsoft\\WinGet\\Links\\pandoc.exe",
      "install_method": "winget",
      "in_path": true
    },
    "markitdown": {
      "invocation": "python -m markitdown",
      "kind": "python-module",
      "package": "markitdown",
      "install_method": "pip",
      "in_path": false,
      "note": "Windows では markitdown.exe が PATH に載らないことがあるためモジュール実行を既定とする"
    },
    "pac": {
      "invocation": "pac",
      "kind": "dotnet-tool",
      "resolved_path": "C:\\Users\\yu\\.dotnet\\tools\\pac.exe",
      "install_method": "dotnet-tool",
      "in_path": true
    }
  },
  "wsl": {
    "available": true,
    "distros": ["Ubuntu"],
    "default_distro": "Ubuntu",
    "managed_distros": ["podman-machine-default"],
    "tools": {
      "docker": {
        "invocation": "wsl.exe -d Ubuntu -- docker",
        "resolved_path": "/usr/bin/docker",
        "note": "Windows 側に未導入のため WSL 側を使う。Windows パスは wslpath -a で変換する"
      }
    }
  },
  "python_packages": {
    "docling": true,
    "openpyxl": true,
    "python-docx": true,
    "python-pptx": true,
    "reportlab": true
  }
}
```

`tools` は Tier A 以外のコマンド（`references/tool_catalog.md` の Tier B / D）を格納する汎用領域。
`python_packages` は CLI を持たない Python パッケージ（Tier C）の import 可否を保持する。

**`powershell` と `rust` は `tools` に入れず独立したキーにする**（単一のパス・版数では表現できないため）。

- `powershell`: Windows PowerShell 5.x と PowerShell Core 6.x / 7.x は同居する別ランタイム。**エディション単位で記録し、`default` にどちらを既定で使うかを持つ**。未導入側は当該キーを省略する（Unix では `windows_powershell` は常に無い）
- `rust`: 実体が `%USERPROFILE%\.cargo\bin`（Unix は `~/.cargo/bin`）にあり **PATH 未登録のことがある**。`in_path: false` なら `invocation` にフルパスを入れる。ビルド可否は toolchain（`active_toolchain` の host target triple）に依存するため併せて記録する

## マシン単位: Mac/Linuxの例

```json
{
  "detected_at": "2026-07-27",
  "os": "macos",
  "shell": "zsh",
  "default_console_encoding": "utf-8",
  "utf8_override_works": true,
  "package_manager": "brew",
  "python": {
    "invocation": "python3",
    "resolved_path": "/opt/homebrew/bin/python3.12",
    "install_method": "homebrew",
    "in_path": true
  },
  "node": {
    "invocation": "node",
    "resolved_path": "/opt/homebrew/bin/node",
    "install_method": "homebrew",
    "in_path": true
  },
  "git": {
    "invocation": "git",
    "resolved_path": "/usr/bin/git",
    "install_method": "official_installer",
    "in_path": true
  }
}
```

## プロジェクト単位: `<project>/.claude/tool-environment.json`

```json
{
  "detected_at": "2026-07-27",
  "venv_active": true,
  "venv_path": ".venv",
  "python_invocation_in_project": ".venv\\Scripts\\python.exe",
  "pip_invocation_in_project": ".venv\\Scripts\\python.exe -m pip"
}
```

## フィールド説明

| フィールド | 説明 |
|---|---|
| `detected_at` | 検出を行った日付。30日以上前なら再検出の候補 |
| `os` | `windows` / `macos` / `linux` |
| `shell` | `powershell` / `cmd` / `bash` / `zsh` 等 |
| `default_console_encoding` | 検出されたコンソールの既定文字コード |
| `utf8_override_works` | UTF-8強制設定(chcp 65001やPYTHONUTF8=1等)が問題なく機能するか |
| `package_manager` | Unix系のみ。`brew` / `apt` / `dnf` / `pacman` |
| `invocation` | 実際にツールを呼び出す際に使うコマンド文字列 |
| `resolved_path` | 解決済みの絶対パス |
| `install_method` | どの手順でインストールされたか（`official_installer` / `winget` / `homebrew` / `apt` / `dnf` / `pacman` / `pip` / `dotnet-tool` / `npm` / `rustup` / `os_bundled` / `manual`） |
| `in_path` | フルパス指定なしでPATH経由のまま呼べるか |
| `edition` | `powershell` 配下のみ。`Desktop`（Windows PowerShell 5.x）/ `Core`（PowerShell 6.x・7.x） |
| `default` | 同居する複数エディションのうち既定で使うキー（`windows_powershell` / `powershell_core`） |
| `active_toolchain` | `rust` のみ。`rustup show` のアクティブ toolchain（host target triple 込み。例: `stable-x86_64-pc-windows-msvc`） |
| `cargo_bin_dir` / `rustup_home` | `rust` のみ。`in_path: false` のときにフルパスを組み立てる基点 |
| `detected_by` | 検出に使ったスクリプト。手書きの記録と自動検出を区別するために残す |
| `not_installed` | **未導入と確認できたもの**をコマンド名 → 理由・代替手段で保持する。これが無いと同じ試し打ちが繰り返される |
| `git_bash` | Windows のみ。Git のインストールルートと探索対象ディレクトリ（`references/tool_catalog.md`「Windows: PowerShell と Git Bash で PATH が違う」） |
| `kind` | ツールの種別。`native-cli` / `python-module` / `dotnet-tool` / `node-package` |
| `package` | `kind` が `python-module` 等の場合の配布パッケージ名（import 名と異なることがある: python-docx → docx） |
| `version` | バージョン確認が必要な作業で使う。取得できた場合のみ記録する |
| `note` | 呼び出し方に注意が必要な場合の補足（例: Windows で CLI が PATH に載らない） |

**運用上の注意:** `<project>/.claude/tool-environment.json` は環境依存の
情報のため、`.gitignore` に追加し、リポジトリにはコミットしないこと。
