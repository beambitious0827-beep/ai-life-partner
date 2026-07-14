# AI Life Partner

# 05_SystemArchitecture

## System Architecture Ver.1.0

---

## Document Information

### Version

Ver.1.0

### Purpose

本書は、AI Life Partnerの思想、機能、概念データモデルを、実際に動作するシステムへ変換するための全体構造を定義する。

本書では、次の内容を定める。

- Human Firstを実現するシステム構造
- モバイルアプリの責務
- Life Project Engineの位置付け
- Thinking and Dialogue Serviceの役割
- Journey、Reflection、Insight、Growthの処理構造
- AI Gatewayの責務
- データ基盤
- 家族利用と共有権限
- 外部サービス連携
- セキュリティとプライバシーの境界
- Family MVPの実装範囲
- 将来拡張可能なアーキテクチャ

### Depends On

- `FOUNDATION/00_MANIFESTO.md`
- `FOUNDATION/01_PROJECT_CHARTER.md`
- `FOUNDATION/02_AI_PRINCIPLES.md`
- `FOUNDATION/03_PRODUCT_PHILOSOPHY.md`
- `FOUNDATION/04_LIFE_OPERATING_SYSTEM.md`
- `FOUNDATION/05_HUMAN_PRINCIPLES.md`
- `docs/00_ProjectOverview.md`
- `docs/01_UserExperience.md`
- `docs/02_Requirements.md`
- `docs/03_Functions.md`
- `docs/04_DataModel.md`

### Provides To

- `docs/06_AI_Architecture.md`
- `docs/07_API_Design.md`
- `docs/08_UI_UX_Design.md`
- `docs/09_Security_Privacy.md`
- `docs/10_Roadmap.md`
- 将来作成する物理データベース設計書
- Flutterアプリケーション実装
- Supabaseバックエンド実装

---

# 1. アーキテクチャの目的

AI Life Partnerのシステムアーキテクチャは、AIを中心に構成しない。

中心に存在するのは、人生を歩むHumanである。

システムは、Humanが自ら考え、自ら選び、自ら行動し、自らの歩みを振り返ることを支えるために存在する。

> **AI Life Partnerは、AIが人を動かすシステムではない。**
>
> **人がより良く考えられる状態を、AIとシステムが支える構造である。**

技術は目的ではない。

Flutter、Supabase、AIモデル、外部サービスは、Humanの成長を支えるための手段である。

---

# 2. Architecture Principles

AI Life Partnerのシステム構造は、次の原則に従う。

## 2.1 Human First

Humanをシステムの中心に置く。

AI、データ、アルゴリズム、通知、分析は、Humanの外側から支援する。

## 2.2 Human Decision

AIが生成した提案を自動的に確定しない。

計画、予定、行動、共有、重要な設定変更は、原則としてHumanの確認を必要とする。

## 2.3 AI Independence

特定のAIモデルやAI事業者へ、システム全体を依存させない。

AIモデルを変更しても、Life Project、Journey、Reflectionなどの中核機能とデータは維持される構造とする。

## 2.4 Domain Independence

Health、Learningなどの分野固有機能を、Life Project Engineから分離する。

新しい分野を追加しても、システム全体を作り直さない構造とする。

## 2.5 Privacy by Design

プライバシーと権限制御は、後から追加する機能ではない。

認証、データ保存、共有、AI利用、外部連携のすべてに最初から組み込む。

## 2.6 Explainable Support

AIの提案は、理由、使用した情報、他の選択肢を確認できる構造とする。

## 2.7 Replaceable Components

AIモデル、通知基盤、外部カレンダー、健康データ連携などは交換可能な構成とする。

## 2.8 MVP First

年末のFamily MVPでは、家族が実際に使える中核体験を優先する。

将来機能のために、初期版を過度に複雑化しない。

---

# 3. Human First Architecture

