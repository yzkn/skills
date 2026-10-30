#!/usr/bin/env python
"""トリガー評価（trigger_eval.py）の交絡を解消するフィクスチャを生成する。

`.claude/skills/vnl/eval/trigger.json` の 4 ケースは token.txt / app.db / qr.png を
参照するが、実物が無いと「発動しない」以外の理由でも落ちうる（ADR-038 が挙げた交絡 4 件）。
このスクリプトはその実物を決定論的に生成する。何度実行しても同じ内容になる。

生成物（すべて .claude/scripts/skill-eval/fixtures/ 配下）:
  token.txt  ダミー JWT。署名は検証不能な固定値（/vnl security jwt は署名を検証しない）
  app.db     SQLite。customers / orders テーブルと架空データ
  qr.png     QR 画像。/vnl qr encode で生成する

架空性の担保: メールアドレスは RFC 2606 の予約ドメイン example.jp のみを使い、電話番号は
含めない（`.claude/rules/security-hardstops.md`・`/vnl testdata` と同じ方針）。

token.txt の JWT は、実測（gitleaks 8.30.1）では既定ルールセットに検出されなかった。ただし
将来のルール変更に備え、`.gitleaks.toml` に値限定の allowlist を予防的に登録してある。
"""
import base64
import json
import os
import sqlite3
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'fixtures')
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
VNL = os.path.join(REPO, '.claude', 'skills', 'vnl', 'scripts', 'vnl.py')


def b64u(raw: bytes) -> str:
    """Base64URL（パディングなし）。JWT の各セグメントに使う。"""
    return base64.urlsafe_b64encode(raw).decode('ascii').rstrip('=')


def make_token() -> str:
    header = {'alg': 'HS256', 'typ': 'JWT'}
    payload = {
        'sub': 'eval-fixture',
        'name': 'trigger eval fixture',
        'iat': 1700000000,  # 固定値（10 桁。gitleaks の桁数ルールには一致しない）
        'exp': 1800000000,
    }
    seg = [b64u(json.dumps(header, separators=(',', ':')).encode('utf-8')),
           b64u(json.dumps(payload, separators=(',', ':')).encode('utf-8')),
           b64u(b'not-a-real-signature')]
    path = os.path.join(OUT, 'token.txt')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('.'.join(seg) + '\n')
    return path


def make_db() -> str:
    path = os.path.join(OUT, 'app.db')
    # 既存があると CREATE TABLE が失敗するため作り直す（生成物のみを対象とする削除）
    if os.path.exists(path):
        os.remove(path)
    con = sqlite3.connect(path)
    con.executescript("""
        CREATE TABLE customers (
            id         INTEGER PRIMARY KEY,
            name       TEXT NOT NULL,
            email      TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE orders (
            id          INTEGER PRIMARY KEY,
            customer_id INTEGER NOT NULL REFERENCES customers(id),
            amount      INTEGER NOT NULL,
            ordered_at  TEXT NOT NULL
        );
    """)
    # customers.name には索引を張らない。評価ケースが name での検索の実行計画を尋ねるため、
    # 全表走査が観測できる状態を意図的に残す。
    con.executemany(
        'INSERT INTO customers (id, name, email, created_at) VALUES (?, ?, ?, ?)',
        [(1, '山田 太郎', 'yamada@example.jp', '2026-01-15'),
         (2, '鈴木 花子', 'suzuki@example.jp', '2026-02-03'),
         (3, '佐藤 次郎', 'sato@example.jp', '2026-02-20'),
         (4, '山田 三郎', 'yamada3@example.jp', '2026-03-11'),
         (5, '高橋 四郎', 'takahashi@example.jp', '2026-04-02')])
    con.executemany(
        'INSERT INTO orders (id, customer_id, amount, ordered_at) VALUES (?, ?, ?, ?)',
        [(1, 1, 12000, '2026-05-01'), (2, 1, 3400, '2026-05-18'),
         (3, 2, 8900, '2026-06-02'), (4, 4, 15600, '2026-06-21')])
    con.commit()
    con.close()
    return path


def make_qr() -> str:
    path = os.path.join(OUT, 'qr.png')
    # 評価ケース 18（URL を QR にする）と内容が重ならないよう別の URL を載せる
    r = subprocess.run([sys.executable, VNL, 'qr', 'encode',
                        '--text', 'https://example.jp/checkin', '--out', path],
                       capture_output=True, text=True, encoding='utf-8')
    if r.returncode != 0:
        raise SystemExit('vnl qr encode failed (exit={}): {}'.format(
            r.returncode, (r.stderr or '')[:300]))
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in (make_token(), make_db(), make_qr()):
        print('generated: {} ({} bytes)'.format(
            os.path.relpath(path, REPO).replace('\\', '/'), os.path.getsize(path)))
    print('token.txt の JWT は署名が無効な固定のダミー値。値は出力しない。')


if __name__ == '__main__':
    main()
