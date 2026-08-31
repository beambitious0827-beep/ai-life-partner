import 'dart:async';

import 'package:ai_life_partner/features/insight/data/demo_reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_client.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_contract.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_exception.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_request.dart';
import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_response.dart';
import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/data/server_reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_request.dart';
import 'package:ai_life_partner/features/insight/domain/services/reflection_thinking_exception.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

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

AiThinkingGatewayResponse createResponse(
  AiThinkingGatewayRequest request, {
  String? requestId,
  List<String> questions = const <String>['どんなふうに見えますか？'],
  List<String> perspectives = const <String>['という見方もできます。'],
  List<String> possibilities = const <String>['という可能性もあります。'],
}) {
  return AiThinkingGatewayResponse(
    requestId: requestId ?? request.requestId,
    contractVersion: AiThinkingGatewayContract.version,
    questions: questions,
    perspectives: perspectives,
    possibilities: possibilities,
  );
}

Matcher throwsThinkingFailure(ReflectionThinkingFailure failure) {
  return throwsA(
    isA<ReflectionThinkingException>().having(
      (error) => error.failure,
      'failure',
      failure,
    ),
  );
}

/// 受け取った内容を記録する、通信のない窓口。
///
/// 実際の通信実装はまだない。ここでは何が外へ出るのかだけを確かめる。
class RecordingGatewayClient implements AiThinkingGatewayClient {
  RecordingGatewayClient({this.respond, this.failure, this.error});

  /// 返す内容を組み立てる。省略した場合は、頼まれたIDで正しい形を返す。
  final AiThinkingGatewayResponse Function(AiThinkingGatewayRequest)? respond;

  /// 窓口としての失敗。
  final AiThinkingGatewayFailure? failure;

  /// 窓口の取り決めにない、思いがけない失敗。
  final Object? error;

  final List<AiThinkingGatewayRequest> receivedRequests =
      <AiThinkingGatewayRequest>[];

  int get callCount => receivedRequests.length;

  @override
  Future<AiThinkingGatewayResponse> requestSupport(
    AiThinkingGatewayRequest request,
  ) async {
    receivedRequests.add(request);

    final error = this.error;

    if (error != null) {
      throw error;
    }

    final failure = this.failure;

    if (failure != null) {
      throw AiThinkingGatewayException(failure, requestId: request.requestId);
    }

    final respond = this.respond;

    return respond == null ? createResponse(request) : respond(request);
  }
}

/// 取り決めにない版を名乗る答え。
///
/// 窓口の実装はこの先増えうる。
/// 型どおりに返ってきても、取り決めの外にある答えは受け取らないことを確かめる。
class UnknownVersionResponse implements AiThinkingGatewayResponse {
  UnknownVersionResponse(this.requestId);

  @override
  final String requestId;

  @override
  String get contractVersion => 'v2';

  @override
  List<String> get questions => const <String>['どんなふうに見えますか？'];

  @override
  List<String> get perspectives => const <String>['という見方もできます。'];

  @override
  List<String> get possibilities => const <String>['という可能性もあります。'];

  @override
  bool get hasAnySupport => true;
}

/// いつまでも答えない窓口。待ち続けないことを確かめるために使う。
class NeverAnsweringGatewayClient implements AiThinkingGatewayClient {
  final Completer<AiThinkingGatewayResponse> _completer =
      Completer<AiThinkingGatewayResponse>();

  int callCount = 0;

  @override
  Future<AiThinkingGatewayResponse> requestSupport(
    AiThinkingGatewayRequest request,
  ) {
    callCount += 1;

    return _completer.future;
  }
}

