/// ひとつの歩みについて、Human自身が振り返った記録。
///
/// Reflectionは反省でも採点でもない。
/// Journeyが「何が起きたか」を残すのに対して、
/// Reflectionは「Humanがどう感じ、何に気づいたか」をHumanの言葉で残す。
///
/// v1ではAIが生成も評価もしない。Humanが書いたものだけが残る。
/// そのため、気分の点数・満足度・達成度のような数値は意図的に持たない。
class ReflectionEntry {
  ReflectionEntry({
    required this.id,
    required this.humanId,
    required this.journeyEntryId,
    required this.reflectedAt,
    required this.createdAt,
    required this.updatedAt,
    this.feelingText,
    this.noticedText,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '振り返りのIDは空にできません。');
    }

    if (humanId.trim().isEmpty) {
      throw ArgumentError.value(humanId, 'humanId', 'Human IDは空にできません。');
    }

    if (journeyEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        journeyEntryId,
        'journeyEntryId',
        'もとになる歩みのIDは空にできません。',
      );
    }

    // どちらか一つだけでも残せる。
    // ただし両方とも空だと、Humanの言葉が何も残らない。
    if (!hasFeelingText && !hasNoticedText) {
      throw ArgumentError('感じたことか気づいたことか、どちらかを残してください。');
    }
  }

  final String id;
  final String humanId;

  /// この振り返りが向き合っている歩みのID。
  ///
  /// 参照のためだけに持つ。歩みの内容はJourney側が持ち続ける。
  final String journeyEntryId;

  /// 「今、どんな感じですか？」への、Humanの言葉。
  final String? feelingText;

  /// 「この歩みから、何か気づいたことはありますか？」への、Humanの言葉。
  final String? noticedText;

  /// Humanがこの振り返りを残した日時。
  final DateTime reflectedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFeelingText {
    final feelingText = this.feelingText;

    return feelingText != null && feelingText.trim().isNotEmpty;
  }

  bool get hasNoticedText {
    final noticedText = this.noticedText;

    return noticedText != null && noticedText.trim().isNotEmpty;
  }
}
