import 'dart:async';

import '../domain/models/reflection_thinking_request.dart';
import '../domain/models/reflection_thinking_support.dart';
import '../domain/services/reflection_thinking_assistant.dart';
import '../domain/services/reflection_thinking_exception.dart';
import 'gateway/ai_thinking_gateway_client.dart';
import 'gateway/ai_thinking_gateway_contract.dart';
import 'gateway/ai_thinking_gateway_exception.dart';
import 'gateway/ai_thinking_gateway_request.dart';
import 'gateway/ai_thinking_gateway_response.dart';

/// server側の窓口を通して、考える材料を受け取るAssistant。
///
/// 責務はこれだけ。
///
///     考える材料の頼みごと
///       → server側の窓口
///       → 考える材料
///
/// 持たないもの：
/// providerの鍵 / provider SDK / systemプロンプト /
/// InsightRepository / ReflectionRepository / 保存の責務。
///
/// 気づきを作ることも、残すこともしない。
/// 気づきを決めるのはいつでもHumanで、保存はHumanの操作だけで起きる。
class ServerReflectionThinkingAssistant implements ReflectionThinkingAssistant {
  ServerReflectionThinkingAssistant({
    required this.client,
    String Function()? requestIdFactory,
    this.timeout = AiThinkingGatewayContract.requestTimeout,
  }) : _requestIdFactory = requestIdFactory ?? generateRequestId;

  /// 同じマイクロ秒に頼んでもIDが重ならないようにする。
  static int _idSequence = 0;

  /// 追跡のためだけのID。
  ///
  /// Humanの名前も、連絡先も、振り返りの本文も含めない。
  static String generateRequestId() {
    _idSequence += 1;

    return 'thinking-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }

  final AiThinkingGatewayClient client;

  /// 待ち続けないための上限。既定は取り決めの値。
  final Duration timeout;

  final String Function() _requestIdFactory;

  /// デモではない。ただし、つながる窓口があるかどうかは別の話である。
  ///
  /// 窓口が用意されていなければ、頼んでも失敗として返る。
  /// 失敗をデモへ差し替えて、つながっているように見せることはしない。
  @override
  bool get isDemo => false;

  @override
  Future<ReflectionThinkingSupport> support(
    ReflectionThinkingRequest request,
  ) async {
    final gatewayRequest = AiThinkingGatewayRequest.fromThinkingRequest(
      request,
      requestId: _requestIdFactory(),
    );

    final AiThinkingGatewayResponse response;

    try {
      response = await client.requestSupport(gatewayRequest).timeout(timeout);
    } on AiThinkingGatewayException catch (error) {
      throw ReflectionThinkingException(_normalize(error.failure));
    } on TimeoutException catch (_) {
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.timeout,
      );
    } on Object catch (_) {
      // 通信やproviderの事情を、そのままの形で外へ出さない。
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.unknown,
      );
    }

    // 返ってきた内容を、そのまま信用しない。
    // 別の頼みごとへの答えを、この画面の答えとして扱わない。
    if (response.requestId != gatewayRequest.requestId) {
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.invalidResponse,
      );
    }

    // 読める版かどうかは、答えを組み立てる側でも確かめている。
    // それでもここで確かめ直す。窓口の実装はこの先増えうるので、
    // 取り決めの外にある答えが、この境界を越えないようにする。
    if (response.contractVersion != AiThinkingGatewayContract.version) {
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.invalidResponse,
      );
    }

    // 材料がひとつもないものを、成功として画面に出さない。
    if (!response.hasAnySupport) {
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.invalidResponse,
      );
    }

    try {
      return ReflectionThinkingSupport(
        questions: response.questions,
        perspectives: response.perspectives,
        possibilities: response.possibilities,
      );
    } on ArgumentError catch (_) {
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.invalidResponse,
      );
    }
  }

  ReflectionThinkingFailure _normalize(AiThinkingGatewayFailure failure) {
    switch (failure) {
      case AiThinkingGatewayFailure.timeout:
        return ReflectionThinkingFailure.timeout;
      case AiThinkingGatewayFailure.unauthorized:
        return ReflectionThinkingFailure.unauthorized;
      case AiThinkingGatewayFailure.rateLimited:
        return ReflectionThinkingFailure.rateLimited;
      case AiThinkingGatewayFailure.unavailable:
        return ReflectionThinkingFailure.unavailable;
      case AiThinkingGatewayFailure.invalidResponse:
        return ReflectionThinkingFailure.invalidResponse;
      case AiThinkingGatewayFailure.unknown:
        return ReflectionThinkingFailure.unknown;
    }
  }
}
