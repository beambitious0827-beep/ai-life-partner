/// 一緒に考えることが、なぜできなかったか。
///
/// 通信やproviderの事情をそのまま外へ出さないための、共通の言い方である。
/// Presentationはこの種類だけを見る。providerの文言には触れない。
enum ReflectionThinkingFailure {
  /// 待てる時間を過ぎた。
  timeout,

  /// 呼び出す資格が確認できなかった。
  unauthorized,

  /// 短い間に頼みすぎた。
  rateLimited,

  /// いまは応えられなかった。
  unavailable,

  /// 返ってきた内容が、取り決めどおりではなかった。
  invalidResponse,

  /// 上のどれとも言えない。
  unknown,
}

/// 考える材料を受け取れなかったことを表す。
///
/// メッセージ本文を持たないのは意図的である。
/// Humanが書いた言葉も、providerの内部情報も、ここには入らない。
class ReflectionThinkingException implements Exception {
  const ReflectionThinkingException(this.failure);

  final ReflectionThinkingFailure failure;

  @override
  String toString() {
    return 'ReflectionThinkingException(${failure.name})';
  }
}
