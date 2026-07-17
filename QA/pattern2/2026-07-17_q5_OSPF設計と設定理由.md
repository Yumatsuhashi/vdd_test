# Task 1.5 OSPF Q&A

## 前提と参照先の注意

- `questions.md` は現時点では 0 byte で、設問本文は入っていない。
- `original/Pattern 4 — 予想コマンド＆知識チートシート.html` の Task 1.5 は、Pattern 4 の **OSPF multi-area / stub area の予想問題**であり、Pattern 2 の解答ではない。
- Pattern 2 の Task 1.5 の実コンフィグは、`original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` の `Task 1.5 — OSPF` にある。本項では、この **Pattern 2** を対象に説明する。
- Pattern 4 の予想問題には「R21/R22 と SW101/SW102 の間」とあるが、実トポロジでは R21/R22 の直結先は **SW201/SW202** である。SW101/SW102 はさらに SW201/SW202 を経由した HQ 側にいるため、この機器名をそのまま信じて設定してはいけない。詳細は末尾の注意を参照。

---

## Q1. そもそも、このトポロジはどんな意図で構成されているのか

### A. 複数拠点・複数ルーティングドメインを一つにまとめる企業網を模擬している

このトポロジは、単に OSPF ネイバーを作るためだけの構成ではない。主な意図は、次の役割を一つのラボで試験することである。

|領域|主な機器|主な役割|
|---|---|---|
|HQ|R11/R12、SW101/SW102、SW110|ユーザー VLAN、冗長な L3 ディストリビューション、外部接続|
|DC|R21/R22、R23/R24、SW201/SW202、SW211/SW212、cEdge21/cEdge22|冗長な内部 L3 ファブリック、BGP 境界、SD-WAN/WAN 接続|
|SP|R1〜R6、SP_1、SP_2|企業網の外側にあるサービスプロバイダ網|
|Branch3|R61/R62、SW601/SW602/SW610|EIGRP、DMVPN/IPsec、冗長な支店 LAN|
|Branch4|R70、SW700|別支店とユーザーセグメント|

Task 1.5 が扱うのは、このうち主に **HQ と DC 内部の IPv4 IGP** である。内部経路は OSPF で交換し、企業網と SP の境界は BGP で交換する、という役割分担になっている。

### 冗長化の意図

ルータやスイッチが 2 台ずつあり、相互にクロス接続されているのは、1 台または 1 リンクが落ちても別経路を選べるようにするためである。

例えば HQ では、R11/R12 の両方が SW101/SW102 の両方へ接続されている。DC でも、R21/R22 は SW201/SW202 の両方へ接続され、R23/R24 は SW211/SW212 の両方へ接続されている。OSPF にこれらの内部 L3 リンクを参加させることで、障害時に SPF を再計算して迂回できる。

### OSPF と BGP の境界を学ぶ意図

- **OSPF**: 企業内部のリンク、内部サブネット、Loopback の到達性を扱う。
- **BGP**: R11/R12、R21/R22、R23/R24 などの外向き回線で、別 AS または SP と経路を交換する。
- **再配送**: R21 が BGP で得た外部経路を OSPF へ入れ、内部機器から外部宛てに到達できるようにする。

したがって、この課題のポイントは「全インターフェースで OSPF を有効にする」ことではない。**内部向きは OSPF、SP 向きは BGP** という境界を正しく選ぶことにある。

### Loopback を OSPF に入れる意図

Loopback は物理リンクの up/down に左右されにくい安定したアドレスであり、次の用途に使われる。

- OSPF Router ID の候補
- iBGP ネイバーの接続元・接続先
- 管理や疎通確認の宛先

例えば R21 と R22 の iBGP は Loopback0 をネイバーアドレスとして使うため、Loopback0 への経路が内部で到達可能でなければならない。その到達性を OSPF で提供する。

---

## Q2. なぜ OSPF の設定を、解答にある機器へ設定しているのか

### A. 解答は全トポロジの OSPF 一覧ではなく、Task 1.5 で設定・確認すべき機器を示しているから

Pattern 2 の表は、純粋な差分だけでなく、最終状態として必要な既存コマンドも一部再掲している。例えば SW101/SW102 の Gi0/0-1 と R21 の内部インターフェースは、`EI_v2.yaml` ですでに OSPF area 0 に入っているが、解答にも再掲されている。

一方、SW201/SW202/SW211/SW212 や一部の cEdge インターフェースには初期状態ですでに必要な OSPF 設定があり、Pattern 2 で追加要件がない。R11/R12、R22、R23/R24 などには OSPF が未設定であり、SW101/SW102 でもユーザー VLAN の SVI と MD5 認証は未設定である。

そのため、Pattern 2 の解答に機器名が出てくる基準は次のいずれかである。

1. OSPF ネイバーを形成する内部 L3 リンクを OSPF へ参加させる、または参加済みであることを確認する。
2. Loopback やユーザー VLAN を OSPF で広告する。
3. OSPF 隣接関係へ MD5 認証を追加する。
4. BGP で得た外部経路を OSPF へ再配送する。

### 機器ごとの理由

