# CML MCP サーバーを Claude Code と Cursor から使えるようにする

## Context

CML 2.10 には MCP サーバーが内蔵されており、CML の UI が接続用の設定スニペットを出力する。
これを使えば、AI エージェント（Claude Code / Cursor）から CCIE ラボの
ノード起動・停止・コンフィグ投入・トポロジ参照などを直接操作できるようになる。

**やりたいこと:** CML が出力したスニペットを、この Mac の実環境で実際に動く形に直して
Claude Code（主に使う方）と Cursor の両方に登録する。

### 現状調査の結果（実測済み）

| 項目 | 実測値 |
|------|--------|
| CML 到達性 | `10.71.157.93` ping OK / HTTPS 200 |
| CML バージョン | `2.10.0+build.13`（MCP 内蔵世代） |
| `/mcp` エンドポイント | 生存。MCP のエラー JSON を返す（Streamable HTTP で稼働中） |
| node | **nvm 版のみ** `/Users/yumatsuh/.nvm/versions/node/v24.14.1/bin`（Homebrew/システム node なし） |
| Cursor | インストール済み。`~/.cursor/mcp.json` に `google-workspace` が1件（perm 600） |
| Claude Code | `~/.claude.json` あり。user スコープの mcpServers は**未登録**。リポジトリに `.mcp.json` なし |
| CML の TLS 証明書 | 自己署名 / SAN が **`DNS:cml-controller` のみ（IP SAN なし）** |

### CML のスニペットをそのまま使えない理由（2点）

**1. `"command": "npx"` は Cursor で `spawn npx ENOENT` になる**

この Mac の node は nvm 配下にしかない。Cursor を Dock/Finder から起動するとログインシェルの
PATH を継承しないため、`npx` が見つからない。→ **npx を絶対パスで指定**し、`env.PATH` にも
node の bin を通す。

**2. `NODE_TLS_REJECT_UNAUTHORIZED=0` は消せない（が、影響範囲は限定できる）**

証明書の SAN が `DNS:cml-controller` だけで **IP アドレスが入っていない**。
つまり `https://10.71.157.93` に対しては、たとえ証明書を信頼ストアに入れても
ホスト名検証で必ず失敗する。検証を切る以外に接続する手段がない（ハードニング案は末尾に記載）。

だからこそ **`mcp-remote` を stdio 子プロセスとして噛ませる構成が正しい**:

- Claude Code はネイティブで HTTP transport をサポートするので `mcp-remote` 無しでも繋げるが、
  その場合 `NODE_TLS_REJECT_UNAUTHORIZED=0` を **Claude Code 本体のプロセスに**
  設定することになり、Anthropic API 通信を含む**全ての TLS 検証が無効化される**。
- `mcp-remote` 経由なら、TLS 検証の無効化は**その子プロセス 1 つの中だけに閉じる**。

→ 両クライアントとも `mcp-remote` 方式で統一する。

---

## 手順

### Step 0: 事前確認（ユーザー作業 / 認証情報の生成）

**認証情報は私（Claude）には渡さず、プレースホルダーを後から自分で差し替える方針。**

```bash
# 1) base64 を生成（<user>/<pass> は CML のログイン情報）
printf '<user>:<pass>' | base64
#    ※ printf を使う（echo だと末尾に改行が入り base64 が壊れる）

# 2) 認証と MCP ハンドシェイクが通るか curl で先に検証する
AUTH="Basic <上で出た base64>"
curl -sk -X POST https://10.71.157.93/mcp \
  -H "X-Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```

`serverInfo` を含む結果が返れば認証 OK。401/403 が返るならこの時点で認証情報を直す
（クライアントに登録してから切り分けると原因が分かりにくくなるため、必ずここで潰す）。

```bash
# 3) mcp-remote を事前ダウンロードして疎通を確認（初回 npx は数十秒かかり、
#    そのままだとクライアント側の起動タイムアウトに引っかかることがある）
NODE_TLS_REJECT_UNAUTHORIZED=0 CML_AUTH_HEADER="$AUTH" \
  npx -y mcp-remote https://10.71.157.93/mcp --header 'X-Authorization:${CML_AUTH_HEADER}'
```

接続待ち状態になれば成功（Ctrl-C で抜ける）。npx のキャッシュも温まる。

---

### Step A: Claude Code に登録（優先）

user スコープ（`~/.claude.json`）に登録する。
**リポジトリ内 `.mcp.json`（project スコープ）は使わない** — 認証情報が git にコミットされてしまうため。

```bash
claude mcp add cml -s user \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -- /Users/yumatsuh/.nvm/versions/node/v24.14.1/bin/npx -y mcp-remote \
     https://10.71.157.93/mcp \
     --header "X-Authorization: Basic PASTE_BASE64_HERE"
```

- Claude Code は args を配列のままプロセスに渡すためスペースが壊れない。
  よって Cursor 向けの `${VAR}` 迂回は不要で、ヘッダを直接書く方が確実
  （`${...}` 展開が二重に走る曖昧さも避けられる）。
