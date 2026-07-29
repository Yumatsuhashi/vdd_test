# ip http server とは何

## 質問

ip http serverとは何

## 回答

`ip http server` は、Cisco IOSルータに内蔵されているHTTPサーバー機能（Webベースの管理インターフェース）を有効化するコマンド。実行するとルータがTCPポート80でHTTPリクエストの待ち受け（listen）を開始する。

### Task 1.12 での役割

Q12のNAT要件は「ポート2002宛ての通信を、R23のLoopback0（10.2.255.23）のTCPポート80へスタティックPATで変換する」というもの。

```
ip nat inside source static tcp 10.2.255.23 80 200.99.23.2 2002 extendable
```

このコマンドは「ポート2002宛ての通信をLoopback0のポート80へ変換する」というNATルールを作るだけで、変換先（宛先）のポート80で実際にサービスが動いているかとは無関係。`ip http server` が設定されておらずポート80をListenするプロセスがなければ、NAT変換自体は成功してもTCPコネクションはR23側からRST（接続拒否）される。

つまり `ip http server` は、NATが変換した先の「宛先ポート80」に実体のあるサービスを用意するために設定されている。R23自身のHTTPサーバーをポート80で稼働させることで、外部から `<外部IP>:2002` にアクセスした際、NATで `10.2.255.23:80` に変換された通信が実際にR23のHTTPサーバーへ届き、正常に応答できる。

なお `ip http server` はコンフィグ上NAT設定より前に置かれているが、これはNATの動作要件（前後関係）ではなく、単に「宛先として意味のあるサービスを用意しておく」ための設定。

## 参照

- `Questions/pattern2/pattern2_q12.md`（Task 1.12 NATおよびTelnetアクセス要件）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.12 — R23 config、`ip http server` および `ip nat inside source static tcp 10.2.255.23 80 200.99.23.2 2002 extendable`）
- `EI_v2.yaml`（R23ノード: `interface Loopback0` / `ip address 10.2.255.23 255.255.255.255`）
