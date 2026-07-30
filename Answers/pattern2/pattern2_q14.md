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
- パスワード/RADIUSキーの表記: original HTML では一貫して `CC!E!nfr4`（`I`が`!`になっている）。問題文（`Questions/pattern2/pattern2_q14.md`）は `CCIE!nfr4`。複数箇所（Task1.12のusernameパスワード、Task1.14のRADIUSキー、SNMP関連文字列）で同一パターンの置換が見られ、単発の誤字ではなくエクスポート時のフォント/アイコン起因のアーティファクトの可能性が高い。実機投入時は問題文の `CCIE!nfr4` を優先すること。

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
