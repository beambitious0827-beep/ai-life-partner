# AI Life Partner

# 09_SupabaseEdgeRuntimeDesign

## Supabase Edge Runtime Design Ver.1.0

---

# 1. Purpose

本書は、`docs/08_AiGatewayDesign.md` が定義した **Gatewayの境界** を、

実際に動くserver runtimeとして置いた場所を定義する。

Phase 10 は「Flutter側から見た境界」を決めた。

Phase 11 は「その境界の向こう側に、誰が立っているか」を決める。

AIとHumanの関わり方（AI出力はInsightではない、Humanが確定する等）は

`docs/07_AiThinkingSupportDesign.md` が定義する。本書はそれを前提にする。

**今回、実際のAI Providerへはまだつないでいない。**

つないでいないことを、つながっているように見せる仕組みは置かない。

---

# 2. Scope Ver.1.0

実装したもの：

- Supabase Edge Function `reflection-thinking`
- 認証を通ったHumanだけが届く入口
- 受け取った内容の独立した確認
- server側の `AiThinkingProvider` 抽象
- 未設定であることをはっきり返すProvider
- Providerが返した材料の確認
- statusと失敗の言い方の統一
- ログの決まりごと
- Deno のテスト

実装していないもの（意図的に残している）：

- 実際のAI Provider接続
- provider secretの受け渡し
- Flutter ↔ Edge Function の実通信
- Reflectionの保存と、その所有権の確認
- 入力の大きさの上限
- rate limit
- 課金・利用量の管理
- idempotency / 重複の検出
- Provider requestのserver側timeout / 打ち切り
- OPTIONS / CORS の実地確認
- remote projectの作成、link、deploy

これらが **いつまでに** 必要かは、17章の3つのGateに分けて書いてある。

---

# 3. Directory

```
supabase/
├── config.toml
├── deno.json
└── functions/
    ├── _shared/
    │   ├── http.ts        応答の組み立て
    │   └── log.ts         ログ1行の組み立て
    ├── reflection-thinking/
    │   ├── index.ts       配線だけ（ここだけがnpm:を読む）
    │   ├── contract.ts    受け取る内容の取り決めと確認
    │   ├── handler.ts     HTTPと業務の境界
    │   └── provider.ts    AI Providerとの境界
    └── tests/
        └── reflection-thinking/
            ├── assert.ts
            ├── fake_provider.ts
            ├── contract_test.ts
            ├── handler_test.ts
            ├── provider_test.ts
            └── configuration_test.ts
```

`index.ts` だけが `npm:@supabase/server` を読む。

`contract.ts` / `handler.ts` / `provider.ts` / `_shared/*` は

runtime固有のものに依存しない。そのため単体で確かめられる。

共有コードは `_shared` に置き、相対パスで読む。

bare specifier（`import x from "pkg"`）は使わない。

---

# 4. Endpoint

```
POST https://<project-ref>.supabase.co/functions/v1/reflection-thinking
```

`docs/08_AiGatewayDesign.md` の `POST /v1/ai/reflection-thinking` は

境界を説明するための書き方であり、実際の経路ではない。

**実際の経路は本書のものが正しい。**

`<project-ref>` はremote projectを作ったときに決まる。

まだ作っていないため、`config.toml` にも本書にも実在しない値を書かない。

---

# 5. Authentication

```ts
export default {
  fetch: withSupabase(
    { auth: "user" },
    (req: Request) => handleReflectionThinking(req, { provider }),
  ),
};
```

`withSupabase({ auth: "user" })` が、サインインしたHumanのrequestだけを通す。

`supabase/config.toml` でも明示する。

```toml
[functions.reflection-thinking]
verify_jwt = true
```

既定がtrueだからという理由で省略しない。falseにもしない。

`reflection-thinking` は公開endpointではない。

**認証を通らなかったrequestは、業務のhandlerまで届かない。**

JWTを自前で解析する処理は書かない。

