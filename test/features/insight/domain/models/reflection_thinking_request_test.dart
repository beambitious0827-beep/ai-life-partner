import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_request.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime reflectedAt = DateTime(2026, 5, 20, 21);

ReflectionEntry createReflectionEntry({
  String id = 'reflection-1',
  String humanId = 'local-human',
  String journeyEntryId = 'journey-1',
  String? feelingText = '思ったより疲れていた',
  String? noticedText = '休んだことで少し気持ちが軽くなった',
}) {
  return ReflectionEntry(
    id: id,
    humanId: humanId,
    journeyEntryId: journeyEntryId,
    feelingText: feelingText,
    noticedText: noticedText,
    reflectedAt: reflectedAt,
    createdAt: reflectedAt,
    updatedAt: reflectedAt,
  );
}

void main() {
  group('ReflectionThinkingRequest', () {
    test('振り返りから、渡してよい言葉だけを写し取る', () {
      final request = ReflectionThinkingRequest.fromReflection(
        createReflectionEntry(
          id: 'reflection-42',
          feelingText: '思ったより疲れていた',
          noticedText: '休んだことで少し気持ちが軽くなった',
        ),
      );

      expect(request.reflectionEntryId, 'reflection-42');
      expect(request.feelingText, '思ったより疲れていた');
      expect(request.noticedText, '休んだことで少し気持ちが軽くなった');
    });

    test('感じたことだけの振り返りでも作れる', () {
      final request = ReflectionThinkingRequest.fromReflection(
        createReflectionEntry(noticedText: null),
      );

      expect(request.hasFeelingText, isTrue);
      expect(request.hasNoticedText, isFalse);
      expect(request.noticedText, isNull);
    });

    test('気づいたことだけの振り返りでも作れる', () {
      final request = ReflectionThinkingRequest.fromReflection(
        createReflectionEntry(feelingText: null),
      );

      expect(request.hasFeelingText, isFalse);
      expect(request.hasNoticedText, isTrue);
    });

    test('もとになる振り返りのIDが空の場合は作れない', () {
      expect(
        () => ReflectionThinkingRequest(
          reflectionEntryId: '  ',
          feelingText: '思ったより疲れていた',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('考えるための言葉がひとつもない場合は作れない', () {
      expect(
        () => ReflectionThinkingRequest(reflectionEntryId: 'reflection-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('空白だけの言葉は、考える材料として扱わない', () {
      expect(
        () => ReflectionThinkingRequest(
          reflectionEntryId: 'reflection-1',
          feelingText: '   ',
          noticedText: '\n',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Human IDや歩みなど、ほかの情報は持たない', () {
      final reflection = createReflectionEntry(
        id: 'reflection-1',
        humanId: 'local-human',
        journeyEntryId: 'journey-99',
      );

      final request = ReflectionThinkingRequest.fromReflection(reflection);

      // 渡せるのはこの3つだけで、誰の振り返りかも、どの歩みかも含まれない。
      expect(request.reflectionEntryId, reflection.id);
      expect(request.feelingText, reflection.feelingText);
      expect(request.noticedText, reflection.noticedText);
    });
  });
}
