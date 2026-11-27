# エージェントの名簿

このリポジトリを読み書きするエージェントの一覧。ID は `<PC>-<道具>[-<アカウントや用途>]`。**同じ ID を 2 か所で使わない**（担当の区別がつかなくなる）。

| ID | PC | 道具 | AI のアカウント | 得意・制約 | 備考 |
|---|---|---|---|---|---|
| `<pc1-claude-main>` | `<PC の名前>` | Claude Code | `<アカウントの呼び名>` | 例: 調査・設計・統合 | |
| `<pc1-copilot>` | `<PC の名前>` | Copilot | `<アカウントの呼び名>` | 例: 定型の実装 | 環境変数 `AUTO_LOOP_AGENT_ID` で ID を渡す |
| `cloud-claude` | クラウド | Claude Code の定期のタスク | `<アカウントの呼び名>` | 受付の起票だけ（毎時。[templates/cloud-intake.md](templates/cloud-intake.md)）。担当の主張・作業対象のリポジトリの操作はしない | 使うときだけ残す。GitHub: `/web-setup`（`<GitHub のアカウント>`）か Claude GitHub App。commit の作者は `Claude <noreply@anthropic.com>`（メッセージの `[cloud-claude]` で分ける） |

- 新しい PC・道具を足したら、ここに 1 行足す（エージェントが `/auto-loop setup` で足してもよい）
- 「AI のアカウント」は利用枠の単位。同じアカウントのエージェントは枠を分け合うので、同時に大きな作業をさせない。空・例のままなら、Claude のエージェント（道具が Claude Code・ID に `claude`）は別の PC でも全部同じアカウントとみなす。別のアカウントを使い分けるときだけ、**すべての Claude の行に**呼び名を書く（書いた行と空の行は別のアカウントになる）
- git ホスト（GitHub / GitLab）のアカウントは、案件ごとに `projects/<案件>/project.md` の表に書く
