import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';

/// NextStepPageでHumanが確定した結果。
///
/// 将来の
///
///     Action → Human confirmation → Calendar Event登録
///
/// に備えて、決めたAction本文だけでなく、選んだ時間の情報も一緒に返す。
/// この時点ではCalendar Eventを作成しない。作成するかどうかは、
/// 後のPhaseでHumanが明示的に決める。
///
/// カレンダーの空き時間と手動の時間指定は排他なので、
/// [selectedCalendarWindow] と [manualDuration] が同時に設定されることはない。
class NextStepResult {
  /// カレンダーの空き時間を選んで確定した場合。
  const NextStepResult.fromCalendarWindow({
    required this.actionText,
    required AvailableTimeWindow window,
  }) : selectedCalendarWindow = window,
       manualDuration = null;

  /// 手動で時間を決めて確定した場合。
  ///
  /// 「時間は調整できる」を選んだ場合は特定の長さを持たないため、
  /// [duration] はnullになる。
  const NextStepResult.fromManualTime({
    required this.actionText,
    Duration? duration,
  }) : selectedCalendarWindow = null,
       manualDuration = duration;

  /// Humanが最終的に決めたActionの本文。
  final String actionText;

  /// カレンダーの空き時間を選んだ場合の時間帯。手動指定の場合はnull。
  ///
  /// この時間帯はActionを行える上限であり、
  /// すべてをActionへ使うことを意味しない。
  final AvailableTimeWindow? selectedCalendarWindow;

  /// 手動で時間を選んだ場合の長さ。カレンダーの空き時間を選んだ場合はnull。
  final Duration? manualDuration;

  bool get usesCalendarWindow => selectedCalendarWindow != null;
}
