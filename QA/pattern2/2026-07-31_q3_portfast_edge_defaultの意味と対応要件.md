# Task 1.3 spanning-tree portfast edge default とは何か・対応する要件

## 質問

spanning-tree portfast edge defaultとは何
問題文のどの部分を満たしている？

## 回答

### spanning-tree portfast edge default とは何か

アクセスポート（トランクではない、`switchport mode access`のポート）全てに対して、個別に設定しなくても自動的にPortFast（Edgeポート）扱いにするグローバルコンフィグコマンド。

通常、STPが有効なポートはリンクアップ時に以下の状態遷移を経てから初めてトラフィックを転送する。

```
blocking → listening（約15秒） → learning（約15秒） → forwarding
```

これはループ形成を防ぐための待機時間だが、PCやサーバーなどループを作りようがないエンドホストが繋がっているポートにとっては、この30秒前後の遅延はただの障害（DHCP取得のタイムアウトやPXEブートの失敗など）にしかならない。PortFast（RSTP用語では「Edgeポート」）を有効にすると、listening/learningをスキップしてリンクアップと同時に即forwarding状態になる（バックグラウンドでのBPDU監視自体は継続される）。

`spanning-tree portfast edge`は本来インターフェース単位のコマンドだが、末尾に`default`を付けてグローバルで実行すると、トランクではない全ポートに一括で適用される。

### 問題文のどの部分を満たしているか

問題文（`Questions/pattern2/pattern2_q3.md`）の該当箇所:

> エンドポイントに接続されるすべてのポートで、各スイッチポートを個別に設定することなく、STPのフォワーディング遅延を省略できるようにしてください。

ポイントは「各スイッチポートを個別に設定することなく」という文言。個別設定でよいなら`interface range ... / spanning-tree portfast edge`のようにポートごとに指定する方法もあるが、それは要件に反する。グローバルにデフォルト適用する`spanning-tree portfast edge default`だけが、この「個別設定なし」という制約を満たせる唯一の方法であるため、この1行のグローバルコマンドが選ばれている。

### 補足

- `spanning-tree portfast edge default`はアクセスポートのみに適用され、トランクポート（Po1/Po2/Po3など）には自動適用されない（トランクにも適用したい場合は別途`spanning-tree portfast edge trunk`が必要だが、Q3の要件はエンドポイント向けポートのみを対象としているため不要）。
- コマンド名に`edge`が付くのは、RSTP/MST（IEEE 802.1w/802.1s）の標準用語「Edge Port」に合わせた現行IOSの表記で、古い`spanning-tree portfast default`と機能的には同じ考え方。`spanning-tree mode rapid-pvst`（Rapid PVST+）を使っているこのタスクでは、この`edge`付きの表記が使われている。

## 参照

- `Questions/pattern2/pattern2_q3.md`（Task 1.3 本社レイヤー2技術の要件）
- `Answers/pattern2/pattern2_q3.md`（SW101/SW102/SW110のTask1.3 config キャッシュ、要件対応表）
