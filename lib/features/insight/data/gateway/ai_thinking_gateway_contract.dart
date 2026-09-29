/// AI Life Partnerのserver側の窓口との、取り決め。
///
/// 版・呼び先・待てる長さ・大きさの上限を1か所へ集めておく。
/// 画面や実装のあちこちに同じ数字を書かないようにするため。
///
/// providerの名前もmodel名もここには現れない。
/// どのproviderをどう使うかはserver側の責任であり、
/// Flutterからは「考える材料がほしい」とだけ伝える。
///
/// ここに書いた上限は、server側の
/// `supabase/functions/_shared/limits.ts` と同じ値である。
/// 片方だけ変えると、client側で通ったものがserver側で断られる。
abstract final class AiThinkingGatewayContract {
  /// やり取りの版。増やすときはserver側と合わせる。
  static const String version = 'v1';

  /// 呼び先のSupabase Edge Functionの名前。
  ///
  /// FlutterはURLを組み立てない。
  /// このFunction名をSupabaseのSDKへ渡し、経路の組み立ては任せる。
  ///
  /// `docs/08_AiGatewayDesign.md` に出てくる
  /// `/v1/ai/reflection-thinking` は、Phase 10で境界を説明するために
  /// 書かれた概念上のpathであり、実際に呼ぶ経路ではない。
  /// 実際の経路は `docs/09_SupabaseEdgeRuntimeDesign.md` 4章のとおり、
  /// Supabaseが `functions/v1/<name>` として解決する。
  static const String functionName = 'reflection-thinking';

  /// 待ち続けないための上限。
  ///
  /// Humanを画面の前で無限に待たせない。
  /// 通信実装を追加するときは、その実装側でも同じ上限を守ること。
  static const Duration requestTimeout = Duration(seconds: 30);

  /// 送ってよいbody全体の大きさ。UTF-8のbyte数で数える。
  ///
  /// server側がこの値で断る。
  /// Flutter側での実際のbyte数の確認は、通信実装を足すときに行う。
  /// いまは、どちらの上限も同じ値であることを示すために持っている。
  static const int maxRequestBodyBytes = 32768;

  /// 追跡IDの長さの上限。UTF-16 code unitで数える。
  static const int maxRequestIdLength = 64;

  /// 振り返りのIDの長さの上限。UTF-16 code unitで数える。
  static const int maxReflectionEntryIdLength = 128;

  /// 振り返りの言葉ひとつあたりの長さの上限。UTF-16 code unitで数える。
  static const int maxReflectionTextLength = 4000;

  /// 追跡IDに許す形。
  ///
  /// server側の `REQUEST_ID_PATTERN` と同じ形である。
  /// 前後の空白を落とす前の、そのままの値へ当てる。
  /// 落としてから当てると、空白を含むIDが通ってしまう。
  static final RegExp requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
}
