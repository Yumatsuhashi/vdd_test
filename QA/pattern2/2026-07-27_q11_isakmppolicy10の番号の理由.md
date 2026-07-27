# Task 1.11 DMVPN — `crypto isakmp policy` の番号がなぜ「10」なのか

## 質問

CCIE_train_hub/Questions/pattern2/pattern2_q11.md において crypto isakamp の後にpolicy 10 なのはなぜ？

## 回答

結論: 「10」という番号は候補者が新規に選んだものではなく、**R24 の初期コンフィグ（ラボ投入済みの base config）にすでに `crypto isakmp policy 10` として存在している**番号です。Task 1.11 ではこの既存ポリシーを流用・修正するだけでよいため、解答も同じ「policy 10」を使い続けています。

### 1. R24 の初期コンフィグにすでに存在する

`EI_v2.yaml` の R24 ノードブロック（起動前コンフィグ）には次がプリステージされています。

```
crypto isakmp policy 10
 encr 3des
 authentication pre-share
 group 2
crypto isakmp key cisco address 0.0.0.0
!
crypto ipsec transform-set trans esp-3des esp-md5-hmac
```

つまり暗号化方式 `3DES` はすでに policy 10 に設定済みで、要件（暗号化方式：3DES）を満たしています。トランスフォームセットも `esp-3des esp-md5-hmac` ですでに用意されています。

### 2. Task 1.11 で足りないのは「ハッシュ方式」と「事前共有鍵」だけ

問題文の要件は以下の3点です。

- 事前共有鍵: `CCIE!nfr4`
- 暗号化方式: 3DES → **すでに policy 10 に設定済み**
- ハッシュ方式: MD5 → **未設定（デフォルトの SHA のまま）なので追加が必要**

そのため解答（`original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` Task 1.11 セクション）では、既存の `policy 10` に対して

```
crypto isakmp policy 10
hash md5

no crypto isakmp key cisco address 0.0.0.0
crypto isakmp key CC!E!nfr4 address 0.0.0.0
```

を追加するだけで完結しています。もし新しい番号（例えば `policy 20`）で作り直すと、`encr 3des` や `group 2` などすでに要件を満たしている行をもう一度書く二度手間になり、かつ古い `policy 10`（`crypto isakmp key cisco`＝デフォルトの誤った鍵のまま）が残ってしまい、IKE がそちらを先にマッチさせてしまうリスクもあります（ISAKMP はポリシー番号の小さい方から順にネゴシエーションを試みるため）。したがって「既存の 10 番を編集する」のが最も安全かつ最小差分の解答になります。

### 3. 補足: ポリシー番号自体はピア間で一致させる必要はない

IKE（ISAKMP）フェーズ1のポリシー番号はローカルスコープの値であり、対向ルータと番号を揃える必要はありません（マッチするのは暗号化・ハッシュ・認証方式・DHグループ・ライフタイムの「中身」であって番号ではない）。実際、スポークの R61/R70 は `crypto isakmp policy` を持たず、`crypto keyring KR vrf WAN` ＋ `pre-shared-key` 方式（VRF対応のIKEv1鍵管理）で鍵だけを設定しており、番号という概念自体が出てきません。それでも R24 側の policy 10（3DES/MD5/事前共有鍵/DHグループ2）とパラメータが一致していれば、Phase1 SA は正しく確立します。

## 参照

- `EI_v2.yaml` — R24 ノードブロックの初期コンフィグ（`crypto isakmp policy 10` / `encr 3des` / `crypto ipsec transform-set trans esp-3des esp-md5-hmac`）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.11 セクション（比較表 1627〜1660行付近、パターン2単体解答 2887〜2990行付近）
- `Answers/pattern2/pattern2_q11.md`（今回新規作成したキャッシュ）
