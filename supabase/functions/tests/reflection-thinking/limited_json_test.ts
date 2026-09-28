/**
 * bodyの大きさの境目を確かめる。
 *
 * ここで見るのは **UTF-8のbyte数** である。
 * 項目の長さ（UTF-16 code unit）とは数え方が違う。
 *
 * `Content-Length` はclientの申告なので、
 * 無い場合・嘘の場合・壊れている場合でも境目が保たれることを確かめる。
 */

import {
  parseContentLength,
  readLimitedJson,
} from "../../_shared/limited_json.ts";
import { MAX_REQUEST_BODY_BYTES } from "../../_shared/limits.ts";
import { assert, assertEquals } from "./assert.ts";

const URL_UNDER_TEST = "https://example.test/functions/v1/reflection-thinking";

/** 中身を見分けるための目印。応答にもログにも出てはいけない。 */
const PRIVATE_BODY_MARKER = "PRIVATE_BODY_MARKER";

/** 指定したbyte数ちょうどの、正しいJSONを作る。 */
function jsonOfBytes(totalBytes: number, filler = "a"): string {
  const envelope = '{"note":""}';
  const padding = totalBytes - envelope.length;

  assert(padding >= 0, "作れない大きさを頼まれている");

  const body = `{"note":"${filler.repeat(padding)}"}`;

  assertEquals(
    new TextEncoder().encode(body).byteLength,
    totalBytes,
    "狙ったbyte数になっていない",
  );

  return body;
}

function requestWithBody(
  body: string | ReadableStream<Uint8Array>,
  contentLength?: string,
): Request {
  const headers = new Headers({ "content-type": "application/json" });

  if (contentLength !== undefined) {
    headers.set("content-length", contentLength);
  }

  return new Request(URL_UNDER_TEST, { method: "POST", headers, body });
}

/** 小さなかたまりに分けて流す。実際の受信のされ方に近づける。 */
function streamOf(text: string, chunkBytes = 1024): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);

  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (let offset = 0; offset < bytes.byteLength; offset += chunkBytes) {
        controller.enqueue(bytes.slice(offset, offset + chunkBytes));
      }

      controller.close();
    },
  });
}

Deno.test("上限より小さいJSONは読める", () => {
  const body = '{"requestId":"thinking-1"}';

  return readLimitedJson(requestWithBody(body)).then((result) => {
    assert(result.ok, "読めるはず");

    if (!result.ok) return;

    assertEquals(
      (result.value as Record<string, unknown>).requestId,
      "thinking-1",
    );
  });
});

Deno.test("上限ちょうど32768 bytesは読める", async () => {
  const body = jsonOfBytes(MAX_REQUEST_BODY_BYTES);

  assertEquals(new TextEncoder().encode(body).byteLength, 32768);

  const result = await readLimitedJson(requestWithBody(body));

  assert(result.ok, "上限ちょうどは通すはず");
});

Deno.test("上限を1 byte超えたら断る", async () => {
  const body = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 1);

  assertEquals(new TextEncoder().encode(body).byteLength, 32769);

  const result = await readLimitedJson(requestWithBody(body));

  assert(!result.ok, "断るはず");

  if (result.ok) return;

  assertEquals(result.reason, "payload_too_large");
});

Deno.test("申告値が上限を超えていれば、bodyを読む前に断る", async () => {
  // bodyそのものは小さい。headerの申告だけで断る。
  const body = '{"requestId":"thinking-1"}';
  const request = requestWithBody(body, String(MAX_REQUEST_BODY_BYTES + 1));

  const result = await readLimitedJson(request);

  assert(!result.ok, "断るはず");

  if (result.ok) return;

  assertEquals(result.reason, "payload_too_large");

  // 読む前に断っているので、bodyは手つかずのまま残っている。
  assertEquals(request.bodyUsed, false);
});

Deno.test("申告が無くても、実際に届いたbyte数で断る", async () => {
  const body = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 100);
  const request = requestWithBody(streamOf(body));

  assertEquals(request.headers.get("content-length"), null);

  const result = await readLimitedJson(request);

  assert(!result.ok, "断るはず");

  if (result.ok) return;

  assertEquals(result.reason, "payload_too_large");
});

Deno.test("申告が実際より小さくても、実際のbyte数で断る", async () => {
  const body = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 100);

  // 「10 bytesです」と申告しながら、32868 bytes送ってくる。
  const result = await readLimitedJson(requestWithBody(streamOf(body), "10"));

  assert(!result.ok, "断るはず");

  if (result.ok) return;

  assertEquals(result.reason, "payload_too_large");
});

Deno.test("申告が実際より大きくても、上限以内なら読む", async () => {
  const body = '{"requestId":"thinking-1"}';

  // 上限は超えていないが、実際のbodyよりは大きい申告。
  const result = await readLimitedJson(requestWithBody(body, "9999"));

  assert(result.ok, "読めるはず");

  if (!result.ok) return;

  assertEquals(
    (result.value as Record<string, unknown>).requestId,
    "thinking-1",
  );
});

