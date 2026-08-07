import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_source.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key saveButtonKey = Key('event_editor_save_button');
const Key cancelButtonKey = Key('event_editor_cancel_button');
const Key titleFieldKey = Key('event_editor_title_field');
const Key descriptionFieldKey = Key('event_editor_description_field');
const Key allDaySwitchKey = Key('event_editor_all_day_switch');

/// 保存に失敗したときにEvent Editorが表示するメッセージ。
///
/// タップが届いていない場合と、保存処理が失敗した場合を
/// テスト結果から区別できるようにするために使用する。
const String saveErrorMessage = '予定を保存できませんでした。もう一度お試しください。';

/// Event Editorを一度pushしてから閉じられるように、簡単な呼び出し元を用意する。
///
/// 画面全体が入る大きさのビューポートを使い、
/// 保存ボタンがスクロール位置によって隠れないようにする。
Future<void> pumpEditor(
  WidgetTester tester, {
  required CalendarRepository repository,
  required DateTime initialDate,
  String humanId = 'local-human',
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push<CalendarEvent>(
                    MaterialPageRoute<CalendarEvent>(
                      builder: (context) => EventEditorPage(
                        repository: repository,
                        humanId: humanId,
                        initialDate: initialDate,
                      ),
                    ),
                  );
                },
                child: const Text('予定を追加'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('予定を追加'));
  await tester.pumpAndSettle();

  expect(find.byType(EventEditorPage), findsOneWidget);
}

/// 画面下部にあるボタンを、確実に表示してからタップする。
///
/// warnIfMissedは既定のtrueのままにして、
/// タップが対象へ届かなかった場合に警告が出るようにしている。
Future<void> tapBottomButton(WidgetTester tester, Key key) async {
  final button = find.byKey(key);

  expect(button, findsOneWidget);

  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  await tester.ensureVisible(button);

  await tester.pumpAndSettle();

  await tester.tap(button);

  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tapBottomButton(tester, saveButtonKey);

  expect(find.text(saveErrorMessage), findsNothing);
}

Future<void> tapCancel(WidgetTester tester) async {
  await tapBottomButton(tester, cancelButtonKey);
}

Future<List<CalendarEvent>> readEvents(
  CalendarRepository repository, {
  required DateTime month,
}) {
  return repository.getEvents(
    humanId: 'local-human',
    rangeStart: DateTime(month.year, month.month),
    rangeEnd: DateTime(month.year, month.month + 1),
  );
}

void main() {
  group('EventEditorPage', () {
    testWidgets('時間指定予定を保存すると、選択日と時刻から日時が作られる', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      await tester.enterText(find.byKey(titleFieldKey), '数学の模試');
      await tester.enterText(find.byKey(descriptionFieldKey), '会場は駅前');

      await tapSave(tester);

      // 保存に成功するとEvent Editorは閉じる。
      expect(find.byType(EventEditorPage), findsNothing);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.title, '数学の模試');
      expect(event.description, '会場は駅前');
      expect(event.humanId, 'local-human');
      expect(event.startAt, DateTime(2026, 7, 22, 9));
      expect(event.endAt, DateTime(2026, 7, 22, 10));
      expect(event.isAllDay, isFalse);
      expect(event.source, CalendarSource.internal);
      expect(event.lifeProjectId, isNull);
      expect(event.id.isNotEmpty, isTrue);
    });

    testWidgets('終日予定を保存すると、選択日の00:00から翌日の00:00になる', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      await tester.enterText(find.byKey(titleFieldKey), '家族の記念日');

      final allDaySwitch = find.byKey(allDaySwitchKey);

      await tester.ensureVisible(allDaySwitch);
      await tester.pumpAndSettle();

      await tester.tap(allDaySwitch);
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(find.byType(EventEditorPage), findsNothing);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.isAllDay, isTrue);
      expect(event.startAt, DateTime(2026, 7, 22));
      expect(event.endAt, DateTime(2026, 7, 23));
    });

    testWidgets('予定名が空の場合は保存せず、日本語で知らせる', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      await tapSave(tester);

      // 保存されていないので、Event Editorは開いたままになる。
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(find.text('予定名を入力してください。'), findsOneWidget);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, isEmpty);
    });

    testWidgets('AI Visibilityの初期値は詳細を渡さない設定で、選択肢が表示される', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      for (final visibility in AiVisibility.values) {
        expect(find.text(visibility.label), findsOneWidget);
      }

      await tester.enterText(find.byKey(titleFieldKey), '通院');

      await tapSave(tester);

      expect(find.byType(EventEditorPage), findsNothing);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, hasLength(1));
      expect(events.single.aiVisibility, AiVisibility.busyOnly);
    });

    testWidgets('キャンセルすると何も保存しない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      await tester.enterText(find.byKey(titleFieldKey), '保存しない予定');

      await tapCancel(tester);

      // タップが届いたことを確認するため、画面が閉じたことも検証する。
      expect(find.byType(EventEditorPage), findsNothing);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, isEmpty);
    });
  });
}
