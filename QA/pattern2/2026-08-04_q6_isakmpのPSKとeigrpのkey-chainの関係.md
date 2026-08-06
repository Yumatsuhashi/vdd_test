# Task 1.6 — ISAKMP の事前共有鍵と EIGRP の key chain は関係あるか（鍵の入れ物の使い分け解説）

## 質問

q6について

isakmpとeigrpで使うkey-chainは関係ある？ 知識がないから解説して欲しい

## 回答

**結論: まったく別物。コンフィグ上も内部動作上も一切つながっていない。** 唯一の共通点は、このラボで両方に同じ文字列 `CC!E!nfr4` を使っていること（値がたまたま同じなだけ）。

R62 は初期コンフィグの時点でこの2つが同居している良い例:

```ios
crypto isakmp policy 10                        ← ISAKMP（IKEv1）側
 authentication pre-share
crypto isakmp key cisco address 0.0.0.0        ← PSK。鍵文字列がコマンドに直書き
!
router eigrp ccie                              ← EIGRP 側
 address-family ipv4 unicast autonomous-system 65006
  af-interface GigabitEthernet0/1
   authentication mode md5
   authentication key-chain CCIE_MD5           ← key chain という別オブジェクトを名前で参照
```

`crypto isakmp key` を消しても EIGRP 隣接は落ちないし、`key chain CCIE_MD5` を消しても DMVPN の IPsec は落ちない。参照関係がゼロだから。

---

### 1. `key chain` とは何者か

IOS における **ルーティングプロトコル認証専用の「鍵の入れ物」**。グローバルコンフィグに独立したオブジェクトとして作り、各プロトコルが**名前で参照**する。

```ios
key chain CCIE_MD5          ← 入れ物の名前
 key 1                      ← Key ID（0〜2147483647）
  key-string CC!E!nfr4      ← 実際の鍵文字列
  accept-lifetime ...       ← （任意）この鍵を受け入れる期間
  send-lifetime  ...        ← （任意）この鍵で送信する期間
```

key chain を参照できるのは主に次のプロトコル:

| プロトコル | 参照コマンド |
|---|---|
| **EIGRP（classic）** | `ip authentication key-chain eigrp <AS> <名前>` |
| **EIGRP（named mode）** | `authentication key-chain <名前>`（af-interface 配下）← **Task 1.6 はこれ** |
| RIPv2 | `ip rip authentication key-chain <名前>` |
| IS-IS | `authentication key-chain <名前>` |
| BFD | `bfd ... key-chain` |
| HSRP | `standby 1 authentication md5 key-chain <名前>` |
| OSPFv2（新しめの IOS） | `ip ospf authentication key-chain <名前>` |

**このラボ全体で key chain を使うのは Task 1.6 の EIGRP だけ**（`EI_v2.yaml` 全文 grep で `key chain` は 0 件 = 実例なし、`original/` の解答でも Task 1.6 以外に登場しない）。

### 2. ISAKMP の PSK はどう違うか

ISAKMP（= IKEv1 のフェーズ1）の事前共有鍵は、**鍵の入れ物を作らず、コマンドに文字列を直接書く**:

```ios
crypto isakmp key CC!E!nfr4 address 0.0.0.0        ← Task 1.11 の R24 / R61
```

`address 0.0.0.0` は「どのピアからでもこの鍵を使う」の意味（DMVPN のスポークが動的アドレスでも通るように）。
VRF の中でトンネルを張る R70 だけは `crypto keyring` という入れ物を使う:

```ios
crypto keyring KR vrf WAN
 pre-shared-key address 0.0.0.0 0.0.0.0 key CC!E!nfr4
```

この **`crypto keyring` は名前が紛らわしいが `key chain` とは完全に別のコマンド体系**。VRF ごとに PSK を分けるために存在するもので、`authentication key-chain` から参照することはできない（逆も不可）。IKEv2 だとさらに `crypto ikev2 keyring` という別の入れ物になる。

### 3. なぜ EIGRP だけ「入れ物」が要るのか（設計思想の違い）

ここが本質。**鍵をどうやって特定するか**が違う。

| | EIGRP（ルーティング認証） | ISAKMP（IPsec の PSK） |
|---|---|---|
| 守る対象 | EIGRP の Hello / Update パケット1つ1つ | IKE フェーズ1のネゴシエーション（＝そこから鍵を作る） |
| 鍵の特定方法 | パケットに載っている **Key ID** で引く | **ピアの IP アドレス**で引く |
| ゆえに必要なもの | 「ID → 文字列」の**対応表** = key chain | 対応表は不要（IP で引ければ十分） |
| 鍵の更新 | `accept-lifetime` / `send-lifetime` で**無停止ローテーション**が可能 | IKE を張り直す（＝一瞬切れる） |
| 鍵の使い方 | 鍵そのものを HMAC-MD5 の材料に使う（毎パケット） | 鍵は SKEYID の生成材料。実際の暗号鍵は DH で別途生成 |