AI Life Partnerの全体構造は、次の考え方を基本とする。

    Human
       │
       │  考える・選ぶ・決定する
       ▼
    Mobile Application
       │
       │  入力・確認・対話・表示
       ▼
    Application Services
       │
       ├── Life Project Engine
       ├── Planning Service
       ├── Journey Service
       ├── Reflection Service
       ├── Growth Interpretation Service
       ├── Family and Sharing Service
       └── Notification Service
       │
       ▼
    Thinking and Dialogue Service
       │
       ▼
    AI Gateway
       │
       ▼
    AI Provider
       
    Application Services
       │
       ▼
    Data Platform
       ├── Authentication
       ├── PostgreSQL
       ├── Storage
       ├── Authorization
       ├── Audit
       └── Server Functions

AIはHumanの内部には存在しない。

AIは、Application ServicesとAI Gatewayを通して、Humanとの対話を支援する。

HumanのPurpose、Goal、Journey、Reflection、Insight、Growthを、AIモデルそのものの内部記憶だけに保持してはならない。

重要な情報は、ユーザーが確認・修正・削除できるデータとして管理する。

---

# 4. システム全体構造

AI Life Partnerは、次の六つの領域で構成する。

## 4.1 Client Layer

Humanが直接利用するモバイルアプリケーション。

## 4.2 Application Layer

画面操作をLife ProjectやJourneyなどの処理へ変換する。

## 4.3 Domain Layer

AI Life Partner独自の概念とルールを扱う。

## 4.4 AI Support Layer

対話、提案、問いかけ、情報整理を支援する。

## 4.5 Data and Infrastructure Layer

認証、データ保存、ストレージ、監査、外部通信を扱う。

## 4.6 External Integration Layer

カレンダー、通知、健康データ、AI Providerなどと連携する。

全体像は次のとおりである。

    ┌─────────────────────────────┐
    │            Human            │
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │      Flutter Mobile App      │
    │ Presentation / Local State   │
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │     Application Services     │
    │ Use Cases / Coordination     │
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │        Domain Services       │
    │ Life Project / Journey       │
    │ Reflection / Growth          │
    └───────┬──────────────┬──────┘
            │              │
    ┌───────▼───────┐ ┌────▼────────────┐
    │  AI Gateway   │ │  Data Platform   │
    └───────┬───────┘ └────┬────────────┘
            │              │
    ┌───────▼───────┐ ┌────▼────────────┐
    │  AI Provider  │ │    Supabase      │
    └───────────────┘ │ Auth / Postgres  │
                      │ Storage / RLS     │
                      │ Edge Functions    │
                      └───────────────────┘

---

# 5. Client Application

## 5.1 Flutter Mobile Application

Family MVPでは、iPhoneおよびAndroid向けアプリをFlutterで構築する方針とする。

Flutterアプリは、次の責務を持つ。

- 画面表示
- ユーザー入力
- フォーム検証
- 画面状態の管理
- 一時的なローカル保存
- サーバーとの通信
- AIとの対話画面
- 通知の受信
- カメラ・写真選択
- 端末固有機能との連携
- オフライン時の最低限の入力保持

Flutterアプリは、AI Providerへ直接接続しない。

AI処理は必ずAI Gatewayを通す。

## 5.2 Feature-Based Structure

Flutterのコードは、画面種類だけで分けるのではなく、機能領域ごとに分割する。

想定構成は次のとおりである。

    lib/
    ├── main.dart
    ├── app/
    │   ├── app.dart
    │   ├── router/
    │   └── theme/
    ├── core/
    │   ├── authentication/
    │   ├── networking/
    │   ├── storage/
    │   ├── errors/
    │   └── utilities/
    ├── features/
    │   ├── onboarding/
    │   ├── home/
    │   ├── life_projects/
    │   ├── schedule/
    │   ├── actions/
    │   ├── journey/
    │   ├── reflection/
    │   ├── dialogue/
    │   ├── training/
    │   ├── nutrition/
    │   ├── sleep/
    │   ├── learning/
    │   ├── family/
    │   └── settings/
    └── shared/
        ├── widgets/
        ├── models/
        └── services/

この構成は初期案であり、実装時の検証を通して更新する。

## 5.3 Client Responsibilities

クライアントは、表示と入力に責任を持つ。

