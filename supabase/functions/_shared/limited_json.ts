/**
 * request bodyを、決めた大きさまでしか読まないための道具。
 *
 * `req.json()` はbodyを最後まで読んでから展開する。
 * 大きさの上限が要るのに、上限を超えたことが分かるのは読み終えたあとになる。
 * それでは遅いので、読みながら数えて、超えた時点で止める。
 *
 * `Content-Length` の扱いは3つに分かれる。
 *
 * 1. 正しい非負整数として読めて、上限を **超えている** 場合。
 *    bodyを読み始めずに、その場で大きすぎたものとして断る。
 *    実際のbodyが小さいかどうかは確かめない。申告を信じて断るのではなく、
 *    「その大きさを送るつもりだ」という申告を受け取らないということである。
 *
 * 2. 正しい非負整数として読めて、上限 **以下** の場合。
 *    これだけでは安全と見なさない。読みながら実際のbyte数を数える。
 *
 * 3. header が無い、または正しい非負整数として読めない場合
 *    （負の値・小数・指数表記・複数値など）。
 *    大きさの判断には使わず、実際のbyte数だけで決める。
 *
 * 2と3で行う実際のbyte数の数えが、境目そのものである。
 * clientが実際より小さく申告しても、header を付けずに送ってきても、
 * これがあるかぎり上限を越えられない。
 *
 * ここではbodyの中身を持ち出さない。
 * 大きすぎたことを伝えるだけで、その中身も、先頭の数文字も返さない。
 */

import { MAX_REQUEST_BODY_BYTES } from "./limits.ts";

/**
 * 読み取りの結果。
 *
 * 「大きすぎた」と「JSONとして読めなかった」を、呼び手が見分けられるようにする。
 * 前者は413、後者は400であり、混ぜると原因が分からなくなる。
 */
export type LimitedJsonResult =
  | { readonly ok: true; readonly value: unknown }
  | { readonly ok: false; readonly reason: "payload_too_large" }
  | { readonly ok: false; readonly reason: "invalid_json" };

/**
 * `Content-Length` を、正しい非負整数としてだけ読む。
 *
 * 数字だけで書かれていなければ、無かったものとして扱う。
 * 負の値も、小数も、指数表記も、複数値も、ここで弾かれる。
 * 「読めなかった」と「0」を取り違えないよう、読めなければnullを返す。
 *
 * nullを返したものは、大きさの判断にいっさい使わない。
 */
export function parseContentLength(raw: string | null): number | null {
  if (raw === null) {
    return null;
  }

  const trimmed = raw.trim();

  if (!/^\d+$/.test(trimmed)) {
    return null;
  }

  const value = Number(trimmed);

  return Number.isFinite(value) ? value : null;
}

/**
 * bodyを上限まで読み、JSONとして解釈する。
 *
 * `Content-Length` が正しく読めて上限を超えていれば、bodyを読まずに断る。
 * それ以外は、読みながら数えて、超えた時点でやめる。
 * 上限ちょうどは通す。超えたものだけを断る。
 */
export async function readLimitedJson(
  req: Request,
  maxBytes: number = MAX_REQUEST_BODY_BYTES,
): Promise<LimitedJsonResult> {
  // 正しく読めた申告が上限を超えているなら、ここで断る。
  // 実際のbodyが小さいかどうかは確かめない。読み始めること自体をやめる。
  const declared = parseContentLength(req.headers.get("content-length"));

  if (declared !== null && declared > maxBytes) {
    return { ok: false, reason: "payload_too_large" };
  }

  // ここを通った理由は2つある。
  //   - 申告が上限以下だった
  //   - 申告が無い、または正しい非負整数として読めなかった
  // どちらも、これだけでは安全と見なさない。以下で実際のbyte数を数える。
  // 過小申告とheader不在を防いでいるのは、この数えである。
  const body = req.body;

  if (body === null) {
    // bodyが無いものは、JSONとして読めないものとして扱う。
    // これまでの `req.json()` と同じ結果になる。
    return { ok: false, reason: "invalid_json" };
  }

  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();

      if (done) {
        break;
      }

      if (value === undefined) {
        continue;
      }

      total += value.byteLength;

      // 超えた時点でやめる。残りは読まない。
      if (total > maxBytes) {
        await cancelQuietly(reader);

        return { ok: false, reason: "payload_too_large" };
      }

      chunks.push(value);
    }
  } catch {
    // 途中で切れたものは、JSONとして読めないものとして扱う。
    await cancelQuietly(reader);

    return { ok: false, reason: "invalid_json" };
  }

  const bytes = concat(chunks, total);

  try {
    // UTF-8として読めないものは、ここで断る。中身は持ち出さない。
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);

    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, reason: "invalid_json" };
  }
}

/** 読むのをやめる。やめ方の失敗で、判断を変えない。 */
async function cancelQuietly(
  reader: ReadableStreamDefaultReader<Uint8Array>,
): Promise<void> {
  try {
    await reader.cancel();
  } catch {
    // 相手が先に閉じていることもある。ここで騒がない。
  }
}

function concat(chunks: Uint8Array[], total: number): Uint8Array {
  const bytes = new Uint8Array(total);
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return bytes;
}