古い書き方（手でJWTを検証する）へ戻さない。

## 5.1 Server Identity

Humanの身元は、認証を通ったidentityだけを使う。

clientのbodyが申告した `humanId` は受け取らないし、身元としても使わない。

そのため request contract に `humanId` は存在しない。

（`docs/08_AiGatewayDesign.md` 7章の要件を、ここで満たしている。）

## 5.2 Ownership（未実装）

server側にReflectionの保存先はない。

したがって、

```
requestしているHuman
  が
reflectionEntryId の振り返りを使える
```

ことを **確かめられない**。

`reflectionEntryId` は、突き合わせと将来の紐づけのために受け取るだけであり、

「所有権を確認済みのresource ID」ではない。

`ownershipVerified` のような、確かめていないのに確かめたことにする値は持たない。

「Reflectionの認可を実装した」とは言わない。

---

# 6. HTTP Method and CORS

受け付けるのは `POST` だけ。

それ以外は `405 method_not_allowed` として断る。

断る判断は、bodyを読む前に行う。

`OPTIONS` とCORSは `withSupabase` が扱う。

自前のCORS headerを重ねて持たない。

任せてはいるが、実際の振る舞いはまだ確かめていない。

確認は17.2のGate（deployしたあと、公開の前）で行う。

---

# 7. Request Contract

```json
{
  "requestId": "...",
  "contractVersion": "v1",
  "reflectionEntryId": "...",
  "reflection": {
    "feelingText": "...",
    "noticedText": "..."
  }
}
```

Flutter側の `AiThinkingGatewayContract` と意味をそろえてある。

ただし **Dartの型をそのまま写したものではない**。

HTTPのbodyは信用できない入力なので、server側で独立に確かめ直す。

受け取らないもの：

- `humanId`
- `provider` / `model`
- `systemPrompt`
- Insight / Journey / Calendar / プロフィール

## 7.1 Validation

`parseThinkingRequest` が、次をすべて満たすものだけを先へ通す。

- JSONとして読めること
- 入れ物の形（object）であること
- `requestId` が空でない文字列であること
- `contractVersion` が `"v1"` であること
- `reflectionEntryId` が空でない文字列であること
- `reflection` が入れ物の形であること
- `feelingText` / `noticedText` が文字列またはnullであること
- 少なくともどちらかが空でないこと

空白だけの値は、書かれていないものとして扱う。

clientがtrimしている前提を置かず、server側でtrimしてからProviderへ渡す。

確かめ終わった材料は次の4つだけで組み立てる。

```
requestId / reflectionEntryId / feelingText / noticedText
```

bodyに知らない項目があっても読まないので、AIの材料には入らない。

版が違う場合（`"v2"` など）は当てずっぽうで解釈せず、

`unsupported_contract` として断る。

---

# 8. Provider Abstraction

```ts
type AiThinkingProviderInput = {
  readonly feelingText: string | null;
  readonly noticedText: string | null;
};

type AiThinkingProviderResult = {
  readonly questions: string[];
  readonly perspectives: string[];
  readonly possibilities: string[];
};
```

Providerへ渡すのは、Humanが書いた振り返りの言葉だけである。

渡さないもの：

- JWT / Authorization header
- email / 名前 / プロフィール
- `requestId`
- `reflectionEntryId`
- HTTP Request そのもの

Providerが返してよいのは、考えるための材料だけである。

返さないもの：

`insightText` / `finalAnswer` / `diagnosis` / `score` /
`nextAction` / `confidenceScore`

Providerを差し替えても、この入口と出口は変わらない。

handlerがprovider SDKを直接呼ぶ形にはしない。

## 8.1 Unconfigured Provider

本番の配線は `UnconfiguredAiThinkingProvider` を使う。

呼ばれたら、材料を作らずに失敗として返す。

→ `503` / `provider_unavailable`

**デモの材料へ黙って切り替えることはしない。**

