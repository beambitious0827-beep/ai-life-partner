import '../models/reflection_thinking_request.dart';
import '../models/reflection_thinking_support.dart';

/// 振り返りについて、Humanが考えるための材料を返すService。
///
/// Repositoryではない。ここで返るものは記録ではなく、その場限りの手がかりである。
/// そのため保存もしないし、InsightRepositoryへも触れない。
///
///     Reflection
///       → ReflectionThinkingRequest
///       → ReflectionThinkingAssistant
///       → ReflectionThinkingSupport
///       → Humanが読んで考える
///       → Humanが自分の言葉でInsightを書く
///
/// Assistantが気づきを決めることも、保存することもない。
abstract interface class ReflectionThinkingAssistant {
  /// 渡された材料について、考えるための問い・別の見方・可能性を返す。
  ///
  /// 失敗した場合は ReflectionThinkingException を投げる。
  /// 通信やproviderの事情は、そこで共通の言い方へそろえてある。
  /// AIと一緒に考えられないことは、気づきを残せないことを意味しない。
  Future<ReflectionThinkingSupport> support(ReflectionThinkingRequest request);

  /// デモの実装かどうか。
  ///
  /// 本物のAIへつながっているとHumanに誤解させないため、
  /// 画面側がこれを見て、控えめな断り書きを出す。
  bool get isDemo;
}