次の重要な判断を、クライアントだけで完結させない。

- AI提案の生成
- 家族共有権限の最終判定
- 機密データへのアクセス判定
- AIへ渡す情報範囲の決定
- サーバー側監査が必要な操作
- 管理権限の判定

---

# 6. Application Services

Application Servicesは、Clientからの要求を受け取り、複数のDomain ServiceやInfrastructureを調整する。

主なサービスは次のとおりである。

## 6.1 Onboarding Service

- 取り組んでいることの登録
- 目指す状態の登録
- 困っていることの登録
- 支援方法の設定
- 初期Life Projectの作成
- AIが理解した内容の確認

## 6.2 Life Project Application Service

- Life Projectの作成
- 編集
- 一時停止
- 再開
- 完了
- 優先順位の確認
- 関連データの取得

## 6.3 Planning Service

- Goalから計画候補を作る
- 予定と空き時間を確認する
- 複数Life Projectを調整する
- 計画案をHumanへ提示する
- Humanが決定した計画を保存する
- 予定変更時に再計画候補を作る

## 6.4 Journey Service

- Actionの実施結果を受け取る
- 予定どおりでなかった出来事も保存する
- 食事、睡眠、学習、運動などの歩みを関連付ける
- 写真やメモを保存する
- 事実、本人申告、推定を区別する

## 6.5 Reflection Service

- 日次振り返り
- 週次振り返り
- 月次振り返り
- Life Projectの節目の振り返り
- Reflectionから次の問いを組み立てる
- Humanが考えた内容を保存する

## 6.6 Growth Interpretation Service

Growth Interpretation Serviceは、成長を自動的に断定するサービスではない。

次の情報を整理し、Humanが自分の変化を理解できるようにする。

- Journeyの積み重ね
- Reflectionの変化
- Insight
- Goalへの進み方
- 習慣の変化
- 判断方法の変化
- 自分で計画・調整した経験

成長に関するAIの解釈は、Humanが確認・修正できるものとする。

## 6.7 Family and Sharing Service

- Family Groupの作成
- 家族メンバーの招待
- 本人と保護者の関係管理
- データ単位の共有設定
- 同意の記録
- 共有解除
- 年齢や役割に応じた制御
- 親子の対話材料の生成

---

# 7. Domain Layer

Domain Layerは、AI Life Partner固有の意味とルールを保持する。

Domain Layerは、Flutter、Supabase、特定のAIモデルなどの技術へ直接依存しないことを目指す。

主要なDomainは次のとおりである。

## 7.1 Human Domain

- Human
- Identity
- Life
- Relationship
- Preference
- Consent

## 7.2 Life Project Domain

- Life Project
- Purpose
- Goal
- Plan
- Action
- Project Status
- Project Priority

## 7.3 Journey Domain

- Journey
- Journey Entry
- Context
- Source
- Confirmation Status

## 7.4 Reflection Domain

- Reflection
- Reflection Question
- Reflection Answer
- Insight
- Next Decision

## 7.5 Growth Domain

- Growth Observation
- Growth Evidence
- Human Confirmation
- Growth Perspective

## 7.6 Health Domain

- Training
- Exercise
- Training Set
- Meal
- Sleep
- Body Condition
- Weight
- Fatigue
- Pain

## 7.7 Learning Domain

- Learning Project
- School
- Examination
- Subject
- Unit
- Study Action
- Assessment
- Score
- Question Result
- Understanding
- Teacher Advice

---

# 8. Life Project Engine

Life Project Engineは、AI Life Partnerの中核となるDomain Serviceである。

Life Projectを管理することだけを目的としない。

Humanが次の循環を歩めるよう支援する。

    Dialogue
       ↓
    Purpose
       ↓
    Goal
       ↓
    Current Status
       ↓
    Planning
       ↓
    Human Decision
       ↓
    Action
       ↓
    Journey
       ↓
    Reflection
       ↓
    Insight
       ↓
    Growth
       ↓
    Next Dialogue

## 8.1 Engine Responsibilities

