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
/// 時間の情報は次の2つで表す。
///
/// - [selectedCalendarWindow] … Actionを行える時間帯（上限）
/// - [actionDuration] … その中で実際に提案したActionの長さ
///
/// カレンダーの空き時間と手動の時間指定は排他なので、
/// 手動指定の場合 [selectedCalendarWindow] はnullになる。
class NextStepResult {
  /// カレンダーの空き時間を選んで確定した場合。
  ///
  /// [duration] は空き時間の長さではなく、
  /// 余力などから提案したActionの長さ。
  const NextStepResult.fromCalendarWindow({
    required this.actionText,
    required AvailableTimeWindow window,
    required Duration duration,
  }) : selectedCalendarWindow = window,
       actionDuration = duration;

  /// 手動で時間を決めて確定した場合。
  ///
  /// 「時間は調整できる」を選んだ場合は特定の長さを持たないため、
  /// [duration] はnullになる。
  const NextStepResult.fromManualTime({
    required this.actionText,
    Duration? duration,
  }) : selectedCalendarWindow = null,
       actionDuration = duration;

  /// Humanが最終的に決めたActionの本文。
  ///
  /// 表示用のテキストであり、ここから時刻や長さを読み取ってはいけない。
  final String actionText;

  /// カレンダーの空き時間を選んだ場合の時間帯。手動指定の場合はnull。
  ///
  /// この時間帯はActionを行える上限であり、
  /// すべてをActionへ使うことを意味しない。
  final AvailableTimeWindow? selectedCalendarWindow;

  /// Actionとして提案した長さ。
  ///
  /// 長さが決まっていない場合（「時間は調整できる」など）はnull。
  final Duration? actionDuration;

  bool get usesCalendarWindow => selectedCalendarWindow != null;

  /// 同じ内容の一歩かどうかを、構造化された値だけで比べる。
  ///
  /// Action textだけでは、同じ文でも時間帯や長さが違うことがある。
  /// カレンダー登録済みかどうかの判定に使うため、
  /// 時間の情報まで含めて一致したときだけ同じとみなす。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is NextStepResult &&
        other.actionText == actionText &&
        other.selectedCalendarWindow == selectedCalendarWindow &&
        other.actionDuration == actionDuration;
  }

  @override
  int get hashCode {
    return Object.hash(actionText, selectedCalendarWindow, actionDuration);
  }

  @override
  String toString() {
    return 'NextStepResult($actionText, '
        'window: $selectedCalendarWindow, duration: $actionDuration)';
  }
}
