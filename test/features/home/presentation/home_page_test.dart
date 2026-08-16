import 'dart:async';

import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_source.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/calendar_page.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_editor_page.dart';
import 'package:ai_life_partner/features/home/presentation/home_page.dart';
import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_page.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_record_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_page.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

/// 予定を取得できないRepository。
///
/// 「確認できなかった」状態を再現するために使う。
class FailingCalendarRepository implements CalendarRepository {
  int getEventsCallCount = 0;

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    getEventsCallCount += 1;

    throw StateError('カレンダーを読み込めませんでした');
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) async {
    throw StateError('カレンダーを読み込めませんでした');
  }

  @override
  Future<void> saveEvent(CalendarEvent event) async {
    throw StateError('カレンダーへ保存できませんでした');
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    throw StateError('カレンダーから削除できませんでした');
  }
}

/// HomePageは「今日」の予定から空き時間を算出するため、テストも今日を基準にする。
DateTime todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day, hour, minute);
}

CalendarEvent createEvent({
  required DateTime startAt,
  required DateTime endAt,
  String id = 'seeded-event',
  String title = '打ち合わせ',
  String description = '',
  AiVisibility aiVisibility = AiVisibility.full,
}) {
  final createdAt = DateTime(2026, 8, 1, 9);

  return CalendarEvent(
    id: id,
    humanId: humanId,
    title: title,
    description: description,
    startAt: startAt,
    endAt: endAt,
    aiVisibility: aiVisibility,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<void> pumpHome(
  WidgetTester tester, {
  required CalendarRepository repository,
  JourneyRepository? journeyRepository,
  ReflectionRepository? reflectionRepository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        displayName: 'Daishi',
        selectedAreas: const <String>['トレーニング'],
        goals: const <String, String>{},
        supportPreferences: const <String>[],
        calendarRepository: repository,
        journeyRepository: journeyRepository,
        reflectionRepository: reflectionRepository,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// 手動で30分・いつもどおりを選んだときに先頭へ出る候補。
const String manualActionText = '無理のない範囲で、30分でできるトレーニングを1つ選んで行う';

const Key addToCalendarKey = Key('home_add_action_to_calendar_button');
const Key declineCalendarKey = Key('home_decline_action_calendar_button');
const Key calendarPromptKey = Key('home_action_calendar_prompt');
const Key calendarRegisteredKey = Key('home_action_calendar_registered');
const Key calendarDeferredKey = Key('home_action_calendar_deferred');

const Key recordJourneyKey = Key('home_record_journey_button');
const Key journeyPromptKey = Key('home_action_journey_prompt');
const Key journeyRecordedKey = Key('home_action_journey_recorded');

const Key journeySaveButtonKey = Key('journey_record_save_button');
const Key journeyCancelButtonKey = Key('journey_record_cancel_button');

const Key editorTitleFieldKey = Key('event_editor_title_field');
const Key editorSaveButtonKey = Key('event_editor_save_button');
const Key editorCancelButtonKey = Key('event_editor_cancel_button');

/// 「次の一歩を考える」からNextStepPageを開く。
///
/// 空き時間の算出が非同期なので、遷移が終わるまで確実に待つ。
Future<void> openNextStep(WidgetTester tester) async {
  final button = find.text('次の一歩を考える');

  expect(button, findsOneWidget);

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);

  await tester.pumpAndSettle();
  await tester.pumpAndSettle();

  expect(find.byType(NextStepPage), findsOneWidget);
}

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);

  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> tapByText(WidgetTester tester, String text) async {
  final target = find.text(text);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// SnackBarの自動クローズ待ちを消化して、保留中のTimerを残さないようにする。
Future<void> settleSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// その日に登録されている予定をすべて読み出す。
Future<List<CalendarEvent>> readTodayEvents(
  CalendarRepository repository,
) async {
  final now = DateTime.now();

  return repository.getEvents(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// その日に残っている歩みをすべて読み出す。
Future<List<JourneyEntry>> readJourneyEntries(
  JourneyRepository repository,
) async {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// これまでに残された振り返りを読み出す。
Future<List<ReflectionEntry>> readReflections(
  ReflectionRepository repository,
) async {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// Homeから記録画面を開き、結果を選んで歩みとして残す。
Future<void> recordJourney(
  WidgetTester tester,
  JourneyOutcome outcome, {
  String? note,
}) async {
  await tapByKey(tester, recordJourneyKey);

  expect(find.byType(JourneyRecordPage), findsOneWidget);

  await tapByKey(tester, Key('journey_record_outcome_${outcome.name}'));

  if (note != null) {
    await tester.enterText(
      find.byKey(const Key('journey_record_note_field')),
      note,
    );

    await tester.pumpAndSettle();
  }

  await tapByKey(tester, journeySaveButtonKey);

  await settleSnackBar(tester);

  expect(find.byType(JourneyRecordPage), findsNothing);
}

/// NextStepPageの候補確定までを通しで行い、Homeへ戻る。
Future<void> confirmNextStep(WidgetTester tester, String energyLabel) async {
  await tapByText(tester, energyLabel);
  await tapByText(tester, '今の状況から候補を考える');

  await tapByKey(tester, const Key('next_step_suggestion_0'));

  await tapByText(tester, 'この一歩に決める');

  final confirmButton = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('この一歩に決める'),
  );

  expect(confirmButton, findsOneWidget);

  await tester.tap(confirmButton);
  await tester.pumpAndSettle();

  expect(find.byType(NextStepPage), findsNothing);
  expect(find.byType(HomePage), findsOneWidget);
}

/// 手動で時間を決めて今日の一歩を確定する。
Future<void> confirmManualNextStep(
  WidgetTester tester, {
  AvailableTime time = AvailableTime.thirtyMinutes,
  String energyLabel = 'いつもどおり',
}) async {
  await openNextStep(tester);

  await tapByKey(tester, Key('next_step_manual_time_${time.name}'));

  await confirmNextStep(tester, energyLabel);
}

/// カレンダーの空き時間を選んで今日の一歩を確定する。
Future<void> confirmCalendarWindowNextStep(
  WidgetTester tester, {
  String energyLabel = 'いつもどおり',
}) async {
  await openNextStep(tester);

  await tapByKey(tester, const Key('next_step_available_window_0'));

  await confirmNextStep(tester, energyLabel);
}

/// 保存だけが待機するRepository。
///
/// Supabaseなどで保存に時間がかかる状況を再現するために使う。
class SlowSaveCalendarRepository implements CalendarRepository {
  SlowSaveCalendarRepository();

  final InMemoryCalendarRepository _inner = InMemoryCalendarRepository();

  final Completer<void> _saveGate = Completer<void>();

  void completeSave() {
    if (!_saveGate.isCompleted) {
      _saveGate.complete();
    }
  }

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _inner.getEvents(
      humanId: humanId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) {
    return _inner.getEventById(eventId);
  }

  @override
  Future<void> saveEvent(CalendarEvent event) async {
    await _saveGate.future;

    await _inner.saveEvent(event);
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _inner.deleteEvent(eventId);
  }
}

/// getEventByIdを任意のタイミングまで待機させられるRepository。
///
/// 古い照合結果が、新しい登録状態を上書きしないかを見るために使う。
class RaceableCalendarRepository implements CalendarRepository {
  final InMemoryCalendarRepository _inner = InMemoryCalendarRepository();

  Completer<void>? _getEventByIdGate;

  /// 次のgetEventByIdを待機させる。
  void holdNextGetEventById() {
    _getEventByIdGate = Completer<void>();
  }

  /// 待機していたgetEventByIdを進める。
  void releaseGetEventById() {
    final gate = _getEventByIdGate;

    _getEventByIdGate = null;

    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _inner.getEvents(
      humanId: humanId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) async {
    final gate = _getEventByIdGate;

    if (gate != null) {
      await gate.future;
    }

    return _inner.getEventById(eventId);
  }

  @override
  Future<void> saveEvent(CalendarEvent event) {
    return _inner.saveEvent(event);
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _inner.deleteEvent(eventId);
  }
}

/// 1回目のsaveEventだけ失敗するRepository。
///
/// 保存に失敗したあと、やり直せることを確かめるために使う。
class FlakySaveCalendarRepository implements CalendarRepository {
  final InMemoryCalendarRepository _inner = InMemoryCalendarRepository();

  int saveAttempts = 0;

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _inner.getEvents(
      humanId: humanId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) {
    return _inner.getEventById(eventId);
  }

  @override
  Future<void> saveEvent(CalendarEvent event) async {
    saveAttempts += 1;

    if (saveAttempts == 1) {
      throw StateError('カレンダーへ保存できませんでした');
    }

    await _inner.saveEvent(event);
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _inner.deleteEvent(eventId);
  }
}

/// getEventByIdだけが失敗するRepository。
///
/// 「確認できなかった」を「削除された」と取り違えていないかを見るために使う。
class UncheckableCalendarRepository implements CalendarRepository {
  final InMemoryCalendarRepository _inner = InMemoryCalendarRepository();

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _inner.getEvents(
      humanId: humanId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) async {
    throw StateError('予定を確認できませんでした');
  }

  @override
  Future<void> saveEvent(CalendarEvent event) {
    return _inner.saveEvent(event);
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _inner.deleteEvent(eventId);
  }
}

/// Homeのクイックアクションからカレンダーを開く。
Future<void> openCalendarFromHome(WidgetTester tester) async {
  await tapByText(tester, 'カレンダー');

  await tester.pumpAndSettle();

  expect(find.byType(CalendarPage), findsOneWidget);
}

/// 戻る操作でHomeへ帰る。
Future<void> backToHome(WidgetTester tester) async {
  await tester.pageBack();

  await tester.pumpAndSettle();
  await tester.pumpAndSettle();

  expect(find.byType(HomePage), findsOneWidget);
}

/// カレンダー上で指定した予定を削除する。
Future<void> deleteEventOnCalendar(WidgetTester tester, String eventId) async {
  await tapByKey(tester, Key('calendar_event_card_$eventId'));

  expect(find.byType(EventEditorPage), findsOneWidget);

  await tapByKey(tester, const Key('event_editor_delete_button'));

  await tester.tap(find.byKey(const Key('event_editor_delete_confirm_button')));

  await tester.pumpAndSettle();

  await settleSnackBar(tester);
}

/// 「次の一歩を見直す」からNextStepPageを開く。
Future<void> reviseNextStep(WidgetTester tester) async {
  await tapByText(tester, '次の一歩を見直す');

  await tester.pumpAndSettle();
  await tester.pumpAndSettle();

  expect(find.byType(NextStepPage), findsOneWidget);
}

/// 06:00〜23:00のうち、[startHour]:[startMinute] から [endHour]:[endMinute]
/// だけが空き時間になるように予定を用意する。
List<CalendarEvent> eventsLeavingOneWindow({
  required int startHour,
  int startMinute = 0,
  required int endHour,
  int endMinute = 0,
}) {
  return <CalendarEvent>[
    createEvent(
      id: 'before-window',
      startAt: todayAt(6),
      endAt: todayAt(startHour, startMinute),
    ),
    createEvent(
      id: 'after-window',
      startAt: todayAt(endHour, endMinute),
      endAt: todayAt(23),
    ),
  ];
}

void main() {
  group('HomePage から NextStepPage への空き時間の受け渡し', () {
    testWidgets('予定がない日は06:00 - 23:00がそのまま渡る', (tester) async {
      await pumpHome(tester, repository: InMemoryCalendarRepository());

      await openNextStep(tester);

      expect(find.text('カレンダーから見つかった空き時間'), findsOneWidget);
      expect(find.text('06:00 - 23:00'), findsOneWidget);
      expect(find.text('17時間'), findsOneWidget);
    });

    testWidgets('今日の予定によって空き時間が分割されて渡る', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(id: 'a', startAt: todayAt(9), endAt: todayAt(10)),
          createEvent(id: 'b', startAt: todayAt(12), endAt: todayAt(13)),
        ],
      );

      await pumpHome(tester, repository: repository);

      await openNextStep(tester);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('10:00 - 12:00'), findsOneWidget);
      expect(find.text('13:00 - 23:00'), findsOneWidget);

      expect(find.text('06:00 - 23:00'), findsNothing);
    });

    testWidgets('対象時間が予定で埋まっている日は空き時間なしとして渡る', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(startAt: todayAt(6), endAt: todayAt(23)),
        ],
      );

      await pumpHome(tester, repository: repository);

      await openNextStep(tester);

      // 取得は成功していて、空き時間が0件だった状態。
      expect(
        find.textContaining('カレンダー上では、この時間帯に空いている時間が見つかりませんでした。'),
        findsOneWidget,
      );

      // 取得失敗として扱われていないことを確認する。
      expect(find.textContaining('カレンダーを確認できませんでした。'), findsNothing);
      expect(
        find.byKey(const Key('next_step_reload_availability_button')),
        findsNothing,
      );

      // 空き時間がなくても、手動の時間指定は使える。
      for (final time in AvailableTime.values) {
        expect(
          find.byKey(Key('next_step_manual_time_${time.name}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('AIに見せない予定でも空き時間は塞がれ、内容はNextStepPageへ渡らない', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            startAt: todayAt(14),
            endAt: todayAt(16),
            title: '見せたくない予定',
            description: '見せたくない詳細',
            aiVisibility: AiVisibility.hidden,
          ),
        ],
      );

      await pumpHome(tester, repository: repository);

      await openNextStep(tester);

      // 予定の時間は空き時間から除かれている。
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('16:00 - 23:00'), findsOneWidget);
      expect(find.text('06:00 - 23:00'), findsNothing);

      // 予定の内容はNextStepPageへ渡らない。
      expect(find.text('見せたくない予定'), findsNothing);
      expect(find.text('見せたくない詳細'), findsNothing);
      expect(find.textContaining('見せたくない'), findsNothing);
    });
  });

  group('カレンダーを確認できなかった場合', () {
    testWidgets('取得失敗は、予定で埋まっている状態と区別して伝えられる', (tester) async {
      final repository = FailingCalendarRepository();

      await pumpHome(tester, repository: repository);

      await openNextStep(tester);

      expect(repository.getEventsCallCount, 1);

      expect(find.textContaining('カレンダーを確認できませんでした。'), findsOneWidget);

      // 「確認したが空き時間がなかった」とは言わない。
      expect(find.textContaining('この時間帯に空いている時間が見つかりませんでした。'), findsNothing);
      expect(find.text('カレンダーから見つかった空き時間'), findsNothing);
    });

    testWidgets('取得に失敗してもNextStepPageは使え、手動の時間指定で候補を作れる', (tester) async {
      await pumpHome(tester, repository: FailingCalendarRepository());

      await openNextStep(tester);

      for (final time in AvailableTime.values) {
        expect(
          find.byKey(Key('next_step_manual_time_${time.name}')),
          findsOneWidget,
        );
      }

      await tapByKey(tester, const Key('next_step_manual_time_thirtyMinutes'));

      await tapByText(tester, 'いつもどおり');
      await tapByText(tester, '今の状況から候補を考える');

      expect(find.text('無理のない範囲で、30分でできるトレーニングを1つ選んで行う'), findsOneWidget);
    });

    testWidgets('「もう一度確認する」でHomePageの取得処理が再実行される', (tester) async {
      final repository = FailingCalendarRepository();

      await pumpHome(tester, repository: repository);

      await openNextStep(tester);

      expect(repository.getEventsCallCount, 1);

      await tapByKey(tester, const Key('next_step_reload_availability_button'));

      // 再試行でもRepositoryはHomePage側から呼ばれる。
      expect(repository.getEventsCallCount, 2);

      // まだ失敗しているので、表示は失敗のまま。
      expect(find.textContaining('カレンダーを確認できませんでした。'), findsOneWidget);
    });
  });

  group('今日の一歩をカレンダーへ追加する確認', () {
    testWidgets('Actionを確定しただけではCalendar Eventを作らない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      expect(find.text(manualActionText), findsOneWidget);

      // 確定しただけでは保存しない。追加するかはHumanが決める。
      expect(await readTodayEvents(repository), isEmpty);

      expect(find.byKey(calendarPromptKey), findsOneWidget);
      expect(find.text('この一歩をカレンダーに追加しますか？'), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsOneWidget);
      expect(find.byKey(declineCalendarKey), findsOneWidget);
    });

    testWidgets('「今は追加しない」を選んでも今日の一歩は残る', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, declineCalendarKey);

      expect(await readTodayEvents(repository), isEmpty);

      // 今日の一歩は消えない。
      expect(find.text(manualActionText), findsOneWidget);

      // 強い問いかけは閉じる。
      expect(find.byKey(calendarPromptKey), findsNothing);
      expect(find.text('この一歩をカレンダーに追加しますか？'), findsNothing);
      expect(find.byKey(calendarRegisteredKey), findsNothing);

      // ただし「もう追加しない」ではないので、控えめな操作は残る。
      expect(find.byKey(calendarDeferredKey), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsOneWidget);
      expect(find.text('カレンダーへの追加を考える'), findsOneWidget);
    });

    testWidgets('「今は追加しない」のあとでも、後からEvent Editorを開ける', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, declineCalendarKey);

      // 控えめな操作から、そのままEvent Editorへ進める。
      await tapByKey(tester, addToCalendarKey);

      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(editorTitleFieldKey),
          matching: find.text(manualActionText),
        ),
        findsOneWidget,
      );

      // 開いただけでは保存しない。
      expect(await readTodayEvents(repository), isEmpty);

      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      expect(await readTodayEvents(repository), hasLength(1));
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
    });

    testWidgets('「カレンダーに追加」でEvent Editorが開き、まだ保存されない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);

      expect(find.byType(EventEditorPage), findsOneWidget);

      // 予定名にAction textが入っている。
      expect(
        find.descendant(
          of: find.byKey(editorTitleFieldKey),
          matching: find.text(manualActionText),
        ),
        findsOneWidget,
      );

      // 開いただけでは保存しない。
      expect(await readTodayEvents(repository), isEmpty);
    });

    testWidgets('Event Editorで保存したときだけCalendar Eventが作られる', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);

      expect(await readTodayEvents(repository), isEmpty);

      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final events = await readTodayEvents(repository);

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.title, manualActionText);
      expect(event.humanId, humanId);
      expect(event.source, CalendarSource.internal);
      expect(event.category, EventCategory.lifeProject);
      expect(event.aiVisibility, AiVisibility.busyOnly);
      expect(event.lifeProjectId, isNull);
    });

    testWidgets('Event Editorをキャンセルした場合はCalendar Eventを作らない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);

      await tapByKey(tester, editorCancelButtonKey);

      expect(find.byType(EventEditorPage), findsNothing);
      expect(await readTodayEvents(repository), isEmpty);

      // 今日の一歩は残り、追加の操作も引き続き使える。
      expect(find.text(manualActionText), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsOneWidget);
      expect(find.byKey(calendarRegisteredKey), findsNothing);
    });

    testWidgets('手動で決めた長さが初期候補の長さになる', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final event = (await readTodayEvents(repository)).single;

      expect(
        event.endAt.difference(event.startAt),
        const Duration(minutes: 30),
      );
    });

    testWidgets('「時間は調整できる」では固定の長さを作らず、Event Editorの既定を使う', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester, time: AvailableTime.flexible);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final event = (await readTodayEvents(repository)).single;

      final now = DateTime.now();

      // Event Editorの新規作成時の既定（09:00 - 10:00）のまま。
      expect(event.startAt, DateTime(now.year, now.month, now.day, 9));
      expect(event.endAt, DateTime(now.year, now.month, now.day, 10));
    });

    testWidgets('空き時間を選んだ場合は、その開始からAction長さぶんが初期候補になる', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: eventsLeavingOneWindow(startHour: 18, endHour: 21),
      );

      await pumpHome(tester, repository: repository);

      await confirmCalendarWindowNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final events = await readTodayEvents(repository);

      final saved = events.firstWhere(
        (event) => event.id != 'before-window' && event.id != 'after-window',
      );

      expect(saved.startAt, todayAt(18));
      expect(saved.endAt, todayAt(18, 30));

      // 空き時間全体（18:00 - 21:00）を予定にしない。
      expect(saved.endAt, isNot(todayAt(21)));
    });

    testWidgets('初期候補は選んだ空き時間の終わりを超えない', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: eventsLeavingOneWindow(
          startHour: 18,
          endHour: 18,
          endMinute: 20,
        ),
      );

      await pumpHome(tester, repository: repository);

      // 余力があると60分が目安になるが、空き時間は20分しかない。
      await confirmCalendarWindowNextStep(tester, energyLabel: '余力がある');

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final events = await readTodayEvents(repository);

      final saved = events.firstWhere(
        (event) => event.id != 'before-window' && event.id != 'after-window',
      );

      expect(saved.startAt, todayAt(18));
      expect(saved.endAt, todayAt(18, 20));
      expect(saved.endAt.isAfter(todayAt(18, 20)), isFalse);
    });

    testWidgets('保存後は同じ一歩の「カレンダーに追加」を出さない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      expect(find.byKey(addToCalendarKey), findsNothing);
      expect(find.byKey(calendarPromptKey), findsNothing);
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
      expect(find.text('この一歩はカレンダーに追加済みです。'), findsOneWidget);

      expect(await readTodayEvents(repository), hasLength(1));
    });

    testWidgets('新しい一歩を確定すると、また追加できる状態に戻る', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      // 新しい一歩を決め直す。
      await tapByText(tester, '次の一歩を見直す');
      await tester.pumpAndSettle();

      expect(find.byType(NextStepPage), findsOneWidget);

      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.tenMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      // 前の一歩が登録済みでも、新しい一歩は追加できる。
      expect(find.byKey(addToCalendarKey), findsOneWidget);
      expect(find.byKey(calendarRegisteredKey), findsNothing);

      // 新しい一歩を保存するまで、予定は増えない。
      expect(await readTodayEvents(repository), hasLength(1));
    });
  });

  group('カレンダー登録状態とCalendar Eventの対応', () {
    testWidgets('保存したEventがカレンダー側で削除されると、登録済み状態が解除される', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final saved = (await readTodayEvents(repository)).single;

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      await openCalendarFromHome(tester);

      await deleteEventOnCalendar(tester, saved.id);

      expect(await readTodayEvents(repository), isEmpty);

      await backToHome(tester);

      // 予定が無くなったので、同じ一歩をもう一度追加できる。
      expect(find.byKey(calendarRegisteredKey), findsNothing);
      expect(find.byKey(addToCalendarKey), findsOneWidget);

      // 今日の一歩自体は残る。
      expect(find.text(manualActionText), findsOneWidget);
    });

    testWidgets('カレンダーを開いても削除していなければ登録済みのまま', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      await openCalendarFromHome(tester);
      await backToHome(tester);

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsNothing);
    });

    testWidgets('存在確認に失敗した場合は、削除されたと判断しない', (tester) async {
      final repository = UncheckableCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final saved = (await readTodayEvents(repository)).single;

      await openCalendarFromHome(tester);

      // 実際には削除されているが、確認手段が失敗する。
      await deleteEventOnCalendar(tester, saved.id);

      await backToHome(tester);

      // 確認できなかっただけなので、登録済みの記録は残す。
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
    });

    testWidgets('実質的に同じ一歩を決め直しても、登録済み状態を維持する', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      // 同じ時間・同じ余力で、同じ候補をもう一度確定する。
      await reviseNextStep(tester);

      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.thirtyMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      expect(find.text(manualActionText), findsOneWidget);

      // 同じ登録対象なので、追加済みのまま。二重登録しやすい状態へ戻さない。
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsNothing);

      expect(await readTodayEvents(repository), hasLength(1));
    });

    testWidgets('異なる一歩を確定した場合は登録状態を引き継がない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      await reviseNextStep(tester);

      // 時間の指定を変えるので、別の一歩になる。
      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.tenMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      expect(find.text(manualActionText), findsNothing);

      expect(find.byKey(calendarRegisteredKey), findsNothing);
      expect(find.byKey(addToCalendarKey), findsOneWidget);

      // 新しい一歩を保存するまで、予定は増えない。
      expect(await readTodayEvents(repository), hasLength(1));
    });
  });

  group('Event Editorの保存中', () {
    testWidgets('保存が終わるまで戻る操作で閉じられない', (tester) async {
      final repository = SlowSaveCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);

      expect(find.byType(EventEditorPage), findsOneWidget);

      // 保存中は画面がアニメーションし続けるため、pumpAndSettleは使わない。
      await tester.tap(find.byKey(editorSaveButtonKey));
      await tester.pump();

      // 保存中であることが分かる。
      expect(find.text('保存しています…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pageBack();
      await tester.pump();

      // まだ保存が終わっていないので閉じない。
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(await readTodayEvents(repository), isEmpty);

      // 保存が完了すれば、そのまま閉じて登録済みになる。
      repository.completeSave();

      await tester.pumpAndSettle();
      await settleSnackBar(tester);

      expect(find.byType(EventEditorPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);

      expect(await readTodayEvents(repository), hasLength(1));
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
    });

    testWidgets('保存に失敗しても閉じず、もう一度保存できる', (tester) async {
      final repository = FlakySaveCalendarRepository();

      await pumpHome(tester, repository: repository);

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);

      expect(find.byType(EventEditorPage), findsOneWidget);

      // 1回目の保存は失敗する。
      await tapByKey(tester, editorSaveButtonKey);

      expect(repository.saveAttempts, 1);

      // Event Editorに留まり、Homeへは戻らない。
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(find.text('予定を保存できませんでした。もう一度お試しください。'), findsOneWidget);

      // 保存中の表示は解除され、もう一度保存できる状態に戻る。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('保存しています…'), findsNothing);
      expect(find.text('この予定を保存する'), findsOneWidget);

      // 保存成功として扱わない。
      expect(await readTodayEvents(repository), isEmpty);
      expect(find.byKey(calendarRegisteredKey), findsNothing);

      // 2回目の保存は成功する。
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      expect(repository.saveAttempts, 2);

      expect(find.byType(EventEditorPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);

      final events = await readTodayEvents(repository);

      expect(events, hasLength(1));
      expect(events.single.title, manualActionText);

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsNothing);
    });
  });

  group('登録状態の照合と新しい登録の競合', () {
    testWidgets('古い照合結果は、新しい登録を解除しない', (tester) async {
      final repository = RaceableCalendarRepository();

      await pumpHome(tester, repository: repository);

      // Action A を確定してカレンダーへ保存する。
      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final eventA = (await readTodayEvents(repository)).single;

      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      // カレンダー側で Event A を削除する。
      await openCalendarFromHome(tester);

      await deleteEventOnCalendar(tester, eventA.id);

      expect(await readTodayEvents(repository), isEmpty);

      // Homeへ戻った直後の照合を、途中で止める。
      repository.holdNextGetEventById();

      await backToHome(tester);

      // 照合はまだ終わっていない。
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      // 照合を待たせたまま、別の Action B を確定して保存する。
      await reviseNextStep(tester);

      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.tenMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      expect(find.byKey(addToCalendarKey), findsOneWidget);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final eventB = (await readTodayEvents(repository)).single;

      expect(eventB.id, isNot(eventA.id));
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);

      // ここで Event A の「存在しない」という古い結果が返ってくる。
      repository.releaseGetEventById();

      await tester.pump();
      await tester.pumpAndSettle();

      // Action B の登録は影響を受けない。
      expect(find.byKey(calendarRegisteredKey), findsOneWidget);
      expect(find.byKey(addToCalendarKey), findsNothing);
      expect(find.byKey(calendarPromptKey), findsNothing);

      expect(await readTodayEvents(repository), hasLength(1));
    });
  });

  group('今日の一歩を歩みとして残す', () {
    testWidgets('Actionを確定しただけでは歩みを記録しない', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      expect(find.text(manualActionText), findsOneWidget);

      // 決めただけでは残さない。残すかどうかはHumanが決める。
      expect(await readJourneyEntries(journeyRepository), isEmpty);

      expect(find.byKey(journeyPromptKey), findsOneWidget);
      expect(find.byKey(recordJourneyKey), findsOneWidget);
      expect(find.byKey(journeyRecordedKey), findsNothing);
    });

    testWidgets('「歩みとして残す」で記録画面が開き、まだ保存されない', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await tapByKey(tester, recordJourneyKey);

      expect(find.byType(JourneyRecordPage), findsOneWidget);
      expect(find.text('その後、どうでしたか？'), findsOneWidget);

      // もとになった一歩が引き継がれている。
      expect(find.text(manualActionText), findsWidgets);

      // 開いただけでは保存しない。
      expect(await readJourneyEntries(journeyRepository), isEmpty);
    });

    testWidgets('記録画面で保存したときだけ歩みが残る', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await tapByKey(tester, recordJourneyKey);

      await tapByKey(
        tester,
        Key('journey_record_outcome_${JourneyOutcome.rested.name}'),
      );

      expect(await readJourneyEntries(journeyRepository), isEmpty);

      await tapByKey(tester, journeySaveButtonKey);

      await settleSnackBar(tester);

      expect(find.byType(JourneyRecordPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);

      final entries = await readJourneyEntries(journeyRepository);

      expect(entries, hasLength(1));

      final entry = entries.single;

      expect(entry.plannedActionText, manualActionText);
      expect(entry.humanId, humanId);
      expect(entry.outcome, JourneyOutcome.rested);
      expect(entry.plannedDuration, const Duration(minutes: 30));
    });

    testWidgets('記録画面をキャンセルすると歩みを残さない', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await tapByKey(tester, recordJourneyKey);

      await tapByKey(
        tester,
        Key('journey_record_outcome_${JourneyOutcome.completed.name}'),
      );

      await tapByKey(tester, journeyCancelButtonKey);

      expect(find.byType(JourneyRecordPage), findsNothing);
      expect(await readJourneyEntries(journeyRepository), isEmpty);

      // 今日の一歩は残り、記録操作も引き続き使える。
      expect(find.text(manualActionText), findsOneWidget);
      expect(find.byKey(recordJourneyKey), findsOneWidget);
      expect(find.byKey(journeyRecordedKey), findsNothing);
    });

    testWidgets('保存後は同じ一歩の「歩みとして残す」を出さない', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.completed);

      expect(find.byKey(recordJourneyKey), findsNothing);
      expect(find.byKey(journeyPromptKey), findsNothing);
      expect(find.byKey(journeyRecordedKey), findsOneWidget);
      expect(find.text('この一歩は歩みに残しました。'), findsOneWidget);

      expect(await readJourneyEntries(journeyRepository), hasLength(1));
    });

    testWidgets('実質的に同じ一歩を決め直しても、記録済みのまま', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.completed);

      await reviseNextStep(tester);

      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.thirtyMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      // 同じ記録対象なので、二重に残しやすい状態へ戻さない。
      expect(find.byKey(journeyRecordedKey), findsOneWidget);
      expect(find.byKey(recordJourneyKey), findsNothing);

      expect(await readJourneyEntries(journeyRepository), hasLength(1));
    });

    testWidgets('異なる一歩を確定した場合は、また記録できる', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.completed);

      await reviseNextStep(tester);

      await tapByKey(
        tester,
        Key('next_step_manual_time_${AvailableTime.tenMinutes.name}'),
      );

      await confirmNextStep(tester, 'いつもどおり');

      expect(find.byKey(journeyRecordedKey), findsNothing);
      expect(find.byKey(recordJourneyKey), findsOneWidget);

      // 新しい一歩を残すまで、歩みは増えない。
      expect(await readJourneyEntries(journeyRepository), hasLength(1));
    });

    testWidgets('カレンダーへ登録済みの一歩は、予定IDを写しとして残す', (tester) async {
      final calendarRepository = InMemoryCalendarRepository();
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: calendarRepository,
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final savedEvent = (await readTodayEvents(calendarRepository)).single;

      await recordJourney(tester, JourneyOutcome.completed);

      final entry = (await readJourneyEntries(journeyRepository)).single;

      expect(entry.sourceCalendarEventId, savedEvent.id);
    });

    testWidgets('カレンダー未登録の一歩では、予定IDを持たない', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.completed);

      final entry = (await readJourneyEntries(journeyRepository)).single;

      expect(entry.sourceCalendarEventId, isNull);
    });

    testWidgets('歩みは予定が削除されても残る', (tester) async {
      final calendarRepository = InMemoryCalendarRepository();
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: calendarRepository,
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await tapByKey(tester, addToCalendarKey);
      await tapByKey(tester, editorSaveButtonKey);

      await settleSnackBar(tester);

      final savedEvent = (await readTodayEvents(calendarRepository)).single;

      await recordJourney(tester, JourneyOutcome.partial);

      expect(await readJourneyEntries(journeyRepository), hasLength(1));

      // カレンダー側で予定を削除する。
      await openCalendarFromHome(tester);
      await deleteEventOnCalendar(tester, savedEvent.id);
      await backToHome(tester);

      expect(await readTodayEvents(calendarRepository), isEmpty);

      // 歩みは独立した履歴なので、そのまま残る。
      final entries = await readJourneyEntries(journeyRepository);

      expect(entries, hasLength(1));
      expect(entries.single.sourceCalendarEventId, savedEvent.id);
      expect(find.byKey(journeyRecordedKey), findsOneWidget);
    });

    testWidgets('Homeから歩みの一覧を開ける', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.partial);

      await tapByText(tester, '歩み');

      expect(find.byType(JourneyPage), findsOneWidget);
      expect(find.text('これまでの歩み'), findsOneWidget);

      // 残した歩みが履歴として読める。
      // Homeも背後に残るため、一歩の文言は複数見つかる。
      expect(find.text(manualActionText), findsWidgets);
      expect(find.text('少し取り組んだ'), findsOneWidget);
    });
  });

  group('歩みから振り返りへ', () {
    testWidgets('Homeから振り返りの一覧を開ける', (tester) async {
      await pumpHome(tester, repository: InMemoryCalendarRepository());

      await tapByText(tester, '振り返る');

      expect(find.byType(ReflectionPage), findsOneWidget);
      expect(find.text('これまでの振り返り'), findsOneWidget);
      expect(find.byKey(const Key('reflection_empty_state')), findsOneWidget);
    });

    testWidgets('歩みから残した振り返りが、振り返りの一覧でも読める', (tester) async {
      final journeyRepository = InMemoryJourneyRepository();
      final reflectionRepository = InMemoryReflectionRepository();

      await pumpHome(
        tester,
        repository: InMemoryCalendarRepository(),
        journeyRepository: journeyRepository,
        reflectionRepository: reflectionRepository,
      );

      await confirmManualNextStep(tester);

      await recordJourney(tester, JourneyOutcome.partial);

      final journeyEntry = (await readJourneyEntries(journeyRepository)).single;

      // 歩みの一覧から、その歩みを振り返る。
      await tapByText(tester, '歩み');

      expect(find.byType(JourneyPage), findsOneWidget);

      await tapByKey(tester, Key('journey_reflect_button_${journeyEntry.id}'));

      await tester.enterText(
        find.byKey(const Key('reflection_record_feeling_field')),
        '少し肩の力が抜けた',
      );
      await tester.pumpAndSettle();

      await tapByKey(tester, const Key('reflection_record_save_button'));

      expect(
        find.byKey(Key('journey_reflected_label_${journeyEntry.id}')),
        findsOneWidget,
      );

      await backToHome(tester);

      // Homeの振り返り一覧も、同じRepositoryの内容を見ている。
      await tapByText(tester, '振り返る');

      expect(find.byType(ReflectionPage), findsOneWidget);
      expect(find.byKey(const Key('reflection_empty_state')), findsNothing);
      expect(find.text('振り返った歩み'), findsOneWidget);
      expect(find.text('少し肩の力が抜けた'), findsOneWidget);

      final reflections = await readReflections(reflectionRepository);

      expect(reflections.single.journeyEntryId, journeyEntry.id);
    });
  });
}
