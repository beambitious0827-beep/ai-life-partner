/**
 * AI Providerとの境界。
 *
 * Providerへ渡すのは、Humanが書いた振り返りの言葉だけである。
 * JWT / email / Humanのプロフィール / reflectionEntryId /
 * HTTP Request そのもの は渡さない。
 *
 * Providerが返してよいのは、考えるための材料だけである。
 * 気づきの本文・最終的な答え・診断・点数・次の行動は返さない。
 */

/** Providerへ渡す材料。これ以上は渡さない。 */
export type AiThinkingProviderInput = {
  readonly feelingText: string | null;
  readonly noticedText: string | null;
};

/** Providerから返る材料。 */
export type AiThinkingProviderResult = {
  readonly questions: string[];
  readonly perspectives: string[];
  readonly possibilities: string[];
};

export interface AiThinkingProvider {
  requestSupport(
    input: AiThinkingProviderInput,
  ): Promise<AiThinkingProviderResult>;
}

/**
 * Providerがまだ用意されていないことを表す。
 *
 * メッセージにHumanの言葉やprovider内部の事情を入れない。
 */
export class ProviderUnavailableError extends Error {
  constructor() {
    super("ai thinking provider is not configured");
    this.name = "ProviderUnavailableError";
  }
}

/**
 * まだAI Providerへつないでいないことを、はっきり示す実装。
 *
 * 呼ばれたら失敗として返す。デモの材料で埋め合わせない。
 * つながっていないことをHumanに隠さないためである。
 * secretも要求しない。
 */
export class UnconfiguredAiThinkingProvider implements AiThinkingProvider {
  requestSupport(
    _input: AiThinkingProviderInput,
  ): Promise<AiThinkingProviderResult> {
    return Promise.reject(new ProviderUnavailableError());
  }
}