EIGRP は「key 1 で送りながら key 2 も受け入れる」期間を作れば、隣接を落とさずに鍵を入れ替えられる。この**時間管理と ID 管理を持つために key chain という入れ物が要る**。
ISAKMP は鍵の入れ替え自体が再ネゴを伴うので、ID 表も lifetime 表も不要 → 入れ物がない。

### 4. このラボで `CC!E!nfr4` が出てくる6つの書き方（全部フォーマットが違う）

同じ文字列なのにタスクごとにコマンドの形が違うのは、上記のとおり「鍵をどう特定するか」がプロトコルごとに違うから。

| Task | プロトコル | コマンド | 鍵の入れ物 | 鍵の引き方 |
|---|---|---|---|---|
| 1.5 | OSPFv2 | `ip ospf message-digest-key 1 md5 CC!E!nfr4` | なし（I/F に直書き） | Key ID（パケットに載る） |
| **1.6** | **EIGRP named** | `key chain CCIE_MD5` + `authentication key-chain CCIE_MD5` | **key chain** | Key ID（パケットに載る） |
| 1.7 | LDP | `mpls ldp neighbor <ip> password CC!E!nfr4` / `mpls ldp password option 1 for 11 CC!E!nfr4` | なし（ACL でグループ化は可） | LDP ID / ACL |
| 1.8・1.10 | BGP | `neighbor <ip> password CC!E!nfr4` | なし | ネイバー IP |
| 1.11 | ISAKMP(IKEv1) | `crypto isakmp key CC!E!nfr4 address 0.0.0.0` / `crypto keyring KR vrf WAN` + `pre-shared-key` | crypto keyring（VRF 用のみ） | ピア IP |
| 1.14 | RADIUS | `key 0 CC!E!nfr4` / `client 10.2.252.11 server-key 0 CC!E!nfr4` | なし | サーバ/クライアント IP |

覚え方: **「先に入れ物を作れ」と言われるのは EIGRP（1.6）だけ**。他の5タスクはコマンド1行に鍵文字列が埋め込まれる。
逆に、ISAKMP のところで key chain を作ろうとしても参照する構文が存在しないので無駄になる。

※ 層の違いも整理しておくと、OSPF/EIGRP は**ルーティングパケット自体に MD5 ダイジェストを付ける**方式、BGP/LDP は**TCP セッションの TCP-MD5 オプション**（RFC 2385）、ISAKMP は**UDP 500 の IKE ネゴシエーションでの相手認証**、RADIUS は**UDP 1812/1813 の共有シークレット**。守っている層がそれぞれ違う。

### 5. 確認・切り分けコマンド（別系統であることが出力でも分かる）

| 見たいもの | コマンド |
|---|---|
| key chain が定義されているか | `show key chain` / `show run \| sec key chain` |
| EIGRP の I/F が認証有効か | `show ip eigrp interfaces detail`（`Authentication mode is md5, key-chain is "CCIE_MD5"`） |
| EIGRP 隣接 | `show ip eigrp neighbors` |
| ISAKMP の PSK | `show crypto isakmp key` / `show run \| sec crypto isakmp` |
| IKE フェーズ1の状態 | `show crypto isakmp sa`（`QM_IDLE` なら成立） |

不一致時の症状も別物:

- **EIGRP の鍵不一致/鍵不在** → 隣接がそもそも上がらない（Hello が破棄される）。`debug eigrp packets` で authentication mismatch が見える。今の R62 は `authentication key-chain CCIE_MD5` の参照先が存在しないため、この状態にある
- **ISAKMP の PSK 不一致** → `show crypto isakmp sa` が `MM_NO_STATE` で止まり、`%CRYPTO-4-IKMP_BAD_MESSAGE` 系のログ。トンネルが上がらない

## 参照

- `EI_v2.yaml` 3340〜3456 行 — R62 初期コンフィグ（`crypto isakmp key cisco address 0.0.0.0`（3356行）と `authentication key-chain CCIE_MD5`（3412/3418/3424行）が同居）
- `EI_v2.yaml` 1709 行（R24）/ 3193 行（R61）/ 3537〜3540 行（R70 の `crypto keyring KR vrf WAN`）— ISAKMP PSK のプリステージ状況
- `EI_v2.yaml` 全文 grep — `key chain` / `key-string` は 0 件（ラボ内で key chain を使うのは Task 1.6 のみ）
- `Answers/pattern2/pattern2_q5.md`（OSPF `message-digest-key`）、`q7.md`（LDP password）、`q8.md`・`q10.md`（BGP neighbor password）、`q11.md`（ISAKMP PSK / crypto keyring）、`q14.md`（RADIUS key）— 6形式の実コマンド
- 関連QA:
  - `QA/pattern2/2026-08-04_q6_key_chainのお手本が実機にあるか.md`（key chain の実例がラボに無い件）
  - `QA/pattern2/2026-07-30_q5-14_CCIEnfr4パスワード使用タスクと事前鍵設定要否.md`（値の事前設定の要否）