つながっていないことをHumanに隠さないためである。

（`docs/08_AiGatewayDesign.md` 21章「No Silent Fallback」と同じ約束。）

## 8.2 Provider Response Validation

Providerの返事も信用できない入力として扱う。

compile-timeの型がどうであれ、runtimeでは何が返るかわからない。

そのため確認は `unknown` として受け、**入れ物の形から先に確かめる**。

- object であること（`null` / 文字 / 数 / 真偽 / 一覧 ではないこと）
- 3つの項目がそろっていること
- どれも一覧であること
- 中身がすべて文字列であること
- 空文字・空白だけの手がかりが混ざっていないこと
- 3つとも空ではないこと

満たさない場合は `502` / `invalid_provider_response` として返す。

確認そのものがthrowしないため、`500` へ紛れ込むことはない。

「取り決めに合わない返事」と「server側の想定外の失敗」を混ぜない。

本番のコードで `as AiThinkingProviderResult` を使い、

不正な値を正しいことにはしない。

未検証の材料をHumanへ渡さない。

---

# 9. Status Policy

| status | code | いつ |
| --- | --- | --- |
| 200 | — | 材料を返せた |
| 400 | `invalid_json` | bodyがJSONとして読めない |
| 400 | `invalid_request` | 取り決めに合わない |
| 400 | `unsupported_contract` | 読めない版 |
| 401 | — | 認証を通らない（wrapperが返す） |
| 405 | `method_not_allowed` | POST以外 |
| 429 | `rate_limited` | **未実装**。将来のrate limit用に空けてある |
| 500 | `internal_error` | server側の想定外の失敗 |
| 502 | `invalid_provider_response` | Providerの返事が取り決めに合わない |
| 503 | `provider_unavailable` | Providerが未設定、または使えない |

401 はhandlerの手前で決まる。handlerは401を組み立てない。

429 は今回返さない。表に載せてあるのは、あとで意味を変えないためである。

---

# 10. Response Shape

成功：

```json
{
  "requestId": "...",
  "contractVersion": "v1",
  "support": {
    "questions": ["..."],
    "perspectives": ["..."],
    "possibilities": ["..."]
  }
}
```

失敗：

```json
{
  "requestId": "...",
  "contractVersion": "v1",
  "error": { "code": "provider_unavailable" }
}
```

`requestId` が取り出せなかった場合だけ `null` になる。

応答に入れないもの：

- `feelingText` / `noticedText`（成功でも失敗でも返さない）
- stack trace
- providerの生のエラー文
- secret
- 内部のファイル名・行番号

失敗の `error` は `code` だけを持つ。

Humanへの言い方は `docs/07_AiThinkingSupportDesign.md` のとおり、

client側が決める。serverはHumanへの文章を作らない。

---

# 11. Logging and Redaction

振り返りの本文はHumanのprivate contentである。

ログへ出してよいもの：

- `requestId`
- 結果の種類（`success` / `provider_unavailable` など）
- status
- 所要時間
- Supabaseが付けるexecution ID

ログへ出してはならないもの：

- `feelingText` / `noticedText`
- 生成された材料の本文
- Authorization header / JWT
- request payload全文
- provider secret

書かない：

```
console.log(req)
console.log(await req.json())
console.log(payload)
console.error(rawProviderErrorWithPayload)
```

`_shared/log.ts` には、requestやpayloadをそのまま渡せる関数を用意しない。

渡せる形にしておくと、いつか渡してしまうためである。

ログ1行の組み立ては純粋な関数に切り出してあり、

何が出るのかをテストから確かめられる。

---

# 12. Secrets

今回のPhaseで新しいsecretは要らない。

- ソースへAPI keyのplaceholderを置かない
- `.env` をcommitしない
  （`supabase/.env*` と `supabase/functions/.env*` を `.gitignore` に入れてある。
  Edge Functionsは `supabase/functions/.env` を読むため、両方が要る。
  `supabase/functions/` と `supabase/config.toml` そのものは無視しない。）
