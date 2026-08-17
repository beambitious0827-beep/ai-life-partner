import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReflectionThinkingSupport', () {
    test('問い・別の見方・可能性を持てる', () {
      final support = ReflectionThinkingSupport(
        questions: <String>['どんなふうに見えますか？'],
        perspectives: <String>['という見方もできます。'],
        possibilities: <String>['という可能性もあります。'],
      );

      expect(support.questions, <String>['どんなふうに見えますか？']);
      expect(support.perspectives, <String>['という見方もできます。']);
      expect(support.possibilities, <String>['という可能性もあります。']);
      expect(support.isEmpty, isFalse);
    });

    test('どれか一種類だけでも作れる', () {
      final support = ReflectionThinkingSupport(
        questions: <String>['どんなふうに見えますか？'],
      );

      expect(support.questions, hasLength(1));
      expect(support.perspectives, isEmpty);
      expect(support.possibilities, isEmpty);
    });

    test('受け取った一覧は書き換えられない', () {
      final support = ReflectionThinkingSupport(
        questions: <String>['どんなふうに見えますか？'],
      );

      expect(support.questions.clear, throwsUnsupportedError);
    });

    test('材料がひとつもない場合は作れない', () {
      expect(() => ReflectionThinkingSupport(), throwsA(isA<ArgumentError>()));
    });

    test('空の手がかりは受け付けない', () {
      expect(
        () => ReflectionThinkingSupport(questions: <String>['  ']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('別の見方や可能性が空文字の場合も受け付けない', () {
      expect(
        () => ReflectionThinkingSupport(
          questions: <String>['どんなふうに見えますか？'],
          perspectives: <String>[''],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
