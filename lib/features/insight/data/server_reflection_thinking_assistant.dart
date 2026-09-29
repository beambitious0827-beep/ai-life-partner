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
    // 追跡IDを作るのは、組み立ての確認とは別の仕事である。
    // ここで作っておき、tryの中では確認だけを行う。
    // 同じtryへ入れると、factory自身の失敗まで
    // 「取り決めに合わなかった」として扱ってしまう。
    final requestId = _requestIdFactory();

    // 送る形を組み立てるところにも、取り決めの確認がある。
    // 取り決めに合わないものは、窓口まで行かずにここで止まる。
    //
    // この境界を狭く囲うのは、包む範囲を広げると、
    // 通信より手前のプログラムの誤りまで unknown に飲み込んでしまうためである。
    // ここで受け取るのは、組み立ての確認が投げる ArgumentError だけにする。
    //
    // Gatewayの上限（長さや形）は通信の境界の取り決めであり、
    // Domain側の ReflectionThinkingRequest へは移さない。
    final AiThinkingGatewayRequest gatewayRequest;

    try {
      gatewayRequest = AiThinkingGatewayRequest.fromThinkingRequest(
        request,
        requestId: requestId,
      );
    } on ArgumentError catch (_) {
      // 何が長すぎたかは外へ出さない。Humanの言葉が混ざるためである。
      throw const ReflectionThinkingException(
        ReflectionThinkingFailure.unknown,
      );
    }

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
