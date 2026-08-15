import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';

/// 今日の一歩を歩みとして残した記録。
///
/// 「残したかどうか」だけをboolで持つと、
/// どの一歩をどのJourneyEntryとして残したのかが分からなくなる。
/// 記録対象の一歩と、保存されたJourneyEntryのIDを対にして保持する。
class ActionJourneyRecord {
  const ActionJourneyRecord({
    required this.action,
    required this.journeyEntryId,
  });

  /// 記録した時点の一歩。
  final NextStepResult action;

  /// 保存されたJourneyEntryのID。
  final String journeyEntryId;

  /// [other] が、この記録の対象と同じ一歩かどうか。
  ///
  /// Action textだけでなく、時間帯と長さも含めて比べる。
  bool isFor(NextStepResult other) {
    return action == other;
  }
}