Deno.test("申告が壊れていても、実際のbyte数の数えは働く", async () => {
  const oversized = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 100);

  for (const contentLength of ["abc", "1e5", "12.5", "100, 100", " ", "+10"]) {
    // 読めない申告は無かったものとして扱う。数えるのは実際のbyte数。
    assertEquals(parseContentLength(contentLength), null);

    const result = await readLimitedJson(
      requestWithBody(streamOf(oversized), contentLength),
    );

    assert(!result.ok, `断るはず: ${contentLength}`);

    if (result.ok) continue;

    assertEquals(result.reason, "payload_too_large");
  }
});

Deno.test("負の申告や桁あふれでも、境目は壊れない", async () => {
  // 負の値は読めない申告として扱う。実際のbyte数で決める。
  assertEquals(parseContentLength("-1"), null);
  assertEquals(parseContentLength("-99999999"), null);

  const oversized = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 100);

  const negative = await readLimitedJson(
    requestWithBody(streamOf(oversized), "-1"),
  );

  assert(!negative.ok, "断るはず");

  if (!negative.ok) {
    assertEquals(negative.reason, "payload_too_large");
  }

  // 桁があふれるほど大きい申告は、そのまま超過として読める。
  const huge = parseContentLength("999999999999999999999");

  assert(huge !== null && huge > MAX_REQUEST_BODY_BYTES, "超過として読める");

  const declared = await readLimitedJson(
    requestWithBody('{"a":1}', "999999999999999999999"),
  );

  assert(!declared.ok, "断るはず");

  if (declared.ok) return;

  assertEquals(declared.reason, "payload_too_large");
});

Deno.test("申告の読み方は、数字だけを受け取る", () => {
  assertEquals(parseContentLength(null), null);
  assertEquals(parseContentLength("0"), 0);
  assertEquals(parseContentLength("32768"), 32768);
  assertEquals(parseContentLength(" 32768 "), 32768);
  assertEquals(parseContentLength(""), null);
  assertEquals(parseContentLength("０"), null);
});

Deno.test("上限以内でもJSONとして読めなければ、大きすぎとは言わない", async () => {
  const result = await readLimitedJson(requestWithBody("{ this is not json"));

  assert(!result.ok, "読めないはず");

  if (result.ok) return;

  // 「大きすぎた」と「読めなかった」を混ぜない。
  assertEquals(result.reason, "invalid_json");
});

Deno.test("bodyが無いものは、読めなかったものとして扱う", async () => {
  const request = new Request(URL_UNDER_TEST, { method: "POST" });

  assertEquals(request.body, null);

  const result = await readLimitedJson(request);

  assert(!result.ok, "読めないはず");

  if (result.ok) return;

  assertEquals(result.reason, "invalid_json");
});

Deno.test("UTF-8として読めないbodyは、読めなかったものとして扱う", async () => {
  const broken = new ReadableStream<Uint8Array>({
    start(controller) {
      // 単独では意味をなさないbyte列。
      controller.enqueue(new Uint8Array([0xff, 0xfe, 0xfd]));
      controller.close();
    },
  });

  const result = await readLimitedJson(requestWithBody(broken));

  assert(!result.ok, "読めないはず");

  if (result.ok) return;

  assertEquals(result.reason, "invalid_json");
});

Deno.test("大きすぎるbodyを、最後まで読み切らない", async () => {
  let enqueued = 0;
  let cancelled = false;

  const chunk = new TextEncoder().encode("a".repeat(1024));

  const endless = new ReadableStream<Uint8Array>({
    pull(controller) {
      enqueued += 1;

      // 上限を大きく超えても流し続ける。
      if (enqueued > 1000) {
        controller.close();

        return;
      }

      controller.enqueue(chunk);
    },
    cancel() {
      cancelled = true;
    },
  });

  const result = await readLimitedJson(requestWithBody(endless));

  assert(!result.ok, "断るはず");

  if (!result.ok) {
    assertEquals(result.reason, "payload_too_large");
  }

  // 32 KiB を渡すのに必要なかたまりは32個。
  // それを少し超えたあたりで止まっていれば、読み切っていない。
  assert(
    enqueued <= 34,
    `上限を超えた時点で止まるはず。実際に流れたかたまり: ${enqueued}`,
  );
  assert(cancelled, "読むのをやめたことを相手へ伝えるはず");
});

Deno.test("大きすぎたbodyの中身は、結果に残らない", async () => {
  const body = jsonOfBytes(MAX_REQUEST_BODY_BYTES + 100, "x").replace(
    '"note":"',
    `"note":"${PRIVATE_BODY_MARKER}`,
  );

  const result = await readLimitedJson(requestWithBody(streamOf(body)));

  assert(!result.ok, "断るはず");

  if (result.ok) return;

  // 結果に入るのは理由だけ。中身も、その先頭の数文字も持ち出さない。
  assertEquals(Object.keys(result).sort(), ["ok", "reason"]);

  const serialized = JSON.stringify(result);

  assert(
    !serialized.includes(PRIVATE_BODY_MARKER),
    "中身は結果へ入らない",
  );
});
