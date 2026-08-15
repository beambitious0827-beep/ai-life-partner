import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';

/// 既存の予定以外を起点にEvent Editorを開くときの、初期値の候補。
///
/// 「次の一歩」をカレンダーへ追加する場合など、
/// 呼び出し側が決めた内容をEvent Editorへ渡すために使う。
///
/// ここに入るのはあくまで候補であり、確定した予定ではない。
/// Humanはすべての項目をEvent Editorで確認・変更でき、
/// 保存を押すまでCalendar Eventは作成されない。
class EventEditorPrefill {
  const EventEditorPrefill({
    required this.title,
    this.startAt,
    this.endAt,
    this.category = EventCategory.lifeProject,
    this.aiVisibility = AiVisibility.busyOnly,
  });

  /// 予定名の初期値。
  final String title;

  /// 開始日時の候補。
  ///
  /// nullの場合は、Event Editorの新規作成時の既定の日時を使う。
  /// 長さが決まっていないActionのために、勝手な時刻を確定しないようにしている。
  final DateTime? startAt;

  /// 終了日時の候補。[startAt] と対で指定する。
  final DateTime? endAt;

  /// 予定の種類の初期値。
  final EventCategory category;

  /// AIが参照できる範囲の初期値。
  ///
  /// Action由来でも、内容をAIへ渡さない安全な既定を維持する。
  final AiVisibility aiVisibility;

  /// 開始・終了の候補がそろっていて、範囲として使えるか。
  bool get hasSchedule {
    final startAt = this.startAt;
    final endAt = this.endAt;

    return startAt != null && endAt != null && endAt.isAfter(startAt);
  }
}
