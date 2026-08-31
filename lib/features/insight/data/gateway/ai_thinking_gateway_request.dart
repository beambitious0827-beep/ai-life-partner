import '../../domain/models/reflection_thinking_request.dart';
import 'ai_thinking_gateway_contract.dart';

/// server側の窓口へ送る内容。
///
/// ReflectionEntryをそのまま送らない。ここに書いてあるものだけを送る。
/// 将来Reflectionへ項目が増えても、この型を変えないかぎり送られない。
///
/// 送らないもの：
/// Humanのプロフィール / AboutYou / Life Projects /
/// 歩みの履歴 / ほかの振り返り / これまでの気づき /
/// カレンダー / 家族 / 健康 / ほかのHumanのデータ。
///
/// humanIdも送らない。
/// 誰の振り返りかをclientの申告で決めてよいことにすると、
/// server側の確認がclientの言い分に頼ることになるためである。
/// 本番では、認証されたserver側の身元からHumanの範囲を決める。
///
/// systemプロンプトも送らない。どう問いかけるかはserver側の責任である。
class AiThinkingGatewayRequest {
  AiThinkingGatewayRequest({
    required this.requestId,
    required this.reflectionEntryId,
    this.contractVersion = AiThinkingGatewayContract.version,
    this.feelingText,
    this.noticedText,
  }) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'requestIdは空にできません。');
    }

    if (contractVersion.trim().isEmpty) {
      throw ArgumentError.value(
        contractVersion,
        'contractVersion',
        'contractVersionは空にできません。',
      );
    }

    if (reflectionEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        reflectionEntryId,
        'reflectionEntryId',
        'もとになる振り返りのIDは空にできません。',
      );
    }
  }

  /// 考える材料の頼みごとから、送ってよい範囲だけを写し取る。
  ///
  /// 写し取る場所をここ1か所に決めておくと、
  /// 何が外へ出るのかを後から読み直せる。
  factory AiThinkingGatewayRequest.fromThinkingRequest(
    ReflectionThinkingRequest request, {
    required String requestId,
  }) {
    return AiThinkingGatewayRequest(
      requestId: requestId,
      reflectionEntryId: request.reflectionEntryId,
      feelingText: request.feelingText,
      noticedText: request.noticedText,
    );
  }

  /// 追跡のためのID。Humanの名前も連絡先も振り返り本文も含めない。
  final String requestId;

  final String contractVersion;

  final String reflectionEntryId;

  final String? feelingText;

  final String? noticedText;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'contractVersion': contractVersion,
      'reflectionEntryId': reflectionEntryId,
      'reflection': <String, Object?>{
        'feelingText': feelingText,
        'noticedText': noticedText,
      },
    };
  }
}