- `PASTE_BASE64_HERE` は Step 0 で生成した値に置き換える。
- 私が実行する場合は `PASTE_BASE64_HERE` のまま登録し、その後ユーザーが
  `claude mcp remove cml -s user` → 実値で再実行、または `~/.claude.json` を直接編集する。

### Step B: Cursor に登録

`~/.cursor/mcp.json` の `mcpServers` に `cml` を**追記**する（既存の `google-workspace` は残す）。

```json
{
  "mcpServers": {
    "google-workspace": {
      "url": "http://127.0.0.1:8000/mcp"
    },
    "cml": {
      "command": "/Users/yumatsuh/.nvm/versions/node/v24.14.1/bin/npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://10.71.157.93/mcp",
        "--header",
        "X-Authorization:${CML_AUTH_HEADER}"
      ],
      "env": {
        "CML_AUTH_HEADER": "Basic PASTE_BASE64_HERE",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0",
        "PATH": "/Users/yumatsuh/.nvm/versions/node/v24.14.1/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }
  }
}
```

CML のスニペットからの変更点:

| 変更 | 理由 |
|------|------|
| サーバー名 `Cisco Modeling Labs (CML)` → `cml` | 空白・括弧入りの名前はツール名の名前空間で問題になりうる。短い方が呼び出しも楽 |
| `command` を npx の絶対パスに | Dock 起動時に PATH を継承せず `spawn npx ENOENT` になるため |
| `env.PATH` を追加 | npx のシェバンが `#!/usr/bin/env node` なので、node 自体も PATH から解決される必要がある |
| `X-Authorization:${CML_AUTH_HEADER}`（コロン後スペース無し）はそのまま維持 | Cursor は引数中のスペースを壊すことがあるため、`Basic xxx` を直書きせず env 経由にする mcp-remote 側の既定の回避策 |

---

## 変更するファイル

- `~/.claude.json` — user スコープに `cml` サーバーを追加（`claude mcp add` 経由）
- `~/.cursor/mcp.json` — `mcpServers.cml` を追記（既存エントリは保持）

**このリポジトリ内のファイルは一切変更しない。** 認証情報を含むため、
`.mcp.json` や `.cursor/mcp.json` をリポジトリ内に作ることはしない。
CLAUDE.md のワークツリー必須ルール・RDD フローの対象外（リポジトリのコード変更ではないため）。

---

## 検証

```bash
# 1) Claude Code — 登録内容と接続状態を確認
claude mcp list          # cml が ✓ connected になること
claude mcp get cml       # command / args / env を目視確認

# 2) Claude Code を再起動し、セッション内で
/mcp                     # cml が接続済みで、公開ツール一覧が見えること
```

3. 実際に CML のツールを呼び、ラボ一覧が取れることを確認する
   （このリポジトリの `EI_v2.yaml` に対応するラボが CML 上に見えるはず）。

4. Cursor を**完全に終了して再起動**（設定リロードだけでは stdio サーバーが起動し直らない）
   → Settings → MCP で `cml` が緑（接続済み）になり、ツール一覧が表示されること。

### 失敗時の切り分け順

1. `claude mcp get cml` で args/env が意図通りか
2. Step 0 の curl が通るか（= 認証情報の問題か、クライアント設定の問題かを分離）
3. `NODE_TLS_REJECT_UNAUTHORIZED=0` が env に入っているか（TLS エラー時）
4. npx の絶対パスが存在するか（`ls /Users/yumatsuh/.nvm/versions/node/v24.14.1/bin/npx`）

---

## 注意点

**認証情報の平文保存**: `~/.claude.json` と `~/.cursor/mcp.json` に base64（= 実質平文）で
CML のパスワードが保存される。base64 は暗号化ではない。両ファイルとも
`chmod 600` になっていることを確認する（`~/.cursor/mcp.json` は現状 600 で OK）。

**nvm の node を上げると壊れる**: `v24.14.1` を絶対パスで埋め込むため、node を
アップグレードするとパスが消えて MCP サーバーが起動しなくなる。その時は
両ファイルのパスを新バージョンに書き換える。恒久対策としては
`sudo ln -s /Users/yumatsuh/.nvm/versions/node/v24.14.1/bin/npx /usr/local/bin/npx` のような
安定した symlink を作り、設定側はそちらを指す手もある。

**CML の IP が変わったら**: `10.71.157.93` を両ファイルで書き換える。

### （任意）TLS 検証を無効化しないハードニング案

どうしても `NODE_TLS_REJECT_UNAUTHORIZED=0` を避けたい場合のみ:

1. `/etc/hosts` に `10.71.157.93 cml-controller` を追加（証明書の SAN と一致させる）
2. CML の証明書を取得: `openssl s_client -connect 10.71.157.93:443 </dev/null | openssl x509 > ~/cml-ca.pem`
3. 接続先 URL を `https://cml-controller/mcp` に変更し、
   `NODE_TLS_REJECT_UNAUTHORIZED=0` の代わりに `NODE_EXTRA_CA_CERTS=/Users/yumatsuh/cml-ca.pem` を設定

ラボ環境の利用が主目的なので、まずは推奨構成（子プロセスに閉じた検証無効化）で動かし、
必要になったらこちらへ移行するのが良い。
