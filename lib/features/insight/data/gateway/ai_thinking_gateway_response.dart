import 'ai_thinking_gateway_contract.dart';
import 'ai_thinking_gateway_exception.dart';

/// server側の窓口から返ってくる内容。
///
/// 返ってくるのは、Humanが考えるための材料だけである。
/// 気づきの本文・最終的な答え・点数・診断・確信度・次の行動は受け取らない。
///
/// 取り決めを満たさない内容からは、この型を作れない。
/// [fromJson] を通しても、直接組み立てても、確かめる内容は同じである。
/// 通信の実装がこの先増えても、取り決め違反がそのまま画面まで届かないようにする。
///
/// 満たすべきこと：
/// - requestIdが空でないこと
/// - contractVersionが読める版であること
/// - 問い・別の見方・可能性の3つがそろっていること（それぞれ空の一覧は可）
/// - 各項目が、空でない文字列であること
class AiThinkingGatewayResponse {
  AiThinkingGatewayResponse({
    required this.requestId,
    required this.contractVersion,
    required List<String> questions,
    required List<String> perspectives,
    required List<String> possibilities,
  }) : questions = List<String>.unmodifiable(questions),
       perspectives = List<String>.unmodifiable(perspectives),
       possibilities = List<String>.unmodifiable(possibilities) {
    if (requestId.trim().isEmpty) {
      throw const AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
      );
    }

    // 読めない版の内容は、当てずっぽうで解釈しない。
    if (contractVersion != AiThinkingGatewayContract.version) {
      throw AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
        requestId: requestId,
      );
    }

    for (final line in <String>[
      ...this.questions,
      ...this.perspectives,
      ...this.possibilities,
    ]) {
      if (line.trim().isEmpty) {
        throw AiThinkingGatewayException(
          AiThinkingGatewayFailure.invalidResponse,
          requestId: requestId,
        );
      }
    }
  }

  /// 受け取った内容を、確かめながら読む。
  ///
  /// 形が違えば [AiThinkingGatewayException] を投げる。
  /// 未確認のまま画面へ流さないための境界である。
  ///
  /// 問い・別の見方・可能性の3つは、取り決め上どれも省略できない。
  /// 「空の一覧」と「項目がない」は違うものとして扱う。
  factory AiThinkingGatewayResponse.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
      );
    }

    final requestId = json['requestId'];

    if (requestId is! String) {
      throw const AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
      );
    }

    final contractVersion = json['contractVersion'];

    if (contractVersion is! String) {
      throw AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
        requestId: requestId,
      );
    }

    final support = json['support'];

    if (support is! Map<String, Object?>) {
      throw AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
        requestId: requestId,
      );
    }

    return AiThinkingGatewayResponse(
      requestId: requestId,
      contractVersion: contractVersion,
      questions: _readLines(support['questions'], requestId),
      perspectives: _readLines(support['perspectives'], requestId),
      possibilities: _readLines(support['possibilities'], requestId),
    );
  }

  /// 一覧をひとつ読む。
  ///
  /// 項目そのものが無い場合も、nullの場合も、取り決め違反として断る。
  /// 空の一覧は、材料がなかったという答えとして受け取る。
  static List<String> _readLines(Object? value, String requestId) {
    if (value is! List<Object?>) {
      throw AiThinkingGatewayException(
        AiThinkingGatewayFailure.invalidResponse,
        requestId: requestId,
      );
    }

    final lines = <String>[];

    for (final line in value) {
      if (line is! String || line.trim().isEmpty) {
        throw AiThinkingGatewayException(
          AiThinkingGatewayFailure.invalidResponse,
          requestId: requestId,
        );
      }

      lines.add(line);
    }

    return lines;
  }

  final String requestId;
  final String contractVersion;

  final List<String> questions;
  final List<String> perspectives;
  final List<String> possibilities;

  /// 考える材料がひとつでもあるかどうか。
  ///
  /// ひとつもないものを成功として画面に出すと、
  /// 何も書かれていないAIの欄をHumanに見せることになる。
  bool get hasAnySupport {
    return questions.isNotEmpty ||
        perspectives.isNotEmpty ||
        possibilities.isNotEmpty;
  }
}
