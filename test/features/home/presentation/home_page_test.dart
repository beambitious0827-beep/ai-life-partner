import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/home/presentation/home_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_page.dart';
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
      ),
    ),
  );

  await tester.pumpAndSettle();
}

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
}
