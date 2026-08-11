# Task 1.13 `switchport port-security mac-address` に書く MAC は SW700 自身か host71/72 か

## 質問

sw 700のsw port-security mac-address あとにかくmacアドレスは自分のもの？それともhost71,72の物？
そして71,72の物ならどうやってそれを見れるようにする？

## 回答

### 答え：host71 / host72 のもの

SW700 自身の MAC ではない。問題文にも明記されている。

> **HOST71およびHOST72のMACアドレス**を**スタティックに設定**すること

### なぜホスト側なのか（原理）

ポートセキュリティが見ているのは **そのポートに「入ってくる」フレームの送信元 MAC**。

```
host71 ──────フレーム送信──────> [SW700 Gi0/0]
   送信元MAC = host71 のMAC
                                  ↑
                        SW700 はここで送信元MACを見て
                        「登録済みリストにあるか？」を判定する
```

SW700 の Gi0/0 に届くフレームは**必ず host71 が送ったもの**。だから許可リストに書くのも host71 の MAC。

例えるなら **ドアに「入っていいのは◯◯さん」と名札を貼る**ようなもので、
書くのは自分（ドア）の名前ではなく、入ってくる人の名前。

### SW700 自身の MAC を書いたらどうなるか

host71 のフレームが届いた瞬間、送信元 MAC が登録リストと違うので**違反扱い**になる。

| ポート | 設定 | 結果 |
|---|---|---|
| Gi0/0 | `violation restrict` | フレーム破棄＋syslog＋カウンタ増加（通信不能） |
| Gi0/1 | `violation shutdown` | **err-disabled でポート停止** |

全滅する。

### ⚠️ ポートの取り違えにも注意

| ポート | 繋がっている機器 | VLAN | 書く MAC |
|---|---|---|---|
| Gi0/0 | **host71** | 100 | **host71 の MAC** |
| Gi0/1 | **host72** | 414 | **host72 の MAC** |

左右を入れ替えると両方とも違反になる。

---

## MAC の調べ方

### 方法1：host のコンソールで直接読む（最速・確実）

CML で host71 のノードをダブルクリック → Console を開く。

```
host71> enable
host71# show interfaces Ethernet0/0 | include address is
  Hardware is iol, address is aabb.cc00.7100 (bia aabb.cc00.7100)
                              ^^^^^^^^^^^^^^ これをメモする
```

host72 でも同じ。

**利点**: VLAN もトランクも port-security も**一切設定不要**で読める。
MAC はハードウェアの値なので疎通も IP も関係ない。詰まったらこれが一番早い。

⚠️ インターフェース名は **`Ethernet0/0`**（`GigabitEthernet` ではない）。

### 方法2：SW700 に学習させて読む

L2 の道が通っている必要がある。**先にこれを入れてから**実行する。

```
vlan 100,414
!
interface GigabitEthernet2/1
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface GigabitEthernet0/0
 switchport mode access
 switchport access vlan 100
!
interface GigabitEthernet0/1
 switchport mode access
 switchport access vlan 414
```

そのうえで R70 から ping（**VRF 指定が必須**）。

```
R70# ping vrf WAN   192.168.0.123      ← host71
R70# ping vrf kiosk 172.31.70.123      ← host72
```

```
SW700# show mac address-table interface GigabitEthernet0/0
Vlan    Mac Address       Type      Ports
100     aabb.cc00.7100    DYNAMIC   Gi0/0     ← これ

SW700# show mac address-table interface GigabitEthernet0/1
414     aabb.cc00.7200    DYNAMIC   Gi0/1     ← これ
```

### 方法3：R70 の ARP テーブルから拾う

方法2の ping を打った後なら R70 側にも残っている。

```
R70# show ip arp vrf WAN   | include 192.168.0.123
Internet  192.168.0.123   0   aabb.cc00.7100  ARPA  GigabitEthernet0/2.100

R70# show ip arp vrf kiosk | include 172.31.70.123
```

---

## 取得した MAC を投入する

```
interface GigabitEthernet0/0
 switchport port-security
 switchport port-security max 1
 switchport port-security mac-address aabb.cc00.7100      ← host71 の MAC
 switchport port-security violation restrict
!
interface GigabitEthernet0/1
 switchport port-security
 switchport port-security max 1
 switchport port-security mac-address aabb.cc00.7200      ← host72 の MAC
 switchport port-security violation shutdown
 switchport port-security aging time 1
 switchport port-security aging type absolute
```

書式は **`H.H.H`（4桁 × 3組をドット区切り）**。`aabb.cc00.7100` の形。

### ⚠️ `sticky` で済ませないこと

`switchport port-security mac-address sticky` は自動学習してくれて楽だが、
`show port-security address` の Type が **`SecureSticky`** になる。
問題文は「**スタティックに設定**」なので、MAC を明示的に打って
**`SecureConfigured`** にすること。

## 確認

```
SW700# show port-security address
Vlan  Mac Address       Type                 Ports  Remaining Age
100   aabb.cc00.7100    SecureConfigured     Gi0/0        -
414   aabb.cc00.7200    SecureConfigured     Gi0/1        1

SW700# show port-security interface GigabitEthernet0/0
Security Violation Count   : 0            ← 0 なら MAC が合っている
```

MAC を間違えているとカウンタが増えるか Gi0/1 が err-disabled になる。直し方:

```
SW700(config-if)# no switchport port-security mac-address <間違えたMAC>
SW700(config-if)# switchport port-security mac-address <正しいMAC>
SW700(config-if)# shutdown
SW700(config-if)# no shutdown          ← err-disable からの復帰（180秒待てば自動復旧もする）
```

## 参照

- `Questions/pattern2/pattern2_q13.md` — 「HOST71およびHOST72のMACアドレスをスタティックに設定すること」
- `Answers/pattern2/pattern2_q13.md` — Pattern 2 Task 1.13 の解答 config（`violation restrict` / `shutdown`、
  `aging time 1` + `aging type absolute`、`errdisable recovery interval 180`）
- `EI_v2.yaml`
  - host71 — `node_definition: iol-xe`、`interface Ethernet 0/0 / ip address 192.168.0.123 255.255.255.0`
  - host72 — `node_definition: iol-xe`、`interface Ethernet 0/0 / ip address 172.31.70.123 255.255.255.0`
  - R70 — `Gi0/2.100 / encapsulation dot1Q 100 / vrf forwarding WAN / 192.168.0.1`、
    `Gi0/2.414 / encapsulation dot1Q 414 / vrf forwarding kiosk / 172.31.70.1`
  - links — `SW700-Gi0/0<->host71-Ethernet0/0`(4812行) / `SW700-Gi0/1<->host72-Ethernet0/0`(4819行) /
    `SW700-Gi2/1<->R70-Gi0/2`(4763行)
- 関連 QA:
  - `QA/pattern2/2026-08-11_q13_host71と72のMACアドレスをどうやって出すか.md`
  - `QA/pattern2/2026-08-11_q13_mac_address_tableが見えるようになる原理.md`
