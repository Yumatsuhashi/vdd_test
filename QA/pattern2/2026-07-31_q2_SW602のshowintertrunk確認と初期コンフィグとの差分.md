# Task 1.2 SW602の show interfaces trunk 確認と初期コンフィグとの差分

## 質問

```
SW602#sh int trun

Port        Mode             Encapsulation  Status        Native vlan
Gi2/0       on               802.1q         trunking      1

Port        Vlans allowed on trunk
Gi2/0       1,2000-2001

Port        Vlans allowed and active in management domain
Gi2/0       1,2000-2001

Port        Vlans in spanning tree forwarding state and not pruned
Gi2/0       1,20
```

SW602においてすでにこうなっているんだけどこれは追加の設定をしなくても題意を満たしている？

## 回答

満たしている。出力をQ2要件（SW602 Gi2/0にVLAN2000/2001をタグ付きで転送）と照合:

| 出力項目 | 値 | 判定 |
|---|---|---|
| Mode | `on` | 静的トランク（`switchport mode trunk`）が有効な場合の表示。ネゴシエーション待ちの`desirable`/`auto`ではなく確定済み |
| Encapsulation | `802.1q` | `switchport trunk encapsulation dot1q`と一致 |
| Status | `trunking` | 実際にトランクとしてUP |
| Vlans allowed on trunk | `1,2000-2001` | `switchport trunk allowed vlan 1,2000,2001`の設定通り |
| Vlans allowed and active in management domain | `1,2000-2001` | 許可VLANが実際に存在しアクティブ |

### 初期コンフィグとの差分（重要）

SW602の初期コンフィグ（`EI_v2.yaml`）ではGi2/0は元々`switchport trunk encapsulation dot1q` / `switchport mode trunk`のみで、`switchport trunk allowed vlan`による制限は一切ない（未設定＝デフォルトで全VLAN許可）。何も設定していなければ`Vlans allowed on trunk`は`1,2000-2001`ではなく`1-4094`のような広い範囲になっているはず。したがってこの出力が`1,2000-2001`に絞られているのは、`switchport trunk allowed vlan 1,2000,2001`を既に投入した結果であり、正しく設定できている証拠。前回のSW101/SW110のケース（初期コンフィグだけで要件を満たし追加設定不要だったパターン）とは異なり、SW602は初期状態だけでは要件を満たさず明示的な投入が必要なパターンだった。

### 確認推奨（最終行が途中で切れている件）

```
Port        Vlans in spanning tree forwarding state and not pruned
Gi2/0       1,20
```

`1,20`で途切れているのは、おそらくターミナル幅による表示の折り返し/貼り付け時の切れで、本来`1,2000-2001`と表示されるはずのものが途中で切られている可能性が高い（SW602の初期コンフィグには`vtp mode transparent`が設定されているため、VTPプルーニングでVLANが自動的に間引かれる心配はない）。念のため `show spanning-tree vlan 2001` または `terminal width 511` してから `show interfaces trunk` を再実行し、Gi2/0がVLAN2001についてもforwarding状態（blockingでない）であることを確認しておくと安心。

## 参照

- `Questions/pattern2/pattern2_q2.md`（Task 1.2 VLAN/転送設定の要件表）
- `Answers/pattern2/pattern2_q2.md`（SW602のTask1.2 config キャッシュ）
- `EI_v2.yaml`（SW602ノードの初期コンフィグ: `vlan 2000-2001`, `interface GigabitEthernet2/0`, `vtp mode transparent`）
