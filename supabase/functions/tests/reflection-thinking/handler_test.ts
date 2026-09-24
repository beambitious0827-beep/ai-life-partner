import { handleReflectionThinking } from "../../reflection-thinking/handler.ts";
import { CONTRACT_VERSION } from "../../reflection-thinking/contract.ts";
import type {
  AiThinkingProvider,
  AiThinkingProviderInput,
  AiThinkingProviderResult,
} from "../../reflection-thinking/provider.ts";
import {
  ProviderUnavailableError,
  UnconfiguredAiThinkingProvider,
} from "../../reflection-thinking/provider.ts";
import { defaultResult, FakeAiThinkingProvider } from "./fake_provider.ts";
import { assert, assertEquals, assertStringNotIncludes } from "./assert.ts";

/**
 * Humanが書いた言葉であることを、テストの中で見分けるための目印。
 * 応答やログにこれが現れたら、本文が漏れているということである。
 */
const PRIVATE_REFLECTION_MARKER = "PRIVATE_REFLECTION_MARKER";

const feelingText = `思ったより疲れていた ${PRIVATE_REFLECTION_MARKER}`;
const noticedText = `休んだら少し軽くなった ${PRIVATE_REFLECTION_MARKER}`;

function createRequest(
  body: unknown,
  method = "POST",
): Request {
  return new Request("https://example.test/functions/v1/reflection-thinking", {
    method,
    headers: {
      "content-type": "application/json",
      // 認証はwrapperが扱う。ここへ来た時点では使わない。
      "authorization": "Bearer test-token-value",
    },
    body: method === "GET" || method === "HEAD"
      ? undefined
      : JSON.stringify(body),
  });
}

function validBody(): Record<string, unknown> {
  return {
    requestId: "thinking-1",
    contractVersion: CONTRACT_VERSION,
    reflectionEntryId: "reflection-1",
    reflection: { feelingText, noticedText },
  };
}

/** ログ行を集めておくための入れ物。 */
function createLogSink(): { lines: string[]; log: (line: string) => void } {
  const lines: string[] = [];

  return { lines, log: (line: string) => lines.push(line) };
}

Deno.test("材料が返れば、そのまま渡す", async () => {
  const provider = new FakeAiThinkingProvider();

  const response = await handleReflectionThinking(
    createRequest(validBody()),
    { provider },
  );

  assertEquals(response.status, 200);

  const body = await response.json();

  assertEquals(body.requestId, "thinking-1");
  assertEquals(body.contractVersion, CONTRACT_VERSION);
  assertEquals(body.support.questions, defaultResult.questions);
  assertEquals(body.support.perspectives, defaultResult.perspectives);
  assertEquals(body.support.possibilities, defaultResult.possibilities);

  // 答え・点数・診断のたぐいは返さない。
  assertEquals(Object.keys(body.support).sort(), [
    "perspectives",
    "possibilities",
    "questions",
  ]);
  assertEquals(Object.keys(body).sort(), [
    "contractVersion",
    "requestId",
    "support",
  ]);
});

Deno.test("POST以外は受け付けない", async () => {
  for (const method of ["GET", "PUT", "PATCH", "DELETE"]) {
    const provider = new FakeAiThinkingProvider();

    const response = await handleReflectionThinking(
      createRequest(validBody(), method),
      { provider },
    );

    assertEquals(response.status, 405);

    const body = await response.json();

    assertEquals(body.error.code, "method_not_allowed");
    assertEquals(body.contractVersion, CONTRACT_VERSION);

    // 中身を見る前に断っているので、Providerは呼ばれない。
    assertEquals(provider.callCount, 0);
  }
});

Deno.test("読めないJSONは断る", async () => {
  const provider = new FakeAiThinkingProvider();

  const request = new Request(
    "https://example.test/functions/v1/reflection-thinking",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{ this is not json",
    },
  );

  const response = await handleReflectionThinking(request, { provider });

  assertEquals(response.status, 400);

  const body = await response.json();

  assertEquals(body.error.code, "invalid_json");
  assertEquals(body.requestId, null);
  assertEquals(provider.callCount, 0);
});

Deno.test("取り決めに合わない要求は、Providerまで進まない", async () => {
  const cases: Array<{ body: Record<string, unknown>; code: string }> = [
    { body: { ...validBody(), requestId: "" }, code: "invalid_request" },
    {
      body: { ...validBody(), contractVersion: "v2" },
      code: "unsupported_contract",
    },
    {
      body: { ...validBody(), reflectionEntryId: "" },
      code: "invalid_request",
    },
    {
      body: { ...validBody(), reflection: { feelingText: "  " } },
      code: "invalid_request",
    },
  ];

  for (const testCase of cases) {
    const provider = new FakeAiThinkingProvider();

    const response = await handleReflectionThinking(
      createRequest(testCase.body),
      { provider },
    );

    assertEquals(response.status, 400);

    const body = await response.json();

    assertEquals(body.error.code, testCase.code);
    assertEquals(provider.callCount, 0);
  }
});

