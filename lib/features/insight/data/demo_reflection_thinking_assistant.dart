import '../domain/models/reflection_thinking_request.dart';
import '../domain/models/reflection_thinking_support.dart';
import '../domain/services/reflection_thinking_assistant.dart';

/// ネットワークもAPI keyも使わない、デモ用のAssistant。
///
/// このアプリのclientには、AI providerの鍵を置かない。
/// 安全なserver側の窓口ができるまでは、この実装でPhase 9の体験だけを形にする。
/// Humanに「本物のAIが答えた」と思わせないよう、[isDemo] をtrueで返す。
///
/// 返す言葉は、その振り返りの中身を読み解いたふりをしない。
/// どの振り返りにも当てはまる、考えはじめるための手がかりだけを置く。
/// 同じ材料からは必ず同じ結果が返る。
class DemoReflectionThinkingAssistant implements ReflectionThinkingAssistant {
  const DemoReflectionThinkingAssistant();

  @override
  bool get isDemo => true;

  @override
  Future<ReflectionThinkingSupport> support(
    ReflectionThinkingRequest request,
  ) async {
    final questions = <String>[
      if (request.hasFeelingText) 'そのとき感じたことは、いま読み返すとどんなふうに見えますか？',
      if (request.hasNoticedText) '気づいたことのなかで、これからも覚えておきたいものはありますか？',
      'この歩みのなかで、自分にとって意味があったと思えることはありますか？',
    ];

    return ReflectionThinkingSupport(
      questions: questions,
      perspectives: <String>[
        'うまく進んだかどうかとは別に、そのときの自分に合った選び方だった、という見方もできます。',
        '同じ出来事でも、時間が経ってから読み返すと、違う意味に見えてくることがあります。',
      ],
      possibilities: <String>[
        'いま言葉にしきれないことが、あとから形になることもあります。',
        '立ち止まっていた時間が、次へ進むための準備だった可能性もあります。',
      ],
    );
  }
}
