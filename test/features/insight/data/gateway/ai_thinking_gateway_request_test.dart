import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_contract.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_request.dart';
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
  group('AiThinkingGatewayRequest', () {
    test('考える材料の頼みごとから、送ってよい範囲だけを写し取る', () {
      final request = AiThinkingGatewayRequest.fromThinkingRequest(
        ReflectionThinkingRequest.fromReflection(
          createReflectionEntry(id: 'reflection-42'),
        ),
        requestId: 'thinking-1',
      );

      expect(request.requestId, 'thinking-1');
      expect(request.contractVersion, AiThinkingGatewayContract.version);
      expect(request.reflectionEntryId, 'reflection-42');
      expect(request.feelingText, '思ったより疲れていた');
      expect(request.noticedText, '休んだことで少し気持ちが軽くなった');
    });

    test('感じたことだけの振り返りでも組み立てられる', () {
      final request = AiThinkingGatewayRequest.fromThinkingRequest(
        ReflectionThinkingRequest.fromReflection(
          createReflectionEntry(noticedText: null),
        ),
        requestId: 'thinking-1',
      );

      expect(request.feelingText, '思ったより疲れていた');
      expect(request.noticedText, isNull);
    });

    test('気づいたことだけの振り返りでも組み立てられる', () {
      final request = AiThinkingGatewayRequest.fromThinkingRequest(
        ReflectionThinkingRequest.fromReflection(
          createReflectionEntry(feelingText: null),
        ),
        requestId: 'thinking-1',
      );

      expect(request.feelingText, isNull);
      expect(request.noticedText, '休んだことで少し気持ちが軽くなった');
    });

    test('送る形は、取り決めどおりの入れ物になる', () {
      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-42',
        feelingText: '思ったより疲れていた',
        noticedText: '休んだことで少し気持ちが軽くなった',
      );

      expect(request.toJson(), <String, Object?>{
        'requestId': 'thinking-1',
        'contractVersion': 'v1',
        'reflectionEntryId': 'reflection-42',
        'reflection': <String, Object?>{
          'feelingText': '思ったより疲れていた',
          'noticedText': '休んだことで少し気持ちが軽くなった',
        },
      });
    });

    test('書かれていない項目はnullのまま送る', () {
      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-42',
        feelingText: '思ったより疲れていた',
      );

      final reflection = request.toJson()['reflection'];

      expect(reflection, isA<Map<String, Object?>>());
      expect((reflection! as Map<String, Object?>)['noticedText'], isNull);
    });

    test('送る項目はこの5つだけで、Human IDも歩みも含まない', () {
      final request = AiThinkingGatewayRequest.fromThinkingRequest(
        ReflectionThinkingRequest.fromReflection(
          createReflectionEntry(humanId: 'local-human', journeyEntryId: 'j-99'),
        ),
        requestId: 'thinking-1',
      );

      final json = request.toJson();

      expect(json.keys.toSet(), <String>{
        'requestId',
        'contractVersion',
        'reflectionEntryId',
        'reflection',
      });

      final reflection = json['reflection']! as Map<String, Object?>;

      expect(reflection.keys.toSet(), <String>{'feelingText', 'noticedText'});

      // 誰の振り返りかも、どの歩みかも、送る内容には現れない。
      expect(json.toString().contains('humanId'), isFalse);
      expect(json.toString().contains('local-human'), isFalse);
      expect(json.toString().contains('journeyEntryId'), isFalse);
      expect(json.toString().contains('j-99'), isFalse);
    });

    test('requestIdが空の場合は組み立てられない', () {
      expect(
        () => AiThinkingGatewayRequest(
          requestId: '  ',
          reflectionEntryId: 'reflection-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('もとになる振り返りのIDが空の場合は組み立てられない', () {
      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('取り決めの版が空の場合は組み立てられない', () {
      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
          contractVersion: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
