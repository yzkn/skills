# safety-net.ps1 — PreToolUse フックによる危険操作の機械的ブロック（Safety Net）
#
# .claude/rules/ の【絶対禁止】/【要指示】ルールのうち、ツール呼び出しから機械的に
# 判定できるものを実行前に deny / ask する多層防御の一層。
# プロンプト（ルール記述）と settings.json の permissions.deny を補完する。
# 判定ロジックは本リポジトリ独自実装（外部リポジトリのコード流用なし）。
#
# 出力仕様（Claude Code PreToolUse フック）:
#   stdout に {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#     "permissionDecision":"deny"|"ask","permissionDecisionReason":"..."}} を返すと
#   その決定が適用される。何も出力せず exit 0 なら通常の権限フローに従う。
#   フック自体の障害でセッションを止めないため、解析失敗時は fail-open（許可）とし
#   stderr にのみ記録する。

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Decision([string]$Decision, [string]$Reason) {
    $obj = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = $Reason
        }
    }
    # リダイレクト時もコンソールコードページの影響を受けないよう UTF-8 バイトを直接書く
    $json  = $obj | ConvertTo-Json -Depth 5 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $out   = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
    exit 0
}

try {
    # stdin はコンソールコードページ（cp932 等）ではなく UTF-8 で明示的に読む。
    # [Console]::In だと日本語を含む tool_input が壊れ、JSON 解析失敗 → fail-open になるため。
    $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("safety-net: stdin JSON parse error: $($_.Exception.Message)")
    exit 0
}

$toolName  = [string]$data.tool_name
$toolInput = $data.tool_input
$cwd       = [string]$data.cwd
if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = (Get-Location).Path }

# 対象パスをリポジトリルート相対（/ 区切り・小文字）に正規化する
function ConvertTo-RelPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $p = $Path -replace '\\', '/'
    $root = ($cwd -replace '\\', '/').TrimEnd('/')
    if ($p.ToLower().StartsWith($root.ToLower() + '/')) {
        $p = $p.Substring($root.Length + 1)
    }
    return $p.TrimStart('./').ToLower()
}

