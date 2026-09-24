/**
 * JSONで応えるための小さな道具。
 *
 * 応答にHumanの言葉を混ぜないよう、組み立て方をここへ集めておく。
 * feelingText / noticedText を応答へ入れる関数は、ここには置かない。
 */

const JSON_HEADERS: HeadersInit = {
  "content-type": "application/json; charset=utf-8",
};

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

/**
 * 失敗の知らせ。
 *
 * 入れるのは、追跡ID・取り決めの版・機械が読める理由だけ。
 * 振り返りの本文・stack trace・providerの生のエラー・secretは入れない。
 */
export function errorResponse(
  status: number,
  options: {
    readonly code: string;
    readonly requestId: string | null;
    readonly contractVersion: string;
  },
): Response {
  return jsonResponse(status, {
    requestId: options.requestId,
    contractVersion: options.contractVersion,
    error: { code: options.code },
  });
}
