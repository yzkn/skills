# 計画テンプレート

`improve-animations` が書き出すすべての計画は、この構造に従う。実行者は文脈を一切持たず、審美眼も持たない、より非力なモデルである可能性がある — 計画にはすべてを正確に含めなければならない。「上の監査結果を参照」「先ほど議論したイージング」のような記述は禁止。

```markdown
# NNN — <簡潔な命令形のタイトル>

- **Status**: TODO
- **Commit**: <この計画を書いた時点の `git rev-parse --short HEAD` の出力>
- **Severity**: HIGH | MEDIUM | LOW
- **Category**: <監査カテゴリ>
- **Estimated scope**: <対象ファイル数、おおよその規模>

## Problem

何が、どこで、なぜ問題なのか。プロダクトの手触りにどう影響するか。すべての
箇所を `path/to/file.tsx:123` の形式で引用し、現状のコードをそのまま含める。

```css
/* src/components/dropdown.css:14 — current */
.dropdown { transition: all 400ms ease-in; }
```

## Target

正確な最終状態。カーブ・duration・spring 設定・メディアクエリなど、すべての
値を明記する。「もっと良いイージングを使う」のような曖昧な表現は禁止。

```css
/* target */
.dropdown {
  transition: transform 200ms var(--ease-out), opacity 200ms var(--ease-out);
  transform-origin: var(--radix-dropdown-menu-content-transform-origin);
}
```

## Repo conventions to follow

このコードベースが既にどうやっているか。実行者が模倣すべき模範例を 1 つ
添える（トークン名、ファイル配置、prop パターン）。

- Easing tokens live in `src/styles/tokens.css`; add new curves there, e.g. `--ease-out: cubic-bezier(0.23, 1, 0.32, 1);`
- <既にこれを正しく行っている模範例の file:line>

## Steps

1. <1 ステップにつき 1 つの具体的な編集: ファイル、変更内容、結果となるコード>
2. …

## Boundaries

- <スコープ外のファイル／コンポーネント> には触れないこと。
- マークアップ・構造は変更しないこと — 手順で明示されない限り、モーション関連のプロパティのみを変更する。
- 新しい依存関係を追加しないこと。
- ある手順が実際のコードと一致しない場合（コミットスタンプ以降にコードが変わっている等）は、独自に判断して進めず、STOP して報告すること。

## Verification

- **Mechanical**: <型チェック・lint・ビルドなど、期待される結果を伴う正確なコマンド>。
- **Feel check**: UI を実行し、<インタラクション> を発生させて以下を確認する。
  - <目視で確認できる項目、例:「ドロップダウンが中心ではなくトリガーから scale する」>
  - <例:「トグルを連打してもアニメーションがゼロから再スタートしない」>
  - DevTools の再生速度を 10%（Animations パネル）に設定し、<詳細> を確認する。
  - `prefers-reduced-motion` を切り替え（Rendering パネル）、動きが取り除かれつつ opacity によるフィードバックは残ることを確認する。
- **Done when**: <機械的または目視で確認できる完了基準>。
```

## 計画作成者向けの注意事項

- 所見 1 件につき計画 1 つ。2 つの所見が同じファイル・同じ修正パターン（例: 複数コンポーネントにまたがる同一のイージングトークンの置き換え）を共有する場合は、1 つの計画に統合してよい。
- すべての値は [AUDIT.md](AUDIT.md) から引用すること — 記憶から近似しないこと。
- feel check は省略できない。モーションは機械的には正しくても手触りが誤っていることがある。実行者（またはその diff をレビューする人間）に、スローモーションで確認すべき具体的なポイントを与えること。
- 計画を書き終えたら、`report/ux/animation-plans/README.md` を作成または更新する。内容は計画の表（番号・タイトル・重要度・ステータス）、推奨実行順序、計画間の依存関係とする。