# ---------------------------------------------------------------
# 1. Bash コマンドの検査
# ---------------------------------------------------------------
if ($toolName -eq 'Bash') {
    $cmd = [string]$toolInput.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    # 【絶対禁止】git push（-C 付き・パイプ/連結の後段を含むすべての形態）
    if ($cmd -match '(?i)(^|[;&|]\s*)git(\.exe)?\s+(-[cC]\s+\S+\s+)?push\b') {
        Write-Decision 'deny' ('git push はユーザーのみが実施する【絶対禁止】操作です（.claude/rules/git-safety.md）。' +
            '実行すべきコマンドを提示してユーザー自身の実行を依頼してください。')
    }

    # 【絶対禁止】ディスク破壊系
    if ($cmd -match '(?i)\b(mkfs(\.\w+)?|diskpart|Format-Volume|Clear-Disk)\b') {
        Write-Decision 'deny' 'ディスク初期化・フォーマット系コマンドは実行できません（Safety Net）。'
    }

    # 【絶対禁止】.env の内容表示（.env.example は除外）
    # [^;&|\r\n]* — コマンド連結記号と改行をまたがない（ヒアドキュメント内の文字列への誤検知防止）
    if ($cmd -match '(?i)\b(cat|type|more|less|head|tail|Get-Content|gc)\b[^;&|\r\n]*\.env\b' -and
        $cmd -notmatch '(?i)\.env\.example') {
        Write-Decision 'deny' ('.env（認証情報を含み得るファイル）の内容表示はブロックされました' +
            '（.claude/rules/security-hardstops.md）。必要な場合は .env.example を参照してください。')
    }

    # 【絶対禁止相当】認証情報ファイル/ディレクトリへの Bash 経由アクセス
    # settings.json の permissions.deny（Bash(* ~/.ssh/*) 等）と合わせた多層防御。
    # Read ツールの deny は Read ツール経由しか塞げないため、cat/type 等での読取・流用をここで遮断する。
    # 誤検知防止: 直前が ~ / \ の「パス参照文脈」に限定し、コミットメッセージ等の単なる
    # 文字列内での言及（例: git commit -m "...netrc..."）は対象外とする。
    # ディレクトリは末尾も区切り文字を必須とし、ファイル名は語境界で終端する。
    if ($cmd -match '(?i)[~\\/]\.ssh[\\/]' -or
        $cmd -match '(?i)[~\\/]\.aws[\\/]' -or
        $cmd -match '(?i)[~\\/]\.config[\\/]gh[\\/]' -or
        $cmd -match '(?i)[~\\/]\.(git-credentials|netrc|npmrc)\b') {
        Write-Decision 'deny' ('認証情報ファイル（~/.ssh・~/.aws・~/.config/gh・.git-credentials・.netrc・.npmrc）への' +
            'Bash 経由のアクセスはブロックされました（.claude/rules/security-hardstops.md）。')
    }

    # 【絶対禁止相当】外部送信コマンドの別経路（deny 回避経路の遮断）
    # settings.json の deny（curl/wget 等）はコマンド先頭のプレフィックスマッチのため、
    # PowerShell エイリアス・.exe 直接指定・パイプ/連結の後段をここで遮断する。
    # 誤検知防止: コマンド位置（先頭または ; & | の直後）に限定し、コミットメッセージ等の
    # 文字列内での言及は対象外とする（git push 検知と同じ構図）。
    if ($cmd -match '(?i)(^|[;&|]\s*)(Invoke-WebRequest|Invoke-RestMethod|iwr|irm|Start-BitsTransfer|curl(\.exe)?|wget(\.exe)?|nc|ncat|telnet)\b') {
        Write-Decision 'deny' ('外部送信・外部通信コマンド（Invoke-WebRequest/Invoke-RestMethod/curl/wget 等）の実行は' +
            'ブロックされました（.claude/rules/external-resources.md）。外部送信が必要な場合は送信先・データ・目的を' +
            '提示してユーザーの確認を得てください。')
    }

    # 【絶対禁止相当】.NET クラス直接利用による外部通信（引用文字列内でも検知）
    if ($cmd -match '(?i)New-Object\s+(System\.)?Net\.(WebClient|Sockets)' -or
        $cmd -match '(?i)\[System\.Net\.(Http|WebRequest|Sockets)') {
        Write-Decision 'deny' ('.NET クラス（WebClient/HttpClient/Sockets 等）経由の外部通信はブロックされました' +
            '（.claude/rules/external-resources.md）。')
    }

    # 【要指示】Python インラインスクリプトによる外部通信の可能性
    if ($cmd -match '(?i)\bpython3?(\.exe)?\s+-[cm]\b' -and
        $cmd -match '(?i)\b(urllib|requests|socket|http\.client|httpx|aiohttp|ftplib|smtplib)\b') {
        Write-Decision 'ask' ('Python インライン実行に外部通信系モジュール（urllib/requests/socket 等）が含まれます。' +
            '送信先・データ・目的を確認してから実行してください（.claude/rules/external-resources.md）。')
    }

    # 【要指示】破壊的 SQL（DROP/TRUNCATE/DELETE）を含むコマンド
    if ($cmd -match '(?i)\b(DROP\s+(TABLE|DATABASE|SCHEMA|INDEX)|TRUNCATE\s+TABLE|DELETE\s+FROM)\b') {
        Write-Decision 'ask' ('破壊的 SQL（DROP/TRUNCATE/DELETE）を含むコマンドです。接続先が本番環境でないこと・' +
            '対象が正しいことをユーザーに確認してから実行してください（.claude/rules/environment-safety.md）。')
    }

    # 【要指示】防御設定ファイルへの Bash 経由の書き込み（リダイレクト・Set-Content 等）
    if ($cmd -match '(?i)(>>?|\b(Set-Content|Out-File|Add-Content|tee)\b)' -and
        $cmd -match '(?i)(\.claude[\\/](settings[^\\/]*\.json|hooks[\\/])|\.mcp\.json|\.githooks[\\/])') {
        Write-Decision 'ask' ('防御設定ファイル（.claude/settings*.json・.claude/hooks/・.mcp.json・.githooks/）への' +
            '書き込みはユーザーの明示的な指示が必要です（.claude/rules/external-resources.md）。')
    }

    # 【要指示】再帰的強制削除
    if ($cmd -match '(?i)\brm\s+(-[a-z]*[rf][a-z]*\s+)*-[a-z]*[rf][a-z]*\b' -or
        $cmd -match '(?i)\bRemove-Item\b[^;&|\r\n]*-Recurse\b[^;&|\r\n]*-Force\b') {
        Write-Decision 'ask' ('再帰的な強制削除です。不可逆的な削除はユーザーの明示的な指示の確認が必要です' +
            '（.claude/rules/safe-file-ops.md）。対象パスが正しいか確認してください。')
    }

    # 【要指示】作業内容を破棄する git 操作
    if ($cmd -match '(?i)\bgit\b[^;&|\r\n]*\breset\s+--hard\b' -or
        $cmd -match '(?i)\bgit\b[^;&|\r\n]*\bclean\s+-[a-z]*f') {
        Write-Decision 'ask' ('未コミットの変更を破棄する git 操作です。実行前にユーザーの確認が必要です' +
            '（.claude/rules/safe-file-ops.md）。')
    }

    # 【要指示】コンテナのデータ・イメージ・キャッシュを戻せない形で消す操作（podman / docker 共通）
    # 誤検知防止: コマンド位置（先頭または ; & | の直後）に限定する（git push 検知と同じ構図）。
    # 1) compose の down / rm でボリュームを消す（-v / --volumes / -fv 等）・down --rmi
    if ($cmd -match '(?i)(^|[;&|]\s*)(podman(\.exe)?\s+compose|podman-compose|docker-compose(\.exe)?|docker(\.exe)?\s+compose)\b[^;&|\r\n]*\b(down|rm)\b[^;&|\r\n]*\s(-[a-z]*v[a-z]*|--volumes|--rmi)\b') {
        Write-Decision 'ask' ('compose のボリューム（DB のデータ等）またはイメージを削除する操作です。' +
            '何が消えるかを示してユーザーの確認を得てください（.claude/skills/container/SKILL.md §4）。')
    }
    # 2) system prune/reset・各種 prune/rm・rmi・kill・rm -f・machine rm/reset
    if ($cmd -match '(?i)(^|[;&|]\s*)(podman|docker)(\.exe)?\s+(system\s+(prune|reset)\b|(volume|image|network|container|builder|buildx|pod)\s+(prune|rm)\b|machine\s+(rm|reset)\b|rmi\b|kill\b|rm\b[^;&|\r\n]*\s(-[a-z]*f[a-z]*|--force)\b)') {
        Write-Decision 'ask' ('コンテナ・イメージ・ボリューム・ネットワーク・ビルドキャッシュ・VM を削除する操作です。' +
            '何が消えるかを示してユーザーの確認を得てください（.claude/skills/container/SKILL.md §4）。')
    }

    # 【要指示】フックのスキップ
    if ($cmd -match '(?i)--no-verify\b') {
        Write-Decision 'ask' ('--no-verify（フックのスキップ）はユーザーの明示的な指示がある場合のみ許可されます' +
            '（.claude/rules/git-safety.md）。')
    }

    # 【要指示】本番環境を示す文字列を含む操作
    if ($cmd -match '(?i)\b(production|prod|prd)\b' -and
        $cmd -match '(?i)\b(deploy|publish|az |aws |gcloud |kubectl |terraform |pulumi |pac )') {
        Write-Decision 'ask' ('本番環境（production/prod/prd）に関わる可能性のある操作です。' +
            '実行前にユーザーへの確認が必要です（.claude/rules/environment-safety.md）。')
    }

    exit 0
}

