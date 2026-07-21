import '../models/calendar_event.dart';

abstract interface class CalendarRepository {
  Future<List<CalendarEvent>> getEvents({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<CalendarEvent?> getEventById(String eventId);

  Future<void> saveEvent(CalendarEvent event);

  Future<void> deleteEvent(String eventId);
}
