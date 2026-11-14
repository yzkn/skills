# 案件

案件ごとにフォルダを作る。フォルダ名は英数字とハイフン（タスクの場所やコマンドの引数に使う）。

```
projects/<案件>/
  project.md      templates/project.md を写して書く
  tasks/          進行中・未着手のタスク（1 タスク 1 ファイル）
  archive/        完了・取りやめ
```

新しい案件は、`inbox.md` に `## 新規: <件名>` と書いてエージェントに作らせるか、`templates/project.md` を写して自分で書く。
