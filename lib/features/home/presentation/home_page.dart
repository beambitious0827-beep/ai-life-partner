import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/services/available_time_calculator.dart';
import 'package:ai_life_partner/features/calendar/presentation/calendar_page.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_editor_page.dart';
import 'package:ai_life_partner/features/home/presentation/action_calendar_registration.dart';
import 'package:ai_life_partner/features/home/presentation/action_journey_record.dart';
import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_page.dart';
import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_page.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_record_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/action_calendar_prefill.dart';
import 'package:ai_life_partner/features/next_step/presentation/calendar_availability.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.selectedAreas,
    required this.goals,
    required this.supportPreferences,
    this.displayName,
    this.calendarRepository,
    this.journeyRepository,
    this.reflectionRepository,
    this.insightRepository,
  });

  final String? displayName;
  final List<String> selectedAreas;
  final Map<String, String> goals;
  final List<String> supportPreferences;

  /// 省略した場合は、アプリ内メモリのRepositoryを使用する。
  ///
  /// Persistent Storage Phaseで別の実装へ差し替えられるようにしてある。
  final CalendarRepository? calendarRepository;

  /// 省略した場合は、アプリ内メモリのRepositoryを使用する。
  final JourneyRepository? journeyRepository;

  /// 省略した場合は、アプリ内メモリのRepositoryを使用する。
  final ReflectionRepository? reflectionRepository;

  /// 省略した場合は、アプリ内メモリのRepositoryを使用する。
  final InsightRepository? insightRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _humanId = 'local-human';

  /// Calendar Available Time UIと同じv1のルール。
  ///
  /// 将来は起床時間や生活パターンから決められるよう、
  /// AvailableTimeCalculatorへは固定せず呼び出し側で範囲を組み立てる。
  static const int _availabilityStartHour = 6;
  static const int _availabilityEndHour = 23;

  static const AvailableTimeCalculator _availableTimeCalculator =
      AvailableTimeCalculator();

  late final CalendarRepository _calendarRepository =
      widget.calendarRepository ?? InMemoryCalendarRepository();

  late final JourneyRepository _journeyRepository =
      widget.journeyRepository ?? InMemoryJourneyRepository();

  /// 振り返りは、Journeyからも振り返り一覧からも同じ内容が見えている必要がある。
  /// そのため、画面ごとに作らず、この一つを渡して共有する。
  late final ReflectionRepository _reflectionRepository =
      widget.reflectionRepository ?? InMemoryReflectionRepository();

  /// 気づきも、振り返りからも気づき一覧からも同じ内容が見えている必要がある。
  /// そのため、画面ごとに作らず、この一つを渡して共有する。
  late final InsightRepository _insightRepository =
      widget.insightRepository ?? InMemoryInsightRepository();

  /// Humanが最後に確定した次の一歩。
  ///
  /// 選んだ時間の情報も保持しておき、将来のCalendar登録フローで利用する。
  /// 現時点ではCalendar Eventを作成しない。
  NextStepResult? _todayNextStep;

  /// 今日の一歩をカレンダーへ登録した記録。
  ///
  /// どの一歩を、どのCalendar Eventとして保存したのかを持つ。
  /// Calendar側で削除された場合は、この記録を解除する。
  ActionCalendarRegistration? _calendarRegistration;

  /// 「今は追加しない」を選んだかどうか。
  ///
  /// 強い問いかけを閉じるだけで、追加そのものを諦めた印ではない。
  /// あとから考え直せるよう、控えめな操作は残す。
  bool _calendarPromptDeclined = false;

  /// 今日の一歩を歩みとして残した記録。
  ///
  /// どの一歩を、どのJourneyEntryとして残したのかを持つ。
  ActionJourneyRecord? _journeyRecord;

  String? get _todayAction => _todayNextStep?.actionText;

  /// いまの一歩を歩みとして残したかどうか。
  bool get _todayActionRecordedInJourney {
    final record = _journeyRecord;
    final nextStep = _todayNextStep;

    if (record == null || nextStep == null) {
      return false;
    }

    return record.isFor(nextStep);
  }

  /// いまの一歩がカレンダーへ登録済みかどうか。
  bool get _todayActionAddedToCalendar {
    final registration = _calendarRegistration;
    final nextStep = _todayNextStep;

    if (registration == null || nextStep == null) {
      return false;
    }

    return registration.isFor(nextStep);
  }

  String get _name {
    final name = widget.displayName?.trim();

    if (name == null || name.isEmpty) {
      return 'あなた';
    }

    return name;
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 今日の予定から空き時間を算出する。
  ///
  ///     CalendarRepository → CalendarEvent
  ///         → AvailableTimeCalculator → AvailableTimeWindow
  ///
  /// NextStepPageへはAvailableTimeWindowだけを渡し、
  /// CalendarEventの内容は持ち出さない。
  Future<CalendarAvailability> _loadTodayAvailability() async {
    final now = DateTime.now();

    final rangeStart = DateTime(
      now.year,
      now.month,
      now.day,
      _availabilityStartHour,
    );

    final rangeEnd = DateTime(
      now.year,
      now.month,
      now.day,
      _availabilityEndHour,
    );

    try {
      final events = await _calendarRepository.getEvents(
        humanId: _humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      return CalendarAvailability.loaded(
        _availableTimeCalculator.calculate(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          events: events,
        ),
      );
    } on Object catch (error) {
      // 失敗を空の結果にすり替えると、
      // 「予定で埋まっている」と「確認できなかった」が区別できなくなる。
      // 失敗はfailedとしてHumanへ伝え、診断は予定の中身を含めずに残す。
      debugPrint('今日の空き時間を確認できませんでした: ${error.runtimeType}');

      return const CalendarAvailability.failed();
    }
  }

  Future<void> _openNextStep() async {
    final availability = await _loadTodayAvailability();

    if (!mounted) {
      return;
    }

    final result = await Navigator.of(context).push<NextStepResult>(
      MaterialPageRoute<NextStepResult>(
        builder: (context) => NextStepPage(
          displayName: widget.displayName,
          selectedAreas: widget.selectedAreas,
          goals: widget.goals,
          availability: availability,
          onReloadAvailability: _loadTodayAvailability,
        ),
      ),
    );

    if (!mounted || result == null || result.actionText.trim().isEmpty) {
      return;
    }

    // 実質的に同じ一歩を決め直しただけなら、登録済みの状態は保つ。
    // 同じCalendar Eventを二重に作りやすい状態へ戻さないため。
    final isSameAction = _todayNextStep == result;

    setState(() {
      _todayNextStep = result;

      if (!isSameAction) {
        // 別の一歩なので、前の一歩の登録記録は引き継がない。
        _calendarRegistration = null;
        _calendarPromptDeclined = false;

        // 歩みの記録も同じで、新しい一歩は未記録から始まる。
        _journeyRecord = null;
      }
    });
  }

  /// 今日の一歩について、その後どうだったかをHumanが残す。
  ///
  /// ここではJourneyEntryを作らない。
  /// 記録画面でHumanが「歩みとして残す」を押したときだけ保存される。
  Future<void> _openJourneyRecord() async {
    final nextStep = _todayNextStep;

    if (nextStep == null || _todayActionRecordedInJourney) {
      return;
    }

    // カレンダーへ登録している一歩なら、その予定IDを写しとして持たせる。
    // Journey自体はCalendar Eventに依存しない。
    final sourceCalendarEventId = _todayActionAddedToCalendar
        ? _calendarRegistration?.calendarEventId
        : null;

    final entry = await Navigator.of(context).push<JourneyEntry>(
      MaterialPageRoute<JourneyEntry>(
        builder: (context) => JourneyRecordPage(
          repository: _journeyRepository,
          humanId: _humanId,
          plannedActionText: nextStep.actionText,
          plannedDuration: nextStep.actionDuration,
          sourceCalendarEventId: sourceCalendarEventId,
        ),
      ),
    );

    if (!mounted || entry == null) {
      return;
    }

    setState(() {
      _journeyRecord = ActionJourneyRecord(
        action: nextStep,
        journeyEntryId: entry.id,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('歩みに残しました。')));
  }

  Future<void> _openJourney() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => JourneyPage(
          repository: _journeyRepository,
          reflectionRepository: _reflectionRepository,
          humanId: _humanId,
        ),
      ),
    );
  }

  /// これまでの振り返りを読み返す画面を開く。
  ///
  /// ここでは新しい振り返りを作らない。
  /// 振り返りを始められるのは、対象になる歩みがある場所からだけにする。
  Future<void> _openReflection() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ReflectionPage(
          reflectionRepository: _reflectionRepository,
          journeyRepository: _journeyRepository,
          insightRepository: _insightRepository,
          humanId: _humanId,
        ),
      ),
    );
  }

  /// これまでの気づきを読み返す画面を開く。
  ///
  /// ここでは新しい気づきを作らない。
  /// 気づきを残し始められるのは、もとになる振り返りがある場所からだけにする。
  Future<void> _openInsight() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => InsightPage(
          insightRepository: _insightRepository,
          reflectionRepository: _reflectionRepository,
          humanId: _humanId,
        ),
      ),
    );
  }

  /// 今日の一歩をカレンダーへ追加するかどうかを、Humanが確認する。
  ///
  /// ここではCalendar Eventを作らない。
  /// Event Editorを開き、内容と日時をHumanが確認して保存したときだけ、
  /// CalendarRepository.saveEvent()が実行される。
  Future<void> _addTodayActionToCalendar() async {
    final nextStep = _todayNextStep;

    if (nextStep == null || _todayActionAddedToCalendar) {
      return;
    }

    final now = DateTime.now();

    // 時刻の情報がないActionのために、
    // Event Editorの新規作成時と同じ既定の開始時刻を基準にする。
    final defaultStartAt = DateTime(
      now.year,
      now.month,
      now.day,
      EventEditorPage.defaultStartTime.hour,
      EventEditorPage.defaultStartTime.minute,
    );

    final prefill = buildActionCalendarPrefill(
      result: nextStep,
      defaultStartAt: defaultStartAt,
    );

    final result = await Navigator.of(context).push<EventEditorResult>(
      MaterialPageRoute<EventEditorResult>(
        builder: (context) => EventEditorPage(
          repository: _calendarRepository,
          humanId: _humanId,
          initialDate: defaultStartAt,
          initialPrefill: prefill,
        ),
      ),
    );

    if (!mounted || result == null || !result.isSaved) {
      return;
    }

    setState(() {
      // 保存されたCalendar EventのIDを、対象の一歩と対にして持つ。
      _calendarRegistration = ActionCalendarRegistration(
        action: nextStep,
        calendarEventId: result.event.id,
      );

      _calendarPromptDeclined = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('カレンダーに追加しました。')));
  }

  void _declineCalendarPrompt() {
    setState(() {
      _calendarPromptDeclined = true;
    });
  }

  /// 登録済みのCalendar Eventが、まだ存在するかを確認する。
  ///
  /// Calendar側で削除されていれば登録記録を解除し、
  /// 同じ一歩をもう一度追加できるようにする。
  ///
  /// 取得に失敗しただけの場合は「削除された」と判断しない。
  Future<void> _reconcileCalendarRegistration() async {
    final registration = _calendarRegistration;

    if (registration == null) {
      return;
    }

    try {
      final event = await _calendarRepository.getEventById(
        registration.calendarEventId,
      );

      if (!mounted) {
        return;
      }

      // 待っている間に、別の一歩が登録されていることがある。
      // その場合この結果は古いので、新しい登録には触れない。
      final current = _calendarRegistration;

      if (current == null || !current.isSameRegistrationAs(registration)) {
        return;
      }

      if (event != null) {
        return;
      }

      setState(() {
        _calendarRegistration = null;
      });
    } on Object catch (error) {
      // 確認できなかっただけなので、登録記録はそのまま残す。
      debugPrint('カレンダーの登録状態を確認できませんでした: ${error.runtimeType}');
    }
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            CalendarPage(repository: _calendarRepository, humanId: _humanId),
      ),
    );

    if (!mounted) {
      return;
    }

    // カレンダー側で予定が削除されている場合があるので、登録状態を確認し直す。
    await _reconcileCalendarRegistration();
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedAreas(BuildContext context) {
    if (widget.selectedAreas.isEmpty) {
      return Text(
        '取り組むことは、これから一緒に考えられます。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.selectedAreas
          .map((area) => Chip(label: Text(area)))
          .toList(),
    );
  }

  Widget _buildGoals(BuildContext context) {
    if (widget.goals.isEmpty) {
      return Text(
        '目標はまだ決まっていません。\n'
        '対話をしながら少しずつ整理していきましょう。',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.goals.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                entry.value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupportPreferences(BuildContext context) {
    if (widget.supportPreferences.isEmpty) {
      return Text(
        '支援方法は、利用しながら選べます。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.supportPreferences
          .map(
            (preference) => Chip(
              avatar: const Icon(Icons.check, size: 18),
              label: Text(preference),
            ),
          )
          .toList(),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 今日の一歩をカレンダーへ追加するかどうかの、控えめな案内。
  ///
  /// Actionを決めたことと、カレンダーへ登録することは別の判断なので、
  /// 追加するかどうかはHumanがここで選ぶ。
  /// 今日の一歩を歩みとして残すかどうかの、控えめな案内。
  ///
  /// Actionを決めたことと、歩みとして残すことは別の判断なので、
  /// 残すかどうかはHumanがここで選ぶ。
  Widget _buildJourneyPrompt(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_todayActionRecordedInJourney) {
      return Row(
        key: const Key('home_action_journey_recorded'),
        children: [
          Icon(Icons.route_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'この一歩は歩みに残しました。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return Column(
      key: const Key('home_action_journey_prompt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'その後どうだったかを、歩みとして残せます。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 4),
        Text(
          '取り組んだ日も、別のことを選んだ日も、休んだ日も残せます。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('home_record_journey_button'),
            onPressed: _openJourneyRecord,
            icon: const Icon(Icons.route_outlined),
            label: const Text('歩みとして残す'),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarPrompt(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_todayActionAddedToCalendar) {
      return Row(
        key: const Key('home_action_calendar_registered'),
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'この一歩はカレンダーに追加済みです。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    // 「今は追加しない」は「もう追加しない」ではない。
    // 問いかけは閉じるが、あとから考え直せる操作は残す。
    if (_calendarPromptDeclined) {
      return Align(
        key: const Key('home_action_calendar_deferred'),
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('home_add_action_to_calendar_button'),
          onPressed: _addTodayActionToCalendar,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('カレンダーへの追加を考える'),
        ),
      );
    }

    return Column(
      key: const Key('home_action_calendar_prompt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'この一歩をカレンダーに追加しますか？',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 4),
        Text(
          '追加しなくても、今日の一歩はそのまま残ります。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('home_add_action_to_calendar_button'),
                onPressed: _addTodayActionToCalendar,
                icon: const Icon(Icons.event_outlined),
                label: const Text('カレンダーに追加'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                key: const Key('home_decline_action_calendar_button'),
                onPressed: _declineCalendarPrompt,
                child: const Text('今は追加しない'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayActionCard(BuildContext context) {
    final action = _todayAction;
    final hasAction = action != null && action.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  hasAction ? Icons.flag_outlined : Icons.lightbulb_outline,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '今日の一歩',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasAction
                  ? action
                  : 'まずは、今の状況や予定を確認しながら、'
                        '今日できることを一緒に考えましょう。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontWeight: hasAction ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openNextStep,
              icon: Icon(hasAction ? Icons.edit_outlined : Icons.arrow_forward),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(hasAction ? '次の一歩を見直す' : '次の一歩を考える'),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildJourneyPrompt(context),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildCalendarPrompt(context),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Life Partner'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () {
              _showComingSoon(context, '設定画面は今後追加します');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$_nameさん、\n今日も一緒に考えましょう。',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'これまでの歩みを振り返りながら、'
                    '今のあなたに合った次の一歩を考えます。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildTodayActionCard(context),
                  const SizedBox(height: 20),
                  _buildSection(
                    context: context,
                    title: 'Life Projects',
                    child: _buildSelectedAreas(context),
                  ),
                  _buildSection(
                    context: context,
                    title: '目指したい状態',
                    child: _buildGoals(context),
                  ),
                  _buildSection(
                    context: context,
                    title: 'AIに希望する支援',
                    child: _buildSupportPreferences(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'できること',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildQuickAction(
                        context: context,
                        icon: Icons.calendar_month_outlined,
                        title: 'カレンダー',
                        description: '月の予定を確認し、日ごとの時間を整理します。',
                        onTap: () {
                          _openCalendar();
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.route_outlined,
                        title: '歩み',
                        description: 'これまで歩いてきた道のりを見返します。',
                        onTap: () {
                          _openJourney();
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.auto_stories_outlined,
                        title: '振り返る',
                        description: '歩みについて感じたことを読み返します。',
                        onTap: () {
                          _openReflection();
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.lightbulb_outline,
                        title: '気づき',
                        description: '振り返りから見つけた気づきを読み返します。',
                        onTap: () {
                          _openInsight();
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.chat_bubble_outline,
                        title: 'AIと相談する',
                        description: '答えを決めつけず、次の一歩を一緒に考えます。',
                        onTap: () {
                          _showComingSoon(context, 'AI Dialogue機能は今後追加します');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
