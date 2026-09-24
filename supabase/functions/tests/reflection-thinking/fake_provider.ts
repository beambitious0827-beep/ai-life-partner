/**
 * テスト用のProvider。
 *
 * 本番の配線では使わない。
 * Providerが未設定のとき、これへ黙って切り替えることはしない。
 */

import type {
  AiThinkingProvider,
  AiThinkingProviderInput,
  AiThinkingProviderResult,
} from "../../reflection-thinking/provider.ts";

export const defaultResult: AiThinkingProviderResult = {
  questions: ["どんなふうに見えますか？"],
  perspectives: ["という見方もできます。"],
  possibilities: ["という可能性もあります。"],
};

/**
 * 受け取った材料を記録するProvider。
 *
 * 何が渡ったのかを、そのままテストから確かめられるようにしてある。
 */
export class FakeAiThinkingProvider implements AiThinkingProvider {
  readonly receivedInputs: AiThinkingProviderInput[] = [];

  constructor(
    private readonly behavior: {
      readonly result?: AiThinkingProviderResult;
      readonly error?: Error;
    } = {},
  ) {}

  get callCount(): number {
    return this.receivedInputs.length;
  }

  requestSupport(
    input: AiThinkingProviderInput,
  ): Promise<AiThinkingProviderResult> {
    this.receivedInputs.push(input);

    const error = this.behavior.error;

    if (error !== undefined) {
      return Promise.reject(error);
    }

    return Promise.resolve(this.behavior.result ?? defaultResult);
  }
}