Deno.test("Providerが未設定のときは、つながっていないと伝える", async () => {
  const provider = new UnconfiguredAiThinkingProvider();

  const response = await handleReflectionThinking(
    createRequest(validBody()),
    { provider },
  );

  assertEquals(response.status, 503);

  const text = await response.text();
  const body = JSON.parse(text);

  assertEquals(body.error.code, "provider_unavailable");
  assertEquals(body.requestId, "thinking-1");
  assertEquals(body.contractVersion, CONTRACT_VERSION);

  // 未設定のときに、デモの材料へ黙って切り替えない。
  assert(body.support === undefined, "材料は入らない");
  assertStringNotIncludes(text, PRIVATE_REFLECTION_MARKER);
});

/**
 * 取り決めから外れた返事を、そのまま返すProvider。
 *
 * Providerはserverの外の境界である。
 * compile-timeの型がどうであれ、runtimeでは何が返るかわからない。
 * ここではその状況を作るために、テスト側で型をわざと外している。
 * 本番のコードでは同じことをしない。
 */
class RawResultProvider implements AiThinkingProvider {
  constructor(private readonly raw: unknown) {}

  requestSupport(
    _input: AiThinkingProviderInput,
  ): Promise<AiThinkingProviderResult> {
    return Promise.resolve(this.raw as AiThinkingProviderResult);
  }
}

Deno.test("Providerが取り決め外の材料を返したら、成功にしない", async () => {
  const badResults: Array<{ label: string; raw: unknown }> = [
    // 入れ物の形をしていないもの。ここで確認がthrowしてはいけない。
    { label: "null", raw: null },
    { label: "undefined", raw: undefined },
    { label: "string", raw: "questions" },
    { label: "number", raw: 42 },
    { label: "boolean", raw: true },
    { label: "array", raw: [{ questions: [], perspectives: [] }] },
    // 入れ物の形はしているが、項目が足りないもの。
    { label: "empty object", raw: {} },
    {
      label: "questions missing",
      raw: { perspectives: ["別の見方"], possibilities: ["可能性"] },
    },
    {
      label: "perspectives missing",
      raw: { questions: ["問い"], possibilities: ["可能性"] },
    },
    {
      label: "possibilities missing",
      raw: { questions: ["問い"], perspectives: ["別の見方"] },
    },
    // 項目はあるが、中身が取り決めに合わないもの。
    {
      label: "questions not an array",
      raw: { questions: "not-an-array", perspectives: [], possibilities: [] },
    },
    {
      label: "questions null",
      raw: { questions: null, perspectives: [], possibilities: [] },
    },
    {
      label: "non-string item",
      raw: { questions: [42], perspectives: [], possibilities: [] },
    },
    {
      label: "blank item",
      raw: { questions: ["  "], perspectives: [], possibilities: [] },
    },
    {
      label: "all empty",
      raw: { questions: [], perspectives: [], possibilities: [] },
    },
  ];

  for (const testCase of badResults) {
    const provider = new RawResultProvider(testCase.raw);

    // 確認がthrowするなら、ここでテストが落ちる。
    // 500ではなく502へそろえるためである。
    const response = await handleReflectionThinking(
      createRequest(validBody()),
      { provider },
    );

    assertEquals(response.status, 502, testCase.label);

    const text = await response.text();
    const body = JSON.parse(text);

    assertEquals(body.error.code, "invalid_provider_response", testCase.label);
    assertEquals(body.requestId, "thinking-1", testCase.label);
    assertEquals(body.contractVersion, CONTRACT_VERSION, testCase.label);
    assertEquals(Object.keys(body.error), ["code"], testCase.label);

    // Providerが返した値そのもの・振り返りの本文・stackを応答へ出さない。
    assertStringNotIncludes(text, PRIVATE_REFLECTION_MARKER, testCase.label);
    assertStringNotIncludes(text, "not-an-array", testCase.label);
    assertStringNotIncludes(text, "別の見方", testCase.label);
    assertStringNotIncludes(text, "at ", testCase.label);
    assert(body.support === undefined, `材料は入らない: ${testCase.label}`);
  }
});

Deno.test("入れ物の形でない返事も、想定外の失敗として扱わない", async () => {
  // 確認そのものがthrowしていれば、ここは internal_error / 500 になる。
  // 「取り決めに合わない返事」と「server側の想定外の失敗」を混ぜないため、
  // ログへ残る種類まで確かめておく。
  for (const raw of [null, undefined, "text", 42, true, []]) {
    const sink = createLogSink();

    const response = await handleReflectionThinking(
      createRequest(validBody()),
      {
        provider: new RawResultProvider(raw),
        now: () => 0,
        log: sink.log,
      },
    );

    assertEquals(response.status, 502);
    await response.body?.cancel();

    assertEquals(sink.lines.length, 1);

    const logged = JSON.parse(sink.lines[0]);

    assertEquals(logged.outcome, "invalid_provider_response");
    assertEquals(logged.status, 502);
  }
});

