# AI Life Partner

# 06_CalendarActionDesign

## Calendar and Action Integration Design Ver.1.0

---

# 1. Purpose

本書は、AI Life Partnerにおけるカレンダー機能と、

- Life Project
- Goal
- Action
- Journey
- Reflection
- AI Dialogue

を接続するための設計方針を定義する。

AI Life Partnerのカレンダーは、単なる予定管理機能ではない。

予定、空き時間、目標、体調、歩みを理解し、

**その人が次の一歩を考えるための時間的な土台**

として存在する。

---

# 2. Core Principle

AI Life Partnerにおいて、予定を決定する主体は人である。

AIは予定を勝手に変更しない。

AIは次の役割を担う。

1. 予定を整理する
2. 空き時間を見つける
3. Life Projectとの関係を考える
4. 実行可能なAction候補を提示する
5. 人の決定を支援する

基本原則は次のとおりである。

> **AIは提案する。決めるのは人である。**

---

# 3. Calendar Position

カレンダーは、Humanの生活とLife Projectを時間軸で接続する。

    Human
      │
      ├── Calendar
      │     ├── Events
      │     ├── Schedules
      │     ├── Available Time
      │     └── Time Constraints
      │
      └── Life Projects
            ├── Purpose
            ├── Goals
            ├── Plans
            ├── Actions
            ├── Journey
            ├── Reflection
            ├── Insight
            └── Growth

カレンダーはHumanの中に存在する。

AIはカレンダーの所有者ではない。

AIは、人から許可された範囲でカレンダーを理解し、支援に利用する。

---

# 4. Calendar Event

カレンダーに登録する予定をCalendar Eventとして扱う。

## 4.1 Basic Properties

Calendar Eventは、次の情報を持つ。

| Property | Description |
|---|---|
| Event ID | 予定を識別するID |
| Title | 予定名 |
| Description | 詳細や補足 |
| Start Date Time | 開始日時 |
| End Date Time | 終了日時 |
| All Day | 終日予定かどうか |
| Category | 予定の種類 |
| Life Project ID | 関連するLife Project |
| Recurrence | 繰り返し設定 |
| AI Visibility | AIが参照できる範囲 |
| Source | アプリ内・Apple・Googleなどの取得元 |
| Created At | 作成日時 |
| Updated At | 更新日時 |

---

# 5. Event Category

予定は次の分類を基本とする。

- 仕事
- 学校・学習
- 家族
- 健康
- トレーニング
- 食事
- 睡眠
- 趣味
- Life Project
- その他

分類は予定を制限するためではなく、AIが予定の意味を理解するために使用する。

利用者は、あとから分類を変更できる。

---

# 6. AI Visibility

予定ごとに、AIが参照できる範囲を設定できるようにする。

## 6.1 Full Access

AIは次の情報を参照できる。

- 予定名
- 日時
- 詳細
- カテゴリー
- 関連Life Project

## 6.2 Busy Time Only

AIは予定の内容を参照しない。

次の情報のみを利用する。

- 予定がある時間帯
- 空き時間
- 予定の長さ

表示例：

> 14時から16時までは予定があります。

## 6.3 Hidden

AIは予定の存在を参照しない。

家族共有や外部カレンダー連携でも、同じ考え方を適用する。

初期値は、利用者が確認できる安全な設定とする。

---

# 7. Available Time

Available Timeは、Calendar Eventから算出される空き時間である。

初期段階ではデータベースへ固定保存せず、予定から都度算出する。

例：

    09:00 - 10:00 仕事
    10:00 - 12:00 空き時間
    12:00 - 13:00 昼食
    13:00 - 15:00 空き時間
    15:00 - 17:00 会議

この場合、AI Life Partnerは次を理解できる。

- 10時から12時まで2時間空いている
- 13時から15時まで2時間空いている
- 15時以降は会議がある
- 長時間のActionは13時までに行う方がよい可能性がある

ただし、空き時間があることと、行動できることは同じではない。

AIは次の情報も確認する。

- 今の余力
- 睡眠
- 体調
- 移動時間
- 前後の予定
- 利用者の希望

---

# 8. Connection with Life Project

Calendar Eventは、任意でLife Projectと関連付けられる。

例：

| Calendar Event | Life Project |
|---|---|
| 数学の模試 | 大学受験 |
| 胸トレーニング | 筋肥大 |
| Flutter開発 | AI Life Partner開発 |
| ゴルフ | 健康・趣味 |

予定とLife Projectを接続することで、AIは単なる時間管理ではなく、

**その予定が何のために存在するか**

を理解できる。

---

# 9. Connection with Action

現在実装している「次の一歩を考える」は、Calendarから情報を受け取れるようにする。

現在の入力項目は次のとおりである。

- 進めたいLife Project
- 使用できる時間
- 今の余力
- 現在の状況

将来は、使用できる時間の初期候補をカレンダーから提示する。

例：

> 今日の予定から、次の空き時間が見つかりました。

- 10:30から11:00まで：30分
- 14:00から15:30まで：90分
- 20:00以降：予定なし

利用者は候補を選ぶことも、自分で別の時間を指定することもできる。

---

# 10. Action Proposal Context

AIがAction候補を考える際は、次の情報を利用する。

## 10.1 Required Context

- 選択されたLife Project
- Goal
- 利用できる時間
- 現在の余力
- 利用者が入力した状況

## 10.2 Extended Context

将来は次も利用する。

- 今日のCalendar Events
- 今週の予定
- 期限
- 直近のJourney
- 過去のAction
- Reflection
- 睡眠や体調
- 学習やトレーニングの履歴
- 利用者が希望する支援方法

---

# 11. Human Confirmation Flow

