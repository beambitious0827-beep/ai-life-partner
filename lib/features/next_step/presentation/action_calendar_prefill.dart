import 'package:ai_life_partner/features/calendar/presentation/event_editor_prefill.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';

/// 確定したActionから、Event Editorへ渡す初期値の候補を組み立てる。
///
/// 日時はNextStepResultが持つ構造化データからだけ決める。
/// Action textは表示用のテキストなので、
/// 「30分」「18:00」のような文字列を解析して時間を決めることはしない。
///
/// ここで作るのは候補であり、予定ではない。
/// 実際に保存するかどうかは、Event EditorでHumanが決める。
EventEditorPrefill buildActionCalendarPrefill({
  required NextStepResult result,
  required DateTime defaultStartAt,
}) {
  final title = result.actionText.trim();

  final window = result.selectedCalendarWindow;
  final duration = result.actionDuration;

  if (window != null) {
    // 空き時間は「この範囲なら実行できる」という上限。
    // 空き時間全体を予定にはせず、提案したActionの長さだけを充てる。
    if (duration == null) {
      // 長さが決まっていない場合、空き時間の終わりまでを予定にはしない。
      // 開始だけを候補にして、長さはEvent Editorの既定に任せる。
      return EventEditorPrefill(title: title);
    }

    final startAt = window.startAt;
    final proposedEndAt = startAt.add(duration);

    // 予定の初期候補は、必ず選んだ空き時間の中に収める。
    final endAt = proposedEndAt.isAfter(window.endAt)
        ? window.endAt
        : proposedEndAt;

    return EventEditorPrefill(title: title, startAt: startAt, endAt: endAt);
  }

  if (duration != null) {
    // 手動で長さだけを決めた場合は、いつ行うかの情報がない。
    // Event Editorの既定の開始時刻を基準にした候補を作り、
    // 実際の日時はHumanがEvent Editorで確認・変更する。
    return EventEditorPrefill(
      title: title,
      startAt: defaultStartAt,
      endAt: defaultStartAt.add(duration),
    );
  }

  // 「時間は調整できる」など、長さが決まっていない場合。
  // 存在しない長さを勝手に決めず、Event Editorの既定の時刻を使う。
  return EventEditorPrefill(title: title);
}
