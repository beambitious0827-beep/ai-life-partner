import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_source.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key saveButtonKey = Key('event_editor_save_button');
const Key cancelButtonKey = Key('event_editor_cancel_button');
const Key deleteButtonKey = Key('event_editor_delete_button');
const Key deleteCancelButtonKey = Key('event_editor_delete_cancel_button');
const Key deleteConfirmButtonKey = Key('event_editor_delete_confirm_button');
const Key titleFieldKey = Key('event_editor_title_field');
const Key descriptionFieldKey = Key('event_editor_description_field');
const Key allDaySwitchKey = Key('event_editor_all_day_switch');

Key categoryKey(EventCategory category) {
  return Key('event_editor_category_${category.name}');
}

Key aiVisibilityKey(AiVisibility visibility) {
  return Key('event_editor_ai_visibility_${visibility.name}');
}

/// 保存に失敗したときにEvent Editorが表示するメッセージ。
///
/// タップが届いていない場合と、保存処理が失敗した場合を
/// テスト結果から区別できるようにするために使用する。
const String saveErrorMessage = '予定を保存できませんでした。もう一度お試しください。';

/// 編集モードのテストで使う既存の予定。
///
/// createdAtとupdatedAtは保存時のDateTime.now()より前になるようにしておく。
CalendarEvent existingEvent({
  String id = 'event-existing',
  String title = '胸トレーニング',
  String description = 'ベンチプレスから始める',
  bool isAllDay = false,
  EventCategory category = EventCategory.training,
  AiVisibility aiVisibility = AiVisibility.full,
}) {
  final createdAt = DateTime(2026, 7, 20, 8);

  return CalendarEvent(
    id: id,
    humanId: 'local-human',
    title: title,
    description: description,
    startAt: isAllDay ? DateTime(2026, 7, 22) : DateTime(2026, 7, 22, 18, 30),
    endAt: isAllDay ? DateTime(2026, 7, 23) : DateTime(2026, 7, 22, 19, 45),
    isAllDay: isAllDay,
    category: category,
    aiVisibility: aiVisibility,
    source: CalendarSource.internal,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

/// Event Editorを一度pushしてから閉じられるように、簡単な呼び出し元を用意する。
///
/// 画面全体が入る大きさのビューポートを使い、
/// 保存ボタンがスクロール位置によって隠れないようにする。
Future<void> pumpEditor(
  WidgetTester tester, {
  required CalendarRepository repository,
  required DateTime initialDate,
  CalendarEvent? initialEvent,
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
                  Navigator.of(context).push<EventEditorResult>(
                    MaterialPageRoute<EventEditorResult>(
                      builder: (context) => EventEditorPage(
                        repository: repository,
                        humanId: humanId,
                        initialDate: initialDate,
                        initialEvent: initialEvent,
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

/// スクロール領域の中にあるWidgetを、確実に表示してからタップする。
///
/// warnIfMissedは既定のtrueのままにして、
/// タップが対象へ届かなかった場合に警告が出るようにしている。
Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  await tester.ensureVisible(target);

  await tester.pumpAndSettle();

  await tester.tap(target);

  await tester.pumpAndSettle();
}

/// ダイアログの中のボタンをタップする。
///
/// ダイアログはスクロール領域の外にあるため、スクロールは行わない。
Future<void> tapDialogButton(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.tap(target);

  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tapByKey(tester, saveButtonKey);

  expect(find.text(saveErrorMessage), findsNothing);
}

Future<void> tapCancel(WidgetTester tester) async {
  await tapByKey(tester, cancelButtonKey);
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

    testWidgets('新規登録モードでは削除の操作を表示しない', (tester) async {
      final repository = InMemoryCalendarRepository();

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 22),
      );

      expect(find.byKey(deleteButtonKey), findsNothing);
      expect(find.text('予定を登録'), findsOneWidget);
    });
  });

  group('EventEditorPage 編集モード', () {
    testWidgets('既存の予定の内容が初期値として表示される', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      expect(find.text('予定を編集'), findsOneWidget);
      expect(find.text('胸トレーニング'), findsOneWidget);
      expect(find.text('ベンチプレスから始める'), findsOneWidget);

      // 初期日付ではなく、既存の予定の日付が表示される。
      expect(find.text('2026年7月22日（水）'), findsOneWidget);

      expect(find.byKey(deleteButtonKey), findsOneWidget);
    });

    testWidgets('何も変更せずに保存すると、既存の値がそのまま維持される', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapSave(tester);

      expect(find.byType(EventEditorPage), findsNothing);

      final updated = await repository.getEventById(event.id);

      expect(updated, isNotNull);
      expect(updated!.title, event.title);
      expect(updated.description, event.description);
      expect(updated.startAt, event.startAt);
      expect(updated.endAt, event.endAt);
      expect(updated.isAllDay, event.isAllDay);
      expect(updated.category, event.category);

      // 画面を開いただけでAI Visibilityが変わらないことを確認する。
      expect(updated.aiVisibility, AiVisibility.full);
    });

    testWidgets('titleを変更して保存すると、同じIDの予定が更新される', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tester.enterText(find.byKey(titleFieldKey), '背中トレーニング');
      await tester.enterText(find.byKey(descriptionFieldKey), '懸垂から始める');

      await tapSave(tester);

      expect(find.byType(EventEditorPage), findsNothing);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      // 新しい予定が増えず、同じ予定が置き換わる。
      expect(events, hasLength(1));

      final updated = events.single;

      expect(updated.id, event.id);
      expect(updated.title, '背中トレーニング');
      expect(updated.description, '懸垂から始める');
      expect(updated.humanId, event.humanId);
      expect(updated.source, event.source);
      expect(updated.lifeProjectId, event.lifeProjectId);
      expect(updated.startAt, event.startAt);
      expect(updated.endAt, event.endAt);
    });

    testWidgets('編集保存でcreatedAtは維持され、updatedAtだけ更新される', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tester.enterText(find.byKey(titleFieldKey), '有酸素運動');

      await tapSave(tester);

      final updated = await repository.getEventById(event.id);

      expect(updated, isNotNull);
      expect(updated!.createdAt, event.createdAt);
      expect(updated.updatedAt.isAfter(event.updatedAt), isTrue);
    });

    testWidgets('categoryを編集できる', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapByKey(tester, categoryKey(EventCategory.work));

      await tapSave(tester);

      final updated = await repository.getEventById(event.id);

      expect(updated?.category, EventCategory.work);
    });

    testWidgets('aiVisibilityを編集できる', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapByKey(tester, aiVisibilityKey(AiVisibility.hidden));

      await tapSave(tester);

      final updated = await repository.getEventById(event.id);

      expect(updated?.aiVisibility, AiVisibility.hidden);
    });

    testWidgets('終日予定を編集すると、終日の日時規則が維持される', (tester) async {
      final event = existingEvent(isAllDay: true);

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tester.enterText(find.byKey(titleFieldKey), '家族の記念日');

      await tapSave(tester);

      final updated = await repository.getEventById(event.id);

      expect(updated?.isAllDay, isTrue);
      expect(updated?.startAt, DateTime(2026, 7, 22));
      expect(updated?.endAt, DateTime(2026, 7, 23));
    });

    testWidgets('削除ボタンを押しただけでは削除せず、確認を求める', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapByKey(tester, deleteButtonKey);

      expect(find.text('この予定を削除しますか？'), findsOneWidget);
      expect(find.byKey(deleteConfirmButtonKey), findsOneWidget);

      // 確認しただけでは削除されない。
      expect(await repository.getEventById(event.id), isNotNull);
    });

    testWidgets('削除確認でキャンセルすると削除されない', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapByKey(tester, deleteButtonKey);

      await tapDialogButton(tester, deleteCancelButtonKey);

      expect(find.text('この予定を削除しますか？'), findsNothing);

      // 編集画面は開いたままで、予定も残っている。
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(await repository.getEventById(event.id), isNotNull);
    });

    testWidgets('削除確認で「削除する」を選ぶとRepositoryから消える', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tapByKey(tester, deleteButtonKey);

      await tapDialogButton(tester, deleteConfirmButtonKey);

      expect(find.byType(EventEditorPage), findsNothing);

      expect(await repository.getEventById(event.id), isNull);

      final events = await readEvents(repository, month: DateTime(2026, 7));

      expect(events, isEmpty);
    });

    testWidgets('通常の戻る操作では変更が保存されない', (tester) async {
      final event = existingEvent();

      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[event],
      );

      await pumpEditor(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 7, 1),
        initialEvent: event,
      );

      await tester.enterText(find.byKey(titleFieldKey), '保存されない変更');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorPage), findsNothing);

      final updated = await repository.getEventById(event.id);

      expect(updated?.title, '胸トレーニング');
      expect(updated?.updatedAt, event.updatedAt);
    });
  });
}
