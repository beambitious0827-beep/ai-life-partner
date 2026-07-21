import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent createEvent({
  required String id,
  required String humanId,
  required DateTime startAt,
  required DateTime endAt,
  String title = '予定',
}) {
  final createdAt = DateTime(2026, 7, 22, 8);

  return CalendarEvent(
    id: id,
    humanId: humanId,
    title: title,
    startAt: startAt,
    endAt: endAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('InMemoryCalendarRepository', () {
    test('指定したHumanと期間の予定を開始日時順で取得できる', () async {
      final repository = InMemoryCalendarRepository(
        seedEvents: <CalendarEvent>[
          createEvent(
            id: 'later',
            humanId: 'human-1',
            startAt: DateTime(2026, 7, 22, 14),
            endAt: DateTime(2026, 7, 22, 15),
          ),
          createEvent(
            id: 'early',
            humanId: 'human-1',
            startAt: DateTime(2026, 7, 22, 10),
            endAt: DateTime(2026, 7, 22, 11),
          ),
          createEvent(
            id: 'outside-range',
            humanId: 'human-1',
            startAt: DateTime(2026, 8, 2, 10),
            endAt: DateTime(2026, 8, 2, 11),
          ),
          createEvent(
            id: 'another-human',
            humanId: 'human-2',
            startAt: DateTime(2026, 7, 22, 9),
            endAt: DateTime(2026, 7, 22, 10),
          ),
        ],
      );

      final events = await repository.getEvents(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 7),
        rangeEnd: DateTime(2026, 8),
      );

      expect(events.map((event) => event.id), <String>['early', 'later']);
    });

    test('予定を保存、更新、削除できる', () async {
      final repository = InMemoryCalendarRepository();

      final event = createEvent(
        id: 'event-1',
        humanId: 'human-1',
        title: 'トレーニング',
        startAt: DateTime(2026, 7, 22, 18),
        endAt: DateTime(2026, 7, 22, 19),
      );

      await repository.saveEvent(event);

      final savedEvent = await repository.getEventById('event-1');

      expect(savedEvent?.title, 'トレーニング');

      final updatedEvent = event.copyWith(
        title: '胸トレーニング',
        updatedAt: DateTime(2026, 7, 22, 12),
      );

      await repository.saveEvent(updatedEvent);

      final result = await repository.getEventById('event-1');

      expect(result?.title, '胸トレーニング');

      await repository.deleteEvent('event-1');

      final deletedEvent = await repository.getEventById('event-1');

      expect(deletedEvent, isNull);
    });
  });
}
