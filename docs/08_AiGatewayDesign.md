# AI Life Partner

# 08_AiGatewayDesign

## AI Gateway Design Ver.1.0

---

# 1. Purpose

本書は、AI Life Partnerが実際のAI Providerへつながるときの

**境界と安全条件**

を定義する。

AIとHumanの関わり方そのもの（AI出力はInsightではない、Humanが確定する等）は

`docs/07_AiThinkingSupportDesign.md` が定義する。本書はそれを前提に、

「どこを通って外へ出るか」「何を守るか」だけを扱う。

---

# 2. Target Architecture

```
InsightRecordPage
  ↓
ReflectionThinkingAssistant            （抽象）
  ↓
ServerReflectionThinkingAssistant      （本番候補）
  ↓
AiThinkingGatewayClient                （抽象／通信の口）
  ↓
AI Life Partner server-side gateway
  ↓
AiThinkingProvider                     （server側のprovider抽象）
  ↓
AI Provider
```

デモの経路：

```
InsightRecordPage
  ↓
ReflectionThinkingAssistant
  ↓
DemoReflectionThinkingAssistant
```

Presentationは `ReflectionThinkingAssistant` だけに依存する。

デモ実装にも、provider SDKにも、通信の口にも直接依存しない。

---

# 3. Implementation Status Ver.1.0

このリポジトリにserver runtimeは存在しない。

HTTP client dependencyも存在しない。

そのため Phase 10 では次までを実装した。

- Gateway contract（版・場所・待てる長さ）
- Request DTO / Response DTO
- `AiThinkingGatewayClient` 抽象
- `ServerReflectionThinkingAssistant`
- 応答の検証と、失敗の言い方の統一
- テスト

**未実装（意図的に残している）**

- 実際の通信実装
- server runtime
- 認証
- 認可
- rate limit
- provider統合
- server側のprompt管理

未実装のものを、実装済みのように見せる仕組みは置かない。

---

# 4. Provider Secret

Flutterリポジトリにprovider secretを置かない。

禁止：

- ソースへ直接書いたAPI key
- コミットされた `.env` のsecret
- Flutter assetのsecret
- `--dart-define` による本番provider secret
- client側のOpenAI key / Anthropic key

provider secretはserver側だけが持つ。

Flutterはprovider APIを直接呼ばない。呼び先はserver側の窓口だけである。

---

# 5. Request Contract

```
POST /v1/ai/reflection-thinking
```

Request：

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

Response：

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

---

# 6. Data Minimization

送るもの：

- `requestId`（追跡のためのopaqueなID）
- `contractVersion`
- `reflectionEntryId`
- `feelingText`
- `noticedText`

送らないもの：

- Humanのプロフィール
- AboutYou / Life Projects
- 歩みの履歴
- ほかの振り返り
- これまでの気づき
- カレンダー
- 家族の情報
- 健康の情報
- ほかのHumanのデータ
- systemプロンプト

`ReflectionEntry` をそのままserializeしない。

送る項目は `AiThinkingGatewayRequest` に書かれたものだけであり、

将来Reflectionへ項目が増えても、この型を変えないかぎり外へ出ない。

---

# 7. Human ID

client payloadに `humanId` を含めない。

clientが申告したHuman IDをserverが無条件で信用する設計にしないためである。

本番では、

```
認証されたserver側の身元
  → そのHumanが使える範囲
```

をserver側で解決する。

Ver.1.0では認証が未実装のため、この点は要件として残っている。

---

# 8. Request ID

`requestId` はランダム、またはopaqueな値とする。

含めてよいもの：なし（追跡のためだけの識別子）。

含めてはならないもの：

- メールアドレス
- 名前
- 振り返りの本文
- Reflection ID をそのまま流用した値

用途：

- 追跡
- 重複依頼の調査
- 将来の冪等化 / 重複検出
- 遅延応答の切り分け

---

# 9. Contract Version

`contractVersion` を Request / Response の両方に持つ。

Ver.1.0では `"v1"`。

