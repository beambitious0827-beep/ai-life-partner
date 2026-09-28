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
    "functions/_shared/limited_json.ts",
    "functions/_shared/limits.ts",
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
    // bodyの一部を持ち出す書き方も置かない。
    ".slice(0, 100)",
    "preview",
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
    "functions/_shared/limited_json.ts",
    "functions/_shared/limits.ts",
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

Deno.test("handlerがbodyを無制限に展開していない", () => {
  // 説明のために名前を書くことはある。見たいのは実際に呼んでいるかどうかなので、
  // 注釈の行は除いてから確かめる。
  const code = readRepoFile("functions/reflection-thinking/handler.ts")
    .split("\n")
    .filter((line) => {
      const trimmed = line.trim();

      return !trimmed.startsWith("//") && !trimmed.startsWith("*") &&
        !trimmed.startsWith("/*");
    })
    .join("\n");

  // `req.json()` はbodyを最後まで読んでから展開する。
  // 上限を設けたあとで、これが戻ってきていないことを見張る。
  for (
    const forbidden of [
      "req.json()",
      "req.text()",
      "req.arrayBuffer()",
      "req.blob()",
      "req.formData()",
    ]
  ) {
    assertStringNotIncludes(code, forbidden, "上限なしの読み取りが戻っている");
  }

  assert(code.includes("readLimitedJson"), "上限つきの読み取りを通している");
});

Deno.test("上限の値は、1か所にまとめてある", () => {
  const limits = readRepoFile("functions/_shared/limits.ts");

  for (
    const name of [
      "MAX_REQUEST_BODY_BYTES",
      "MAX_REQUEST_ID_LENGTH",
      "REQUEST_ID_PATTERN",
      "MAX_REFLECTION_ENTRY_ID_LENGTH",
      "MAX_REFLECTION_TEXT_LENGTH",
    ]
  ) {
    assert(limits.includes(`export const ${name}`), `${name} がある`);
  }

  // 使う側は、数字を書き写さずにここから読む。
  for (
    const path of [
      "functions/reflection-thinking/contract.ts",
      "functions/_shared/limited_json.ts",
    ]
  ) {
    const source = readRepoFile(path);

    assert(
      source.includes('from "../_shared/limits.ts"') ||
        source.includes('from "./limits.ts"'),
      `${path} は上限をlimits.tsから読む`,
    );
    assertStringNotIncludes(source, "32768", `${path} に数字が写されている`);
    assertStringNotIncludes(source, "4000", `${path} に数字が写されている`);
    assertStringNotIncludes(source, "128", `${path} に数字が写されている`);
  }
});
