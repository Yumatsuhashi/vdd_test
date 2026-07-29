# Task 1.12 Telnet ACL / rotary 設定が問題文のどの要件を満たすか

## 質問

```
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
これはもんだいぶんの何を満たしている？

## 回答

Q12「Telnetアクセス」要件（`Questions/pattern2/pattern2_q12.md`）:

1. 有効なすべてのGigabitEthernetインターフェイス経由のTelnetはポート3003のみで受け付ける
2. 標準のTCPポート23はVTYラインの設定で拒否する
3. R24→R23へ `ccieuser` / `CCIE!nfr4` でTelnet接続できる
4. VTYのログイン認証はローカルデータベース、AAAは使わない
5. この構成はNATに依存しない

### config各行との対応

| 設定行 | 満たしている要件 |
|---|---|
| `ip access-list extended CCIETELNET` | ACLの箱を定義 |
| `deny tcp any any eq 23` | 要件2「標準ポート23を拒否」 |
| `permit tcp any any eq 3003` | 要件1「ポート3003を許可」。ACL末尾の暗黙deny anyと合わせて「3003番のみ」を実現 |
| `username ccieuser password CC!E!nfr4` | 要件3の認証情報、かつ要件4「ローカルデータベース」の実体 |
| `line vty 0 15` | 要件2の「VTYラインの設定で」の対象（全16ライン） |
| `login local` | 要件4「ログイン認証はローカルDB」＋「AAAを使わない」＝`aaa authentication login`を介さず直接usernameテーブルを参照 |
| `access-class CCIETELNET in` | 上記ACLをVTYラインの着信(in)側に適用＝ACLを実際に効かせる設定 |
| `rotary 3` | 要件1「ポート3003で受け付ける」の土台。VTYはデフォルトではTCP23番のみlistenするため、`rotary <n>` でTCP 3000+n（=3003）番でもlisten対象にする |
| `transport input telnet` | Telnetプロトコルでのアクセスを許可 |

### rotary と ACL の役割分担

ACL（`deny 23` / `permit 3003`）だけでは「フィルタ条件」しか定義できず、そもそも3003番で接続要求を受け取れる（listenしている）状態を作るのは `rotary 3` の役割。逆に `rotary 3` だけでは標準の23番も引き続きlisten対象のままなので、23番接続を明示的に拒否するACLがないと要件2を満たせない。listen（rotary）とfilter（ACL）が両方揃って初めて「3003番のみ」が実現する。

### NAT非依存（要件5）

このブロックはGigabitEthernet1やNAT関連のコマンド（`ip nat ...`）に一切触れておらず、VTYライン単体のACL・local認証のみで完結。NAT設定の有無に関わらず動作するため要件5を満たす。

### 気になった点（要確認）

問題文のパスワードは `CCIE!nfr4` だが、解答configは `username ccieuser password CC!E!nfr4` で表記が異なる（`CCIE` vs `CC!E`）。原本HTML側もこの表記のため転記ミスの可能性あり。実機認証時は問題文の記載を優先するか両方試して確認することを推奨。

## 参照

- `Questions/pattern2/pattern2_q12.md`（Task 1.12 Telnetアクセス要件）
- `Answers/pattern2/pattern2_q12.md`（R23のTask 1.12 config キャッシュ）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.12 — R23 config、パスワード表記の原本確認）
