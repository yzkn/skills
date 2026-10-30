# Claude Code カスタム資産パッケージ — 索引

切り出し元: `claudecode-pm-starter-kit`（非公開。コミット b2af8d1）

各パッケージは `packages/<slug>/` にあり、`README.md`・`MANUAL.md`・`LICENSE`（または `LICENSE-KIT`）・資産の実体を持つ。導入手順は各パッケージの `README.md` にある。

## 件数

| 種別 | パッケージ数 |
|---|---:|
| Claude Code スキル | 61 |
| Claude Code サブエージェント | 21 |
| Claude Code ルール（CLAUDE.md から読み込む規約） | 16 |
| Claude Code フック | 5 |
| 共有スクリプト | 9 |
| Git フック | 1 |
| **合計** | **113** |

## 公開区分

| 区分 | 件数 | 意味 |
|---|---:|---|
| 🟢 公開可（独自） | 77 | 切り出し元の Apache-2.0 を継承。著作権表示は Copyright 2026 YA（記入済み） |
| 🟢 公開可（第三者由来） | 36 | permissive。原典 LICENSE の同梱と帰属表示が必須 |

## Claude Code スキル

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-skill-16minds`](packages/claude-skill-16minds/) | `.claude/skills/16minds/` | 🟢 第三者由来 | 18 | 16 タイプの人格エージェントに議論・レビュー・助言をさせる。`/16minds mind <type> <お題>` / `pair <a> <b> <お題>` / `all <お題>`。明示的に呼び出したときだけ動作し、自動適用しない。3 |
| [`claude-skill-anti-slop-review`](packages/claude-skill-anti-slop-review/) | `.claude/skills/anti-slop-review/` | 🟢 第三者由来 | 3 | 生成 UI が「AI が作った見た目（AI slop）」になっていないか診断する読み取り専用の監査。「AI っぽくないか見て」「AI slop を監査して」で自動適用。/anti-slop-review [対象]。品質レビューは ux-re |
| [`claude-skill-api-guide`](packages/claude-skill-api-guide/) | `.claude/skills/api-guide/` | 🟢 独自 | 1 | RESTful API の設計規約を参照するスキル。API 設計・実装・レビュー時に呼び出す。 |
| [`claude-skill-app-theme-proposer`](packages/claude-skill-app-theme-proposer/) | `.claude/skills/app-theme-proposer/` | 🟢 独自 | 2 | アプリ実装テーマ提案スキル。「何を作るか決まっていない」ユーザーに 5 問ヒアリングし、テーマ候補を比較表で提示する。確定後は仕様書とワイヤーフレームを design/ に生成する。/app-theme-proposer [テーマ名または要 |
| [`claude-skill-apple-design`](packages/claude-skill-apple-design/) | `.claude/skills/apple-design/` | 🟢 第三者由来 | 2 | Apple のインターフェースデザインと物理的なモーションを Web に翻案した実装・レビュー指針。「Apple 風の UI を設計して」「モーションを診断して」で自動適用。/apple-design [対象]。 |
| [`claude-skill-auto-resume`](packages/claude-skill-auto-resume/) | `.claude/skills/auto-resume/` | 🟢 独自 | 1 | 5 時間のセッションリミット（429）で中断した作業を、解除時刻に自動で再開できる状態にする。「リミットが解けたら自動で続けて」「セッションが切れても再開したい」「自動再開の状態を見せて」で自動適用。/auto-resume <status |
| [`claude-skill-bulk-ops`](packages/claude-skill-bulk-ops/) | `.claude/skills/bulk-ops/` | 🟢 第三者由来 | 3 | 多数ファイル（目安 10 件以上）の一括解析・一括改名・一括置換をスクリプトで完結させ、要約だけをコンテキストに載せる。「まとめてリネームして」「一括削除して」で自動適用。/bulk-ops <サブコマンド>。書き込みは dry-run→承 |
| [`claude-skill-citation-format`](packages/claude-skill-citation-format/) | `.claude/skills/citation-format/` | 🟢 第三者由来 | 2 | 外部ソースの引用書式規約（引用ブロック・文中参照・典拠一覧）。design/・report/ 配下では自動適用される。「引用の書き方」「典拠一覧を作って」で呼び出す。/citation-format。 |
| [`claude-skill-code-refactor`](packages/claude-skill-code-refactor/) | `.claude/skills/code-refactor/` | 🟢 独自 | 6 | コードの外部的な振る舞いを変えずに内部構造を改善するスキル。/project-code-review の指摘事項を受けて呼び出されるほか、単独でも使用できる。 |
| [`claude-skill-container`](packages/claude-skill-container/) | `.claude/skills/container/` | 🟢 第三者由来 | 5 | Containerfile / Dockerfile・compose.yaml・.dockerignore を Podman 前提で作成・レビューする（マルチステージ・キャッシュ・非 root・ヘルスチェック）。「コンテナ化して」「Dock |
| [`claude-skill-context-engineering`](packages/claude-skill-context-engineering/) | `.claude/skills/context-engineering/` | 🟢 第三者由来 | 2 | Claude に渡す情報を意図的に絞り、トークン消費と出力品質を同時に改善する。「コンテキストを整理して」「トークンを減らしたい」「途中から精度が落ちてきた」で自動適用。/context-engineering。 |
| [`claude-skill-db-review`](packages/claude-skill-db-review/) | `.claude/skills/db-review/` | 🟢 第三者由来 | 4 | DB 設計（スキーマ・テーブル定義・マイグレーション）のアンチパターンを深刻度別に検出する。「DB 設計をレビューして」「スキーマをチェックして」で自動適用。/db-review [対象パス]。新規設計は data-modeler。 |
| [`claude-skill-deploy-guide`](packages/claude-skill-deploy-guide/) | `.claude/skills/deploy-guide/` | 🟢 独自 | 1 | CI/CD パイプラインとデプロイメント方針を参照するスキル。デプロイ・リリース作業時に呼び出す。 |
| [`claude-skill-deprecation-migration`](packages/claude-skill-deprecation-migration/) | `.claude/skills/deprecation-migration/` | 🟢 第三者由来 | 2 | 旧システム・API・機能の廃止と移行を計画・実行する。「移行計画を作って」「この機能を廃止したい」「カラム名を安全に変えたい」で自動適用。/deprecation-migration [対象]。 |
| [`claude-skill-design-dna`](packages/claude-skill-design-dna/) | `.claude/skills/design-dna/` | 🟢 第三者由来 | 2 | 参考 Web デザインのスクリーンショットまたは URL から「デザイン DNA」（構造・アーキタイプ・タイポ・カラー・リズム）を抽出し、骨格として転用できる形で診断する。「この参考サイトを分析して」で自動適用。/design-dna <U |
| [`claude-skill-design-md`](packages/claude-skill-design-md/) | `.claude/skills/design-md/` | 🟢 第三者由来 | 5 | デザイントークンを DESIGN.md（Google Labs 仕様）として作成・検証・取り込みする。「DESIGN.md を作って」「デザイントークンを整理して」「DESIGN.md を検証して」で自動適用。/design-md <new |
| [`claude-skill-design-sync`](packages/claude-skill-design-sync/) | `.claude/skills/design-sync/` | 🟢 独自 | 1 | 新情報（議事録・追加資料・意思決定）を設計書と WBS に反映する。差分を提示し、合意後に反映する（合意前に既存ファイルを変更しないことが鉄則）。「議事録から設計書を更新して」「sync して」で自動適用。/design-sync。 |
| [`claude-skill-document-review`](packages/claude-skill-document-review/) | `.claude/skills/document-review/` | 🟢 独自 | 2 | 指定したドキュメントをレビューし、品質・完全性・整合性の観点から構造化されたフィードバックを提供する。「レビューして」「確認して」「ドキュメントをチェックして」などのリクエストがあった場合に自動で適用される。 |
| [`claude-skill-domain-modeling`](packages/claude-skill-domain-modeling/) | `.claude/skills/domain-modeling/` | 🟢 第三者由来 | 2 | ドメインモデル（ユビキタス言語・用語集）を構築・精緻化する。「用語集を作って」「用語を統一して」「用語がぶれている」で自動適用。/domain-modeling。正本は design/GLOSSARY.md。 |
| [`claude-skill-drawio`](packages/claude-skill-drawio/) | `.claude/skills/drawio/` | 🟢 第三者由来 | 63 | 顧客が編集できる .drawio 図（UML・ER・BPMN・C4・クラウド構成等）を生成する。「draw.io の図を作って」「編集できる構成図が欲しい」で自動適用。/drawio <対象>。Mermaid の画像化は pretty-me |
| [`claude-skill-explainer-html`](packages/claude-skill-explainer-html/) | `.claude/skills/explainer-html/` | 🟢 第三者由来 | 6 | 概念・仕組み・調査結果を説明する自己完結 HTML 文書を作成・編集する。「HTML の解説文書を作って」「説明ページにして」で自動適用。/explainer-html <対象>。図 1 点だけなら visual-doc。 |
| [`claude-skill-file-lock`](packages/claude-skill-file-lock/) | `.claude/skills/file-lock/` | 🟢 独自 | 1 | 編集・削除すべきでないファイルを OS レベルでロック・解除・状態確認する。「ファイルをロックして」「編集禁止にして」「ロックを解除して」で自動適用。/file-lock <lock\|unlock\|status> [パス...]。 |
| [`claude-skill-find-animation-opportunities`](packages/claude-skill-find-animation-opportunities/) | `.claude/skills/_disabled/find-animation-opportunities/` | 🟢 第三者由来 | 2 | コードベースや UI を調査し、アニメーションが入っていないが入れるべき箇所を洗い出し、不要な箇所は明確に却下するスキル。読み取り専用であり、正確な数値を伴う motion の提案は行うが実装はしない。「どこにアニメーションを入れられる?」 |
| [`claude-skill-ghostwriter`](packages/claude-skill-ghostwriter/) | `.claude/skills/ghostwriter/` | 🟢 独自 | 3 | 文章執筆ガイドラインに基づいてドキュメント・プレゼンテーション資料をゴーストライティングする。「文章を書いて」「資料を作って」「代わりに書いて」「下書きを整形して」などのリクエストで自動適用される。 |
| [`claude-skill-governance`](packages/claude-skill-governance/) | `.claude/skills/governance/` | 🟢 独自 | 1 | Power Platform ガバナンス管理案件の目的・用語・標準作業項目・成果物テンプレートを提供する。「ガバナンス管理」「ガバナンス案件」で自動適用、または /governance。 |
| [`claude-skill-grill`](packages/claude-skill-grill/) | `.claude/skills/grill/` | 🟢 第三者由来 | 2 | 作業開始前に計画・設計・要求を 1 問ずつの質問で精緻化する。「質問攻めにして」「壁打ちして」「計画を詰めて」で自動適用。/grill [トピック]。設計判断の記録は /record adr。 |
| [`claude-skill-handoff`](packages/claude-skill-handoff/) | `.claude/skills/handoff/` | 🟢 第三者由来 | 3 | 現在の会話を、別セッション・別担当が続きを引き継げる文書に圧縮する。「引き継ぎ資料を作って」「別のセッションに渡したい」で自動適用。/handoff [次にやること]。不変の証跡は record、リミット中断からの復帰は auto-resu |
| [`claude-skill-improve-animations`](packages/claude-skill-improve-animations/) | `.claude/skills/_disabled/improve-animations/` | 🟢 第三者由来 | 4 | シニアモーションアドバイザーとしてコードベースのアニメーション・モーション実装を調査し、優先順位付けされた監査結果と、他のエージェント（または安価なモデル）が実行できる自己完結型の実装計画を作成する。ソースコードに対しては読み取り専用 —  |
| [`claude-skill-lint`](packages/claude-skill-lint/) | `.claude/skills/lint/` | 🟢 独自 | 2 | コーディング規約への準拠をチェックする。静的解析ツールを優先実行し、ツールで検出できない点を補足する。「lint して」「規約チェックして」で自動適用。構造的レビューは /project-code-review。 |
| [`claude-skill-long-run`](packages/claude-skill-long-run/) | `.claude/skills/long-run/` | 🟢 独自 | 10 | 5 時間のセッションリミットを超えうる長時間処理を、OS 側に detach した自走・再開可能なジョブとして起動する。「セッションが切れても続く形で走らせて」「時間のかかるビルドを流して」で自動適用。/long-run <コマンド> [- |
| [`claude-skill-natural-japanese`](packages/claude-skill-natural-japanese/) | `.claude/skills/natural-japanese/` | 🟢 第三者由来 | 24 | 日本語の自然さ・読みやすさを lint で機械検出して直す。「AI っぽくない日本語にして」「読みやすく直して」で自動適用。/natural-japanese [write\|score] [quick\|full] <対象>。社内文書の型と表 |
| [`claude-skill-newcomer-guide`](packages/claude-skill-newcomer-guide/) | `.claude/skills/newcomer-guide/` | 🟢 独自 | 3 | 社内文書を、IT や業務の知識がない新人でもわかるレベルまで噛み砕いて解説する。「わかりやすく説明して」「噛み砕いて」「読んでも意味がわからない」など理解が目的の依頼で発動。/newcomer-guide [テキストまたはパス]。 |
| [`claude-skill-office`](packages/claude-skill-office/) | `.claude/skills/office/` | 🟢 独自 | 1 | Word・Excel・PowerPoint・PDF の読み書きを行う。「Excel を読んで」「Word に書いて」「PowerPoint を作って」等の製品名、または .docx / .xlsx / .pptx / .csv / .pdf |
| [`claude-skill-office-pandoc`](packages/claude-skill-office-pandoc/) | `.claude/skills/office-pandoc/` | 🟢 独自 | 2 | Markdown を pandoc で Word（.docx）/ PowerPoint（.pptx）へ一括変換する。「Word に変換して」「設計書を納品用 Word にして」で自動適用。/office-pandoc <入力md> [--t |
| [`claude-skill-pretty-mermaid`](packages/claude-skill-pretty-mermaid/) | `.claude/skills/pretty-mermaid/` | 🟢 第三者由来 | 16 | 既存の Mermaid 記法を静的な SVG に描画する。主用途は design/ の図を Word・PowerPoint・PDF の納品物へ載せること。「Mermaid を画像にして」「納品用に図を焼き込んで」で自動適用。/pretty- |
| [`claude-skill-project-code-review`](packages/claude-skill-project-code-review/) | `.claude/skills/project-code-review/` | 🟢 独自 | 1 | 実装フェーズのコードレビュー（本プロジェクト規約準拠）。「コードレビューして」「このコード見て」「PR チェックして」で自動適用。規約の機械的チェックは /lint、設計原則は /se-principles。組み込みの /code-revi |
| [`claude-skill-project-dashboard`](packages/claude-skill-project-dashboard/) | `.claude/skills/project-dashboard/` | 🟢 独自 | 1 | プロジェクトの現在状況（フェーズ進捗・WBS・課題・意思決定・未確定事項）を単一 HTML ダッシュボードに可視化する。「進捗を見える化して」「今の状況をまとめて見せて」で自動適用。/project-dashboard。 |
| [`claude-skill-receiving-code-review`](packages/claude-skill-receiving-code-review/) | `.claude/skills/receiving-code-review/` | 🟢 第三者由来 | 3 | 受け取ったレビュー指摘を、空返事にも鵜呑みにもせず、コードベースの事実に照らして検証してから実装する。`/receiving-code-review` で呼び出す。明示的に呼び出したときだけ動作し、自動適用しない。レビューする側は proj |
| [`claude-skill-record`](packages/claude-skill-record/) | `.claude/skills/record/` | 🟢 独自 | 1 | 会話内容を doc/prompt/ と doc/thought/ に記録するスキル。/record adr でアーキテクチャ意思決定を doc/adr/ に ADR として記録する。 |
| [`claude-skill-release-guide`](packages/claude-skill-release-guide/) | `.claude/skills/release-guide/` | 🟢 独自 | 1 | セマンティックバージョニングとリリース手順を参照するスキル。バージョン番号の決定・タグ付け・リリース作業時に呼び出す。 |
| [`claude-skill-research`](packages/claude-skill-research/) | `.claude/skills/research/` | 🟢 第三者由来 | 3 | 特定トピックの詳細調査を行う。「調べて」「リサーチして」「詳しく教えて」「情報収集して」で自動適用。一次情報を優先し、情報源の信頼性を評価してレポートを作成する。/research <トピック>。 |
| [`claude-skill-resolve-merge-conflicts`](packages/claude-skill-resolve-merge-conflicts/) | `.claude/skills/resolve-merge-conflicts/` | 🟢 第三者由来 | 2 | 進行中の git merge / rebase / cherry-pick のコンフリクトを解消する。「コンフリクトを解消して」「マージが衝突した」「rebase が止まった」で自動適用。/resolve-merge-conflicts。 |
| [`claude-skill-review-animations`](packages/claude-skill-review-animations/) | `.claude/skills/_disabled/review-animations/` | 🟢 第三者由来 | 3 | Emil Kowalski のデザインエンジニアリング哲学に基づく高いクラフト基準で、アニメーション・モーションのコードをレビューする。デフォルトは指摘（flag）であり、承認（approval）は勝ち取るもの。「アニメーションをレビューし |
| [`claude-skill-se-principles`](packages/claude-skill-se-principles/) | `.claude/skills/se-principles/` | 🟢 独自 | 2 | SOLID・DRY・KISS・YAGNI・Clean Architecture 等のソフトウェア工学原理原則に基づいて設計・実装を行い、または原則への適合を検証するスキル。/se-principles [check <パス> \| desig |
| [`claude-skill-security-review`](packages/claude-skill-security-review/) | `.claude/skills/security-review/` | 🟢 独自 | 1 | 現在のブランチの変更差分にセキュリティレビューを実施する。「セキュリティレビューして」「脆弱性チェックして」で自動適用。OWASP Top 10 2021 の診断は owasp-check に委任する。 |
| [`claude-skill-slides-maker`](packages/claude-skill-slides-maker/) | `.claude/skills/slides-maker/` | 🟢 独自 | 9 | 自然言語プロンプトからコンサルティング品質の PowerPoint (.pptx) を生成する。2 エンジン・テーマ切り替えに対応。/slides-maker <プロンプト> [--engine <名前>] [--theme <名前>]。 |
| [`claude-skill-source-driven-development`](packages/claude-skill-source-driven-development/) | `.claude/skills/source-driven-development/` | 🟢 第三者由来 | 2 | フレームワーク固有の実装を記憶で書かず、公式ドキュメントで裏取りして出典付きで書く。「公式ドキュメントを確認して実装して」「最新の書き方で書いて」「この API は本当に存在する？」で自動適用。/source-driven-developm |
| [`claude-skill-source-extract`](packages/claude-skill-source-extract/) | `.claude/skills/source-extract/` | 🟢 独自 | 1 | 顧客受領資料・議事メモを要約せず全文抽出する（PDF / pptx / docx / xlsx / テキスト）。「資料を全文抽出して」「議事録を取り込んで」で自動適用。/source-extract [対象パス]。 |
| [`claude-skill-split-pr`](packages/claude-skill-split-pr/) | `.claude/skills/split-pr/` | 🟢 第三者由来 | 2 | 大きすぎる変更を PR の鎖に分割する（1 PR 300 行上限・1 PR = 1 機能 + テスト）。「PR が大きすぎる」「変更を分割して」で自動適用。/split-pr [対象ブランチ]。push と PR 作成はユーザーが実行する。 |
| [`claude-skill-systematic-debugging`](packages/claude-skill-systematic-debugging/) | `.claude/skills/systematic-debugging/` | 🟢 第三者由来 | 7 | 修正着手前に根本原因を確定させる 4 フェーズの規律。「原因が分からない」「直したのに再発する」「とりあえず動くようにした」で自動適用。/systematic-debugging [症状]。実行して特定するのは debugger、本番障害は |
| [`claude-skill-tdd`](packages/claude-skill-tdd/) | `.claude/skills/tdd/` | 🟢 第三者由来 | 4 | レッド→グリーン→リファクタのループで機能追加・バグ修正を行う。「TDDで実装して」「テストファーストで進めて」「失敗するテストから書いて」で自動適用。/tdd [対象]。後付けのテスト生成は unit-test-gen、実行は unit- |
| [`claude-skill-to-questionnaire`](packages/claude-skill-to-questionnaire/) | `.claude/skills/to-questionnaire/` | 🟢 第三者由来 | 3 | 自分だけでは決められない事項を、相手に記入してもらう質問票（Markdown）に変換する。「顧客に確認したいことを整理して」「ヒアリングシートを作って」で自動適用。/to-questionnaire [トピック]。自分に問うのは grill |
| [`claude-skill-tool-environment`](packages/claude-skill-tool-environment/) | `.claude/skills/tool-environment/` | 🟢 独自 | 10 | 外部コマンドを実行する前に必ず確認する。呼び出し方・格納パス・文字コード・未導入時の導入手順をキャッシュから解決する。「pip が見つからない」「pandoc が無い」「文字化けする」でも参照。 |
| [`claude-skill-trouble-shoot`](packages/claude-skill-trouble-shoot/) | `.claude/skills/trouble-shoot/` | 🟢 独自 | 1 | トラブルシューティング支援スキル。「トラブルシューティング」「障害調査」「問い合わせ対応」「事象の調査」などのリクエストで自動適用。/trouble-shoot <問い合わせ内容> で直接呼び出しも可能。 |
| [`claude-skill-ui-ux-pro-max`](packages/claude-skill-ui-ux-pro-max/) | `.claude/skills/ui-ux-pro-max/` | 🟢 第三者由来 | 40 | UI/UX デザインインテリジェンス。スタイル・パレット・フォントペアリング・UX ガイドラインを検索提供する。「配色を提案して」「フォントを選んで」「デザインシステムを生成して」で自動適用。/ui-ux-pro-max <キーワード>。 |
| [`claude-skill-unit-test-gen`](packages/claude-skill-unit-test-gen/) | `.claude/skills/unit-test-gen/` | 🟢 独自 | 2 | ソースコードを解析し、単体テストケースを自動生成するスキル。「テストを書いて」「テストケースを生成して」「このコードのテストを作って」などのリクエストがあった場合に自動で適用される。 |
| [`claude-skill-unit-test-run`](packages/claude-skill-unit-test-run/) | `.claude/skills/unit-test-run/` | 🟢 独自 | 1 | 単体テストを実行し、結果を報告するスキル。「テストを実行して」「テストを走らせて」「テスト結果を確認して」などのリクエストがあった場合に自動で適用される。 |
| [`claude-skill-ux-writing`](packages/claude-skill-ux-writing/) | `.claude/skills/ux-writing/` | 🟢 第三者由来 | 4 | UI コピー（マイクロコピー）の執筆・レビュー。「ボタンの文言を考えて」「エラーメッセージを書いて」で自動適用。/ux-writing [対象]。文書執筆は ghostwriter。 |
| [`claude-skill-visual-doc`](packages/claude-skill-visual-doc/) | `.claude/skills/visual-doc/` | 🟢 第三者由来 | 6 | 設計書・レポートに添える自己完結 HTML の図をインライン SVG で生成する。「構成図を作って」「フロー図にして」「ガントチャートを描いて」で自動適用。/visual-doc <モード> [対象]。プロジェクト状況は project-d |
| [`claude-skill-vnl`](packages/claude-skill-vnl/) | `.claude/skills/vnl/` | 🟢 独自 | 14 | ハッシュ・Base64・UUID・JWT・コントラスト比・検査数字・形式変換・テストデータ・cron の次回実行時刻・営業日計算をローカルのスクリプトで算出する。「ハッシュ値を出して」「3 営業日後はいつ」で自動適用。/vnl <群> <サ |
| [`claude-skill-wizard`](packages/claude-skill-wizard/) | `.claude/skills/wizard/` | 🟢 第三者由来 | 4 | 人間にしか実行できない手順（認証情報の発行・CI シークレット設定・外部ポータル操作・一度きりの移行）を、画面を追って進む対話式スクリプトに書き起こす。「セットアップ手順をスクリプト化して」で自動適用。/wizard [対象]。Claude |

## Claude Code サブエージェント

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-agent-api-spec-generator`](packages/claude-agent-api-spec-generator/) | `.claude/agents/api-spec-generator.md` | 🟢 独自 | 1 | API 仕様書生成エージェント。既存のコントローラー・ルーター・DTO から OpenAPI 3.0 仕様書（YAML）を逆生成する。api-guide が設計規約の参照であるのに対し実装済みコードの仕様書化を担う。 |
| [`claude-agent-app-theme-proposer`](packages/claude-agent-app-theme-proposer/) | `.claude/agents/app-theme-proposer.md` | 🟢 独自 | 1 | アプリ実装テーマ提案エージェント。「何を作るか決まっていない」ユーザーに 5 問ヒアリングし、テーマ候補を比較表で提示する。確定後は仕様書とワイヤーフレームを生成する。コードは変更しない。 |
| [`claude-agent-code-reviewer`](packages/claude-agent-code-reviewer/) | `.claude/agents/code-reviewer.md` | 🟢 独自 | 1 | 読み取り専用のコードレビュー専門エージェント。未コミット・未追跡の変更または指定パスを Critical / Warning / Suggestion の 3 段階で指摘する。ユーザーからの依頼は /project-code-review  |
| [`claude-agent-complexity-analyzer`](packages/claude-agent-complexity-analyzer/) | `.claude/agents/complexity-analyzer.md` | 🟢 独自 | 1 | コード複雑度診断エージェント。循環的複雑度・認知的複雑度・クラスサイズ・ネスト深度を静的解析し、閾値超過箇所を優先度付きで一覧化する。perf-analyzer の性能リスクに対し保守性リスクを担う。 |
| [`claude-agent-compliance-checker`](packages/claude-agent-compliance-checker/) | `.claude/agents/compliance-checker.md` | 🟢 独自 | 2 | コンプライアンス診断エージェント。個人情報保護法・GDPR・PCI DSS 等の規制要件および ISO 27001 / SOC 2 への適合状況を静的診断する。owasp-check・riss-ioqeo の技術的観点に対し法的観点を担う。 |
| [`claude-agent-data-modeler`](packages/claude-agent-data-modeler/) | `.claude/agents/data-modeler.md` | 🟢 独自 | 2 | データモデリングエージェント。ER 図設計・テーブル定義書・正規化アドバイス・マイグレーション案を作成する。system-architect が上位構成を扱うのに対しテーブル・スキーマ設計に特化。 |
| [`claude-agent-debugger`](packages/claude-agent-debugger/) | `.claude/agents/debugger.md` | 🟢 独自 | 1 | デバッグ実施エージェント。テスト実行・ログ/スタックトレース解析でバグを特定し、修正案をチャットに提示する（コードは自動適用しない）。subagent_type:'debugger' で呼び出す。 |
| [`claude-agent-dependency-auditor`](packages/claude-agent-dependency-auditor/) | `.claude/agents/dependency-auditor.md` | 🟢 独自 | 2 | 依存関係診断エージェント（SCA）。依存定義ファイルから既知 CVE・ライセンスリスク・EOL パッケージを診断し、owasp-check・riss-ioqeo が扱わないライブラリ自体のリスクを補完する。 |
| [`claude-agent-iac-reviewer`](packages/claude-agent-iac-reviewer/) | `.claude/agents/iac-reviewer.md` | 🟢 独自 | 1 | IaC 設計・レビューエージェント。Terraform / Bicep / CloudFormation / Pulumi を対象に、IAM 過剰権限・暗号化欠如・ネットワーク過剰公開・コスト最適化を診断する。 |
| [`claude-agent-incident-responder`](packages/claude-agent-incident-responder/) | `.claude/agents/incident-responder.md` | 🟢 独自 | 2 | インシデント対応エージェント。障害ログから影響範囲を分析し、タイムライン整理・RCA・ポストモーテム・再発防止策を作成する。認証情報の漏えい・リポジトリの誤公開の初動手順も示す。debugger の開発中バグ修正に対し本番障害の事後分析を担 |
| [`claude-agent-observability-designer`](packages/claude-agent-observability-designer/) | `.claude/agents/observability-designer.md` | 🟢 独自 | 2 | 観測可能性設計エージェント。ログ設計・メトリクス設計・アラート閾値設計・分散トレーシング設計を担う。incident-responder の事後分析に対し、障害を早期検知できる設計を事前に行う。 |
| [`claude-agent-owasp-check`](packages/claude-agent-owasp-check/) | `.claude/agents/owasp-check.md` | 🟢 独自 | 2 | OWASP Top 10 2021 に基づく静的脆弱性診断エージェント。A01〜A10 の各カテゴリで診断し、CVSS v3.1 付きでレポートを保存して git コミットする。/security-review から自動的に呼ばれる。 |
| [`claude-agent-perf-analyzer`](packages/claude-agent-perf-analyzer/) | `.claude/agents/perf-analyzer.md` | 🟢 独自 | 2 | パフォーマンス診断エージェント。N+1 クエリ・未インデックスカラム・同期ブロッキング・大量メモリロード・キャッシュ欠如を静的解析で特定する。コードは修正せず改善案の提示にとどめる。 |
| [`claude-agent-requirements-analyst`](packages/claude-agent-requirements-analyst/) | `.claude/agents/requirements-analyst.md` | 🟢 独自 | 1 | 要件定義アナリスト。自然言語の要求をユーザーストーリー・受け入れ条件・業務フロー図に構造化し、曖昧な要件の指摘・MoSCoW 優先度付け・ユースケース記述を行う。 |
| [`claude-agent-riss-ioqeo`](packages/claude-agent-riss-ioqeo/) | `.claude/agents/riss-ioqeo.md` | 🟢 独自 | 2 | 情報処理安全確保支援士相当のセキュリティ診断エージェント。IPA セキュアプログラミング・徳丸本に基づき SC-01〜SC-07 を診断し、OWASP Top 10 で扱わない観点を担う。 |
| [`claude-agent-sprint-planner`](packages/claude-agent-sprint-planner/) | `.claude/agents/sprint-planner.md` | 🟢 独自 | 1 | スプリント計画エージェント。ストーリーポイント見積もり・タスク分解・スプリントバックログ整理・WBS 生成を行う。requirements-analyst の後工程を担う。subagent_type:'sprint-planner' で呼び |
| [`claude-agent-system-architect`](packages/claude-agent-system-architect/) | `.claude/agents/system-architect.md` | 🟢 独自 | 2 | システムアーキテクトエージェント。技術選定・システム構成設計・スケーラビリティ設計・セキュリティアーキテクチャ・再アーキテクチャ戦略を担う。設計フェーズではコードを変更しない。 |
| [`claude-agent-test-strategist`](packages/claude-agent-test-strategist/) | `.claude/agents/test-strategist.md` | 🟢 独自 | 2 | テスト戦略エージェント。テスト計画・結合/E2E テスト設計・テスト観点の網羅性診断を担う。unit-test-gen/run が扱わないテスト戦略全体を設計する。subagent_type:'test-strategist' で呼び出す。 |
| [`claude-agent-trouble-shooter`](packages/claude-agent-trouble-shooter/) | `.claude/agents/trouble-shooter.md` | 🟢 独自 | 2 | 障害発生中のリアルタイム調査を対話形式で 8 ステップで支援する。「トラブルシューティング」「障害調査」「問い合わせ対応」で呼び出す。本番環境は変更しない。事後分析は incident-responder。 |
| [`claude-agent-ui-designer`](packages/claude-agent-ui-designer/) | `.claude/agents/ui-designer.md` | 🟢 独自 | 2 | UI デザイナーエージェント。デザインシステム設計・高精度 HTML モックアップ・ビジュアル品質監査を担う。リサーチ・ワイヤーフレームは ux-designer。コードは修正しない。 |
| [`claude-agent-ux-designer`](packages/claude-agent-ux-designer/) | `.claude/agents/ux-designer.md` | 🟢 独自 | 2 | UX デザイナーエージェント。ユーザーリサーチ・UI/UX 設計・プロトタイプ・ユーザビリティテスト・アクセシビリティ改善を担う。コードは修正せず設計書・HTML モックアップの生成にとどめる。 |

