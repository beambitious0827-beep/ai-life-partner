import 'package:ai_life_partner/features/insight/data/demo_reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_request.dart';
import 'package:flutter_test/flutter_test.dart';

const DemoReflectionThinkingAssistant assistant =
    DemoReflectionThinkingAssistant();

ReflectionThinkingRequest createRequest({
  String reflectionEntryId = 'reflection-1',
  String? feelingText = '思ったより疲れていた',
  String? noticedText = '休んだことで少し気持ちが軽くなった',
}) {
  return ReflectionThinkingRequest(
    reflectionEntryId: reflectionEntryId,
    feelingText: feelingText,
    noticedText: noticedText,
  );
}

void main() {
  group('DemoReflectionThinkingAssistant', () {
    test('デモであることを名乗る', () {
      expect(assistant.isDemo, isTrue);
    });

    test('問い・別の見方・可能性を返す', () async {
      final support = await assistant.support(createRequest());

      expect(support.questions, isNotEmpty);
      expect(support.perspectives, isNotEmpty);
      expect(support.possibilities, isNotEmpty);
    });

    test('同じ材料からは同じ結果を返す', () async {
      final first = await assistant.support(createRequest());
      final second = await assistant.support(createRequest());

      expect(first.questions, second.questions);
      expect(first.perspectives, second.perspectives);
      expect(first.possibilities, second.possibilities);
    });

    test('書かれていない項目についての問いは出さない', () async {
      final feelingOnly = await assistant.support(
        createRequest(noticedText: null),
      );

      expect(
        feelingOnly.questions.any((line) => line.contains('気づいたこと')),
        isFalse,
      );

      final noticedOnly = await assistant.support(
        createRequest(feelingText: null),
      );

      expect(
        noticedOnly.questions.any((line) => line.contains('感じたこと')),
        isFalse,
      );
    });

    test('Humanが書いた言葉をそのまま返さない', () async {
      final support = await assistant.support(
        createRequest(feelingText: 'ひどく落ち込んでいた', noticedText: '誰にも会いたくなかった'),
      );

      final lines = <String>[
        ...support.questions,
        ...support.perspectives,
        ...support.possibilities,
      ];

      for (final line in lines) {
        expect(line.contains('ひどく落ち込んでいた'), isFalse);
        expect(line.contains('誰にも会いたくなかった'), isFalse);
      }
    });

    test('断定や決めつけの言葉を使わない', () async {
      final support = await assistant.support(createRequest());

      const forbidden = <String>[
        'べきです',
        'べきだ',
        '原因は',
        'あなたは',
        '間違',
        '正しい答え',
        '改善',
        '診断',
        '性格',
        '分析',
        '成功',
        '失敗',
        '評価',
        '問題点',
      ];

      final lines = <String>[
        ...support.questions,
        ...support.perspectives,
        ...support.possibilities,
      ];

      for (final line in lines) {
        for (final word in forbidden) {
          expect(
            line.contains(word),
            isFalse,
            reason: '$word はAIの手がかりでは使わない: $line',
          );
        }
      }
    });
  });
}
