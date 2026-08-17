# AI Life Partner

# 07_AiThinkingSupportDesign

## AI Thinking Support Design Ver.1.0

---

# 1. Purpose

本書は、AI Life Partnerにおける

**Reflection から Insight へ向かうときの、AIの関わり方**

を定義する。

AIは、Humanの振り返りを分析して「あなたの気づきはこれです」と答えを出す存在ではない。

AIは、Humanが自分で考えるための

- 問い
- 別の見方
- 可能性

を差し出すだけである。

最終的な気づきは、必ずHuman自身が考え、自分の言葉で書き、残すかどうかを決める。

---

# 2. Core Principle

AI出力は Thinking Support であり、Insight ではない。

| | 作る主体 | 保存されるか |
| --- | --- | --- |
| Thinking Support | AI | されない |
| Insight | Human | InsightEntryとして保存 |

AIが返した文章が、そのままInsightEntry.insightTextになることはない。

AIが返した文章を、気づきの入力欄へ自動で書き込むこともしない。

---

# 3. Flow

```
Reflection
  ↓ Humanが「一緒に考える」を選ぶ（任意）
ReflectionThinkingRequest
  ↓
ReflectionThinkingAssistant
  ↓
ReflectionThinkingSupport
  ↓ Humanが読んで考える
Humanが自分の言葉で気づきを書く
  ↓ Humanが「気づきを残す」を押す
InsightRepository.saveEntry()
```

AIを使わない場合も、この流れは成立する。

Reflection → InsightRecordPage → 入力 → 保存 だけで気づきは残せる。

---

# 4. Explicit Invocation

AIへの問い合わせは、Humanが明示的に操作したときにだけ始まる。

次のいずれでもAIを呼ばない。

- アプリ起動
- Home表示
- Reflection保存
- ReflectionPage表示
- InsightRecordPage表示
- 気づきの入力中
- 気づきの保存

自動再生成もしない。もう一度考えたいときは、Humanがもう一度選ぶ。

---

# 5. Data Minimization

AIへ渡すのは、Humanが選んだその振り返りの言葉だけである。

渡す：

- reflectionEntryId
- feelingText
- noticedText

渡さない：

- humanId
- 歩み（Journey）の履歴
- ほかのReflection
- Calendarの予定
- 家族の情報
- AboutYou / Life Projects
- 健康に関する情報
- これまでのInsight
- ほかのHumanのデータ

境界は `ReflectionThinkingRequest` として型で表す。

ReflectionEntryをそのままAI層へ渡さない。

そのまま渡すと、将来Reflectionへ項目が増えたときに、

Humanが意図しないものまで自動的にAIへ流れてしまうためである。

---

# 6. Human Ownership

別のHumanの振り返りをAIへ渡してはならない。

`InsightRecordPage` は、

`humanId != reflectionEntry.humanId`

のとき、

- 気づきの入力欄を出さない
- 保存操作を出さない
- AIへの入り口も出さない

assertではなく通常の分岐で確かめ、リリースビルドでも働くようにする。

---

# 7. AI Output Constraints

AIが返す言葉は、Humanが考える余地を残すものに限る。

使う：

- 〜かもしれません
- 〜という見方もあります
- 〜について考えてみることもできます
- 〜はどう感じますか？

使わない：

- あなたは○○です
- 原因は○○です
- ○○すべきです
- 正しい答え
- 改善すべき点
- あなたの問題点

精神疾患の診断、性格の断定、トラウマの断定、内面の断定は行わない。

Growth level / maturity / progress score / learning score へ変換することもしない。

AI supportからNext Actionを生成することもしない。

---

# 8. Provider Secret Handling

Flutter clientへ、AI providerの鍵を置かない。

- OpenAI API key
- Anthropic API key
- その他のprovider secret

をclientへ埋め込むこと、`.env` をassetへ入れてclientから直接provider APIを呼ぶことは禁止する。

安全なserver側の窓口ができるまでは、production AI providerへ直接つながない。

---

# 9. Implementation Status Ver.1.0

現時点でserver側の窓口は存在しない。

そのため v1 では、

- `ReflectionThinkingAssistant`（抽象）
- `DemoReflectionThinkingAssistant`（デモ実装）

までを用意し、体験の形だけを完成させている。

デモ実装は、

- ネットワークを使わない
- 外部packageを使わない
- 同じ材料からは同じ結果を返す
- 振り返りの中身を読み解いたふりをしない

`isDemo` がtrueのとき、画面は「AI思考サポート デモ」と控えめに断る。

本物のAIにつながっていると誤解させないためである。

server側の窓口ができたら、同じ抽象へ別の実装を差し替えることで、

画面の表示は自然に切り替わる。

---

# 10. Not a Repository

Thinking Supportは記録ではない。

そのため Repository を作らない。

- AI supportを永続保存しない
- InsightEntryへ questions / perspectives / possibilities / prompt / model名 / confidence を持たせない
- HumanのReflectionやInsightを「AI学習用データ」として蓄積しない

AI supportは画面の中だけに存在し、画面を離れれば消える。

---

# 11. Service Boundary

`ReflectionThinkingAssistant` から `InsightRepository` へ直接つながない。

AI serviceは気づきを保存しない。保存するのはHumanの操作だけである。

Assistantの実体は、Repositoryと同じく上位で1つ作って渡す。

画面が自分でデモ実装を作らない。

---

# 12. Failure Isolation

AIと一緒に考えられないことは、気づきを残せないことではない。

AI requestが失敗しても、

- 振り返りの内容は表示したままにする
- 気づきの入力欄は使えるままにする
- 気づきの保存もできるままにする
- AIの失敗だけをニュートラルに伝える
- Humanが望めばもう一度頼める

自動でのretryはしない。

---

# 13. Concurrency

考えている間は、続けて頼めないようにする。

それとは別に、答えが頼んだ順に返るとは限らないため、

要求ごとの通し番号で「いま受け入れる答え」を決める。

古い答えも、古い失敗も、新しい結果を上書きしない。

画面を離れた場合は、あとから返ってきた答えを捨てる。

AI requestのためにHumanを画面へ留めることはしない。

---

# 14. Not Included Ver.1.0

- production AI providerへの接続
- AIによるInsightの自動生成・自動保存
- AIによるReflectionの自動分析
- AIによるNext Action生成
- AIによるCalendar / Journey / Reflectionの変更
- Growth評価
- score / streak / achievement / ranking
- AI confidence score
- AI supportの永続保存
