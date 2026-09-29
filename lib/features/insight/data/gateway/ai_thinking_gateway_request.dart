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
///
/// 取り決めはこの型だけで満たす。
/// 呼び出し元が先に確かめているはず、という前提を置かない。
/// serverが断るものは、ここでも組み立てられないようにしておく。
///
/// 長さはUTF-16 code unit（Dartの `String.length`）で数える。
/// server側のJavaScript `String.length` と同じ数え方である。
/// 字の見た目の数ではないので、絵文字ひとつは2になることがある。
class AiThinkingGatewayRequest {
  AiThinkingGatewayRequest({
    required this.requestId,
    required this.reflectionEntryId,
    this.contractVersion = AiThinkingGatewayContract.version,
    this.feelingText,
    this.noticedText,
  }) {
    // 長さも形も、前後の空白を落とす前のそのままの値へ当てる。
    // 落としてから確かめると、空白を含むIDが通ってしまう。
    if (requestId.length > AiThinkingGatewayContract.maxRequestIdLength) {
      throw ArgumentError.value(requestId, 'requestId', 'requestIdが長すぎます。');
    }

    if (!AiThinkingGatewayContract.requestIdPattern.hasMatch(requestId)) {
      throw ArgumentError.value(
        requestId,
        'requestId',
        'requestIdに使える文字は英数字と - _ だけです。',
      );
    }

    if (contractVersion.trim().isEmpty) {
      throw ArgumentError.value(
        contractVersion,
        'contractVersion',
        'contractVersionは空にできません。',
      );
    }

    if (reflectionEntryId.length >
        AiThinkingGatewayContract.maxReflectionEntryIdLength) {
      throw ArgumentError.value(
        reflectionEntryId,
        'reflectionEntryId',
        'もとになる振り返りのIDが長すぎます。',
      );
    }

    if (reflectionEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        reflectionEntryId,
        'reflectionEntryId',
        'もとになる振り返りのIDは空にできません。',
      );
    }

    // 長さを見るのは空白を落とす前。
    // 落としてから見ると、空白だけの4001文字が0文字として通ってしまう。
    if (_isTooLong(feelingText)) {
      throw ArgumentError.value(feelingText, 'feelingText', '感じたことが長すぎます。');
    }

    if (_isTooLong(noticedText)) {
      throw ArgumentError.value(noticedText, 'noticedText', '気づいたことが長すぎます。');
    }

    if (!_hasText(feelingText) && !_hasText(noticedText)) {
      throw ArgumentError('一緒に考えるための言葉がありません。');
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

  static bool _isTooLong(String? value) {
    return value != null &&
        value.length > AiThinkingGatewayContract.maxReflectionTextLength;
  }

  /// 空白だけの値は、書かれていないものとして扱う。
  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

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
