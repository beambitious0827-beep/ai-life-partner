/// ひとつの振り返りから、Human自身が見いだした気づき。
///
/// Insightは、AIがHumanへ渡す正解ではない。
/// Journeyが「何が起きたか」を、
/// Reflectionが「どう感じ、何に気づいたか」を残すのに対して、
/// Insightは「そこから自分にとって意味があると思えたこと」を残す。
///
/// v1ではAIが生成も評価もしない。Humanが書いた言葉だけが残る。
/// そのため、成長段階・習熟度・学習スコアのような数値は意図的に持たない。
///
/// Reflectionの写しも持たない。関連は [reflectionEntryId] だけで表す。
class InsightEntry {
  InsightEntry({
    required this.id,
    required this.humanId,
    required this.reflectionEntryId,
    required this.insightText,
    required this.discoveredAt,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', '気づきのIDは空にできません。');
    }

    if (humanId.trim().isEmpty) {
      throw ArgumentError.value(humanId, 'humanId', 'Human IDは空にできません。');
    }

    if (reflectionEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        reflectionEntryId,
        'reflectionEntryId',
        'もとになる振り返りのIDは空にできません。',
      );
    }

    // 長さは制限しない。ひとことでも、少し長い文章でも残せる。
    // ただし何も書かれていない気づきは、気づきとして残らない。
    if (insightText.trim().isEmpty) {
      throw ArgumentError.value(insightText, 'insightText', '気づきの言葉は空にできません。');
    }
  }

  final String id;
  final String humanId;

  /// この気づきが生まれた振り返りのID。
  ///
  /// 参照のためだけに持つ。振り返りの内容はReflection側が持ち続ける。
  final String reflectionEntryId;

  /// Humanが最終的に確定した気づきの言葉。
  final String insightText;

  /// Humanがこの気づきを残した日時。
  final DateTime discoveredAt;

  final DateTime createdAt;
  final DateTime updatedAt;
}