Deno.test("Providerの失敗の中身は、応答へ出さない", async () => {
  const provider = new FakeAiThinkingProvider({
    error: new Error(
      `upstream failed: api-key=sk-secret-value payload=${feelingText}`,
    ),
  });

  const response = await handleReflectionThinking(
    createRequest(validBody()),
    { provider },
  );

  assertEquals(response.status, 500);

  const text = await response.text();
  const body = JSON.parse(text);

  assertEquals(body.error.code, "internal_error");
  assertEquals(body.requestId, "thinking-1");
  assertEquals(Object.keys(body.error), ["code"]);

  assertStringNotIncludes(text, "sk-secret-value");
  assertStringNotIncludes(text, "upstream failed");
  assertStringNotIncludes(text, PRIVATE_REFLECTION_MARKER);
});

Deno.test("Providerへ渡すのは、Humanが書いた言葉だけ", async () => {
  const provider = new FakeAiThinkingProvider();

  await handleReflectionThinking(
    createRequest({
      ...validBody(),
      humanId: "local-human",
      provider: "some-provider",
      model: "some-model",
      systemPrompt: "あなたは...",
      accessToken: "test-token-value",
    }),
    { provider },
  );

  assertEquals(provider.callCount, 1);

  const input = provider.receivedInputs[0];

  assertEquals(Object.keys(input).sort(), ["feelingText", "noticedText"]);
  assertEquals(input.feelingText, feelingText);
  assertEquals(input.noticedText, noticedText);

  const serialized = JSON.stringify(input);

  // humanId / reflectionEntryId / requestId / JWT / Authorization /
  // requestそのもの は渡らない。
  assertStringNotIncludes(serialized, "local-human");
  assertStringNotIncludes(serialized, "reflection-1");
  assertStringNotIncludes(serialized, "thinking-1");
  assertStringNotIncludes(serialized, "test-token-value");
  assertStringNotIncludes(serialized, "some-provider");
  assertStringNotIncludes(serialized, "some-model");
  assertStringNotIncludes(serialized, "あなたは...");
  assert(
    !(input as Record<string, unknown>).request,
    "Requestそのものは渡らない",
  );
});

Deno.test("成功した応答へ、振り返りの本文を混ぜない", async () => {
  const provider = new FakeAiThinkingProvider();

  const response = await handleReflectionThinking(
    createRequest(validBody()),
    { provider },
  );

  const text = await response.text();

  assertEquals(response.status, 200);
  assertStringNotIncludes(text, PRIVATE_REFLECTION_MARKER);
});

Deno.test("ログへ残すのは、追跡IDと結果の種類だけ", async () => {
  const sink = createLogSink();
  const provider = new FakeAiThinkingProvider();

  await handleReflectionThinking(createRequest(validBody()), {
    provider,
    now: () => 0,
    log: sink.log,
  });

  assertEquals(sink.lines.length, 1);

  const line = sink.lines[0];

  assertStringNotIncludes(line, PRIVATE_REFLECTION_MARKER);
  assertStringNotIncludes(line, "test-token-value");
  assertStringNotIncludes(line, "Bearer");

  const logged = JSON.parse(line);

  assertEquals(Object.keys(logged).sort(), [
    "durationMs",
    "fn",
    "outcome",
    "requestId",
    "status",
  ]);
  assertEquals(logged.requestId, "thinking-1");
  assertEquals(logged.outcome, "success");
  assertEquals(logged.status, 200);
});

Deno.test("失敗のときも、ログへ本文を残さない", async () => {
  const sink = createLogSink();
  const provider = new FakeAiThinkingProvider({
    error: new Error(`upstream failed: payload=${feelingText}`),
  });

  await handleReflectionThinking(createRequest(validBody()), {
    provider,
    now: () => 0,
    log: sink.log,
  });

  assertEquals(sink.lines.length, 1);

  const line = sink.lines[0];

  assertStringNotIncludes(line, PRIVATE_REFLECTION_MARKER);
  assertStringNotIncludes(line, "upstream failed");

  const logged = JSON.parse(line);

  assertEquals(logged.outcome, "internal_error");
  assertEquals(logged.status, 500);
});

Deno.test("つながっていない場合の失敗は、種類を見分けて返す", async () => {
  const provider = new FakeAiThinkingProvider({
    error: new ProviderUnavailableError(),
  });

  const response = await handleReflectionThinking(
    createRequest(validBody()),
    { provider },
  );

  assertEquals(response.status, 503);

  const body = await response.json();

  assertEquals(body.error.code, "provider_unavailable");
});
