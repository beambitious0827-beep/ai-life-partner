/**
 * reflection-thinking のHTTP／業務の境界。
 *
 * 認証はこの手前（Supabaseのwrapper）で終わっている。
 * ここでは、受け取ったbodyを確かめ、Providerへ最小限だけ渡し、
 * 返ってきた材料をもう一度確かめてから応える。
 *
 * ここではReflectionをDBから読まない。
 * したがって reflectionEntryId の所有権は確かめられていない。
 * 「確認済み」として扱わない。
 */

import { errorResponse, jsonResponse } from "../_shared/http.ts";
import { formatThinkingLogEvent } from "../_shared/log.ts";
import { CONTRACT_VERSION, parseThinkingRequest } from "./contract.ts";
import {
  type AiThinkingProvider,
  type AiThinkingProviderResult,
  ProviderUnavailableError,
} from "./provider.ts";

export type ReflectionThinkingDeps = {
  readonly provider: AiThinkingProvider;
  /** 差し替えられるようにしておく。既定は現在時刻。 */
  readonly now?: () => number;
  /** 差し替えられるようにしておく。既定は標準出力。 */
  readonly log?: (line: string) => void;
};

/** 取り決めに合う材料が返ってきたかどうかを確かめる。 */
function isValidLines(value: unknown): value is string[] {
  if (!Array.isArray(value)) {
    return false;
  }

  return value.every(
    (line) => typeof line === "string" && line.trim().length > 0,
  );
}

/**
 * Providerの返事を、信用できない値として確かめる。
 *
 * Providerは外の境界である。
 * compile-timeの型がどうであれ、runtimeでは何が返るかわからない。
 * null / 文字 / 数 / 真偽 / 一覧 が返っても、ここでthrowしない。
 * 形が違えばfalseを返し、呼び手が502として扱う。
 *
 * 本番のコードで `as AiThinkingProviderResult` を使って
 * 不正な値を正しいことにしない。
 */
function isUsableResult(value: unknown): value is AiThinkingProviderResult {
  // まずrootの形から確かめる。ここを通るまで項目へ触らない。
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  // 項目そのものが無い場合はundefinedになり、次の確認で落ちる。
  const questions = candidate.questions;
  const perspectives = candidate.perspectives;
  const possibilities = candidate.possibilities;

  if (
    !isValidLines(questions) ||
    !isValidLines(perspectives) ||
    !isValidLines(possibilities)
  ) {
    return false;
  }

  // 材料がひとつもないものを、成功として返さない。
  return questions.length > 0 ||
    perspectives.length > 0 ||
    possibilities.length > 0;
}

export async function handleReflectionThinking(
  req: Request,
  deps: ReflectionThinkingDeps,
): Promise<Response> {
  const now = deps.now ?? (() => Date.now());
  const log = deps.log ?? ((line: string) => console.log(line));
  const startedAt = now();

  const finish = (
    response: Response,
    outcome: string,
    requestId: string | null,
  ): Response => {
    log(
      formatThinkingLogEvent({
        requestId,
        outcome,
        status: response.status,
        durationMs: now() - startedAt,
      }),
    );

    return response;
  };

  // OPTIONS はSupabaseのwrapperが扱う。ここではPOSTだけを受ける。
  if (req.method !== "POST") {
    return finish(
      errorResponse(405, {
        code: "method_not_allowed",
        requestId: null,
        contractVersion: CONTRACT_VERSION,
      }),
      "method_not_allowed",
      null,
    );
  }

  let body: unknown;

  try {
    body = await req.json();
  } catch {
    // 読めなかった中身は、ログにも応答にも載せない。
    return finish(
      errorResponse(400, {
        code: "invalid_json",
        requestId: null,
        contractVersion: CONTRACT_VERSION,
      }),
      "invalid_json",
      null,
    );
  }

  const parsed = parseThinkingRequest(body);

  if (!parsed.ok) {
    return finish(
      errorResponse(400, {
        code: parsed.code,
        requestId: parsed.requestId,
        contractVersion: CONTRACT_VERSION,
      }),
      parsed.code,
      parsed.requestId,
    );
  }

  const { requestId, feelingText, noticedText } = parsed.request;

  // Providerの返事は、確かめ終わるまで型のついた値として扱わない。
  let result: unknown;

  try {
    // Providerへ渡すのは、Humanが書いた言葉だけ。
    // 追跡IDも、振り返りのIDも、認証の情報も渡さない。
    result = await deps.provider.requestSupport({ feelingText, noticedText });
  } catch (error) {
    if (error instanceof ProviderUnavailableError) {
      return finish(
        errorResponse(503, {
          code: "provider_unavailable",
          requestId,
          contractVersion: CONTRACT_VERSION,
        }),
        "provider_unavailable",
        requestId,
      );
    }

    // providerの生のエラーは、応答にもログにも載せない。
    return finish(
      errorResponse(500, {
        code: "internal_error",
        requestId,
        contractVersion: CONTRACT_VERSION,
      }),
      "internal_error",
      requestId,
    );
  }

  if (!isUsableResult(result)) {
    return finish(
      errorResponse(502, {
        code: "invalid_provider_response",
        requestId,
        contractVersion: CONTRACT_VERSION,
      }),
      "invalid_provider_response",
      requestId,
    );
  }

  // 応答へ振り返りの本文は入れない。返すのは材料だけ。
  return finish(
    jsonResponse(200, {
      requestId,
      contractVersion: CONTRACT_VERSION,
      support: {
        questions: result.questions,
        perspectives: result.perspectives,
        possibilities: result.possibilities,
      },
    }),
    "success",
    requestId,
  );
}
