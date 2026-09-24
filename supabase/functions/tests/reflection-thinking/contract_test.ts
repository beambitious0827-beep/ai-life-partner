import {
  CONTRACT_VERSION,
  parseThinkingRequest,
} from "../../reflection-thinking/contract.ts";
import { assert, assertEquals } from "./assert.ts";

function createBody(
  overrides: Record<string, unknown> = {},
  reflection: Record<string, unknown> | unknown = {
    feelingText: "思ったより疲れていた",
    noticedText: "休んだことで少し気持ちが軽くなった",
  },
): Record<string, unknown> {
  return {
    requestId: "thinking-1",
    contractVersion: CONTRACT_VERSION,
    reflectionEntryId: "reflection-1",
    reflection,
    ...overrides,
  };
}

Deno.test("取り決めどおりの内容を受け取れる", () => {
  const parsed = parseThinkingRequest(createBody());

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.requestId, "thinking-1");
  assertEquals(parsed.request.reflectionEntryId, "reflection-1");
  assertEquals(parsed.request.feelingText, "思ったより疲れていた");
  assertEquals(
    parsed.request.noticedText,
    "休んだことで少し気持ちが軽くなった",
  );
});

Deno.test("感じたことだけでも受け取れる", () => {
  const parsed = parseThinkingRequest(
    createBody({}, { feelingText: "思ったより疲れていた", noticedText: null }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.feelingText, "思ったより疲れていた");
  assertEquals(parsed.request.noticedText, null);
});

Deno.test("気づいたことだけでも受け取れる", () => {
  const parsed = parseThinkingRequest(
    createBody({}, {
      feelingText: null,
      noticedText: "少し気持ちが軽くなった",
    }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.feelingText, null);
  assertEquals(parsed.request.noticedText, "少し気持ちが軽くなった");
});

Deno.test("項目そのものが無い場合は、書かれていないものとして扱う", () => {
  const parsed = parseThinkingRequest(
    createBody({}, { feelingText: "思ったより疲れていた" }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.noticedText, null);
});

Deno.test("前後の空白は落としてから先へ渡す", () => {
  const parsed = parseThinkingRequest(
    createBody({ requestId: "  thinking-1  " }, {
      feelingText: "  思ったより疲れていた  ",
      noticedText: null,
    }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.requestId, "thinking-1");
  assertEquals(parsed.request.feelingText, "思ったより疲れていた");
});

Deno.test("入れ物の形が違う場合は受け取らない", () => {
  for (const raw of [null, undefined, "text", 42, [1, 2, 3]]) {
    const parsed = parseThinkingRequest(raw);

    assert(!parsed.ok, `受け取ってはいけない: ${JSON.stringify(raw)}`);

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
  }
});

Deno.test("requestIdが無い、空、文字でない場合は受け取らない", () => {
  for (const requestId of [undefined, "", "   ", 7, null]) {
    const parsed = parseThinkingRequest(createBody({ requestId }));

    assert(!parsed.ok, `受け取ってはいけない: ${JSON.stringify(requestId)}`);

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
    assertEquals(parsed.requestId, null);
  }
});

Deno.test("知らない版は、読める版として扱わない", () => {
  const parsed = parseThinkingRequest(createBody({ contractVersion: "v2" }));

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "unsupported_contract");
  assertEquals(parsed.requestId, "thinking-1");
});

Deno.test("版が無い、または文字でない場合は受け取らない", () => {
  for (const contractVersion of [undefined, null, 1]) {
    const parsed = parseThinkingRequest(createBody({ contractVersion }));

    assert(!parsed.ok, "受け取ってはいけない");

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
  }
});

Deno.test("振り返りのIDが無い、または空の場合は受け取らない", () => {
  for (const reflectionEntryId of [undefined, "", "   ", 7]) {
    const parsed = parseThinkingRequest(createBody({ reflectionEntryId }));

    assert(!parsed.ok, "受け取ってはいけない");

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
    assertEquals(parsed.requestId, "thinking-1");
  }
});

Deno.test("振り返りの入れ物が無い、または形が違う場合は受け取らない", () => {
  for (const reflection of [undefined, null, "text", [1, 2]]) {
    // 既定値へ落ちないよう、入れ物そのものを差し替える。
    const parsed = parseThinkingRequest({ ...createBody(), reflection });

    assert(!parsed.ok, "受け取ってはいけない");

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
  }
});

Deno.test("感じたこと・気づいたことの型が違う場合は受け取らない", () => {
  const wrongFeeling = parseThinkingRequest(
    createBody({}, { feelingText: 42, noticedText: "気づいたこと" }),
  );

  assert(!wrongFeeling.ok, "受け取ってはいけない");

  const wrongNoticed = parseThinkingRequest(
    createBody({}, {
      feelingText: "感じたこと",
      noticedText: ["気づいたこと"],
    }),
  );

  assert(!wrongNoticed.ok, "受け取ってはいけない");
});

Deno.test("どちらも空、または空白だけの場合は受け取らない", () => {
  const bothEmpty = parseThinkingRequest(
    createBody({}, { feelingText: "", noticedText: "" }),
  );

  assert(!bothEmpty.ok, "受け取ってはいけない");

  const whitespaceOnly = parseThinkingRequest(
    createBody({}, { feelingText: "   ", noticedText: "\n\t" }),
  );

  assert(!whitespaceOnly.ok, "受け取ってはいけない");

  const bothMissing = parseThinkingRequest(createBody({}, {}));

  assert(!bothMissing.ok, "受け取ってはいけない");
});

Deno.test("余分な項目は、確かめ終わった材料へ入らない", () => {
  const parsed = parseThinkingRequest(
    createBody({
      humanId: "local-human",
      provider: "some-provider",
      model: "some-model",
      systemPrompt: "あなたは...",
      journey: { plannedActionText: "30分トレーニングする" },
      calendar: ["10:00 - 12:00"],
      profile: { email: "someone@example.test" },
    }, {
      feelingText: "思ったより疲れていた",
      noticedText: null,
      extraNote: "余分な項目",
    }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  // 先へ渡るのはこの4つだけ。
  assertEquals(Object.keys(parsed.request).sort(), [
    "feelingText",
    "noticedText",
    "reflectionEntryId",
    "requestId",
  ]);

  const serialized = JSON.stringify(parsed.request);

  assert(!serialized.includes("local-human"), "humanIdは入らない");
  assert(!serialized.includes("some-provider"), "providerは入らない");
  assert(!serialized.includes("some-model"), "modelは入らない");
  assert(!serialized.includes("あなたは..."), "promptは入らない");
  assert(!serialized.includes("30分トレーニングする"), "歩みは入らない");
  assert(!serialized.includes("someone@example.test"), "profileは入らない");
  assert(!serialized.includes("余分な項目"), "余分な項目は入らない");
});
