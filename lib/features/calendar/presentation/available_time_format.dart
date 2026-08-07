import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';

/// 空き時間を画面へ表示するためのフォーマット。
///
/// 日本語の表示ロジックはDomain Modelへ入れず、Presentation層に置く。

/// 時刻を「09:05」の形式で表す。
String formatClockTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

/// 空き時間の時間帯を「06:00 - 09:00」の形式で表す。
String formatAvailableTimeRange(AvailableTimeWindow window) {
  return '${formatClockTime(window.startAt)} - ${formatClockTime(window.endAt)}';
}

/// 長さを日本語で表す。
///
/// 45分  → 「45分」
/// 60分  → 「1時間」
/// 90分  → 「1時間30分」
/// 120分 → 「2時間」
String formatDurationLabel(Duration duration) {
  final totalMinutes = duration.inMinutes;

  if (totalMinutes < 60) {
    return '$totalMinutes分';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (minutes == 0) {
    return '$hours時間';
  }

  return '$hours時間$minutes分';
}