## Claude Code ルール（CLAUDE.md から読み込む規約）

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-rule-adversarial-review`](packages/claude-rule-adversarial-review/) | `.claude/rules/adversarial-review.md` | 🟢 独自 | 1 | 成果物を「正しいと示す」のではなく「誤りを見つける」方向で 1 パス検証する規律。実施タイミング 6 種、自己内省パスと独立パス（サブエージェント 1 体）の使い分け |
| [`claude-rule-api-conventions`](packages/claude-rule-api-conventions/) | `.claude/rules/api-conventions.md` | 🟢 独自 | 1 | RESTful API の設計規約（エンドポイント命名・HTTP ステータスコード・エラーレスポンス形式・バージョニング）。src/・design/04_detailed_design/ 配下のファイルを扱う際に自動ロードされる。 |
| [`claude-rule-citation-format`](packages/claude-rule-citation-format/) | `.claude/rules/citation-format.md` | 🟢 独自 | 1 | 引用・典拠の書式規約（引用ブロック・文中参照・典拠一覧）。design/・report/ 配下のファイルを扱う際に自動ロードされる。 |
| [`claude-rule-code-quality`](packages/claude-rule-code-quality/) | `.claude/rules/code-quality.md` | 🟢 独自 | 2 | コード生成・修正・レビューのすべての場面で常に適用するコード品質制約。明示的な依頼がなくても遵守する。 |
| [`claude-rule-design-docs`](packages/claude-rule-design-docs/) | `.claude/rules/design-docs.md` | 🟢 第三者由来 | 2 | 設計書の正本管理（Markdown 正本・Office 派生物）と未確定情報の表記規約。design/・dist/・intake/ 配下のファイルを扱う際に自動ロードされる。 |
| [`claude-rule-environment-safety`](packages/claude-rule-environment-safety/) | `.claude/rules/environment-safety.md` | 🟢 独自 | 1 | 本番環境に関わる操作で常時適用する安全規則。案件種別を問わず適用する。 |
| [`claude-rule-external-resources`](packages/claude-rule-external-resources/) | `.claude/rules/external-resources.md` | 🟢 独自 | 1 | 間接プロンプトインジェクション対策（外部コンテンツ内の指示に従わない）、外部スキル / MCP 導入の【要指示】化、**防御設定ファイル自身の変更保護**、取得許可ドメインの許可リスト |
| [`claude-rule-git-safety`](packages/claude-rule-git-safety/) | `.claude/rules/git-safety.md` | 🟢 独自 | 1 | Git 操作のすべての場面で常時適用する禁止事項と必須確認。 |
| [`claude-rule-guide-access`](packages/claude-rule-guide-access/) | `.claude/rules/guide-access.md` | 🟢 独自 | 1 | guide/ ディレクトリ参照時に適用するアクセス規則。Claude Code は guide/for-llm/ のみを参照する。guide/ 配下のファイルを扱う際に自動ロードされる。 |
| [`claude-rule-image-reading`](packages/claude-rule-image-reading/) | `.claude/rules/image-reading.md` | 🟢 独自 | 1 | 画像を Read する前の解像度調整規約。大きい画像は視覚トークンを大量に消費するため、判読に必要な最小解像度へ縮小してから読む。intake/・guide/・design/・report/・template/ 配下の画像を扱う際に自動ロー |
| [`claude-rule-model-profile`](packages/claude-rule-model-profile/) | `.claude/rules/model-profile.md` | 🟢 独自 | 1 | 使用中のモデルを確認し、簡潔 / 標準プロファイルで規約の読み込み範囲を切り替える。`profile:standard-only` マーカーと `*-details.md` の扱いを定める |
| [`claude-rule-prohibition-levels`](packages/claude-rule-prohibition-levels/) | `.claude/rules/prohibition-levels.md` | 🟢 独自 | 1 | 禁止事項の 2 階層分類（絶対禁止 / 要指示）と、絶対禁止を指示された場合・違反に気づいた場合の必須行動。すべてのルールに優先して常時適用する。 |
| [`claude-rule-safe-file-ops`](packages/claude-rule-safe-file-ops/) | `.claude/rules/safe-file-ops.md` | 🟢 独自 | 2 | ファイル・ディレクトリを操作するすべての場面で常時適用する安全規則。 |
| [`claude-rule-security-hardstops`](packages/claude-rule-security-hardstops/) | `.claude/rules/security-hardstops.md` | 🟢 独自 | 1 | セキュリティに関わる絶対禁止事項。コード生成・ファイル操作・git 操作のすべての場面で適用する。 |
| [`claude-rule-third-party-licenses`](packages/claude-rule-third-party-licenses/) | `.claude/rules/third-party-licenses.md` | 🟢 独自 | 2 | 持ち込み前のライセンス確認義務、permissive のみ原則許可、コピーレフト / 商用制限付きは【要指示】、**ハルシネーションパッケージ（slopsquatting）対策**、作図アイコンの用途区分 |
| [`claude-rule-wbs-tasks`](packages/claude-rule-wbs-tasks/) | `.claude/rules/wbs-tasks.md` | 🟢 独自 | 1 | WBS・課題管理表の編集規約。ID 採番・依存関係の整合性・ステータス遷移と日付/進捗の連動を定義する。task/ 配下のファイルを扱う際に自動ロードされる。 |

## Claude Code フック

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-hook-auto-record`](packages/claude-hook-auto-record/) | `.claude/hooks/auto-record.ps1` | 🟢 独自 | 3 | 各会話ターン終了時にトランスクリプト `.jsonl` から user / assistant メッセージを抽出し、`doc/prompt/YYYYMMDD_HHMMSS_auto.proof.md` として保存して自動コミットする（1 フ |
| [`claude-hook-japanese-guard`](packages/claude-hook-japanese-guard/) | `.claude/hooks/japanese-guard.ps1` | 🟢 第三者由来 | 3 | Stop フック。そのターンの最終回答（最後のツール呼び出しより後の本文）が英語主体なら`decision: block` を返して終了させず、英語の箇所だけを日本語で書き直させる。差し戻しは 1 ターン 1 回（`stop_hook_ac |
| [`claude-hook-job-resume-check`](packages/claude-hook-job-resume-check/) | `.claude/hooks/job-resume-check.ps1` | 🟢 独自 | 3 | `.jobs/` に「完了済み（`exit.code` あり）かつ未報告（`collected` なし）」のジョブがある場合のみ、再開の指示を出力する |
| [`claude-hook-safety-net`](packages/claude-hook-safety-net/) | `.claude/hooks/safety-net.ps1` | 🟢 独自 | 3 | `.claude/rules/` の【絶対禁止】/【要指示】のうち機械的に判定できる操作（`git push`・証跡の編集 / 上書き・`guide/for-human/` の参照・`.env` の読取・再帰的強制削除）をツール実行前に d |
| [`claude-hook-session-resume-check`](packages/claude-hook-session-resume-check/) | `.claude/hooks/session-resume-check.ps1` | 🟢 独自 | 5 | ① `.resume/pending.json`（解除済みの未回収通知）があれば中断前の指示を出力する ② このセッション用の常駐ウォッチャーを起動する |

## 共有スクリプト

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-script-check-encoding`](packages/claude-script-check-encoding/) | `.claude/scripts/check-encoding.py` | 🟢 独自 | 2 | テキストファイルの文字コード（UTF-8）・改行コード・BOM を拡張子ごとの要件表に照らして検査する。ERROR で終了コード 1、`--fix` で BOM と改行を修正、ディレクトリ再帰対応 |
| [`claude-script-file-lock`](packages/claude-script-file-lock/) | `.claude/scripts/file-lock.ps1` | 🟢 独自 | 1 | 編集・削除すべきでないファイルを OS レベルでロックする（`FileShare.Read` で読み取りのみ許可） |
| [`claude-script-fix-bom`](packages/claude-script-fix-bom/) | `.claude/scripts/fix-bom.py` | 🟢 独自 | 1 | UTF-8 BOM を正確に 1 つ付与する（多重 BOM も正規化）。`check-encoding.py --fix` の BOM 部分だけを行う軽量版 |
| [`claude-script-long-run`](packages/claude-script-long-run/) | `.claude/scripts/long-run.ps1 / long-run.sh` | 🟢 独自 | 2 | 長時間ジョブのスキャフォールド生成エンジン。`.jobs/<id>/` に run / check / worker スクリプトと手順書を自己完結生成し、OS 側に detach して起動する |
| [`claude-script-measure-context`](packages/claude-script-measure-context/) | `.claude/scripts/measure-context.py` | 🟢 独自 | 1 | セッション開始時に常時ロードされるコンテキスト量（`CLAUDE.md` 群・`@` 行のルール・スキル / サブエージェントの `description`）を文字数で集計し、`description` の 200 文字超過を検出する。超過 |
| [`claude-script-office`](packages/claude-script-office/) | `.claude/scripts/office/` | 🟢 独自 | 26 | Office / PDF の読み取り。anydoc → markitdown → Docling の自動フォールバック |
| [`claude-script-pdf-extract-figures`](packages/claude-script-pdf-extract-figures/) | `.claude/scripts/pdf/` | 🟢 第三者由来 | 2 | PDF の `Figure N` / `Table N` を画像として切り出す（PyMuPDF） |
| [`claude-script-resume-watch`](packages/claude-script-resume-watch/) | `.claude/scripts/resume-watch.ps1 / _resume-watcher.ps1` | 🟢 独自 | 2 | セッションリミット（429）自動再開の制御 CLI と常駐ウォッチャー本体。`.jsonl` を 15 秒周期で追尾し、429 レコードを検出したら W1（自前待機）と W2（タスクスケジューラのワンショットタスク）の 2 系統で解除時刻を |
| [`claude-script-skill-eval`](packages/claude-script-skill-eval/) | `.claude/scripts/skill-eval/` | 🟢 独自 | 7 | スキルの `description` によるトリガー精度（発動すべき / すべきでない依頼文での発動率）を `claude -p` で実測するハーネス |

