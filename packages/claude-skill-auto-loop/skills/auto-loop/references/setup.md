# setup — この PC の登録

PC（とエージェント）ごとに 1 回行う。何度行っても安全（あるものは残す）。

## 手順

1. **現状を確かめる。** `~/.claude/auto-loop/config.json` があれば読み、`agentId` と `controlRepoPath` を利用者に示す。足りないものだけを進める
2. **指令リポジトリを用意する。** 利用者に、どれかを確かめる
   - すでにある → URL を聞いて clone する（場所は利用者に確かめる。既定の案は、ほかのリポジトリと同じ親フォルダ）
   - これから作る → 手元に作る。リモートの作成と push は**利用者が行う**（スクリプトが最後にコマンドを示す。指令には案件の内情が入るので非公開にする）

     ```
     pwsh -NoProfile -File <scripts>/new-control-repo.ps1 -Path <場所>
     ```
3. **エージェントの ID を決める。** 形は `<PC>-<道具>[-<アカウントや用途>]`（例 `pc1-claude-main`）。指令リポジトリの `roster.md` を読み、**すでにある ID と重ならない**ことを確かめる。利用者に案を示して決めてもらう
4. **導入する。**

   ```
   pwsh -NoProfile -File <scripts>/install.ps1 -AgentId <ID> -ControlRepoPath <場所>
   ```

   スキルを `~/.claude/skills/auto-loop/` に写し（そこから実行しているときは写さない）、`~/.claude/auto-loop/` に設定とフォルダを作る
5. **名簿に足す。** `roster.md` に自分の行を足し、`sync.ps1 -Message 'setup: <ID> を登録'` で送る
6. **自動再開と連携する（任意。利用者の了承を得てから）。** `auto-resume-global` が入っていれば、再開の指示に「`/auto-loop resume` を実行する」案内を足す。グローバルの設定を書き換えるので、変更の内容を示して了承を得る（控えは `~/.claude/auto-loop/state/` に残る）

   ```
   pwsh -NoProfile -File <scripts>/install.ps1 -NoCopy -LinkAutoResume
   ```
7. **確かめる。** `pwsh -NoProfile -File <scripts>/preflight.ps1` を実行し、NG があれば直し方を示す

## 案件を足すとき

1. 指令リポジトリの `templates/project.md` を `projects/<案件>/project.md` に写し、利用者に聞きながら埋める。「リポジトリ」の表（ホスト・リポジトリ・アカウント・本流のリモート・基準ブランチ）は、手元の clone があれば `git remote -v` で**実物を確かめて**書く。リモートが複数あるときは、どれが本流かを利用者に確かめる
2. この PC での clone の場所を `~/.claude/auto-loop/config.json` の `repoPaths` に足す（キーは `"<案件>/<表のキー>"`）
3. `preflight.ps1 -Project <案件>` で確かめ、`sync.ps1` で送る

## 同じ PC で別のエージェント（Copilot など）も使うとき

- 名簿に別の ID を足し、その道具の起動時に環境変数 `AUTO_LOOP_AGENT_ID` で渡す（スクリプトは設定より環境変数を優先する）
- スクリプトを使えない道具は、指令リポジトリの `AGENTS.md` の手順を git で行う

## してはいけないこと

- リモートのリポジトリの作成・公開範囲の変更を、利用者の指示なしに行わない
- 利用者のグローバルの設定（`~/.claude/CLAUDE.md`・`settings.json`・`auto-resume-global` の設定）を、了承なしに書き換えない
