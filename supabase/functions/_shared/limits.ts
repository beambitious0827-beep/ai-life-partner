/**
 * 受け取ってよい大きさの上限。
 *
 * 数字をあちこちへ書き写さないよう、ここ1か所に置く。
 * server側の実装も、テストも、この値を読む。
 *
 * ふたつの数え方が混ざっているので、名前で区別する。
 *
 * - body は **UTF-8のbyte数**。ネットワークから届いた量そのもの。
 * - 各項目は **UTF-16 code unit数**（JavaScriptの `String.length`）。
 *   decodeしたあとの文字列の長さ。
 *
 * 同じ「長さ」でも数える対象が違う。取り違えない。
 */

/**
 * request body全体の上限。32 KiB。
 *
 * JSONへ展開する前に、この量で打ち切る。
 * Providerへつないでいなくても、大きなbodyを読むこと自体に費用がかかる。
 */
export const MAX_REQUEST_BODY_BYTES = 32768;

/**
 * 追跡IDの上限。UTF-16 code unit。
 *
 * Flutter側が作る `thinking-<micros>-<seq>` は、
 * 十分にこの中へ収まる。
 */
export const MAX_REQUEST_ID_LENGTH = 64;

/**
 * 追跡IDに許す形。
 *
 * 追跡のためだけのIDなので、英数字と `-` `_` だけで足りる。
 * Humanの言葉が紛れ込む余地を残さない。
 */
export const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/**
 * 振り返りのIDの上限。UTF-16 code unit。
 *
 * 形の制限はPhase 12では加えない。
 * clientが作るIDの形がまだ定まっていないためである。
 */
export const MAX_REFLECTION_ENTRY_ID_LENGTH = 128;

/** 振り返りの言葉ひとつあたりの上限。UTF-16 code unit。 */
export const MAX_REFLECTION_TEXT_LENGTH = 4000;
