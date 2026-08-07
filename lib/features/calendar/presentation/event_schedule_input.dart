import 'package:flutter/material.dart' show TimeOfDay;

/// Event Editorで入力された日付・終日設定・時刻から、
/// CalendarEventへ渡す開始日時と終了日時を組み立てる。
///
/// 日時の組み立て規則をUIから切り離し、単体テストできるようにしている。
class EventScheduleInput {
  const EventScheduleInput({
    required this.date,
    required this.isAllDay,
    required this.startTime,
    required this.endTime,
  });

  /// 予定の日付。時刻部分は無視する。
  final DateTime date;

  final bool isAllDay;

  /// 終日予定のときは使用しない。
  final TimeOfDay startTime;

  /// 終日予定のときは使用しない。
  final TimeOfDay endTime;

  /// 終日予定は選択日の00:00、時間指定予定は選択日と開始時刻の組み合わせ。
  DateTime get startAt {
    if (isAllDay) {
      return DateTime(date.year, date.month, date.day);
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
  }

  /// 終日予定は翌日の00:00、時間指定予定は選択日と終了時刻の組み合わせ。
  DateTime get endAt {
    if (isAllDay) {
      return DateTime(date.year, date.month, date.day + 1);
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
  }

  /// 終了日時が開始日時より後であることを確認する。
  bool get isValid {
    return endAt.isAfter(startAt);
  }

  /// 不正なときにユーザーへ表示する日本語のメッセージ。正しいときはnull。
  String? get validationMessage {
    if (isValid) {
      return null;
    }

    return '終了時刻は開始時刻より後に設定してください。';
  }
}
