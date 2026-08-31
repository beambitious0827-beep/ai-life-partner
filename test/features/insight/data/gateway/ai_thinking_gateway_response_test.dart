import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_exception.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_response.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> createSupport({
  Object? questions = const <Object?>['どんなふうに見えますか？'],
  Object? perspectives = const <Object?>['という見方もできます。'],
  Object? possibilities = const <Object?>['という可能性もあります。'],
}) {
  return <String, Object?>{
    'questions': questions,
    'perspectives': perspectives,
    'possibilities': possibilities,
  };
}

Map<String, Object?> createJson({
  Object? requestId = 'thinking-1',
  Object? contractVersion = 'v1',
  Object? support,
}) {
  return <String, Object?>{
    'requestId': requestId,
    'contractVersion': contractVersion,
    'support': support ?? createSupport(),
  };
}

Matcher get throwsInvalidResponse {
  return throwsA(
    isA<AiThinkingGatewayException>().having(
      (error) => error.failure,
      'failure',
      AiThinkingGatewayFailure.invalidResponse,
    ),
  );
}

void main() {
  group('AiThinkingGatewayResponse 組み立て', () {
    test('取り決めどおりなら組み立てられる', () {
      final response = AiThinkingGatewayResponse(
        requestId: 'thinking-1',
        contractVersion: 'v1',
        questions: <String>['どんなふうに見えますか？'],
        perspectives: <String>[],
        possibilities: <String>[],
      );

      expect(response.requestId, 'thinking-1');
      expect(response.hasAnySupport, isTrue);
    });

    test('知らない版を名乗る答えは、組み立てそのものができない', () {
      expect(
        () => AiThinkingGatewayResponse(
          requestId: 'thinking-1',
          contractVersion: 'v2',
          questions: <String>['どんなふうに見えますか？'],
          perspectives: <String>[],
          possibilities: <String>[],
        ),
        throwsInvalidResponse,
      );
    });

    test('requestIdが空の答えは、組み立てそのものができない', () {
      expect(
        () => AiThinkingGatewayResponse(
          requestId: '  ',
          contractVersion: 'v1',
          questions: <String>['どんなふうに見えますか？'],
          perspectives: <String>[],
          possibilities: <String>[],
        ),
        throwsInvalidResponse,
      );
    });

    test('空の手がかりを含む答えも、組み立てそのものができない', () {
      expect(
        () => AiThinkingGatewayResponse(
          requestId: 'thinking-1',
          contractVersion: 'v1',
          questions: <String>['どんなふうに見えますか？'],
          perspectives: <String>['   '],
          possibilities: <String>[],
        ),
        throwsInvalidResponse,
      );
    });

    test('3つとも空の一覧でも組み立てられる', () {
      final response = AiThinkingGatewayResponse(
        requestId: 'thinking-1',
        contractVersion: 'v1',
        questions: <String>[],
        perspectives: <String>[],
        possibilities: <String>[],
      );

      // 形としては正しい。使えるかどうかは、この先の境界で判断する。
      expect(response.hasAnySupport, isFalse);
    });
  });

  group('AiThinkingGatewayResponse.fromJson', () {
    test('取り決めどおりの内容を読める', () {
      final response = AiThinkingGatewayResponse.fromJson(createJson());

      expect(response.requestId, 'thinking-1');
      expect(response.contractVersion, 'v1');
      expect(response.questions, <String>['どんなふうに見えますか？']);
      expect(response.perspectives, <String>['という見方もできます。']);
      expect(response.possibilities, <String>['という可能性もあります。']);
      expect(response.hasAnySupport, isTrue);
    });

    test('一部が空の一覧でも、ほかに材料があれば読める', () {
      final response = AiThinkingGatewayResponse.fromJson(
        createJson(
          support: createSupport(
            questions: const <Object?>[],
            perspectives: const <Object?>[],
          ),
        ),
      );

      expect(response.questions, isEmpty);
      expect(response.perspectives, isEmpty);
      expect(response.possibilities, <String>['という可能性もあります。']);
      expect(response.hasAnySupport, isTrue);
    });

    test('3つとも空の一覧なら、材料がないと分かる形で読める', () {
      final response = AiThinkingGatewayResponse.fromJson(
        createJson(
          support: createSupport(
            questions: const <Object?>[],
            perspectives: const <Object?>[],
            possibilities: const <Object?>[],
          ),
        ),
      );

      expect(response.hasAnySupport, isFalse);
    });

    test('読み取った一覧は書き換えられない', () {
      final response = AiThinkingGatewayResponse.fromJson(createJson());

      expect(response.questions.clear, throwsUnsupportedError);
    });

    test('入れ物の形が違う場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson('壊れた内容'),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(null),
        throwsInvalidResponse,
      );
    });

    test('requestIdが無い、または空の場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(createJson(requestId: null)),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(createJson(requestId: '  ')),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(createJson(requestId: 7)),
        throwsInvalidResponse,
      );
    });

    test('知らない版の内容は、当てずっぽうで解釈しない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(contractVersion: 'v2'),
        ),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(contractVersion: null),
        ),
        throwsInvalidResponse,
      );
    });

    test('材料の入れ物が無い場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(createJson(support: '材料')),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(<String, Object?>{
          'requestId': 'thinking-1',
          'contractVersion': 'v1',
        }),
        throwsInvalidResponse,
      );
    });

    test('問い・別の見方・可能性のどれかが無い答えは読まない', () {
      const keys = <String>['questions', 'perspectives', 'possibilities'];

      for (final missing in keys) {
        final support = createSupport()..remove(missing);

        final json = createJson(support: support);

        expect(
          () => AiThinkingGatewayResponse.fromJson(json),
          throwsInvalidResponse,
          reason: '$missing が無い答えは取り決め違反',
        );
      }
    });

    test('問い・別の見方・可能性のどれかがnullの答えは読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(support: createSupport(questions: null)),
        ),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(support: createSupport(perspectives: null)),
        ),
        throwsInvalidResponse,
      );
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(support: createSupport(possibilities: null)),
        ),
        throwsInvalidResponse,
      );
    });

    test('一覧でないものが入っていた場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(support: createSupport(questions: 'どんなふうに見えますか？')),
        ),
        throwsInvalidResponse,
      );
    });

    test('文字ではないものが混ざっていた場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(
            support: createSupport(
              questions: const <Object?>['どんなふうに見えますか？', 42],
            ),
          ),
        ),
        throwsInvalidResponse,
      );
    });

    test('空の手がかりが混ざっていた場合は読まない', () {
      expect(
        () => AiThinkingGatewayResponse.fromJson(
          createJson(
            support: createSupport(
              perspectives: const <Object?>['という見方もできます。', '   '],
            ),
          ),
        ),
        throwsInvalidResponse,
      );
    });

    test('気づきの本文や点数を受け取る場所を持たない', () {
      final support = createSupport()
        ..addAll(<String, Object?>{
          // 取り決めにない項目は、読み取っても保持しない。
          'insightText': '休むことも前に進むために必要。',
          'confidenceScore': 0.9,
          'nextAction': '明日は30分歩く',
          'provider': 'some-provider',
          'model': 'some-model',
        });

      final response = AiThinkingGatewayResponse.fromJson(
        createJson(support: support),
      );

      expect(response.questions, <String>['どんなふうに見えますか？']);
      expect(response.perspectives, <String>['という見方もできます。']);
      expect(response.possibilities, <String>['という可能性もあります。']);
      expect(response.toString().contains('休むことも前に進むために必要。'), isFalse);
    });
  });
}