- Life Projectの状態を管理する
- PurposeとGoalを関連付ける
- 現在地を整理する
- 計画候補を作る
- Humanの決定を記録する
- ActionとJourneyを関連付ける
- 振り返りを支援する
- Insightを保存する
- 次の計画へ接続する
- 複数Life Project間の調整材料を作る

## 8.2 Engine Restrictions

Life Project Engineは、次を行わない。

- Humanに代わって最終決定する
- AI提案を自動的に確定する
- 未達成を失敗として固定する
- 数値だけで成長を判定する
- HumanのPurposeを無視して効率だけを最適化する
- 一つのLife Projectだけを見て生活全体を無視する

---

# 9. Thinking and Dialogue Service

Thinking and Dialogue Serviceは、単なるチャット機能ではない。

Humanが考えを言葉にし、整理し、自分の答えを見つけるための対話を支援する。

## 9.1 Responsibilities

- Humanの発言を受け取る
- 関連するLife Projectを特定する
- 必要なContextを取得する
- 情報不足を確認する
- 問いを提示する
- 複数の選択肢を整理する
- 提案理由を説明する
- Humanの意思を確認する
- 会話からJourneyやReflectionの候補を作る
- 保存前に確認を求める

## 9.2 Dialogue Types

- 状況整理
- 目標整理
- 計画相談
- Action選択
- 予定変更
- 振り返り
- 気付きの言語化
- 成長の確認
- 人への相談準備
- AIの理解内容の修正

## 9.3 Thinking Support

対話では、AIが結論を先に出すだけでなく、必要に応じてHumanへ問いを返す。

例：

- 今の自分では、どの選択肢が合いそうですか。
- 一番気になっている点は何ですか。
- 前回と今回では、何が違いましたか。
- 次に試してみたい方法はありますか。
- 先生やトレーナーから受けた助言はありますか。

質問を増やしすぎて、Humanの負担にしないことも重要である。

---

# 10. AI Gateway

AI Gatewayは、AI Life Partnerと外部AI Providerの境界である。

モバイルアプリは、外部AI Providerへ直接接続しない。

## 10.1 Responsibilities

- AI Providerへの接続
- APIキーの保護
- 利用モデルの選択
- System Promptの適用
- AI Principlesの適用
- Human Principlesの適用
- 入力データの最小化
- 個人情報の除外・置換
- 出力形式の検証
- 不適切な出力の検出
- タイムアウトと再試行
- 利用量の記録
- 監査情報の保存
- AI Providerの切り替え

## 10.2 Context Construction

AIへすべてのデータを渡してはならない。

問い合わせに必要な範囲だけをContextとして構築する。

例：

トレーニング相談で利用する情報

- 対象Life Project
- 直近のトレーニング
- 今日の予定
- 睡眠
- 疲労
- 痛み
- Humanの希望

高校受験の相談で利用する情報

- 対象Life Project
- 試験日
- 教科・単元別結果
- 学習予定
- 学校・塾の予定
- 本人の理解度
- 先生からの助言

関係のない家族情報や他の相談内容は渡さない。

## 10.3 Structured AI Output

重要な提案は、可能な限り構造化された形式で受け取る。

主な項目は次のとおりである。

- 現在の状況
- 提案候補
- 提案理由
- 他の選択肢
- 注意点
- 不確実性
- 使用した情報
- Humanへの確認事項

AIの自然文だけを、そのまま確定データとして保存しない。

---

# 11. Data Platform

Family MVPのData Platformには、Supabaseを利用する方針とする。

## 11.1 PostgreSQL

次の情報を保存する。

- Human
- Profile
- Family Group
- Relationship
- Life Project
- Purpose
- Goal
- Plan
- Action
- Schedule
- Journey
- Reflection
- Insight
- Growth Observation
- AI Suggestion
- Human Decision
- AI Memory
- Consent
- Sharing Permission
- Audit Log

## 11.2 Authentication

- メールアドレスによる認証
- パスワード管理
- セッション管理
- パスワード再設定
- 将来のパスキー・外部認証
- 家族招待との関連付け

## 11.3 Row Level Security

データアクセスは、データベース側の権限制御を基本とする。

