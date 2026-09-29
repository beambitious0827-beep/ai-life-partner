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
          feelingText: '思ったより疲れていた',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Flutterが作る追跡IDの形は、そのまま通る', () {
      // ServerReflectionThinkingAssistant.generateRequestId() が作る形。
      //   'thinking-${DateTime.now().microsecondsSinceEpoch}-$_idSequence'
      for (final requestId in <String>[
        'thinking-1786991056963000-1',
        'thinking-1790278503609123-42',
        'thinking-0-0',
      ]) {
        final request = AiThinkingGatewayRequest(
          requestId: requestId,
          reflectionEntryId: 'reflection-1',
          feelingText: '思ったより疲れていた',
        );

        expect(request.requestId, requestId);
        expect(
          requestId.length,
          lessThanOrEqualTo(AiThinkingGatewayContract.maxRequestIdLength),
        );
      }
    });

    test('追跡IDは64文字まで受け取る', () {
      final requestId = 'a' * AiThinkingGatewayContract.maxRequestIdLength;

      expect(requestId.length, 64);

      final request = AiThinkingGatewayRequest(
        requestId: requestId,
        reflectionEntryId: 'reflection-1',
        feelingText: '思ったより疲れていた',
      );

      expect(request.requestId, requestId);
    });

    test('追跡IDが65文字なら組み立てられない', () {
      final requestId =
          'a' * (AiThinkingGatewayContract.maxRequestIdLength + 1);

      expect(requestId.length, 65);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: requestId,
          reflectionEntryId: 'reflection-1',
          feelingText: '思ったより疲れていた',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('追跡IDに使えない文字が混じっていたら組み立てられない', () {
      for (final requestId in <String>[
        'thinking/1',
        'thinking.1',
        'thinking:1',
        'thinking+1',
        'thinking#1',
        '振り返り-1',
        '<script>',
      ]) {
        expect(
          () => AiThinkingGatewayRequest(
            requestId: requestId,
            reflectionEntryId: 'reflection-1',
            feelingText: '思ったより疲れていた',
          ),
          throwsA(isA<ArgumentError>()),
          reason: requestId,
        );
      }
    });

    test('追跡IDは、空白を落とさずそのままの形で確かめる', () {
      // 落としてから確かめると、空白を含むIDが通ってしまう。
      // 通ったIDは、server側の応答とログへそのまま載る値でもある。
      for (final requestId in <String>[
        '  thinking-1  ',
        ' thinking-1',
        'thinking-1 ',
        'thinking 1',
        '\tthinking-1',
        'thinking-1\n',
      ]) {
        expect(
          () => AiThinkingGatewayRequest(
            requestId: requestId,
            reflectionEntryId: 'reflection-1',
            feelingText: '思ったより疲れていた',
          ),
          throwsA(isA<ArgumentError>()),
          reason: requestId,
        );
      }
    });

    test('振り返りのIDは128文字まで受け取る', () {
      final reflectionEntryId =
          'r' * AiThinkingGatewayContract.maxReflectionEntryIdLength;

      expect(reflectionEntryId.length, 128);

      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: reflectionEntryId,
        feelingText: '思ったより疲れていた',
      );

      expect(request.reflectionEntryId, reflectionEntryId);
    });

    test('振り返りのIDが129文字なら組み立てられない', () {
      final reflectionEntryId =
          'r' * (AiThinkingGatewayContract.maxReflectionEntryIdLength + 1);

      expect(reflectionEntryId.length, 129);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: reflectionEntryId,
          feelingText: '思ったより疲れていた',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('振り返りのIDは、空白を落として空なら組み立てられない', () {
      for (final reflectionEntryId in <String>['', '   ', '\t\n']) {
        expect(
          () => AiThinkingGatewayRequest(
            requestId: 'thinking-1',
            reflectionEntryId: reflectionEntryId,
            feelingText: '思ったより疲れていた',
          ),
          throwsA(isA<ArgumentError>()),
          reason: reflectionEntryId,
        );
      }
    });

    test('振り返りのIDに形の制限は加えない', () {
      // Phase 12では長さと非空だけを見る。server側も同じ。
      const reflectionEntryId = 'reflection/2026-09-28#1';

      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: reflectionEntryId,
        feelingText: '思ったより疲れていた',
      );

      expect(request.reflectionEntryId, reflectionEntryId);
    });

    test('感じたことは4000文字まで受け取る', () {
      final feelingText =
          'あ' * AiThinkingGatewayContract.maxReflectionTextLength;

      expect(feelingText.length, 4000);

      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        feelingText: feelingText,
      );

      expect(request.feelingText?.length, 4000);
    });

    test('感じたことが4001文字なら組み立てられない', () {
      final feelingText =
          'あ' * (AiThinkingGatewayContract.maxReflectionTextLength + 1);

      expect(feelingText.length, 4001);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
          feelingText: feelingText,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('気づいたことは4000文字まで受け取る', () {
      final noticedText =
          'い' * AiThinkingGatewayContract.maxReflectionTextLength;

      expect(noticedText.length, 4000);

      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        noticedText: noticedText,
      );

      expect(request.noticedText?.length, 4000);
    });

    test('気づいたことが4001文字なら組み立てられない', () {
      final noticedText =
          'い' * (AiThinkingGatewayContract.maxReflectionTextLength + 1);

      expect(noticedText.length, 4001);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
          noticedText: noticedText,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('空白だけの4001文字も、空白を落とす前に断る', () {
      // 落としてから長さを見ると、4001文字が0文字として通ってしまう。
      final feelingText =
          ' ' * (AiThinkingGatewayContract.maxReflectionTextLength + 1);

      expect(feelingText.length, 4001);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
          feelingText: feelingText,
          noticedText: '気づいたこと',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('感じたことだけでも組み立てられる', () {
      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        feelingText: '思ったより疲れていた',
      );

      expect(request.feelingText, '思ったより疲れていた');
      expect(request.noticedText, isNull);
    });

    test('気づいたことだけでも組み立てられる', () {
      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        noticedText: '少し気持ちが軽くなった',
      );

      expect(request.feelingText, isNull);
      expect(request.noticedText, '少し気持ちが軽くなった');
    });

    test('どちらも書かれていなければ組み立てられない', () {
      // 上流のReflectionThinkingRequestに頼らず、この型だけで断る。
      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('どちらも空、または空白だけなら組み立てられない', () {
      for (final pair in <List<String>>[
        <String>['', ''],
        <String>['   ', '\t\n'],
        <String>['', '  '],
      ]) {
        expect(
          () => AiThinkingGatewayRequest(
            requestId: 'thinking-1',
            reflectionEntryId: 'reflection-1',
            feelingText: pair[0],
            noticedText: pair[1],
          ),
          throwsA(isA<ArgumentError>()),
          reason: pair.toString(),
        );
      }
    });

    test('長さはUTF-16 code unitで数える', () {
      // 絵文字ひとつは、見た目は1文字でもcode unitでは2になる。
      // server側のJavaScript String.length と同じ数え方である。
      const emoji = '😀';

      expect(emoji.length, 2);

      final justFits =
          emoji * (AiThinkingGatewayContract.maxReflectionTextLength ~/ 2);

      expect(justFits.length, 4000);

      final fitting = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        feelingText: justFits,
      );

      expect(fitting.feelingText?.length, 4000);

      // 絵文字をひとつ足すと4002になり、上限を超える。
      final tooLong = justFits + emoji;

      expect(tooLong.length, 4002);
      // 見た目は2001文字。code unitで数えていなければ、これは通ってしまう。
      expect(tooLong.runes.length, 2001);

      expect(
        () => AiThinkingGatewayRequest(
          requestId: 'thinking-1',
          reflectionEntryId: 'reflection-1',
          feelingText: tooLong,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('送る形に、余分な項目は入らない', () {
      final request = AiThinkingGatewayRequest(
        requestId: 'thinking-1',
        reflectionEntryId: 'reflection-1',
        feelingText: '思ったより疲れていた',
      );

      final json = request.toJson();
      final serialized = json.toString();

      for (final forbidden in <String>[
        'humanId',
        'jwt',
        'token',
        'authorization',
        'provider',
        'model',
        'systemPrompt',
        'profile',
        'insight',
        'journey',
        'calendar',
      ]) {
        expect(
          serialized.toLowerCase().contains(forbidden.toLowerCase()),
          isFalse,
          reason: forbidden,
        );
      }
    });
  });
}
