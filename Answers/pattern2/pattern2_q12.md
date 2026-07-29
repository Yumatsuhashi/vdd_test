# Pattern 2 — 問題12 NATおよびTelnetアクセス

## 解答 config（デバイス別）

### R23

```
ip http server

interface range GigabitEthernet2-3
ip nat inside

interface GigabitEthernet1
ip nat outside

ip access-list standard CCIENAT
permit 10.0.0.0 0.255.255.255

ip nat inside source list CCIENAT interface GigabitEthernet1 overload
ip nat inside source static tcp 10.2.255.23 80 200.99.23.2 2002 extendable

ip access-list extended CCIETELNET
deny tcp any any eq 23
permit tcp any any eq 3003

username ccieuser password CC!E!nfr4

line vty 0 15
login local
access-class CCIETELNET in
rotary 3
transport input telnet
```

補足:
- `10.2.255.23` は R23 の Loopback0（`EI_v2.yaml` で確認済み）。
- `ip http server` は、静的PATの変換先であるポート80に実体のあるサービス（IOS内蔵HTTPサーバー）を用意するために設定されている（NATルール自体の動作要件ではない）。
- Telnetアクセスはポート3003のみ許可（`CCIETELNET` ACLで標準の23番を拒否）。ログイン認証はローカルデータベース（AAA不使用）。

## 検証コマンド

（なし）

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.12 — NAT / Telnet / HTTP セクション、R23）
- `EI_v2.yaml`（R23ノードの `interface Loopback0`）

最終更新: 2026-07-29