- 本物のsecretの値を、ソース・ドキュメント・ログのどこにも書かない
- `SUPABASE_SECRET_KEY` は使わない（DBへ触らないため）

provider secretは、Providerへ実際につなぐときに

Supabaseのsecretとしてserver側だけが持つ。

Flutterリポジトリには置かない。

---

# 13. Tests

`deno test --allow-read supabase/functions/tests/`

| ファイル | 確かめていること |
| --- | --- |
| `contract_test.ts` | 取り決めの受け入れ／拒否、trim、余分な項目が内部へ入らないこと |
| `handler_test.ts` | methodの扱い、status、Providerへ渡る材料、Providerの不正な返事（root不正を含む）、応答とログに本文が出ないこと |
| `provider_test.ts` | 未設定のProviderが材料を作らずに失敗すること |
| `configuration_test.ts` | 設定の書き換わり検知（後述） |

`handler_test.ts` は、振り返りの本文へ目印の文字列を入れ、

その目印が **成功の応答にも、失敗の応答にも、ログにも** 現れないことを確かめる。

Providerへ渡った材料についても、キーが

`feelingText` / `noticedText` の2つだけであることを確かめる。

ネットワークにつながるテストは書かない。

## 13.1 What the Tests Do Not Prove

`configuration_test.ts` は **security testではない**。

確かめているのは「設定ファイルにそう書いてある」ことだけであり、

未認証requestが実際に止まることは確かめていない。

それはSupabaseのruntimeが動く場所でしか確かめられない。

このリポジトリの検証環境ではSupabase CLIもruntimeも使えないため、

**認証境界の統合テストは書いていない。**

偽の認証を用意して「security確認済み」と言うことはしない。

---

# 14. Runtime Limits

Supabase Edge Functionsの制限として、次を前提にする。

| 項目 | 値 |
| --- | --- |
| メモリ | 256MB |
| worker実行時間（有料プラン） | 400秒 |
| CPU時間 | 1 requestあたり 2秒 |
| requestのidle timeout | 150秒 |

ただし実際に効くのは、client側の待てる長さである。

`AiThinkingGatewayContract.requestTimeout` は30秒であり、

server側の上限より先にこちらが切れる。

`docs/08_AiGatewayDesign.md` 13章のとおり、待てる長さは1か所で管理する。

長く待たせる作りにしない。

CPU時間は1 requestあたり2秒しかないため、

server側で重い処理を行わない。Providerを待つのは待機であって計算ではない。

---

# 15. Deployment（未実施）

今回、次は行っていない。

- Supabase remote projectの作成
- `supabase link`
- `supabase functions deploy`
- remoteのsecret設定

そのため `config.toml` に project-ref を書かない。

実在しないIDを書いて、つながっているように見せることはしない。

deployするときの順番だけを、ここへ残しておく。

## 15.1 Runtime Verification Deploy

最初のdeployは、**いまのままの姿を確かめるため**のものである。

本番の配線は `UnconfiguredAiThinkingProvider` であり（8.1）、

Providerへはまだつないでいない。

したがって、この段階で **provider secretは要らない**。

secretが無いままdeployして、無いままの振る舞いを確かめる。

ただし、このdeployより前に**入力の大きさの上限**を決めておく（17.1）。

Providerへつないでいなくても、deployした瞬間から外に開くためである。

1. remote projectを作る
2. `supabase link`
3. `supabase functions deploy reflection-thinking`
4. 認証を通らないrequest → `401` で止まることを確かめる
5. 認証済みのrequest → `503` / `provider_unavailable` が返ることを確かめる
6. `OPTIONS` preflight とCORSの振る舞いを確かめる

4〜6番は、deployしたあとでなければ確かめられない。

local runtimeを起動できないためである（13.1）。

この3つは17.2のGateであり、**deployの手前ではなく、deployの直後に置く**。

