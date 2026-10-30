# check-encoding — マニュアル

## 1. 前提

| 項目 | 内容 |
|---|---|
| 対象 | Claude Code（CLI / VS Code 拡張 / デスクトップアプリ） |
| 検証環境 | Windows 11 Pro / PowerShell 5.1 と 7.x / Python 3.14 / Git Bash |
| 文字コード | すべて UTF-8。`.ps1` は **BOM 必須**、`.sh` は **BOM 禁止・改行 LF** |
| 前提ツール | Python 3.x |

## 2. 収録物

| パス | サイズ | 役割 |
|---|---|---|
| `docs/text-encoding.md` | 6.8 KB | 詳細編（常時ロードしない参照ドキュメント） |
| `scripts/check-encoding.py` | 7.0 KB | Python スクリプト |

## 3. 導入手順

```sh
mkdir -p .claude/scripts
cp -r scripts/* .claude/scripts/
```

## 4. 内容の構成

本体（`docs/text-encoding.md`）の見出し構成:

- 1. 検証コマンド
- 2. 種別ごとの要件
- 3. 書き込み手段ごとの落とし穴
- 4. 検出できない・しにくいもの
- 5. git 側の防御と、その限界
- 6. 実測した事例

## 5. 導入後の検証

```sh
python -m py_compile scripts/check-encoding.py
echo "exit=$?"
```

## 6. 既知の制約

- 既知の制約なし（切り出し元の記録に基づく）

## 7. 出典と経緯

| 項目 | 内容 |
|---|---|
| 切り出し元 | `claudecode-pm-starter-kit` / `.claude/scripts/check-encoding.py` |
| 元の格納先 | `.claude/scripts/check-encoding.py` |
| 出典 | 本リポジトリ独自 |
| 公開区分 | 🟢 公開可（本リポジトリ独自） |

### 作成の経緯（切り出し元の記録より）

**失敗起点。** 2026-09-03〜04 に文字コード起因の失敗が **3 件連続**した（ADR-050）: ① `wizard/template.sh` 全 204 行が CRLF で Git Bash から実行不能（`bash -n` は終了コード 0 で通った） ② BOM 無し `.ps1` を PowerShell 5.1 が cp932 として読み **192 回の実測ジョブが起動直後に全滅** ③ heredoc 内のバックスラッシュ解釈でコード例が 2 行に割れた。**3 件の共通点は「書いた直後には気づけず、実行して初めて壊れる」**であり、規約の文言追加では防げないと判断して検査を機械化した

## 8. 公開前チェック

このパッケージを GitHub で公開する前に、次を確認する。

1. `LICENSE` の著作権表示が `Copyright 2026 YA` になっていること（切り出し時に記入済み。切り出し元の `LICENSE` は雛形のままなので、再生成時はこの置換が効いているか確認する）
2. 本文に組織固有の情報（顧客名・社内システム名・社内文書の内部構造・個人情報）が残っていないか
3. 第三者由来の場合、原典の LICENSE 同梱と帰属表示が保たれているか
4. 元リポジトリのパスへの参照（README の「単体利用時の注意」）を読み替え済みか
