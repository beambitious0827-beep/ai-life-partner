/// AI Life Partnerのserver側の窓口との、取り決め。
///
/// 版・場所・待てる長さを1か所へ集めておく。
/// 画面や実装のあちこちに同じ数字を書かないようにするため。
///
/// providerの名前もmodel名もここには現れない。
/// どのproviderをどう使うかはserver側の責任であり、
/// Flutterからは「考える材料がほしい」とだけ伝える。
abstract final class AiThinkingGatewayContract {
  /// やり取りの版。増やすときはserver側と合わせる。
  static const String version = 'v1';

  /// server側の窓口の場所。
  ///
  /// Flutterはprovider APIを直接呼ばない。呼び先は必ずこの窓口だけ。
  static const String path = '/v1/ai/reflection-thinking';

  /// 待ち続けないための上限。
  ///
  /// Humanを画面の前で無限に待たせない。
  /// 通信実装を追加するときは、その実装側でも同じ上限を守ること。
  static const Duration requestTimeout = Duration(seconds: 30);
}
