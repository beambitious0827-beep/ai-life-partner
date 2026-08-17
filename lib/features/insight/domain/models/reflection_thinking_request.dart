import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';

/// AIと一緒に考えるときに、AI側へ渡す材料。
///
/// ReflectionEntryをそのまま渡さない。
/// そのまま渡すと、あとからReflectionへ項目が増えたときに、
/// Humanが意図しないものまで自動的にAIへ流れてしまう。
/// 何を渡すのかは、この型で明示的に決めておく。
///
/// v1で渡すのは、Humanが選んだその振り返りの言葉だけ。
/// 歩みの履歴・カレンダー・家族・健康・これまでの気づき・
/// ほかのHumanのデータは、いっさい含めない。
///
/// humanIdも含めない。
/// 誰の振り返りかの確認は呼び出し側の境界で行うことであり、
/// 考える材料そのものには必要がないため。
class ReflectionThinkingRequest {
  ReflectionThinkingRequest({
    required this.reflectionEntryId,
    this.feelingText,
    this.noticedText,
  }) {
    if (reflectionEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        reflectionEntryId,
        'reflectionEntryId',
        'もとになる振り返りのIDは空にできません。',
      );
    }

    if (!hasFeelingText && !hasNoticedText) {
      throw ArgumentError('一緒に考えるための言葉がありません。');
    }
  }

  /// Humanが選んだ、その振り返りだけを対象にするための参照。
  ///
  /// v1では対象を1件に限る。ほかの振り返りはここに現れない。
  factory ReflectionThinkingRequest.fromReflection(ReflectionEntry reflection) {
    // 渡してよい項目をここで書き出す。
    // 増やすときは、この1か所を意識して変えることになる。
    return ReflectionThinkingRequest(
      reflectionEntryId: reflection.id,
      feelingText: reflection.feelingText,
      noticedText: reflection.noticedText,
    );
  }

  final String reflectionEntryId;

  /// 「今、どんな感じですか？」へHumanが書いた言葉。
  final String? feelingText;

  /// 「何か気づいたことはありますか？」へHumanが書いた言葉。
  final String? noticedText;

  bool get hasFeelingText {
    final feelingText = this.feelingText;

    return feelingText != null && feelingText.trim().isNotEmpty;
  }

  bool get hasNoticedText {
    final noticedText = this.noticedText;

    return noticedText != null && noticedText.trim().isNotEmpty;
  }
}
