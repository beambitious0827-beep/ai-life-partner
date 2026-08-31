/// server側の窓口とのやり取りが、なぜ終わらなかったか。
///
/// providerの名前も、providerが返した文言も持たない。
/// Humanへ見せる言葉は、Presentationが自分の言葉で決める。
enum AiThinkingGatewayFailure {
  /// 待てる時間を過ぎた。
  timeout,

  /// 呼び出す資格が確認できなかった。
  unauthorized,

  /// 短い間に頼みすぎた。
  rateLimited,

  /// 窓口へ届かなかった、または窓口が応えられなかった。
  unavailable,

  /// 返ってきた内容が、取り決めどおりではなかった。
  invalidResponse,

  /// 上のどれとも言えない。
  unknown,
}

/// server側の窓口とのやり取りが終わらなかったことを表す。
///
/// メッセージ本文を持たないのは意図的である。
/// 例外がそのままログへ流れても、Humanが書いた言葉が漏れないようにする。
class AiThinkingGatewayException implements Exception {
  const AiThinkingGatewayException(this.failure, {this.requestId});

  final AiThinkingGatewayFailure failure;

  /// 追跡のためのID。Humanの言葉は含まない。
  final String? requestId;

  @override
  String toString() {
    return 'AiThinkingGatewayException('
        '${failure.name}, requestId: $requestId)';
  }
}
