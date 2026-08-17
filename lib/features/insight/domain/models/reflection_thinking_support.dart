/// Humanが考えるための材料。AIからの答えではない。
///
/// ここにあるのは、Humanが自分で考えるときの手がかりでしかない。
/// これをそのままInsightEntryにしてはいけない。
/// 気づきとして何を残すかを決めるのは、いつでもHumanである。
///
/// 断定を置かない。診断もしない。
/// 「〜かもしれません」「〜という見方もあります」のように、
/// Humanが考える余地を残した言葉だけを持つ。
class ReflectionThinkingSupport {
  ReflectionThinkingSupport({
    List<String> questions = const <String>[],
    List<String> perspectives = const <String>[],
    List<String> possibilities = const <String>[],
  }) : questions = List<String>.unmodifiable(questions),
       perspectives = List<String>.unmodifiable(perspectives),
       possibilities = List<String>.unmodifiable(possibilities) {
    for (final line in <String>[
      ...this.questions,
      ...this.perspectives,
      ...this.possibilities,
    ]) {
      if (line.trim().isEmpty) {
        throw ArgumentError('空の手がかりは、考える材料になりません。');
      }
    }

    if (isEmpty) {
      throw ArgumentError('考えるための材料がひとつもありません。');
    }
  }

  /// 考えはじめるための問い。
  final List<String> questions;

  /// 同じ出来事についての、別の見方。
  final List<String> perspectives;

  /// そうだったかもしれない、という可能性。
  final List<String> possibilities;

  bool get isEmpty {
    return questions.isEmpty && perspectives.isEmpty && possibilities.isEmpty;
  }
}