void main() {
  group('ServerReflectionThinkingAssistant', () {
    test('デモではないと名乗る', () {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(),
      );

      expect(assistant.isDemo, isFalse);
    });

    test('窓口から受け取った材料を、そのまま考える手がかりとして返す', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(),
      );

      final support = await assistant.support(createRequest());

      expect(support.questions, <String>['どんなふうに見えますか？']);
      expect(support.perspectives, <String>['という見方もできます。']);
      expect(support.possibilities, <String>['という可能性もあります。']);
    });

    test('窓口へ渡すのは、選ばれた振り返りの言葉だけ', () async {
      final client = RecordingGatewayClient();

      final assistant = ServerReflectionThinkingAssistant(
        client: client,
        requestIdFactory: () => 'thinking-1',
      );

      await assistant.support(
        createRequest(
          reflectionEntryId: 'reflection-42',
          feelingText: '思ったより疲れていた',
          noticedText: '休んだことで少し気持ちが軽くなった',
        ),
      );

      expect(client.callCount, 1);

      final sent = client.receivedRequests.single;

      expect(sent.requestId, 'thinking-1');
      expect(sent.contractVersion, AiThinkingGatewayContract.version);
      expect(sent.reflectionEntryId, 'reflection-42');
      expect(sent.feelingText, '思ったより疲れていた');
      expect(sent.noticedText, '休んだことで少し気持ちが軽くなった');

      expect(sent.toJson().keys.toSet(), <String>{
        'requestId',
        'contractVersion',
        'reflectionEntryId',
        'reflection',
      });
    });

    test('追跡のためのIDに、Humanの言葉を含めない', () async {
      final client = RecordingGatewayClient();

      final assistant = ServerReflectionThinkingAssistant(client: client);

      await assistant.support(
        createRequest(
          reflectionEntryId: 'reflection-42',
          feelingText: 'ひどく落ち込んでいた',
          noticedText: '誰にも会いたくなかった',
        ),
      );

      final requestId = client.receivedRequests.single.requestId;

      expect(requestId, isNotEmpty);
      expect(requestId.contains('ひどく落ち込んでいた'), isFalse);
      expect(requestId.contains('誰にも会いたくなかった'), isFalse);
      expect(requestId.contains('reflection-42'), isFalse);
      expect(requestId.contains(humanId), isFalse);
    });

    test('頼むたびに違う追跡IDになる', () async {
      final client = RecordingGatewayClient();

      final assistant = ServerReflectionThinkingAssistant(client: client);

      await assistant.support(createRequest());
      await assistant.support(createRequest());

      expect(client.callCount, 2);
      expect(
        client.receivedRequests.first.requestId,
        isNot(client.receivedRequests.last.requestId),
      );
    });

    test('窓口の失敗を、共通の言い方へそろえる', () async {
      const pairs = <AiThinkingGatewayFailure, ReflectionThinkingFailure>{
        AiThinkingGatewayFailure.timeout: ReflectionThinkingFailure.timeout,
        AiThinkingGatewayFailure.unauthorized:
            ReflectionThinkingFailure.unauthorized,
        AiThinkingGatewayFailure.rateLimited:
            ReflectionThinkingFailure.rateLimited,
        AiThinkingGatewayFailure.unavailable:
            ReflectionThinkingFailure.unavailable,
        AiThinkingGatewayFailure.invalidResponse:
            ReflectionThinkingFailure.invalidResponse,
        AiThinkingGatewayFailure.unknown: ReflectionThinkingFailure.unknown,
      };

      for (final entry in pairs.entries) {
        final assistant = ServerReflectionThinkingAssistant(
          client: RecordingGatewayClient(failure: entry.key),
        );

        await expectLater(
          assistant.support(createRequest()),
          throwsThinkingFailure(entry.value),
          reason: '${entry.key.name} は ${entry.value.name} として扱う',
        );
      }
    });

    test('思いがけない失敗も、そのままの形では外へ出さない', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(
          error: StateError('provider internal failure detail'),
        ),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.unknown),
      );
    });

    test('待ち続けずに、時間で切り上げる', () async {
      final client = NeverAnsweringGatewayClient();

      final assistant = ServerReflectionThinkingAssistant(
        client: client,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.timeout),
      );

      expect(client.callCount, 1);
    });

    test('別の頼みごとへの答えは受け取らない', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(
          respond: (request) => createResponse(request, requestId: 'other-id'),
        ),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.invalidResponse),
      );
    });

    test('知らない版を名乗る答えは、受け取らない', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(
          respond: (request) => UnknownVersionResponse(request.requestId),
        ),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.invalidResponse),
      );
    });

    test('材料がひとつもない答えは、成功として扱わない', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(
          respond: (request) => createResponse(
            request,
            questions: const <String>[],
            perspectives: const <String>[],
            possibilities: const <String>[],
          ),
        ),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.invalidResponse),
      );
    });

    test('空の手がかりが混ざった答えは、組み立てられずに断られる', () async {
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(
          respond: (request) => createResponse(
            request,
            questions: const <String>['   '],
            perspectives: const <String>[],
            possibilities: const <String>[],
          ),
        ),
      );

      await expectLater(
        assistant.support(createRequest()),
        throwsThinkingFailure(ReflectionThinkingFailure.invalidResponse),
      );
    });

    test('考える材料を頼んでも、何も保存されない', () async {
      final insightRepository = InMemoryInsightRepository();
      final reflectionRepository = InMemoryReflectionRepository();

      // Assistantはそもそもどの保存先も受け取らない。
      final assistant = ServerReflectionThinkingAssistant(
        client: RecordingGatewayClient(),
      );

      await assistant.support(createRequest());

      final now = DateTime.now();
      final rangeStart = DateTime(now.year, now.month, now.day - 1);
      final rangeEnd = DateTime(now.year, now.month, now.day + 1);

      expect(
        await insightRepository.getEntries(
          humanId: humanId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        isEmpty,
      );
      expect(
        await reflectionRepository.getEntries(
          humanId: humanId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        isEmpty,
      );
    });

    test('デモのAssistantは、窓口を呼ばない', () async {
      final client = RecordingGatewayClient();

      const assistant = DemoReflectionThinkingAssistant();

      final support = await assistant.support(createRequest());

      expect(support.questions, isNotEmpty);
      expect(client.callCount, 0);
    });
  });
}
