# Task 1.3 spanning-tree guard root がどの要件を満たすか、なぜこの範囲に適用するか

## 質問

pattern3について
```
interface range GigabitEthernet1/0-3, GigabitEthernet2/0-1, GigabitEthernet0/3
spanning-tree guard root

interface range port-channel 1, port-channel 3
spanning-tree guard root
```
この部分は問題文のどの部分を満たしている？

## 回答

この2つの`spanning-tree guard root`ブロックは、`Questions/pattern2/pattern2_q3.md`の最後の要件を満たす。

> SW101およびSW102は、本社内の他のスイッチから受信する、より優先度の高いBPDUの影響を受けないようにしてください。より優先度の高いBPDUを受信している間は、その受信ポートでトラフィックを転送してはいけません。

これはルートガード（Root Guard）そのものの説明。`spanning-tree guard root`を有効にしたポートで、より優れた（Bridge IDが低い＝優先度が高い）BPDUを受信すると、そのポートは通常のようにルートポートへ昇格させず、代わりに「root-inconsistent」というブロッキング相当の状態に強制的に落とし、そのポートでのトラフィック転送を止める。優れたBPDUを受信しなくなれば自動的に復旧する。

### なぜこの特定のインターフェース群に適用しているのか

SW101のリンク構成（`EI_v2.yaml`）:

| インターフェース | 接続先 | L2/L3 |
|---|---|---|
| Gi0/0 | R11（ルータ） | L3ルーテッド（`no switchport`） |
| Gi0/1 | R12（ルータ） | L3ルーテッド |
| Gi0/2 | SW201（別スイッチ） | L3ルーテッド（`no switchport`） |
| Gi1/2-3 | SW110（Po1メンバー） | L2トランク |
| Gi2/0-1 | SW102（Po3メンバー） | L2トランク |
| Gi1/0-1, Gi0/3 | （未接続・予備ポート） | L2 |

root-guard適用対象の`GigabitEthernet1/0-3, GigabitEthernet2/0-1, GigabitEthernet0/3`と`port-channel 1, port-channel 3`は、SW101のL2（スイッチ側）インターフェース全体（実際に他スイッチへ繋がっているPo1・Po3のメンバーポート＋ポートチャネル本体、および同じ範囲に含まれる未使用ポートGi1/0-1・Gi0/3）を網羅している。Gi0/0〜0/2はL3ルーテッドポート（`no switchport`）なのでSTP自体が動作せず、root-guardの対象から外れている。

SW101はVLAN2000/2001/デフォルトVLANでプライオリティ0（設定可能な最小値）を明示しており、ルートブリッジとして絶対に負けない設定。ルートブリッジ自身には「ルートポート（＝より良いBPDUを受け入れるポート）」が存在しないはずなので、他スイッチへ繋がる全ポートにroot-guardをかけても理論上問題が起きない。これが「全てのスイッチ向けポートに一括でroot-guardをかける」設計の理由。

### 補足：SW102との比較で見える、より重要な設計ルール

SW102（セカンダリルート、`priority 4096`）のroot-guard設定は`GigabitEthernet1/0-3, GigabitEthernet0/3`と`port-channel 2`のみで、SW101へ繋がるGi2/0-1（Po3）は意図的に除外されている。

```
interface range GigabitEthernet1/0-3, GigabitEthernet0/3
spanning-tree guard root

interface range port-channel 2
spanning-tree guard root
```

SW102にとって、SW101（真のルートブリッジ）へ向かうPo3は正当なルートポートになるべきリンク。ここにroot-guardをかけると、SW102はSW101からの本物の優良BPDUまでブロックしてしまい、自分自身の正しいルートパスを塞いでしまう。root-guardは「本来ルートポートになるべきではないポート」にだけ適用し、正当なルートポート（＝実際のルートブリッジへ向かう方向）には絶対に適用してはいけない、というのがこの機能の鉄則。

同様の理由で、SW110（非ルートスイッチ）のTask1.3解答には`spanning-tree guard root`が一切登場しない。SW110はPo1（SW101経由）またはPo2（SW102経由）のどちらかが正当なルートポートになる可能性があるため、どちらのリンクにもroot-guardをかけられない。

## 参照

- `Questions/pattern2/pattern2_q3.md`（Task 1.3 本社レイヤー2技術の要件）
- `Answers/pattern2/pattern2_q3.md`（SW101/SW102/SW110のTask1.3 config キャッシュ）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.3 — EtherChannel/STP セクション、Pattern 2）
- `EI_v2.yaml`（SW101ノードのリンク構成）
