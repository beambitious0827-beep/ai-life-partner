/**
 * テストのための、小さな確認関数。
 *
 * 外部のpackageを持ち込まずに済むよう、必要な分だけをここへ置く。
 * ネットワークが無い場所でも `deno test` がそのまま動くようにするためである。
 */

export function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

export function assertEquals<T>(
  actual: T,
  expected: T,
  message?: string,
): void {
  const actualText = JSON.stringify(actual);
  const expectedText = JSON.stringify(expected);

  if (actualText !== expectedText) {
    throw new Error(
      `${
        message ?? "値が違います"
      }: expected ${expectedText}, got ${actualText}`,
    );
  }
}

export function assertStringNotIncludes(
  haystack: string,
  needle: string,
  message?: string,
): void {
  if (haystack.includes(needle)) {
    throw new Error(
      `${message ?? "含まれてはいけない文字列があります"}: ${needle}`,
    );
  }
}

export async function assertRejects(
  fn: () => Promise<unknown>,
  message: string,
): Promise<Error> {
  try {
    await fn();
  } catch (error) {
    return error instanceof Error ? error : new Error(String(error));
  }

  throw new Error(message);
}