# ---------------------------------------------------------------
# 2. ファイル編集系ツール（Edit / Write / MultiEdit / NotebookEdit）の検査
# ---------------------------------------------------------------
$editTools = @('Edit', 'Write', 'MultiEdit', 'NotebookEdit')
if ($editTools -contains $toolName) {
    $rel = ConvertTo-RelPath ([string]$toolInput.file_path)
    if ($rel -eq '') { exit 0 }

    # 【絶対禁止】証跡ファイル（doc/prompt/・doc/thought/・doc/adr/）の編集・上書き
    if ($rel -match '^doc/(prompt|thought|adr)/') {
        if ($toolName -ne 'Write') {
            Write-Decision 'deny' ('証跡ファイル（doc/prompt/・doc/thought/・doc/adr/）の編集は【絶対禁止】です' +
                '（.claude/CLAUDE.md「証跡の不変性」）。修正は別名での新規作成で対応してください。')
        }
        # Write は新規作成のみ許可し、既存ファイルの上書きは拒否する
        $abs = [string]$toolInput.file_path
        if (Test-Path -LiteralPath $abs) {
            Write-Decision 'deny' ('証跡ファイルの上書きは【絶対禁止】です（.claude/CLAUDE.md「証跡の不変性」）。' +
                '別名（例: 末尾に _2）での新規作成で対応してください。')
        }
    }

    # 【絶対禁止】guide/for-human/ への書き込み（原本の改変防止）
    if ($rel -match '^guide/for-human/') {
        Write-Decision 'deny' ('guide/for-human/ は Office ファイル原本の格納場所であり、Claude Code は' +
            '操作できません（.claude/rules/guide-access.md）。')
    }

    # 【絶対禁止】第三者由来スキル（.claude/skills/anthropics/ 配下）の改変
    # Anthropic 公式スキルは本体を書き換えない（.claude/CLAUDE.md「構成・拡張の保守」）。
    # settings.json の deny（Edit/Write(.claude/skills/anthropics/**)）と合わせた多層防御で、
    # deny のパターンが及ばない MultiEdit / NotebookEdit 経由の改変もここで遮断する。
    if ($rel -match '^\.?claude/skills/anthropics/') {
        Write-Decision 'deny' ('第三者由来のスキル定義（.claude/skills/anthropics/ 配下）の改変は【絶対禁止】です' +
            '（.claude/CLAUDE.md「構成・拡張の保守」）。挙動を変えたい場合は本体を書き換えず、' +
            '自プロジェクト側のスキルとして別途作成してください。')
    }

    # 【要指示】防御設定ファイルの変更（Safety Net の自己防衛）
    # permissions・hooks・MCP 定義・git フックの変更は防御の無効化につながるため、
    # ユーザーの明示的な指示（承認ダイアログでの確認）を必須とする。
    # 注意: ConvertTo-RelPath の TrimStart('./') により先頭の . は除去済み（.claude → claude）
    if ($rel -match '^\.?claude/settings(\.local)?\.json$' -or
        $rel -match '^\.?claude/hooks/[^/]+\.ps1$' -or
        $rel -match '^\.?mcp\.json$' -or
        $rel -match '^\.?githooks/') {
        Write-Decision 'ask' ('防御設定ファイル（.claude/settings*.json・.claude/hooks/*.ps1・.mcp.json・.githooks/）の' +
            '変更はユーザーの明示的な指示が必要です（.claude/rules/external-resources.md）。' +
            '変更内容が指示に基づくものか確認してください。')
    }

    exit 0
}

# ---------------------------------------------------------------
# 3. Read ツールの検査
# ---------------------------------------------------------------
if ($toolName -eq 'Read') {
    $rel = ConvertTo-RelPath ([string]$toolInput.file_path)
    if ($rel -eq '') { exit 0 }

    # 【絶対禁止】guide/for-human/ の参照（トークン大量消費防止）
    if ($rel -match '^guide/for-human/') {
        Write-Decision 'deny' ('guide/for-human/ の参照は【絶対禁止】です（.claude/rules/guide-access.md）。' +
            'Markdown 変換済みの guide/for-llm/ を参照してください。')
    }

    # 【絶対禁止】.env ファイルの読み取り（.env.example は許可）
    $basename = ($rel -split '/')[-1]
    if ($basename -match '^\.env(\..+)?$' -and $basename -ne '.env.example') {
        Write-Decision 'deny' ('.env（認証情報を含み得るファイル）の読み取りはブロックされました' +
            '（.claude/rules/security-hardstops.md）。変数名の確認は .env.example を使用してください。')
    }

    exit 0
}

exit 0
