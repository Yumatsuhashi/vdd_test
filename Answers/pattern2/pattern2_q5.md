# Pattern 2 — 問題5 OSPF (Task 1.5)

## 解答 config（デバイス別）

### SW101

```ios
interface range vlan 2000-2001
 ip ospf 1 area 0
interface range GigabitEthernet0/0-1
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### SW102

```ios
interface range vlan 2000-2001
 ip ospf 1 area 0
interface range GigabitEthernet0/0-1
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R11

```ios
interface Loopback0
 ip ospf 1 area 0
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R12

```ios
interface Loopback0
 ip ospf 1 area 0
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R21

```ios
interface range GigabitEthernet2-4, Loopback0
 ip ospf 1 area 0
router ospf 1
 redistribute bgp 65002 metric-type 1 subnets
```

### R22

```ios
interface range GigabitEthernet2-4, Loopback0
 ip ospf 1 area 0
```

### R23

```ios
router ospf 1
 router-id 10.2.255.23
interface range GigabitEthernet2-3, Loopback0
 ip ospf 1 area 0
```

### R24

```ios
router ospf 1
 router-id 10.2.255.24
interface range GigabitEthernet2-3, Loopback0
 ip ospf 1 area 0
```

## 検証コマンド

```ios
show ip ospf neighbor
show ip ospf interface
show ip ospf interface | include authentication   ! SW101/SW102, R11/R12 で message-digest が有効か確認
```

## 補足（設計上の注意）

- SW201/SW202/SW211/SW212 が解答に出てこないのは、EI_v2.yaml の初期コンフィグで OSPF process 1 / area 0 が設定済みのため（追加要件なし）
- SP 向きインターフェース（R11/R12 の Gi0/0、R21/R22 の Gi1、R23/R24 の Gi1）は BGP 用のため OSPF に入れない
- 設計意図・機器ごとの理由の詳細は `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md` を参照

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — 「Pattern 2」タブ内 Task 1.5 — OSPF（3348行付近）、「検証コマンド」タブ Task 1.5（5307行付近）
- `EI_v2.yaml` — SW201/SW202/SW211/SW212 の初期コンフィグ（OSPF 設定済みの根拠）
- 関連 QA: `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md`

最終更新: 2026-07-17
