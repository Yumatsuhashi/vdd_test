# Task 1.14 dynamic-author / line vty / 認証と認可を2種類設定する理由

## 質問

これらのコマンドは何を意味している？問題文の何を満たしている？
```
aaa server radius dynamic-author
client 10.2.252.11 server-key 0 CC!E

line vty 0 15
```

また、認証と認可についてなぜ2種類設定している？
```
aaa authentication login NO_AUTH none
aaa authorization exec SSH_EXEC_G group ISEG
```

`Questions/pattern2/pattern2_q14.md` この問題についてです

## 回答

### 1. `aaa server radius dynamic-author` / `client 10.2.252.11 server-key 0 CC!E!nfr4`

通常のRADIUS認証（SW211→ISEへ認証要求を送る方向）とは逆方向の設定。

- `aaa server radius dynamic-author` … SW211を「RADIUSのダイナミック認可（CoA: Change of Authorization）を受け付けるサーバ側」として動作させる。ISEから送られるCoA要求（再認証強制、セッション切断など）をSW211が待ち受けられるようにする
- `client 10.2.252.11 server-key 0 CC!E!nfr4` … CoA要求を送ってよい相手（ISE, `10.2.252.11`）と、その要求を認証するための共有鍵を登録する

方向:
- 通常認証: SW211 → ISE（`radius server ise` の設定。SW211がクライアント）
- CoA: ISE → SW211（`aaa server radius dynamic-author` の設定。SW211がサーバ）

問題文（`Questions/pattern2/pattern2_q14.md`）の4箇条書き（コンソール無認証／サーバ名・グループ名／メソッドリスト名／retransmit・timeout倍増）にはCoAを直接指す一文はない。ただし冒頭のISE情報ブロックの「RADIUSキー：CCIE!nfr4」はSW211↔ISE間のRADIUS通信全体（`radius server ise`のkeyと`dynamic-author`のserver-keyの両方）で共通して使う値。dynamic-authorはISE統合のベースライン設定でPattern1/2どちらの解答にも同一に含まれる。

### 2. `line vty 0 15`

SW211のVTYライン0〜15（同時16セッション）の設定モードに入るコマンド。配下に以下が続く（実際のconfigの全体像）:

```
line vty 0 15
login authentication SSH_EXEC_G
authorization exec SSH_EXEC_G
transport input ssh
```

要件「ログイン認証およびEXEC認可で使用するメソッドリストの名前をSSH_EXEC_Gとすること」を、VTYラインに`login authentication SSH_EXEC_G`（認証）と`authorization exec SSH_EXEC_G`（認可）の両方を適用することで満たす。`transport input ssh`はSSHのみ許可。

### 3. 認証と認可を2種類設定する理由

Cisco IOSのAAAはログイン過程を認証（Authentication）と認可（Authorization）の別フェーズとして扱う。

| フェーズ | コマンド | 役割 |
|---|---|---|
| 認証 | `aaa authentication login <リスト名> <方式>` | 「あなたは誰か」を確認（ユーザー名/パスワードチェック） |
| 認可 | `aaa authorization exec <リスト名> <方式>` | 認証後、EXECセッションを与えてよいか確認し、必要なら属性を適用 |

この2つは独立した別々のメソッドリスト（別の名前空間）。認証が通っても認可が拒否されればログインできない。

実際には4つのAAA文がある:

```
aaa authentication login NO_AUTH none
aaa authorization exec default none
aaa authentication login SSH_EXEC_G group ISEG
aaa authorization exec SSH_EXEC_G group ISEG
```

- `NO_AUTH`（認証のみ、方式none）→ `line con 0` に適用 → コンソール無条件ログイン可（要件「コンソールポートでは認証を行わないこと」を`login authentication`で実現）
- `aaa authorization exec default none` → 明示的な認可リストが適用されていないライン（コンソール）は認可チェックをスキップ
- `SSH_EXEC_G`という同じ名前で、認証（login）と認可（exec）の両方をISE（group ISEG）向けに定義 → VTYラインに両方適用

問題文が「メソッドリストの名前をSSH_EXEC_Gとすること（認証・認可両方で共通の名前を使う）」と明示的に要求しているため、同名で認証用・認可用の2つの定義を用意し、両方ともISEに問い合わせる構成になっている。

### 補足: CC!E!nfr4 と CCIE!nfr4 の表記差

問題文は`CCIE!nfr4`、original HTMLのconfigは`CC!E!nfr4`（`I`が`!`になっている）。この置換パターンはTask1.12のusernameパスワード、Task1.14のRADIUSキー、SNMP関連文字列など複数箇所で一貫して見られ、単発の誤字ではなくエクスポート時のフォント/アイコン起因のアーティファクトの可能性が高い。実機投入時は問題文の`CCIE!nfr4`を優先することを推奨。

## 参照

- `Questions/pattern2/pattern2_q14.md`（Task 1.14 AAA要件）
- `Answers/pattern2/pattern2_q14.md`（SW211のTask 1.14 config キャッシュ）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.14 — AAA セクション、Pattern 2 SW211 config）
