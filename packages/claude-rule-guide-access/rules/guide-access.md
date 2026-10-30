---
description: guide/ ディレクトリ参照時に適用するアクセス規則。Claude Code は guide/for-llm/ のみを参照する。guide/ 配下のファイルを扱う際に自動ロードされる。
paths:
  - "guide/**"
---

# guide/ ディレクトリのアクセス規則（パス条件付き適用）

## Claude Code は `guide/for-llm/` のみを参照する

- 【絶対禁止】**`guide/for-human/` の参照禁止**: `.docx` / `.xlsx` / `.pptx` 等の Office ファイルが格納されており、Read ツールで読み込むとトークンを大量消費する。ユーザーから指定された場合を含め、Claude Code はこのディレクトリを参照してはならない（`.claude/rules/prohibition-levels.md` 参照）
- **`guide/for-llm/` を使用する**: `guide/for-human/` の内容は事前に Markdown へ変換済みであり、`guide/for-llm/` に格納されている。案件参考資料・コーディング標準はすべてこちらを参照すること
- **ユーザーへの案内**: ユーザーが `guide/for-human/` のファイルを直接指定してきた場合は、対応する `guide/for-llm/` のパスを案内する

## ディレクトリ対応表

| ユーザー参照先 | Claude Code 参照先 |
|---|---|
| `guide/for-human/` | `guide/for-llm/` |
| `guide/for-human/YAコーディング標準/*.docx` | `guide/for-llm/YAコーディング標準/*.md` |