原則は次のとおりである。

- 本人のデータは本人だけが参照できる
- 家族共有は明示的な許可がある範囲に限定する
- 保護者であっても、すべてを無条件に参照できない
- AIとの相談内容は、他の共有項目と分離する
- 管理者権限による通常データ閲覧を最小限にする

## 11.4 Storage

次のファイルを保存する。

- 食事写真
- 学習資料
- テスト結果画像
- プロフィール画像
- 将来の音声記録
- その他の添付ファイル

ファイルもデータベースの共有権限と連動させる。

## 11.5 Server Functions

サーバー側処理は、次の用途で使用する。

- AI Gateway
- Context構築
- AI Provider呼び出し
- 通知処理
- 定期レビュー生成
- 外部サービス連携
- 監査ログ
- 機密処理
- サーバー側検証

---

# 12. Repository and Data Access

Flutterアプリから、画面が直接データベース処理を行わない構造を目指す。

想定する流れは次のとおりである。

    Screen
      ↓
    View Model / Controller
      ↓
    Use Case
      ↓
    Repository Interface
      ↓
    Repository Implementation
      ↓
    Supabase / Local Storage / External Service

Repositoryを通すことで、次を実現する。

- データ取得方法を画面から分離する
- テストしやすくする
- オフライン対応を追加しやすくする
- Supabase以外の保存先へ変更しやすくする
- AI Providerや外部サービスを交換しやすくする

---

# 13. Family and Sharing Architecture

Family MVPでは、家族利用を最初からシステム構造へ組み込む。

ただし、家族を一つの共有アカウントとして扱わない。

家族一人ひとりが独立したHumanおよびアカウントを持つ。

    Family Group
       │
       ├── Parent
       ├── Child A
       ├── Child B
       └── Other Member

## 13.1 Sharing Unit

共有単位は、データの種類ごとに分ける。

- Life Project概要
- Goal
- Schedule
- Action
- Journey
- Learning Result
- AI Analysis
- Reflection
- Dialogue
- Health Data
- Teacher Advice
- Training Advice

## 13.2 Default Privacy

初期状態は非公開を基本とする。

共有は、Humanの意思、年齢、家族内の役割、法的要件を考慮して設定する。

## 13.3 Parent Support

保護者機能は、監視ではなく支援を目的とする。

保護者へ表示する情報は、次のような対話材料を中心とする。

- 試験までの予定
- 本人が共有したGoal
- 学習計画
- 本人が共有した課題
- 先生からの助言
- 親子で話し合う候補

AIは保護者の代わりに子どもを評価したり、叱ったりしない。

---

# 14. Notification Architecture

通知は、Humanの注意を奪うためではなく、現実の行動を支えるために使用する。

通知処理は次の要素で構成する。

- Notification Preference
- Notification Rule
- Scheduled Notification
- Triggered Notification
- Delivery Result
- Human Response

通知例：

- Humanが設定した予定
- 試験日や期限
- 予定変更に伴う見直し
- Humanが希望した振り返り
- トレーニング前の体調確認
- 週次レビュー

AIが必要と判断しただけで、無制限に通知してはならない。

Humanは通知の分野、頻度、時間帯を設定できる。

---

# 15. External Integrations

## 15.1 Calendar

将来的に、次のカレンダー連携を検討する。

- Google Calendar
- Apple Calendar
- 端末カレンダー

MVPでは、アプリ内スケジュールを優先し、外部連携は段階的に導入する。

## 15.2 Health Data

将来的に、次の連携を検討する。

- Apple HealthKit
- Android Health Connect

連携候補は次のとおりである。

- 睡眠
- 体重
- 歩数
- ワークアウト
- 心拍数
- その他の健康・フィットネス情報

健康情報は機微性が高いため、データ種類ごとに明確な許可を求める。

Family MVPでは、手入力を基本として公開時期を優先する。

## 15.3 AI Provider

外部AI Providerは、AI Gatewayの背後に置く。

AI Providerの変更が、FlutterアプリやDomain Layerへ直接影響しない構造とする。

