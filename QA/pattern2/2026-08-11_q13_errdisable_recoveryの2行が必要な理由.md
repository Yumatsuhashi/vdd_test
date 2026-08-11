# Task 1.13 `errdisable recovery cause psecure-violation` / `interval 180` はなぜ必要か

## 質問

errdisable recovery cause psecure-violation
errdisable recovery interval 180

これらはなぜ必要？

## 回答

### この 2 行は問題文の最後の 1 要件に対応している

> 違反によってerr-disabled状態になった場合、SW700のアクセスポートが **3分ごとに自動復旧**するように設定すること。

**1 つの要件を 2 行で満たす。** 片方だけでは不完全。

### そもそも err-disable とは

ポートセキュリティ違反を検知すると IOS はポートを **err-disabled** という保護状態に落とす。

```
SW700# show interfaces status
Port      Name    Status        Vlan   Duplex  Speed Type
Gi0/1             err-disabled  414    auto    auto  10/100/1000BaseTX
```

厄介なのは **err-disabled がデフォルトでは永久に自動復帰しない**こと。
config 上は `no shutdown` のままなのに line protocol が down し、
管理者が手で `shutdown` → `no shutdown` を打つまで死んだまま。

Task 1.13 の Gi0/1 は `violation shutdown` なので、host72 が想定外の MAC で 1 フレーム送っただけで
ポートが落ち、**誰かが気づいて手動復旧するまで通信不能**になる。それを自動化するのがこの 2 行。

### 2 行の役割分担

| 行 | 役割 | 無いとどうなる |
|---|---|---|
| `errdisable recovery cause psecure-violation` | **どの原因を自動復旧の対象にするか**（ON/OFF スイッチ） | 対象外のまま＝**永久に復旧しない**。interval を設定しても無意味 |
| `errdisable recovery interval 180` | **復旧までの待ち時間**（タイマー） | 復旧はするが**デフォルトの 300 秒（5分）**になり「3分ごと」の要件を満たさない |

**スイッチとタイマーの関係**なので、両方揃って初めて機能する。

デフォルト状態:

```
SW700# show errdisable recovery
ErrDisable Reason     Timer Status
-----------------     --------------
psecure-violation     Disabled          ← 全 cause がデフォルトで Disabled
...
Timer interval: 300 seconds             ← デフォルト 5 分
```

### ⚠️ cause 名の罠：`psecure-violation` と `security-violation` は別物

| cause 名 | 何の違反か |
|---|---|
| **`psecure-violation`** | **ポートセキュリティ**（`switchport port-security`）← **今回はこっち** |
| `security-violation` | **802.1x** の認証違反 |

`security-violation` を選ぶと**エラーは出ないのに永久に復旧しない**。
`errdisable recovery cause ?` で候補を確認する癖をつけると安全。

その他の主な cause: `bpduguard` / `link-flap` / `udld` / `loopback` / `storm-control` /
`dhcp-rate-limit` / `arp-inspection` / `channel-misconfig` など。

### ⚠️ 単位の罠：ここは「秒」

同じ Task 1.13 の中で単位が食い違う。

| コマンド | 単位 | 「3分」「60秒」の書き方 |
|---|---|---|
| `errdisable recovery interval` | **秒** | 3 分 → **`180`** |
| `switchport port-security aging time` | **分** | 60 秒 → **`1`** |

### グローバルコマンドである点に注意

`errdisable recovery` は **インターフェース配下ではなくグローバル設定**。
だから解答 config でも interface ブロックの外に置かれている。

つまり **SW700 全体に効く**。問題文が「SW700のアクセスポートが」と書いているのと整合する
（実際に err-disable するのは `violation shutdown` の Gi0/1 だけだが、設定はスイッチ単位）。

また `interval` は**全 cause 共通で 1 つ**しか持てない。原因ごとに違う待ち時間は設定できない。

### 動作の流れ

```
① host72 以外の MAC からフレーム到着
        ↓
② violation shutdown → Gi0/1 が err-disabled、%PSECURE_VIOLATION ログ
        ↓
③ 180 秒カウントダウン開始
        ↓
④ タイマー満了 → Gi0/1 を自動で up に戻す
        ↓
⑤ まだ不正な MAC が繋がっていれば ②へ戻る（3分ごとにリトライを繰り返す）
```

**⑤が重要**。これは「回復」であって「予防」ではない。
違反の原因（間違った MAC の登録、または不正な機器）が残っている限り
3 分ごとに落ちては戻るを繰り返す。

### 検証

```
SW700# show errdisable recovery
ErrDisable Reason     Timer Status
-----------------     --------------
psecure-violation     Enabled           ← ★ここが Enabled
...
Timer interval: 180 seconds             ← ★ここが 180

Interfaces that will be enabled at the next timeout:
Interface   Errdisable reason    Time left(sec)
Gi0/1       psecure-violation         142      ← 復旧待ちの残り秒数

SW700# show interfaces status err-disabled
SW700# show errdisable detect                  ! 検知側の設定
```

### パターン間の差分

| | interval |
|---|---|
| **Pattern 2** | **180**（3分） |
| Pattern 1 | 120（2分） |
| Pattern 3 | このタスク自体なし（Pattern 3 の 1.13 は AAA） |

`cause psecure-violation` は Pattern 1・2 共通。変わるのは秒数だけなので、
**問題文の「◯分ごと」を秒に直す**ことだけ確実にやる。

## 参照

- `Questions/pattern2/pattern2_q13.md` — 「違反によってerr-disabled状態になった場合、
  SW700のアクセスポートが3分ごとに自動復旧するように設定すること」
- `Answers/pattern2/pattern2_q13.md` — Pattern 2 Task 1.13 の解答 config
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 1893〜1894行付近 — `errdisable recovery cause psecure-violation`（P1/P2 共通）、
    `errdisable recovery interval` は P1=**120** / P2=**180**（`diff-hl` でハイライト）
  - 4082〜4083行 — Pattern 2 単体解答ブロックの該当 2 行
  - 3063〜3064行付近 — Pattern 1 単体解答ブロック（interval 120）
- 関連 QA:
  - `QA/pattern2/2026-08-11_q13_port-securityに書くMACは自分かホストか.md`
  - `QA/pattern2/2026-08-11_q13_mac_address_tableが見えるようになる原理.md`