Flutterは、知らない版のResponseを当てずっぽうで解釈しない。

版が一致しない場合は `invalidResponse` として扱う。

---

# 10. Response Validation

Gateway responseを無条件で信用しない。

Flutter側の境界で次を確認する。

- 応答が入れ物の形をしていること
- `requestId` が空でない文字列であること
- `requestId` が、こちらが送ったものと一致すること
- `contractVersion` が読める版であること
- `support` が入れ物の形をしていること
- `questions` / `perspectives` / `possibilities` の3つがそろっていること
- 各項目が文字列の一覧であること
- 空文字・空白だけの手がかりが混ざっていないこと

いずれかを満たさない場合、未検証の内容をPresentationへ渡さない。

## 10.1 Required Support Keys

`support` の3つの項目は、どれも省略できない。

**空の一覧**と**項目がないこと**は、別のものとして扱う。

有効：

```json
{ "questions": [], "perspectives": [], "possibilities": ["別の見方"] }
```

無効（`questions` が無い）：

```json
{ "perspectives": [], "possibilities": ["別の見方"] }
```

無効（`questions` がnull）：

```json
{ "questions": null, "perspectives": [], "possibilities": ["別の見方"] }
```

確認は二段階に分かれる。

1. 形の確認：3つの一覧がそろっていること
2. 中身の確認：3つとも空なら、使える材料がない応答として扱う

## 10.2 Where the Invariant Lives

`AiThinkingGatewayResponse` は、`fromJson` を通しても直接組み立てても、

同じ取り決めを満たしたものしか作れない。

`fromJson` だけが安全、という状態にしない。

加えて `ServerReflectionThinkingAssistant` でも

`requestId` の一致と `contractVersion` を確かめ直す。

`AiThinkingGatewayClient` はarchitecture上の境界であり、

通信の実装はこの先増えうるためである。

Responseで受け取らないもの：

- `insightText`
- `finalAnswer`
- `score`
- `diagnosis`
- `confidenceScore`
- `nextAction`

取り決めにない項目は読み取らず、保持もしない。

---

# 11. Empty Support

`questions` / `perspectives` / `possibilities` がすべて空の応答は、

**使えない応答**として扱う。

空のAIの欄を成功としてHumanに見せない。

Humanにはニュートラルな失敗として伝える。

---

# 12. Error Normalization

Presentationがprovider固有のerrorに依存しないよう、

次の2段階で言い方をそろえる。

| 層 | 型 |
| --- | --- |
| 通信の口 | `AiThinkingGatewayException` / `AiThinkingGatewayFailure` |
| アプリ共通 | `ReflectionThinkingException` / `ReflectionThinkingFailure` |

区別する種類：

`timeout` / `unauthorized` / `rateLimited` / `unavailable` /
`invalidResponse` / `unknown`

providerのエラーメッセージをそのままUIへ表示しない。

Humanへは `07_AiThinkingSupportDesign.md` のとおり、

「今はAIと一緒に考えることができませんでした。自分の言葉で気づきを残すことはできます。」

とだけ伝える。

---

# 13. Timeout

待てる長さは `AiThinkingGatewayContract.requestTimeout` の1か所で管理する。

Ver.1.0では30秒。

`ServerReflectionThinkingAssistant` がこの上限を適用し、

超えた場合は `timeout` として扱う。

通信実装を追加するときは、その実装側でも同じ上限を守ること。

画面側に秒数を書かない。

---

# 14. Logging and Redaction

振り返りの本文はHumanのprivate contentである。

通常のログへ本文を出さない。

ログに出してよいもの：

- `requestId`
- 時刻
- 成功 / 失敗
- 所要時間
- 応答のstatus
- 機微でないエラー分類

ログに出してはならないもの：

- `feelingText`
- `noticedText`
- 生成されたThinking Support本文
- request payload全文

例外の文字列にも本文を含めない。

`AiThinkingGatewayException` と `ReflectionThinkingException` は

