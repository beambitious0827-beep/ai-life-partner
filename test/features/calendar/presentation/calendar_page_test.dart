import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

/// CalendarPageは起動時に「今日」を選択するため、テストも今日を基準にする。
DateTime todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day, hour, minute);
}

CalendarEvent createEvent({
  required DateTime startAt,
  required DateTime endAt,
  String id = 'seeded-event',
  String title = '打ち合わせ',
  AiVisibility aiVisibility = AiVisibility.full,
}) {
  final createdAt = DateTime(2026, 8, 1, 9);

  return CalendarEvent(
    id: id,
    humanId: humanId,
    title: title,
    startAt: startAt,
    endAt: endAt,
    aiVisibility: aiVisibility,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<void> pumpCalendar(
  WidgetTester tester, {
  required CalendarRepository repository,
}) async {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: CalendarPage(repository: repository, humanId: humanId),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
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

/// 表示中のshowTimePickerで時刻を設定する。
///
/// ダイヤルの操作は座標に依存するため、テキスト入力モードへ切り替えて入力する。
Future<void> setTimeInPicker(
  WidgetTester tester, {
  required int hour,
  required int minute,
}) async {
  expect(find.byType(TimePickerDialog), findsOneWidget);

  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();

  final timeFields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );

  expect(timeFields, findsNWidgets(2));

  await tester.enterText(timeFields.first, hour.toString());
  await tester.enterText(timeFields.last, minute.toString().padLeft(2, '0'));

  await tester.pumpAndSettle();

  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  expect(find.byType(TimePickerDialog), findsNothing);
}

void main() {
  group('CalendarPage 空いている時間', () {
    testWidgets('予定がない日は06:00 - 23:00がまとめて空き時間になる', (tester) async {
      await pumpCalendar(tester, repository: InMemoryCalendarRepository());

      expect(
        find.byKey(const Key('calendar_available_time_section')),
        findsOneWidget,
      );
      expect(find.text('空いている時間'), findsOneWidget);
      expect(find.text('06:00 - 23:00'), findsOneWidget);
      expect(find.text('17時間'), findsOneWidget);
      expect(find.text('空いている時間は、休息や次の一歩に活用できます。'), findsOneWidget);
    });

    testWidgets('予定を挟むと複数の空き時間が表示される', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(id: 'a', startAt: todayAt(9), endAt: todayAt(10)),
          createEvent(id: 'b', startAt: todayAt(12), endAt: todayAt(13)),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('3時間'), findsOneWidget);

      expect(find.text('10:00 - 12:00'), findsOneWidget);
      expect(find.text('2時間'), findsOneWidget);

      expect(find.text('13:00 - 23:00'), findsOneWidget);
      expect(find.text('10時間'), findsOneWidget);
    });

    testWidgets('分単位の空き時間も日本語で表示される', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(startAt: todayAt(6), endAt: todayAt(9, 30)),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('09:30 - 23:00'), findsOneWidget);
      expect(find.text('13時間30分'), findsOneWidget);
    });

    testWidgets('対象時間がすべて埋まっていると空き時間なしの表示になる', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(startAt: todayAt(6), endAt: todayAt(23)),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('この時間帯には空いている時間がありません。'), findsOneWidget);
      expect(find.text('06:00 - 23:00'), findsNothing);
      expect(find.text('空いている時間は、休息や次の一歩に活用できます。'), findsNothing);
    });

    testWidgets('終日予定でも空き時間がなくなる', (tester) async {
      final now = DateTime.now();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            startAt: DateTime(now.year, now.month, now.day),
            endAt: DateTime(now.year, now.month, now.day + 1),
          ),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('この時間帯には空いている時間がありません。'), findsOneWidget);
    });

    testWidgets('hiddenの予定も空き時間を塞ぐ', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            startAt: todayAt(9),
            endAt: todayAt(10),
            aiVisibility: AiVisibility.hidden,
          ),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('10:00 - 23:00'), findsOneWidget);

      // hiddenの時間を空き時間として返していないことを確認する。
      expect(find.text('06:00 - 23:00'), findsNothing);
    });

    testWidgets('busyOnlyの予定も空き時間を塞ぎ、一覧のPrivacy表示は変わらない', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            startAt: todayAt(9),
            endAt: todayAt(10),
            title: '通院',
            aiVisibility: AiVisibility.busyOnly,
          ),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('予定あり'), findsOneWidget);
      expect(find.text('通院'), findsNothing);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('10:00 - 23:00'), findsOneWidget);
    });

    testWidgets('予定を追加すると空き時間が再算出される', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpCalendar(tester, repository: repository);

      expect(find.text('06:00 - 23:00'), findsOneWidget);

      await tapByText(tester, '予定を追加');

      await tester.enterText(
        find.byKey(const Key('event_editor_title_field')),
        '朝の学習',
      );

      // Event Editorの既定は選択日の09:00 - 10:00。
      await tapByKey(tester, const Key('event_editor_save_button'));

      await settleSnackBar(tester);

      expect(find.text('06:00 - 23:00'), findsNothing);
      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('3時間'), findsOneWidget);
      expect(find.text('10:00 - 23:00'), findsOneWidget);
      expect(find.text('13時間'), findsOneWidget);
    });

    testWidgets('予定を削除すると空き時間が元に戻る', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(startAt: todayAt(9), endAt: todayAt(10)),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('06:00 - 09:00'), findsOneWidget);

      await tapByKey(tester, const Key('calendar_event_card_seeded-event'));

      await tapByKey(tester, const Key('event_editor_delete_button'));

      await tester.tap(
        find.byKey(const Key('event_editor_delete_confirm_button')),
      );
      await tester.pumpAndSettle();

      await settleSnackBar(tester);

      expect(find.text('06:00 - 23:00'), findsOneWidget);
      expect(find.text('17時間'), findsOneWidget);
    });

    testWidgets('別の日付を選択すると、その日の空き時間へ切り替わる', (tester) async {
      final now = DateTime.now();

      // 今日とは必ず異なる、同じ月の日付を選ぶ。
      final otherDay = now.day == 1
          ? DateTime(now.year, now.month, 2)
          : DateTime(now.year, now.month, 1);

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            id: 'today-event',
            title: '今日の予定',
            startAt: todayAt(9),
            endAt: todayAt(10),
          ),
          createEvent(
            id: 'other-day-event',
            title: '別の日の予定',
            startAt: DateTime(otherDay.year, otherDay.month, otherDay.day, 14),
            endAt: DateTime(otherDay.year, otherDay.month, otherDay.day, 16),
          ),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('今日の予定'), findsOneWidget);
      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('10:00 - 23:00'), findsOneWidget);

      // 月カレンダーの日付セルを実際にタップする。
      await tapByText(tester, otherDay.day.toString());

      // 選択日の見出しが切り替わる。
      expect(
        find.textContaining('${otherDay.month}月${otherDay.day}日'),
        findsOneWidget,
      );

      expect(find.text('別の日の予定'), findsOneWidget);
      expect(find.text('今日の予定'), findsNothing);

      // 14:00 - 16:00の予定に基づいた空き時間へ切り替わる。
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('8時間'), findsOneWidget);
      expect(find.text('16:00 - 23:00'), findsOneWidget);
      expect(find.text('7時間'), findsOneWidget);

      expect(find.text('06:00 - 09:00'), findsNothing);
      expect(find.text('10:00 - 23:00'), findsNothing);
    });

    testWidgets('予定の時刻を編集して保存すると空き時間が更新される', (tester) async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(startAt: todayAt(9), endAt: todayAt(10)),
        ],
      );

      await pumpCalendar(tester, repository: repository);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('10:00 - 23:00'), findsOneWidget);

      // 予定カードをタップして編集モードのEvent Editorを開く。
      await tapByKey(tester, const Key('calendar_event_card_seeded-event'));

      expect(find.text('予定を編集'), findsOneWidget);

      // 09:00 - 10:00 を 10:00 - 11:00 へ変更する。
      await tapByKey(tester, const Key('event_editor_start_time_tile'));
      await setTimeInPicker(tester, hour: 10, minute: 0);

      await tapByKey(tester, const Key('event_editor_end_time_tile'));
      await setTimeInPicker(tester, hour: 11, minute: 0);

      await tapByKey(tester, const Key('event_editor_save_button'));

      await settleSnackBar(tester);

      expect(find.byType(CalendarPage), findsOneWidget);

      expect(find.text('06:00 - 10:00'), findsOneWidget);
      expect(find.text('4時間'), findsOneWidget);
      expect(find.text('11:00 - 23:00'), findsOneWidget);
      expect(find.text('12時間'), findsOneWidget);

      expect(find.text('06:00 - 09:00'), findsNothing);
    });
  });
}
