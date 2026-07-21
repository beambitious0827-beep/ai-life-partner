import '../domain/models/calendar_event.dart';
import '../domain/repositories/calendar_repository.dart';

class InMemoryCalendarRepository implements CalendarRepository {
  InMemoryCalendarRepository({
    Iterable<CalendarEvent> seedEvents = const <CalendarEvent>[],
  }) {
    for (final event in seedEvents) {
      _events[event.id] = event;
    }
  }

  final Map<String, CalendarEvent> _events = <String, CalendarEvent>{};

  @override
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('取得期間の終了日時は、開始日時より後に設定してください。');
    }

    final events = _events.values.where((event) {
      return event.humanId == humanId &&
          event.overlaps(rangeStart: rangeStart, rangeEnd: rangeEnd);
    }).toList();

    events.sort((first, second) => first.startAt.compareTo(second.startAt));

    return List<CalendarEvent>.unmodifiable(events);
  }

  @override
  Future<CalendarEvent?> getEventById(String eventId) async {
    return _events[eventId];
  }

  @override
  Future<void> saveEvent(CalendarEvent event) async {
    _events[event.id] = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }
}
