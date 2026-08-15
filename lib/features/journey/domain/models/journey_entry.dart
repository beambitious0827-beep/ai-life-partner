import 'journey_outcome.dart';

/// その日の一歩について、実際に何が起きたかの記録。
///
/// Journeyは達成度や消化率を測るためのものではない。
/// 考え、選び、行動し、休み、変えた事実をそのまま残すためのものである。
///
/// Reflection（あとから振り返って考えること）とは責務を分ける。
/// ここには問いも評価も置かない。
///
/// Calendar Eventとは独立した記録なので、
/// [sourceCalendarEventId] の予定が編集・削除されても、
/// このJourneyEntryは変わらない。
class JourneyEntry {
  JourneyEntry({
    required this.id,
    required this.humanId,
    required this.plannedActionText,
    required this.outcome,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.actualActionText,
    this.note,
    this.plannedDuration,
    this.sourceCalendarEventId,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '歩みのIDは空にできません。');
    }

    if (humanId.trim().isEmpty) {
      throw ArgumentError.value(humanId, 'humanId', 'Human IDは空にできません。');
    }

    if (plannedActionText.trim().isEmpty) {
      throw ArgumentError.value(
        plannedActionText,
        'plannedActionText',
        'もとになった一歩は空にできません。',
      );
    }

    if (outcome.requiresActualActionText) {
      final actualActionText = this.actualActionText;

      if (actualActionText == null || actualActionText.trim().isEmpty) {
        throw ArgumentError('別の一歩になった場合は、どんな一歩になったかを残してください。');
      }
    }
  }

  final String id;
  final String humanId;

  /// 記録したときの「今日の一歩」の写し。
  ///
  /// あとからHomeの一歩が変わっても、この歩みの内容は変わらない。
  final String plannedActionText;

  final JourneyOutcome outcome;

  /// 実際にどんな一歩になったか。
  ///
  /// 別の一歩になった場合は必須。それ以外では任意。
  final String? actualActionText;

  /// Humanが自由に残すひとこと。
  ///
  /// 振り返りでも評価でもなく、その日のメモである。
  final String? note;

  /// もとの一歩に長さの情報があった場合の写し。評価には使わない。
  final Duration? plannedDuration;

  /// もとの一歩をカレンダーへ登録していた場合の、予定IDの写し。
  ///
  /// 参照のためだけに持つ。JourneyEntryはCalendar Eventに依存しない。
  final String? sourceCalendarEventId;

  /// この歩みが起きた日時。
  final DateTime occurredAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasActualActionText {
    final actualActionText = this.actualActionText;

    return actualActionText != null && actualActionText.trim().isNotEmpty;
  }

  bool get hasNote {
    final note = this.note;

    return note != null && note.trim().isNotEmpty;
  }
}
