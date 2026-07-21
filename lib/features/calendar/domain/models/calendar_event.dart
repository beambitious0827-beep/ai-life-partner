import 'ai_visibility.dart';
import 'calendar_source.dart';
import 'event_category.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.humanId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.isAllDay = false,
    this.category = EventCategory.other,
    this.lifeProjectId,
    this.aiVisibility = AiVisibility.busyOnly,
    this.source = CalendarSource.internal,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '予定IDは空にできません。');
    }

    if (humanId.trim().isEmpty) {
      throw ArgumentError.value(humanId, 'humanId', 'Human IDは空にできません。');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '予定名は空にできません。');
    }

    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('終了日時は開始日時より後に設定してください。');
    }
  }

  final String id;
  final String humanId;
  final String title;
  final String description;

  final DateTime startAt;
  final DateTime endAt;

  final bool isAllDay;
  final EventCategory category;
  final String? lifeProjectId;
  final AiVisibility aiVisibility;
  final CalendarSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration {
    return endAt.difference(startAt);
  }

  bool overlaps({required DateTime rangeStart, required DateTime rangeEnd}) {
    return startAt.isBefore(rangeEnd) && endAt.isAfter(rangeStart);
  }

  CalendarEvent copyWith({
    String? id,
    String? humanId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    EventCategory? category,
    String? lifeProjectId,
    bool clearLifeProjectId = false,
    AiVisibility? aiVisibility,
    CalendarSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      humanId: humanId ?? this.humanId,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      category: category ?? this.category,
      lifeProjectId: clearLifeProjectId
          ? null
          : lifeProjectId ?? this.lifeProjectId,
      aiVisibility: aiVisibility ?? this.aiVisibility,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