4番を確かめるまで、「認証境界を確認した」とは言わない。

5番は、つながっていないことが**つながっていないものとして返る**ことの確認である。

デモの材料へ切り替わっていないことも、ここで見える。

6番を確かめるまで、「CORSは確認済み」とは言わない。

4〜6番がそろうまで、deployの検証は完了しておらず、公開運用へは進まない。

## 15.2 Real Provider Connection

provider secretを設定するのは、**実際のProviderへつなぐとき**である。

15.1のdeployの一部ではない。

順番は17.3のGateに従う。

- ownership authorization / rate limit / 利用量の上限 /
  idempotency / provider timeout を先に満たす
- provider secretをSupabaseのsecretとしてserver側へ設定する（12章）
- `UnconfiguredAiThinkingProvider` を実装済みのProviderへ差し替える
- 再度deployし、つながったことを確かめる

secretをsourceやFlutterリポジトリへ置かないことは、12章のとおり変わらない。

---

# 16. Flutter Side

このPhaseでFlutter側は変えていない。

- `ServerReflectionThinkingAssistant` はHomeへ配線していない
- 画面はこれまでどおりデモの経路で動く
- 「本番につながっている」表示は出さない
- `pubspec.yaml` は変えていない
- `supabase_flutter` も HTTP packageも追加していない

Flutterからこの窓口へ実際につなぐのは、次のPhaseの仕事である。

---

# 17. Future Security Pipeline

この窓口が本番で満たすべき順番。

```
1. 認証         … 実装済み（withSupabase / verify_jwt）
2. 取り決めの確認 … 実装済み
3. 認可         … 未実装（Reflectionの保存先が必要）
4. rate limit   … 未実装
5. 利用量の管理   … 未実装
6. Provider接続  … 未実装
```

上から順に積む。

3を飛ばして6を先に行わない。

残っている要件には、**いつまでに必要か** という境目がある。

「あとで」とだけ書くと、境目が消えて先送りになるため、

ここで3つのGateに分けて書いておく。

```
入力の大きさの上限          … 17.1（最初のdeployより前）
       ↓
Runtime Verification Deploy … 15.1
       ↓
401 / 503 / OPTIONS / CORS の確認 … 17.2（deployしたあと、公開の前）
       ↓
公開運用
       ↓
認可・rate limit・利用量・idempotency・
provider timeout・secret・prompt管理  … 17.3（実Providerより前）
       ↓
実Provider接続
```

どれも今回は実装しない。実装しないことを、ここに残す。

確かめる順番が守れるように、Gateも確かめる順番で並べてある。

## 17.1 Required Before Runtime Verification Deploy

**hosted runtimeへ最初にdeployするより前に**満たす必要があるもの。

外から誰でも叩ける場所へ置く時点で必要になる、という意味である。

Providerへつないでいなくても、deployした瞬間から外に開く。

### 入力の大きさの上限

現在、受け取る内容に長さの上限がない。

取り決めの形だけを確かめており、大きさは確かめていない。

最初のdeployより前に次を決める。

- request bodyそのものの大きさの上限
- `requestId` の最大長と、形式の制限
- `reflectionEntryId` の最大長
- `feelingText` の最大長
- `noticedText` の最大長

上限を超えたものは、Providerへ渡す前に断る。

Providerへつなぐ前であっても、CPU時間とメモリは有限である。

`UnconfiguredAiThinkingProvider` のままでも、

大きなbodyを読むこと自体に費用がかかる。

## 17.2 Required After Runtime Verification Deploy, Before Public Operation

**hosted runtimeへdeployしたあと、公開して使い始めるより前に**確かめるもの。

これらは設計ではなく、**実環境での確認**である。

このリポジトリの検証環境ではSupabase runtimeを起動できないため、

deployするまで確かめようがない（13.1と同じ理由）。

だからこそ、deployの手前ではなく、deployの直後のGateに置く。