メッセージ本文を持たず、種類と `requestId` だけを示す。

`print(request)` / `debugPrint(jsonEncode(request))` のような出力を書かない。

---

# 15. Authentication（未実装）

本番のGatewayは認証済みrequestだけを受け付ける必要がある。

Ver.1.0では認証を実装していない。

偽の認証を用意して安全になったように見せることはしない。

以下は禁止：

- ソースへ直接書いたbearer token
- 偽の本番API key
- 「localhostだから安全」という扱い
- clientの `humanId` だけで認可済みとみなす扱い
- デモのendpointを本番Gatewayと呼ぶこと

---

# 16. Authorization（未実装）

本番のserverは、

```
requestしているHuman
  が
対象のReflectionを使える
```

ことをserver側で確認する必要がある。

Ver.1.0ではserver側にReflectionの保存先がないため実装できない。

Flutter側のownership確認（`humanId != reflectionEntry.humanId` なら

AIへ渡さない）は、Humanの取り違えを防ぐための画面上の境界であり、

本番のsecurity boundaryではない。

---

# 17. Rate Limit（未実装）

本番Gatewayにはrate limitが必要である。

方針：

- 認証されたHumanごと
- 妥当な時間窓

振り返りの本文をkeyにしない。

Ver.1.0では要件として記載するにとどめる。

---

# 18. Prompt Ownership

本番のpromptはserver側で管理する。

Flutterからsystem promptを送らない。

Flutterが送るのはHumanのcontextだけであり、

どう問いかけるかはserverの責任である。

server側のprompt policyとして、AIは：

- Humanの答えを決めない
- 診断しない
- 採点しない
- 行動を命令しない
- Insightを確定しない

AIは：

- 問い
- 別の見方
- 可能性

を提示する。

---

# 19. Provider Abstraction

server runtimeを作るときも、

```
Gateway handler
  → OpenAI SDK 直書き
```

にしない。

server側にも `AiThinkingProvider` 等の抽象を置き、

provider差し替えとprompt policyを一箇所にまとめる。

Flutter側の contract には `provider` / `model` を含めない。

どのproviderをどのmodelで使うかはserverが決める。

---

# 20. Demo / Server Switching

どちらのAssistantを使うかは、dependency wiring側で決める。

Presentationに `if (production)` のような分岐を置かない。

`HomePage` は `ReflectionThinkingAssistant` を受け取り、

省略された場合だけ `DemoReflectionThinkingAssistant` を使う。

---

# 21. No Silent Fallback

Server Assistantが失敗したとき、自動でDemo Assistantへ切り替えない。

Humanが本物のAIとデモを取り違えるためである。

- 本番Gatewayの失敗 → 失敗としてHumanへ伝える
- デモを使う場合 → 明示的なデモとして使う

`isDemo` がtrueのときだけ「AI思考サポート デモ」と表示する。

`ServerReflectionThinkingAssistant` は `isDemo` がfalseだが、

それは「つながる窓口がある」という意味ではない。

窓口がなければ、頼んでも失敗として返る。

「接続済み」と誤認させる表示は出さない。

---

# 22. Duplicate and Stale Requests

client側では Phase 9 のとおり、

- 考えている間は重ねて頼めない（handler自身が拒否する）
- 古い答えは新しい答えを上書きしない
- 画面を離れたあとの答えは捨てる

を維持する。

Gateway contractに `requestId` があるため、

将来server側で重複検出を追加できる。

Ver.1.0では重複検出のための保存先を追加しない。

---

# 23. Retry

失敗後の再依頼はHumanの明示操作だけで行う。

自動retryを行わない。

`rateLimited` に対して繰り返し頼まない。

---

# 24. Insight Save Independence

Gatewayが使えなくても、Humanは自分の言葉で気づきを残せる。

```
AI Gateway の可用性
  ≠
Insight機能の可用性
```

`ServerReflectionThinkingAssistant` はInsightRepositoryにも

ReflectionRepositoryにも依存しない。

AI serviceが気づきを保存することはない。