## 15.4 Push Notification Provider

iOSおよびAndroid向けのPush通知基盤を利用する。

通知内容には、機微な健康情報や学習相談の詳細を安易に表示しない。

---

# 16. Security and Privacy Boundary

AI Life Partnerは、次のような私的情報を扱う。

- 予定
- 健康
- 食事
- 睡眠
- 学習
- 成績
- 家族
- 相談
- 気持ち
- AIとの対話

そのため、システム境界を明確にする。

## 16.1 Trusted Client Boundary

モバイルアプリに秘密情報を埋め込まない。

アプリ内の値だけで権限を判断しない。

## 16.2 Server Boundary

AI ProviderのAPIキー、管理用キー、機密処理はサーバー側で扱う。

## 16.3 Database Boundary

データベースのRow Level Securityを主要な防御境界とする。

## 16.4 AI Boundary

AIへ渡すデータは、問い合わせに必要な範囲へ限定する。

AI Providerを、恒久的な正式記録の保存先として扱わない。

## 16.5 Family Boundary

家族であっても、Humanごとのデータ境界を維持する。

## 16.6 Health Boundary

健康データは他の一般データと同じ感覚で扱わず、権限、保存、利用目的を厳格に管理する。

---

# 17. Offline and Synchronization

Family MVPでは、完全なオフライン動作を必須としない。

ただし、通信が不安定な場合でも、入力途中の内容を失いにくい構造を目指す。

初期対応候補：

- 入力フォームの一時保存
- 未送信データの保持
- 再送処理
- 通信状態の表示
- 同期失敗時の再試行
- Humanによる内容確認

将来的には、ローカルデータベースとクラウド同期を検討する。

競合が発生した場合、重要なReflectionやJourneyを自動的に上書きしない。

---

# 18. Observability and Audit

システムは、問題発生時に原因を確認できなければならない。

ただし、監視のためにHumanの私的な内容を必要以上に収集しない。

記録する主な情報：

- ログイン結果
- APIエラー
- AI Gatewayエラー
- 同期エラー
- 権限エラー
- データ変更操作
- 共有設定変更
- 同意変更
- AI提案の生成日時
- 使用したモデル識別情報
- 提案の採用・修正・拒否状態

AIとの会話本文や健康情報を、通常の技術ログへそのまま出力しない。

---

# 19. Family MVP Architecture

年末までに家族が利用するFamily MVPでは、次の構成を対象とする。

    Flutter Mobile App
           │
           ▼
    Supabase Authentication
           │
           ▼
    Core Application Services
           ├── Onboarding
           ├── Life Project
           ├── Schedule
           ├── Action
           ├── Journey
           ├── Reflection
           ├── Training
           ├── Meal
           ├── Sleep
           ├── Learning
           └── Family Sharing
           │
           ├─────────────┐
           ▼             ▼
    Supabase Data     AI Gateway
    Platform              │
                         ▼
                     AI Provider

## 19.1 MVP User Flow

    Account Creation
          ↓
    Onboarding
          ↓
    Life Project Creation
          ↓
    Purpose and Goal
          ↓
    Schedule and Action
          ↓
    Human Decision
          ↓
    Journey
          ↓
    Reflection
          ↓
    AI Dialogue
          ↓
    Next Action

## 19.2 MVP Completion Criteria

Family MVPは、少なくとも次を満たした時点で利用可能と判断する。

1. 家族それぞれが自分のアカウントでログインできる
2. 自分のLife Projectを作成できる
3. PurposeとGoalを登録できる
4. スケジュールとActionを登録できる
5. トレーニング、食事、睡眠、学習の歩みを残せる
6. Reflectionを残せる
7. AIと対話して次の行動を考えられる
8. AI提案を修正・保留・拒否・決定できる
9. AIが利用した主な根拠を確認できる
10. 本人が許可した情報だけを家族と共有できる
11. 重要な操作の履歴を確認できる
12. Android端末で日常利用できる
13. iPhone向けビルドへ移行できる構造になっている

---

# 20. MVPで実装しないもの

公開時期を守るため、次の機能はFamily MVPの必須範囲から外す。

