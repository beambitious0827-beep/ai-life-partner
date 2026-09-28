import {
  CONTRACT_VERSION,
  parseThinkingRequest,
} from "../../reflection-thinking/contract.ts";
import {
  MAX_REFLECTION_ENTRY_ID_LENGTH,
  MAX_REFLECTION_TEXT_LENGTH,
  MAX_REQUEST_ID_LENGTH,
} from "../../_shared/limits.ts";
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

Deno.test("振り返りの言葉の前後の空白は落としてから先へ渡す", () => {
  const parsed = parseThinkingRequest(
    createBody({}, {
      feelingText: "  思ったより疲れていた  ",
      noticedText: null,
    }),
  );

  assert(parsed.ok, "受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.feelingText, "思ったより疲れていた");
});

Deno.test("追跡IDは、空白を落とさずそのままの形で確かめる", () => {
  // 落としてから確かめると、空白を含むIDが通ってしまう。
  // 通ったIDは応答とログへそのまま載るので、はじめから受け取らない。
  for (
    const requestId of [
      "  thinking-1  ",
      "thinking 1",
      "\tthinking-1",
      "thinking-1\n",
    ]
  ) {
    const parsed = parseThinkingRequest(createBody({ requestId }));

    assert(!parsed.ok, `受け取ってはいけない: ${JSON.stringify(requestId)}`);

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
    assertEquals(parsed.requestId, null);
  }
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

// ---------------------------------------------------------------------------
// 大きさの上限。
//
// 数えるのはUTF-16 code unit（JavaScriptの `String.length`）。
// 字の見た目の数ではない。絵文字はひとつで2になる。
// ---------------------------------------------------------------------------

/** 指定した長さちょうどの、形の通る追跡IDを作る。 */
function requestIdOfLength(length: number): string {
  return "a".repeat(length);
}

Deno.test("追跡IDは64文字まで受け取る", () => {
  const requestId = requestIdOfLength(MAX_REQUEST_ID_LENGTH);

  assertEquals(requestId.length, 64);

  const parsed = parseThinkingRequest(createBody({ requestId }));

  assert(parsed.ok, "64文字は受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.requestId, requestId);
});

Deno.test("追跡IDが65文字なら受け取らない", () => {
  const requestId = requestIdOfLength(MAX_REQUEST_ID_LENGTH + 1);

  assertEquals(requestId.length, 65);

  const parsed = parseThinkingRequest(createBody({ requestId }));

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "invalid_request");
  // 形も長さも確かめ終わっていないIDを、応答へ持ち出さない。
  assertEquals(parsed.requestId, null);
});

Deno.test("追跡IDに使えない文字が混じっていたら受け取らない", () => {
  for (
    const requestId of [
      "thinking/1",
      "thinking.1",
      "thinking:1",
      "thinking+1",
      "thinking#1",
      "振り返り-1",
      "thinking-1\u0000",
      "<script>",
    ]
  ) {
    const parsed = parseThinkingRequest(createBody({ requestId }));

    assert(!parsed.ok, `受け取ってはいけない: ${JSON.stringify(requestId)}`);

    if (parsed.ok) continue;

    assertEquals(parsed.code, "invalid_request");
    assertEquals(parsed.requestId, null);
  }
});

Deno.test("Flutterが作る追跡IDの形は、そのまま通る", () => {
  // ServerReflectionThinkingAssistant.generateRequestId() が作る形。
  //   'thinking-${DateTime.now().microsecondsSinceEpoch}-$_idSequence'
  for (
    const requestId of [
      "thinking-1786991056963000-1",
      "thinking-1790278503609123-42",
      "thinking-0-0",
    ]
  ) {
    assert(
      requestId.length <= MAX_REQUEST_ID_LENGTH,
      "Flutterが作る形は上限に収まる",
    );

    const parsed = parseThinkingRequest(createBody({ requestId }));

    assert(parsed.ok, `受け取れるはず: ${requestId}`);

    if (!parsed.ok) continue;

    assertEquals(parsed.request.requestId, requestId);
  }
});

Deno.test("振り返りのIDは128文字まで受け取る", () => {
  const reflectionEntryId = "r".repeat(MAX_REFLECTION_ENTRY_ID_LENGTH);

  assertEquals(reflectionEntryId.length, 128);

  const parsed = parseThinkingRequest(createBody({ reflectionEntryId }));

  assert(parsed.ok, "128文字は受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.reflectionEntryId, reflectionEntryId);
});

Deno.test("振り返りのIDが129文字なら受け取らない", () => {
  const reflectionEntryId = "r".repeat(MAX_REFLECTION_ENTRY_ID_LENGTH + 1);

  assertEquals(reflectionEntryId.length, 129);

  const parsed = parseThinkingRequest(createBody({ reflectionEntryId }));

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "invalid_request");
  // 追跡IDは確かめ終わっているので、こちらは返せる。
  assertEquals(parsed.requestId, "thinking-1");
});

Deno.test("振り返りのIDに、形の制限はまだ加えない", () => {
  // Phase 12では長さと非空だけを見る。
  const reflectionEntryId = "reflection/2026-09-28#1 のようなIDも通る";

  const parsed = parseThinkingRequest(createBody({ reflectionEntryId }));

  assert(parsed.ok, "受け取れるはず");
});

Deno.test("感じたことは4000文字まで受け取る", () => {
  const feelingText = "あ".repeat(MAX_REFLECTION_TEXT_LENGTH);

  assertEquals(feelingText.length, 4000);

  const parsed = parseThinkingRequest(
    createBody({}, { feelingText, noticedText: null }),
  );

  assert(parsed.ok, "4000文字は受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.feelingText?.length, 4000);
});

Deno.test("感じたことが4001文字なら受け取らない", () => {
  const feelingText = "あ".repeat(MAX_REFLECTION_TEXT_LENGTH + 1);

  assertEquals(feelingText.length, 4001);

  const parsed = parseThinkingRequest(
    createBody({}, { feelingText, noticedText: null }),
  );

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "invalid_request");
  assertEquals(parsed.requestId, "thinking-1");
});

Deno.test("気づいたことは4000文字まで受け取る", () => {
  const noticedText = "い".repeat(MAX_REFLECTION_TEXT_LENGTH);

  assertEquals(noticedText.length, 4000);

  const parsed = parseThinkingRequest(
    createBody({}, { feelingText: null, noticedText }),
  );

  assert(parsed.ok, "4000文字は受け取れるはず");

  if (!parsed.ok) return;

  assertEquals(parsed.request.noticedText?.length, 4000);
});

Deno.test("気づいたことが4001文字なら受け取らない", () => {
  const noticedText = "い".repeat(MAX_REFLECTION_TEXT_LENGTH + 1);

  assertEquals(noticedText.length, 4001);

  const parsed = parseThinkingRequest(
    createBody({}, { feelingText: null, noticedText }),
  );

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "invalid_request");
});

Deno.test("空白だけの4001文字も、空白を落とす前に断る", () => {
  // trimしてから長さを見ると、4001文字が0文字として通ってしまう。
  // 長さを見るのは、落とす前でなければならない。
  const feelingText = " ".repeat(MAX_REFLECTION_TEXT_LENGTH + 1);

  assertEquals(feelingText.length, 4001);

  const parsed = parseThinkingRequest(
    createBody({}, { feelingText, noticedText: "気づいたこと" }),
  );

  assert(!parsed.ok, "受け取ってはいけない");

  if (parsed.ok) return;

  assertEquals(parsed.code, "invalid_request");
});

Deno.test("空白だけの4000文字は、長さは通るが中身が無いものとして扱う", () => {
  // 上限そのものは超えていない。
  // それでも、書かれた言葉がひとつも無ければ受け取らない。
  const feelingText = " ".repeat(MAX_REFLECTION_TEXT_LENGTH);

  assertEquals(feelingText.length, 4000);

  const bothBlank = parseThinkingRequest(
    createBody({}, { feelingText, noticedText: "   " }),
  );

  assert(!bothBlank.ok, "受け取ってはいけない");

  if (bothBlank.ok) return;

  assertEquals(bothBlank.code, "invalid_request");

  // 片方に言葉があれば、これまでどおり受け取る。
  const oneWritten = parseThinkingRequest(
    createBody({}, { feelingText, noticedText: "気づいたこと" }),
  );

  assert(oneWritten.ok, "受け取れるはず");

  if (!oneWritten.ok) return;

  assertEquals(oneWritten.request.feelingText, null);
  assertEquals(oneWritten.request.noticedText, "気づいたこと");
});

Deno.test("長さはUTF-16 code unitで数える", () => {
  // 絵文字ひとつは、見た目は1文字でもcode unitでは2になる。
  // 見た目の数へ勝手に読み替えない。
  const emoji = "😀";

  assertEquals(emoji.length, 2);

  const justFits = emoji.repeat(MAX_REFLECTION_TEXT_LENGTH / 2);

  assertEquals(justFits.length, 4000);

  const fitting = parseThinkingRequest(
    createBody({}, { feelingText: justFits, noticedText: null }),
  );

  assert(fitting.ok, "4000 code unitは受け取れるはず");

  // 絵文字をひとつ足すと4002になり、上限を超える。
  const tooLong = justFits + emoji;

  assertEquals(tooLong.length, 4002);

  const overflowing = parseThinkingRequest(
    createBody({}, { feelingText: tooLong, noticedText: null }),
  );

  assert(!overflowing.ok, "受け取ってはいけない");

  if (overflowing.ok) return;

  assertEquals(overflowing.code, "invalid_request");

  // 見た目は2001文字。code unitで数えていなければ、これは通ってしまう。
  assertEquals([...tooLong].length, 2001);
});
