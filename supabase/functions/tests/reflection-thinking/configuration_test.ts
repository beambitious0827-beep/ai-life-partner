/**
 * 設定が書き換わっていないことを見張るためのテスト。
 *
 * これはsecurity testではない。
 * ここで確かめているのは「設定ファイルにそう書いてある」ことだけであり、
 * 実際に未認証requestが止まることを確かめてはいない。
 * それはSupabaseのruntimeが動く場所でしか確かめられない。
 * 詳しくは docs/09_SupabaseEdgeRuntimeDesign.md の「まだできていないこと」を見る。
 */

import { assert, assertStringNotIncludes } from "./assert.ts";

function readRepoFile(relativePath: string): string {
  return Deno.readTextFileSync(
    new URL(`../../../${relativePath}`, import.meta.url),
  );
}

Deno.test("config.tomlで、JWTの検証を明示して有効にしている", () => {
  const config = readRepoFile("config.toml");

  assert(
    config.includes("[functions.reflection-thinking]"),
    "reflection-thinking の設定がある",
  );
  assert(
    config.includes("verify_jwt = true"),
    "verify_jwt = true と書いてある",
  );
  assertStringNotIncludes(
    config,
    "verify_jwt = false",
    "検証を切る設定は書かない",
  );
});

Deno.test("index.tsで、サインインしたHumanだけを通す設定にしている", () => {
  const source = readRepoFile("functions/reflection-thinking/index.ts");

  assert(source.includes("withSupabase"), "wrapperを通している");
  assert(source.includes('auth: "user"'), "auth は user である");
  assertStringNotIncludes(source, 'auth: "none"', "認証なしにはしない");
});

Deno.test("本番の配線に、デモや偽のProviderを混ぜない", () => {
  const source = readRepoFile("functions/reflection-thinking/index.ts");

  assert(
    source.includes("UnconfiguredAiThinkingProvider"),
    "未設定であることを示す実装を使う",
  );
  assertStringNotIncludes(
    source,
    "FakeAiThinkingProvider",
    "テスト用は使わない",
  );
  assertStringNotIncludes(source, "Demo", "デモの材料へ切り替えない");
});

Deno.test("受け取った内容を、そのままログへ出す書き方をしていない", () => {
  const sources = [
    "functions/reflection-thinking/index.ts",
    "functions/reflection-thinking/handler.ts",
    "functions/reflection-thinking/contract.ts",
    "functions/reflection-thinking/provider.ts",
    "functions/_shared/http.ts",
    "functions/_shared/log.ts",
  ];

  const forbidden = [
    "console.log(req",
    "console.log(await req",
    "console.log(body",
    "console.log(payload",
    "console.log(input",
    "console.log(feelingText",
    "console.log(noticedText",
    "console.error(",
    "JSON.stringify(req",
  ];

  for (const path of sources) {
    const source = readRepoFile(path);

    for (const pattern of forbidden) {
      assertStringNotIncludes(source, pattern, `${path} に危うい書き方がある`);
    }
  }
});

Deno.test("sourceにsecretらしき値を置いていない", () => {
  const sources = [
    "config.toml",
    "functions/reflection-thinking/index.ts",
    "functions/reflection-thinking/handler.ts",
    "functions/reflection-thinking/provider.ts",
    "functions/_shared/http.ts",
    "functions/_shared/log.ts",
  ];

  for (const path of sources) {
    const source = readRepoFile(path);

    assertStringNotIncludes(source, "sk-", `${path} にAPI keyらしき値がある`);
    assertStringNotIncludes(source, "OPENAI_API_KEY", `${path}`);
    assertStringNotIncludes(source, "ANTHROPIC_API_KEY", `${path}`);
    assertStringNotIncludes(source, "SUPABASE_SECRET_KEY", `${path}`);
  }
});