- 高度な音声会話
- Apple HealthKit連携
- Android Health Connect連携
- 高度な食事画像解析
- スマートウォッチアプリ
- 家計管理
- 旅行計画
- SNS機能
- 一般ユーザー同士のコミュニティ
- 高度な自動スケジューリング
- AIによる無確認の予定変更
- 完全なオフライン同期
- 複数AI Providerの自動切り替え
- 大規模な管理者向け分析画面

これらは、Family MVPの利用結果を踏まえて検討する。

---

# 21. Future Architecture

将来的には、次の拡張を想定する。

## 21.1 Domain Expansion

- Work Domain
- Career Domain
- Reading Domain
- Hobby Domain
- Finance Domain
- Parenting Domain
- Travel Domain

## 21.2 External Supporters

- 先生
- 塾講師
- トレーナー
- 栄養士
- 医療専門家
- コーチ

ただし、各支援者が閲覧できる情報は、Humanの同意と権限によって制御する。

## 21.3 Multi-Device

- iPhone
- Android
- Tablet
- Web
- Smartwatch

## 21.4 Advanced AI

- 複数AIモデル
- 分野別AI
- 音声対話
- 画像理解
- 長期的なJourney分析
- Reflection支援
- Human自身が作成する思考テンプレート

AIが高性能になっても、Human FirstとHuman Decisionを維持する。

---

# 22. Technology Candidates

Family MVPの技術候補は次のとおりである。

## Client

- Flutter
- Dart

## Backend and Data Platform

- Supabase
- PostgreSQL
- Supabase Auth
- Supabase Storage
- Row Level Security
- Edge Functions

## AI Integration

- Server-side AI Gateway
- External AI Provider
- Structured Output
- Context Builder
- Safety and Principle Validator

## Development

- GitHub
- Codex
- VS Code
- Flutter SDK
- Android Studio
- Xcode for iOS build and release

## Testing

- Flutter Unit Test
- Widget Test
- Integration Test
- Repository Test
- Domain Service Test
- Security Policy Test
- AI Output Validation Test

技術候補は、実装検証と費用、開発速度、保守性を踏まえて変更できる。

---

# 23. Architecture Decision Principles

技術や構造を決定する際は、次の順序で判断する。

1. Humanの安全と尊厳を守れるか
2. Humanの自己決定を守れるか
3. プライバシーを守れるか
4. Family MVPを期限内に実現できるか
5. シンプルに実装・運用できるか
6. テストできるか
7. 将来交換・拡張できるか
8. 費用を現実的に維持できるか
9. 開発者が理解しやすいか
10. 技術的な新しさ

新しい技術であることよりも、Human Firstを安定して実現できることを優先する。

---

# 24. Architecture Review Questions

新しい機能やサービスを追加するときは、次を確認する。

- Humanが中心になっているか
- AIが決定者になっていないか
- 提案と確定事項が分離されているか
- Humanが修正・拒否できるか
- Life Project Engineとの関係が明確か
- Journeyとして残すべき情報は何か
- Reflectionを支援できるか
- AIへ渡す情報は必要最小限か
- 家族間の境界を守れているか
- 子どもの主体性を守れているか
- 専門家の役割を置き換えていないか
- 将来別のAIや基盤へ交換できるか
- Family MVPに本当に必要か

一つでも重大な問題がある場合は、設計を見直す。

---

# Closing Statement

AI Life Partnerのシステムアーキテクチャは、AIを中心に構築されない。

中心にいるのは、人生を歩むHumanである。

Humanは考える。

Humanは選ぶ。

Humanは行動する。

Humanは立ち止まり、振り返り、気付き、再び歩き始める。

システムは、その循環を支える。

AIは、その循環の外側から、対話を通じて伴走する。

技術はHumanを管理するために存在するのではない。

Humanが自分の歩みを理解し、自分の次の一歩を選び、より良く考えられるようになるために存在する。

> **Human is the center.**
>
> **AI is the partner.**
>
> **Growth is the purpose.**

それが、AI Life PartnerのSystem Architectureである。