AIが提示したActionは、確定済みの予定ではない。

Action確定までの基本フローは次のとおりである。

    CalendarとLife Projectを確認
              ↓
    AIまたはシステムが候補を提示
              ↓
    人が候補を比較する
              ↓
    人が選択・編集する
              ↓
    人がActionを確定する
              ↓
    必要な場合だけCalendarへ登録する

AIが候補を提示しただけでは、Calendar Eventを作成しない。

カレンダーへ追加する前に、必ず人へ確認する。

---

# 12. Calendar Registration Flow

Action確定後、次の選択肢を表示できるようにする。

- 今日のActionとして保存する
- カレンダーへ予定として追加する
- 開始時刻を決める
- 通知を設定する
- 今は登録しない

表示例：

> このActionを、18時から19時の予定として追加しますか？

利用者が承認した場合のみ登録する。

---

# 13. Journey Connection

Actionを実行した後は、結果をJourneyへ残す。

    Calendar Event
          ↓
    Confirmed Action
          ↓
    Actual Experience
          ↓
    Journey
          ↓
    Reflection
          ↓
    Insight
          ↓
    Next Action

予定どおりできなかった場合も、失敗として扱わない。

次のような情報も歩みとして記録する。

- 実行できた
- 一部できた
- 別の行動をした
- 休むことを選んだ
- 予定を変更した
- 実行しなかった理由

すべてがその人の歩みである。

---

# 14. Internal Calendar MVP

最初のCalendar MVPでは、AI Life Partner内の予定だけを扱う。

## 14.1 Included

- 月表示
- 日付選択
- 予定一覧
- 予定作成
- 予定編集
- 予定削除
- 終日予定
- 時間指定予定
- カテゴリー
- Life Projectとの関連付け
- AI Visibility
- 今日の予定表示
- 空き時間の簡易算出
- 「次の一歩を考える」との接続

## 14.2 Not Included

初期MVPでは次を対象外とする。

- Appleカレンダー同期
- Googleカレンダー同期
- 複雑な繰り返し予定
- 複数人の予定調整
- AIによる自動予定変更
- 完全自動スケジューリング

---

# 15. External Calendar Integration

内部カレンダー完成後、外部カレンダーとの連携を検討する。

対象候補：

- Apple Calendar
- Google Calendar

利用者は連携方法を選択できるようにする。

- 読み込みのみ
- 書き込みのみ
- 双方向同期
- 時間枠のみ共有
- 連携しない

外部カレンダーとの同期は、利用者の明確な許可を必要とする。

---

# 16. Privacy Principles

カレンダーには、生活に関わる重要な情報が含まれる。

そのため、次の原則を守る。

1. 利用者が情報の所有者である
2. AIの参照範囲を選択できる
3. 家族共有は任意である
4. 予定の詳細を隠せる
5. AIが勝手に予定を変更しない
6. 外部カレンダー連携は明示的な許可を必要とする
7. 利用者はいつでも連携を解除できる

---

# 17. Initial Data Model

## 17.1 CalendarEvent

    CalendarEvent
    ├── id
    ├── humanId
    ├── title
    ├── description
    ├── startAt
    ├── endAt
    ├── isAllDay
    ├── category
    ├── lifeProjectId
    ├── aiVisibility
    ├── source
    ├── createdAt
    └── updatedAt

## 17.2 CalendarSource

    CalendarSource
    ├── internal
    ├── apple
    └── google

## 17.3 AIVisibility

    AIVisibility
    ├── full
    ├── busyOnly
    └── hidden

## 17.4 AvailableTimeWindow

AvailableTimeWindowは予定から算出する。

    AvailableTimeWindow
    ├── startAt
    ├── endAt
    └── durationMinutes

---

# 18. UI Structure

Calendar機能の基本画面構成は次のとおりとする。

    Calendar
    ├── Month View
    ├── Day View
    ├── Event List
    ├── Event Editor
    └── Availability View

ホーム画面には次を表示する。

- 今日の予定
- 次の予定
- 今日の空き時間
- 今日のAction
- 「次の一歩を考える」への入口

---

# 19. Implementation Phases

## Phase 1：Calendar Domain

- CalendarEventモデル
- Category
- AIVisibility
- CalendarRepositoryインターフェース
- メモリ上の予定保存

## Phase 2：Internal Calendar UI

- 月表示
- 日表示
- 予定作成
- 予定編集
- 予定削除

## Phase 3：Action Integration

- 今日の予定取得
- 空き時間算出
- NextStepPageへの受け渡し
- Action確定後のカレンダー登録

## Phase 4：Persistent Storage

- Supabase保存
- 認証ユーザーごとの分離
- RLS
- 複数端末同期

## Phase 5：External Integration

- Apple Calendar
- Google Calendar
- 同期範囲の選択
- AI参照範囲の設定

---

# 20. MVP Acceptance Criteria

Calendar MVPは、次の条件を満たしたとき完成とする。

- 月の予定を確認できる
- 日付ごとに予定を登録できる
- 予定を編集・削除できる
- 予定をLife Projectへ関連付けられる
- AI Visibilityを選択できる
- 今日の予定をホームで確認できる
- 今日の空き時間を算出できる
- 「次の一歩を考える」が予定を参照できる
- Actionを人が決定できる
- 承認後にActionを予定へ追加できる

---

# 21. Final Statement

AI Life Partnerのカレンダーは、

人の時間を管理するためだけの機能ではない。

人が大切にしていることと、

現実の予定をつなぎ、

その人が実行できる次の一歩を考えるための機能である。

AIは予定を支配しない。

AIは人の時間と歩みを理解し、

より良く考えるための選択肢を提示する。

そして最後に決めるのは、常に人である。