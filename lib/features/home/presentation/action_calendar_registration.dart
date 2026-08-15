import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';

/// 今日の一歩をカレンダーへ登録した記録。
///
/// 「登録したかどうか」だけをboolで持つと、
/// どの一歩をどのCalendar Eventとして保存したのかが分からなくなる。
/// 登録対象の一歩と、保存されたCalendar EventのIDを対にして保持する。
///
/// Action textからCalendar Eventを探し直すようなことはしない。
/// 対応関係はここで持つ。
class ActionCalendarRegistration {
  const ActionCalendarRegistration({
    required this.action,
    required this.calendarEventId,
  });

  /// 登録した時点の一歩。
  final NextStepResult action;

  /// 保存されたCalendar EventのID。
  ///
  /// Calendar側で削除されていないかを確認するために使う。
  final String calendarEventId;

  /// [other] が、この登録の対象と同じ一歩かどうか。
  ///
  /// Action textだけでなく、時間帯と長さも含めて比べる。
  bool isFor(NextStepResult other) {
    return action == other;
  }

  /// [other] が、同じ一歩を同じCalendar Eventとして登録した記録かどうか。
  ///
  /// 非同期の照合結果が古くなっていないかを確かめるために使う。
  bool isSameRegistrationAs(ActionCalendarRegistration other) {
    return calendarEventId == other.calendarEventId && isFor(other.action);
  }
}
