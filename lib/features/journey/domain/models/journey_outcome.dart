/// その日の一歩が、実際にはどうなったか。
///
/// 良し悪しの段階ではない。
/// 取り組めた日も、別のことを選んだ日も、休んだ日も、
/// どれも同じようにその人の歩みである。
/// 「できなかった」「失敗した」という区分は意図的に持たない。
enum JourneyOutcome { completed, partial, changed, rested }

extension JourneyOutcomeView on JourneyOutcome {
  String get label {
    switch (this) {
      case JourneyOutcome.completed:
        return 'できた';
      case JourneyOutcome.partial:
        return '少し取り組んだ';
      case JourneyOutcome.changed:
        return '別の一歩になった';
      case JourneyOutcome.rested:
        return '今日は休んだ';
    }
  }

  /// 選ぶときの手がかりになる、事実だけの補足。
  ///
  /// 評価や励ましではなく、何が起きたかを表す。
  String get description {
    switch (this) {
      case JourneyOutcome.completed:
        return '決めた一歩に取り組めた。';
      case JourneyOutcome.partial:
        return '一部だけ進めた。';
      case JourneyOutcome.changed:
        return '別のことを選んだ。';
      case JourneyOutcome.rested:
        return '休むことを選んだ。';
    }
  }

  /// 実際に何をしたかの入力が必要かどうか。
  ///
  /// 別の一歩になった場合、それを書き残さないと
  /// 何が起きた日だったのかが歩みに残らない。
  bool get requiresActualActionText {
    return this == JourneyOutcome.changed;
  }
}