手順は15.1のとおり。

### 認証境界の確認

- 認証を通らないrequest → `401` で止まること

`withSupabase({ auth: "user" })` と `verify_jwt = true` は設定済みだが、

設定してあることと、確かめたことは違う。

### つながっていないことの確認

- 認証済みのrequest → `503` / `provider_unavailable` が返ること

つながっていないことが、つながっていないものとして返るかを見る。

デモの材料へ切り替わっていないことも、ここで見える。

### OPTIONS / CORS の確認

CORSとpreflightは `withSupabase` に任せている（6章）。

**任せていることと、確かめたことは違う。**

- `OPTIONS` preflight が通ること
- 実際に返るCORS headerが、想定した通りであること

### 確かめるまで言わないこと

上の3つを確かめるまで、次のように扱わない。

- runtimeの認証境界を確認した
- CORSを確認した
- deployの検証が完了した
- 公開運用できる状態である

ひとつでも未確認なら、まだ検証の途中である。

## 17.3 Required Before Real Provider

**実際のAI Providerへつなぐより前に**満たす必要があるもの。

お金と、他のHumanのデータが関わり始める境目である。

### ownership authorization

`reflectionEntryId` の所有権をserver側で確かめる（5.2）。

Reflectionの保存先が要る。

### rate limit

認証されたHumanごと、妥当な時間窓で制限する。

振り返りの本文をkeyにしない。

### 利用量 / 費用の上限

1人あたり、および全体の上限を決める。

上限に達したときの返し方も決める。

### idempotency / deduplication

同じrequestが二重にProviderへ届かないようにする。

- 同じ `requestId` のrequestを二重に処理しない
- 再試行のとき、Providerの実行が二重に起きないようにする
- 二重の課金が起きないようにする（retry時のduplicate charge protection）

`requestId` は最初からあるが、突き合わせるための保存先がまだない。

### provider timeout / cancellation

Provider requestに、**server側の**待ち切り／打ち切りの境界を設ける。

client側の待てる長さ（30秒）だけに頼らない。

clientが先に切っても、server側の処理とProviderへの課金は続きうるためである。

14章に書いたのは「今はclient側が先に切れる」という現状であり、

Providerへつないだあとも同じでよい、という意味ではない。

### provider secret management

provider secretはSupabaseのsecretとしてserver側だけが持つ（12章）。

置き場所、入れ替えの手順、漏れたときの手順を決める。

### provider / model / prompt の管理

どのproviderをどのmodelで使うか、どう問いかけるかはserverが決める。

clientから `provider` / `model` / `systemPrompt` を受け取らない（7章）。

prompt policyは `docs/08_AiGatewayDesign.md` 18章のとおり。

---

# 18. Relationship to Other Documents

| 文書 | 受け持ち |
| --- | --- |
| `07_AiThinkingSupportDesign.md` | AIとHumanの関わり方 |
| `08_AiGatewayDesign.md` | Flutter側から見たGatewayの境界 |
| `09_SupabaseEdgeRuntimeDesign.md`（本書） | 境界の向こう側のserver runtime |

08で確定した Phase 10 の設計判断は、そのまま維持している。

Phase 11 で08の設計を書き換えてはいない。

ただし08は**まったくの無変更ではない**。

Supabase Edge Runtimeを置いたことに伴う注記として、次の2つだけを加えてある。

- 3章へ：この境界の向こう側にEdge Functionを置いたこと、
  認証と取り決めの確認は実装済みで、認可・rate limit・Provider接続は
  未実装のまま残っていること、本書を参照すること
- 5章へ：`POST /v1/ai/reflection-thinking` は境界を説明するための書き方であり、
  実際の経路は本書4章のものであること

どちらも補足であり、08の判断そのものは変えていない。

Phase 10 の判断は Phase 10 の文書のまま残す。

本書と08で書き方が食い違うのは endpoint だけであり、

実際の経路は本書の4章が正しい。
