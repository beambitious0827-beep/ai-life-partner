import 'ai_thinking_gateway_request.dart';
import 'ai_thinking_gateway_response.dart';

/// AI Life Partnerのserver側の窓口へ、考える材料を頼むための口。
///
/// この先にprovider（OpenAI等）があるかどうかは、Flutterからは見えない。
/// provider名・model名・プロンプト・鍵は、いずれもこちら側に現れない。
/// それらはすべてserver側の責任である。
///
/// 実際の通信を行う実装は、まだこのリポジトリにない。
/// 安全なserver側の窓口ができた時点で、この口へ実装をつなぐ。
///
/// 失敗した場合は [AiThinkingGatewayException] を投げる。
abstract interface class AiThinkingGatewayClient {
  Future<AiThinkingGatewayResponse> requestSupport(
    AiThinkingGatewayRequest request,
  );
}
