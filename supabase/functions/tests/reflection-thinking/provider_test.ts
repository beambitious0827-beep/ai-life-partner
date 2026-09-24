import {
  ProviderUnavailableError,
  UnconfiguredAiThinkingProvider,
} from "../../reflection-thinking/provider.ts";
import { assert, assertEquals, assertRejects } from "./assert.ts";

Deno.test("未設定のProviderは、材料を作らずに失敗として返す", async () => {
  const provider = new UnconfiguredAiThinkingProvider();

  const error = await assertRejects(
    () =>
      provider.requestSupport({
        feelingText: "思ったより疲れていた",
        noticedText: null,
      }),
    "失敗として返るはず",
  );

  assert(
    error instanceof ProviderUnavailableError,
    "つながっていないことを表す失敗であるはず",
  );
});

Deno.test("失敗の内容に、Humanの言葉やsecretを含めない", async () => {
  const provider = new UnconfiguredAiThinkingProvider();

  const error = await assertRejects(
    () =>
      provider.requestSupport({
        feelingText: "PRIVATE_REFLECTION_MARKER",
        noticedText: "PRIVATE_REFLECTION_MARKER",
      }),
    "失敗として返るはず",
  );

  assertEquals(error.name, "ProviderUnavailableError");
  assert(
    !error.message.includes("PRIVATE_REFLECTION_MARKER"),
    "Humanの言葉は入らない",
  );
  assert(!/key|token|secret/i.test(error.message), "secretらしき語は入らない");
});
