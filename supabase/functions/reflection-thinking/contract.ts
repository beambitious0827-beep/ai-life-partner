/**
 * reflection-thinking の取り決め。
 *
 * Flutter側の `AiThinkingGatewayContract` と意味をそろえてある。
 * ただしDartの型をそのまま写したものではない。
 * HTTPのbodyは信用できない入力なので、ここで独立に確かめ直す。
 *
 * 受け取るのは、Humanが選んだ振り返りの言葉だけである。
 * humanId / provider / model / systemPrompt / Journey / Calendar などは
 * 受け取らないし、余分な項目があっても内部へは流さない。
 */

/** やり取りの版。増やすときはFlutter側と合わせる。 */
export const CONTRACT_VERSION = "v1";

/** 確かめ終わった、AIへ渡してよい材料。 */
export type ThinkingRequest = {
  /** 追跡のためのID。Humanの言葉は含まない。 */
  readonly requestId: string;
  /**
   * client が申告した振り返りのID。
   *
   * この時点では「所有権を確かめ終えたresource ID」ではない。
   * serverは振り返りを保存していないため、確かめようがない。
   * 突き合わせと、将来の紐づけのためだけに持つ。
   */
  readonly reflectionEntryId: string;
  readonly feelingText: string | null;
  readonly noticedText: string | null;
};

/** 取り決めに合わない要求の理由。Humanの言葉は含まない。 */
export type RequestErrorCode =
  | "invalid_json"
  | "invalid_request"
  | "unsupported_contract";

export type ParseResult =
  | { readonly ok: true; readonly request: ThinkingRequest }
  | {
    readonly ok: false;
    readonly code: RequestErrorCode;
    /** 安全に取り出せた場合だけ入る。 */
    readonly requestId: string | null;
  };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** 空白だけの値は、書かれていないものとして扱う。 */
function trimmedOrNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();

  return trimmed.length === 0 ? null : trimmed;
}

/**
 * 受け取ったbodyを確かめる。
 *
 * clientが正しく送ってくる前提を置かない。
 * 取り決めどおりのものだけを、この先へ通す。
 */
export function parseThinkingRequest(raw: unknown): ParseResult {
  if (!isPlainObject(raw)) {
    return { ok: false, code: "invalid_request", requestId: null };
  }

  // 追跡IDは、あとの応答でも使うので先に取り出す。
  const requestId = trimmedOrNull(raw.requestId);

  if (requestId === null) {
    return { ok: false, code: "invalid_request", requestId: null };
  }

  const contractVersion = raw.contractVersion;

  if (typeof contractVersion !== "string") {
    return { ok: false, code: "invalid_request", requestId };
  }

  if (contractVersion !== CONTRACT_VERSION) {
    return { ok: false, code: "unsupported_contract", requestId };
  }

  const reflectionEntryId = trimmedOrNull(raw.reflectionEntryId);

  if (reflectionEntryId === null) {
    return { ok: false, code: "invalid_request", requestId };
  }

  const reflection = raw.reflection;

  if (!isPlainObject(reflection)) {
    return { ok: false, code: "invalid_request", requestId };
  }

  // 文字でもnullでもないものは、取り決め違反として断る。
  // 項目そのものが無い場合は、書かれていないものとして扱う。
  if (!isOptionalText(reflection.feelingText)) {
    return { ok: false, code: "invalid_request", requestId };
  }

  if (!isOptionalText(reflection.noticedText)) {
    return { ok: false, code: "invalid_request", requestId };
  }

  // clientがtrimしている前提を置かない。ここで整えてから先へ渡す。
  const feelingText = trimmedOrNull(reflection.feelingText);
  const noticedText = trimmedOrNull(reflection.noticedText);

  if (feelingText === null && noticedText === null) {
    return { ok: false, code: "invalid_request", requestId };
  }

  // ここで組み立てたものだけが先へ進む。
  // bodyに余分な項目があっても、読まないので内部へは入らない。
  return {
    ok: true,
    request: { requestId, reflectionEntryId, feelingText, noticedText },
  };
}

function isOptionalText(value: unknown): boolean {
  return value === undefined || value === null || typeof value === "string";
}