## Git フック

| パッケージ | 元の格納先 | 区分 | ファイル数 | 概要 |
|---|---|---|---:|---|
| [`claude-githook-pre-commit`](packages/claude-githook-pre-commit/) | `.githooks/pre-commit` | 🟢 独自 | 2 | ① gitleaks による機密情報検知（`.gitleaks.toml` の 136 行のルール・allowlist を使う。未導入なら終了コード 1 で停止し導入コマンドを表示） ② **不可視 Unicode 文字の検知**（ゼロ幅ス |

## 収録しなかったもの

| 対象 | 件数 | 理由 |
|---|---:|---|
| `.claude/skills/anthropics/` | 19 | Anthropic 公式スキル。**独自カスタマイズではない**。うち docx / pdf / pptx / xlsx / doc-coauthoring は source-available で**第三者への再配布が原典ライセンスで禁じられている**。Apache-2.0 のものは上流で公開済み |
| `.claude/docs/*.md` | 12 | 本テンプレートの索引・保守ガイドであり、単体で機能する資産ではない。参照しているパッケージの中に `docs/` として同梱した |
| `.claude/references/*-reference.md` | 14 | 対応するサブエージェントのパッケージに同梱した |
| `.claude/scripts/office/` の特定組織マスター向けサブディレクトリ・`node/` | — | 特定組織のスライドマスター依存と `node_modules` のため除外 |
| 初期化を促す SessionStart フック（Claude Code フック） | 1 | プロジェクト初期化スキル（これも収録しない）の実行を促すだけのフックで、単体では機能しない |
| AI 機能の UX デザインパターン集スキル（Claude Code スキル） | 1 | 参照ファイルが外部リポジトリの原文の収録で、原典にライセンスが無く再配布できない |
| 作図アイコンの検索・取得スキル（Claude Code スキル） | 1 | 社内資料に限って利用を許した外部アイコン（AGPL-3.0・CC BY-SA 4.0・表記なし）の扱いを前提にしており、公開配布では成り立たない |
| スライドマスター準拠の pptx 生成スキル（Claude Code スキル） | 1 | 特定組織のスライドマスターに忠実準拠する前提のスキルで、マスター自体を同梱できない |
| プロジェクト初期化スキル（Claude Code スキル） | 1 | 切り出し元テンプレートの初期化フロー（SETUP.md・PROJECT_UNINITIALIZED.md）に密結合で、単体では動かない |
| プロジェクト構成のセットアップスキル（Claude Code スキル） | 1 | 切り出し元テンプレートの標準ディレクトリ構造に密結合で、単体では動かない |
| UX リサーチ手法集スキル（Claude Code スキル） | 1 | 参照ファイルが外部リポジトリの原文の収録で、原典にライセンスが無く再配布できない |
| UX 品質レビュースキル（Claude Code スキル） | 1 | 参照ファイルが外部リポジトリの原文の収録で、原典にライセンスが無く再配布できない |
| `claude-script-office` の特定組織向けテーマ | 1 | 特定組織のスライドマスター（ロゴ・写真を含む）から作ったテーマのため除外 |
| `CLAUDE.md`・`.claude/CLAUDE.md`・`.claude/project-types/` | — | テンプレート全体の構成そのもので、単体項目として切り出せない |
