import 'dart:io';

import 'package:ai_life_partner/features/insight/data/gateway/ai_thinking_gateway_contract.dart';
import 'package:flutter_test/flutter_test.dart';

/// server側の上限が書かれている場所。
///
/// 値がずれていないかを、実際のファイルを読んで確かめる。
const String serverLimitsPath = 'supabase/functions/_shared/limits.ts';

/// Gateway contractが書かれている場所。
const String contractPath =
    'lib/features/insight/data/gateway/ai_thinking_gateway_contract.dart';

String readRepoFile(String path) {
  return File(path).readAsStringSync();
}

void main() {
  group('AiThinkingGatewayContract', () {
    test('やり取りの版はv1', () {
      expect(AiThinkingGatewayContract.version, 'v1');
    });

    test('呼び先はFunction名であり、URLの一部ではない', () {
      expect(AiThinkingGatewayContract.functionName, 'reflection-thinking');

      // URLを組み立てるための断片ではない。SDKへ渡す名前である。
      expect(AiThinkingGatewayContract.functionName.contains('/'), isFalse);
      expect(
        AiThinkingGatewayContract.functionName.startsWith('http'),
        isFalse,
      );
    });

    test('Phase 10の概念上のpathを、呼び先として持っていない', () {
      // `/v1/ai/reflection-thinking` は境界を説明するための書き方であり、
      // 実際に呼ぶ経路ではない。定数として残すと、いつか呼んでしまう。
      final source = readRepoFile(contractPath);

      expect(source.contains("'/v1/ai/reflection-thinking'"), isFalse);
      expect(source.contains('static const String path'), isFalse);
    });

    test('待てる長さの上限は30秒のまま', () {
      expect(
        AiThinkingGatewayContract.requestTimeout,
        const Duration(seconds: 30),
      );
    });

    test('大きさの上限は、server側と同じ値である', () {
      expect(AiThinkingGatewayContract.maxRequestBodyBytes, 32768);
      expect(AiThinkingGatewayContract.maxRequestIdLength, 64);
      expect(AiThinkingGatewayContract.maxReflectionEntryIdLength, 128);
      expect(AiThinkingGatewayContract.maxReflectionTextLength, 4000);
    });

    test('server側のlimits.tsに書かれている値と突き合わせる', () {
      // 片方だけ変えると、client側で通ったものがserver側で断られる。
      final source = readRepoFile(serverLimitsPath);

      expect(
        source.contains(
          'MAX_REQUEST_BODY_BYTES = '
          '${AiThinkingGatewayContract.maxRequestBodyBytes}',
        ),
        isTrue,
      );
      expect(
        source.contains(
          'MAX_REQUEST_ID_LENGTH = '
          '${AiThinkingGatewayContract.maxRequestIdLength}',
        ),
        isTrue,
      );
      expect(
        source.contains(
          'MAX_REFLECTION_ENTRY_ID_LENGTH = '
          '${AiThinkingGatewayContract.maxReflectionEntryIdLength}',
        ),
        isTrue,
      );
      expect(
        source.contains(
          'MAX_REFLECTION_TEXT_LENGTH = '
          '${AiThinkingGatewayContract.maxReflectionTextLength}',
        ),
        isTrue,
      );
    });

    test('追跡IDの形も、server側と同じである', () {
      final source = readRepoFile(serverLimitsPath);

      expect(source.contains(r'/^[A-Za-z0-9_-]{1,64}$/'), isTrue);
      expect(
        AiThinkingGatewayContract.requestIdPattern.pattern,
        r'^[A-Za-z0-9_-]{1,64}$',
      );
    });

    test('形の上限と、長さの上限は食い違っていない', () {
      // 形の中にも64が書かれているので、両方が同じ値であることを確かめる。
      final allowed = 'a' * AiThinkingGatewayContract.maxRequestIdLength;
      final tooLong = 'a' * (AiThinkingGatewayContract.maxRequestIdLength + 1);

      expect(
        AiThinkingGatewayContract.requestIdPattern.hasMatch(allowed),
        isTrue,
      );
      expect(
        AiThinkingGatewayContract.requestIdPattern.hasMatch(tooLong),
        isFalse,
      );
    });
  });
}