|機器|OSPF を設定する対象|設定する理由|
|---|---|---|
|SW101|Vlan2000-2001、Gi0/0-1|VLAN 2000/2001 のユーザーサブネットを OSPF へ広告する。Gi0/0-1 は R11/R12 との内部 L3 リンクなので OSPF ネイバーを形成し、Pattern 2 では MD5 認証も有効にする。Gi0/2 と Loopback0 は初期状態ですでに OSPF 済み。|
|SW102|Vlan2000-2001、Gi0/0-1|SW101 と同じ。HQ のもう一方の冗長経路を構成し、R11/R12 との隣接関係にも同じ MD5 設定を入れる。Gi0/2 と Loopback0 は初期状態ですでに OSPF 済み。|
|R11|Loopback0、Gi0/1-3|Loopback を内部へ広告する。Gi0/1 は R12、Gi0/2-3 は SW101/SW102 への内部リンクであり、ここで OSPF 隣接関係を作る。Pattern 2 では Gi0/1-3 に MD5 認証を入れる。SP 向き Gi0/0 は BGP 用なので OSPF に入れない。|
|R12|Loopback0、Gi0/1-3|R11 と同じ。Gi0/1 は R11、Gi0/2-3 は SW101/SW102 への内部リンク。SP 向き Gi0/0 は OSPF 対象外。|
|R21|Loopback0、Gi2-4、OSPF/BGP 再配送|Gi2 は R22、Gi3-4 は SW202/SW201 への内部リンク。Loopback0 は R22 との iBGP 到達性にも必要。R21 は BGP と OSPF の境界にある ASBR なので、`redistribute bgp 65002 metric-type 1 subnets` で外部経路を内部 OSPF へ渡す。SP 向き Gi1 は BGP 用なので OSPF に入れない。|
|R22|Loopback0、Gi2-4|Gi2 は R21、Gi3-4 は SW201/SW202 への内部リンク。R21 と対になる冗長な OSPF 経路を作り、Loopback ベースの iBGP 到達性も確保する。SP 向き Gi1 は OSPF 対象外。|
|R23|Loopback0、Gi2-3|Gi2-3 は SW211/SW212 への内部リンクであり、DC 内部の OSPF に参加させる。明示的な `router-id 10.2.255.23` により Router ID を安定させる。外向き Gi1 は BGP/WAN 側なので OSPF に入れない。|
|R24|Loopback0、Gi2-3|R23 と対になる冗長経路を作る。Gi2-3 は SW211/SW212 への内部リンク。`router-id 10.2.255.24` を固定する。外向き Gi1 は BGP/WAN 側なので OSPF に入れない。|

### なぜ SW201/SW202/SW211/SW212 は Pattern 2 の追加対象に見えないのか

これらは不要なのではなく、`EI_v2.yaml` の初期コンフィグですでに OSPF process 1 / area 0 が有効だからである。

- SW201/SW202: R21/R22、HQ 側、DC 内部への各 routed port と Loopback で OSPF 済み。
- SW211/SW212: R23/R24、SW201/SW202、cEdge 側などの各 routed port と Loopback で OSPF 済み。

解答が差分だけを示しているため、設定済み機器は出てこない。**解答にない機器 = OSPF を使わない機器**という意味ではない。

### なぜ MD5 認証は両端に必要なのか

Pattern 2 では、HQ の R11/R12 と SW101/SW102 間、および R11-R12 間の OSPF リンクで message-digest 認証を使う。

```ios
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 CC!E!nfr4
```

OSPF 認証はリンクの両端で認証方式、key-id、key-string が一致しなければならない。一方の機器にだけ設定すると Hello の認証に失敗し、ネイバーが Full にならない。Loopback0 はネイバー形成用リンクではないため、解答では OSPF 広告だけを有効にし、MD5 は付けていない。

### R21 の再配送コマンドの意味

```ios
router ospf 1
 redistribute bgp 65002 metric-type 1 subnets
```

- `redistribute bgp 65002`: AS 65002 の BGP ルートを OSPF 外部ルートとして内部へ渡す。
- `metric-type 1`: OSPF E1 とし、外部メトリックだけでなく ASBR である R21 までの内部 OSPF コストも経路選択へ含める。
- `subnets`: クラスフルなメジャーネットワークだけでなく、BGP にあるサブネットも再配送対象にする。

これにより、HQ/DC の内部機器は BGP を直接動かさなくても、OSPF 経由で外部プレフィックスを学習できる。

---

## Pattern 4 の multi-area / stub 記述についての注意

Pattern 4 の予想解答は、外部 BGP 再配送ルートを末端側へ大量に流さず、デフォルトルートだけで外へ出すために stub または totally stubby area を作る、という**設計意図自体**は妥当である。

ただし、実トポロジに照らすと次の記述は整合しない。

- R21/R22 の直結ディストリビューションは SW201/SW202 であり、SW101/SW102 ではない。
- SW101/SW102 を別エリアにするなら、R21/R22 との間には SW201/SW202 が存在するため、単純に「R21/R22 を ABR、SW101/SW102 を area 1」とすることはできない。
- HQ 側への 10.2.241.0/30 と 10.2.242.0/30 を area 1 にする設計なら、実際のエリア境界候補は SW201/SW202 になる。
- OSPF の stub 属性は同一エリア内の全ルータで一致が必要で、`no-summary` は totally stubby area の ABR 側だけに設定する。

したがって Pattern 4 を解く場合は、実際の設問で指定されたエリア、対象リンク、ABR を確認してから設定すること。予想 HTML の機器名だけを根拠に R21/R22/SW101/SW102 へ `area 1 stub` を投入するのは危険である。
