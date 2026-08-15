import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';

/// カレンダーの空き時間を読み込んだ結果の状態。
enum CalendarAvailabilityStatus {
  /// カレンダーを確認できた。空き時間が0件のこともある。
  loaded,

  /// カレンダーを確認できなかった。
  failed,
}

/// NextStepPageへ渡す、今日の空き時間の読み込み結果。
///
/// 「確認したうえで空き時間がなかった」と「そもそも確認できなかった」を
/// 取り違えないよう、状態として区別する。
/// 前者は予定が詰まっている事実、後者は情報が欠けている状態であり、
/// Humanへ伝えるべき内容が異なる。
class CalendarAvailability {
  const CalendarAvailability.loaded(this.windows)
    : status = CalendarAvailabilityStatus.loaded;

  const CalendarAvailability.failed()
    : status = CalendarAvailabilityStatus.failed,
      windows = const <AvailableTimeWindow>[];

  /// 空き時間を確認していない状態の既定値。
  static const CalendarAvailability none = CalendarAvailability.loaded(
    <AvailableTimeWindow>[],
  );

  final CalendarAvailabilityStatus status;

  /// 見つかった空き時間。読み込みに失敗した場合は空になる。
  final List<AvailableTimeWindow> windows;

  bool get isLoaded => status == CalendarAvailabilityStatus.loaded;

  bool get isFailed => status == CalendarAvailabilityStatus.failed;

  /// 確認できたうえで、使える空き時間が見つかった状態。
  bool get hasWindows => isLoaded && windows.isNotEmpty;

  /// 確認できたが、対象時間がすべて予定で埋まっていた状態。
  bool get isFullyOccupied => isLoaded && windows.isEmpty;
}
