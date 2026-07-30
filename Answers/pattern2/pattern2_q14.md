# Pattern 2 — 問題14 AAA（ISE RADIUS連携）

## 解答 config（デバイス別）

### SW211

```
aaa new-model

aaa group server radius ISEG
server name ise

aaa server radius dynamic-author
client 10.2.252.11 server-key 0 CC!E!nfr4

radius server ise
address ipv4 10.2.252.11 auth-port 1645 acct-port 1646
key 0 CC!E!nfr4

aaa authentication login NO_AUTH none
aaa authorization exec default none
aaa authentication login SSH_EXEC_G group ISEG
aaa authorization exec SSH_EXEC_G group ISEG

ip radius source-interface GigabitEthernet1/1
radius-server retransmit 6
radius-server timeout 10

line con 0
login authentication NO_AUTH

line vty 0 15
login authentication SSH_EXEC_G
authorization exec SSH_EXEC_G
transport input ssh
```

補足:
- `radius-server retransmit 6` / `radius-server timeout 10` は Pattern 2 固有の追加（デフォルトはretransmit=3, timeout=5。要件「デフォルト値の2倍」を満たすための値）。Pattern 1 にはこの2行と `aaa authorization exec default none` がない。
- `aaa server radius dynamic-author` + `client 10.2.252.11 server-key 0 ...` は CoA（ISE→SW211方向のダイナミック認可）受け入れ設定。通常のRADIUS認証（SW211→ISE方向、`radius server ise`）とは逆方向。
- `SSH_EXEC_G` は認証（`aaa authentication login`）と認可（`aaa authorization exec`）の両方に同名で定義し、VTYラインの `login authentication` / `authorization exec` それぞれに適用する。
- パスワード/RADIUSキーの表記: original HTML では一貫して `CC!E!nfr4`（`I`が`!`になっている）。問題文（`Questions/pattern2/pattern2_q14.md`）は `CCIE!nfr4`。
  **訂正（2026-07-30）**: これは HTML エクスポート時のアーティファクトではない。`EI_v2.yaml`（CMLラボの実体）をバイト単位で確認したところ、
  Task 1.14 の ISE 役を担う FreeRADIUS コンテナの初期コンフィグ自体に `CC!E!nfr4` が literal に書き込まれている
  （`clients.conf` の `secret = CC!E!nfr4` — 4304/4311行、`users` の `iseuser Cleartext-Password := "CC!E!nfr4"` — 4344行、
  SW211ローカルの `username iseuser password 0 CC!E!nfr4` — 1010行）。つまり **実機のRADIUSバックエンドが実際に持っている鍵の値は `CC!E!nfr4` の方**であり、
  SW211の `key 0` / `server-key 0` は `CC!E!nfr4` に合わせないと実際にRADIUS認証が失敗する。問題文の `CCIE!nfr4` を優先すると
  実機では通らないので、本タスクに関しては上記解答configの `CC!E!nfr4` をそのまま使うこと。
  （他タスクのMD5/PSKは候補者が両端を新規設定するため綴りの選択自体は自由だが、公式解答configとの一致を優先するなら同様に `CC!E!nfr4` で統一するのが安全）
- ユーザー名: 問題文は「集中管理されている認証情報:ユーザー名 `ccieuser`」とあるが、FreeRADIUSの `users` ファイルに実在するのは `iseuser` のみ
  （`ccieuser` というアカウントはRADIUS DBに存在しない）。公式の検証コマンドも `Ssh -l iseuser 10.2.255.211` を使っており、実機でSSH+RADIUS認証を
  試す際のログイン名は `ccieuser` ではなく `iseuser` にする必要がある。

## 検証コマンド

- `ssh -l iseuser 10.2.255.211`
- `show aaa servers`（RADIUS サーバ到達確認）
- `show aaa sessions`
- `show radius statistics`（retransmit 6, timeout 10 の反映確認）
- `show aaa method-lists | include exec`（`aaa authorization exec default none` の確認）

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.14 — AAA セクション、Pattern 2 の SW211 config、および Pattern1/2差分比較テーブル）
- `Questions/pattern2/pattern2_q14.md`（要件本文）

最終更新: 2026-07-30
