/**
 * reflection-thinking Edge Function.
 *
 *     POST https://<project-ref>.supabase.co/functions/v1/reflection-thinking
 *
 * サインインしたHumanだけが呼べる。
 * 認証は `withSupabase({ auth: "user" })` が行い、
 * CORSとpreflightもそのwrapperに任せる。自前では持たない。
 *
 * ここは配線だけの場所である。
 * 受け取った内容の確認も、Providerとのやり取りも handler.ts が行う。
 *
 * まだAI Providerへはつないでいない。
 * `UnconfiguredAiThinkingProvider` は呼ばれたら失敗として返す。
 * デモの材料へ黙って切り替えることはしない。
 */

import { withSupabase } from "npm:@supabase/server@^1";

import { handleReflectionThinking } from "./handler.ts";
import { UnconfiguredAiThinkingProvider } from "./provider.ts";

const provider = new UnconfiguredAiThinkingProvider();

export default {
  fetch: withSupabase(
    { auth: "user" },
    // 認証済みの身元はwrapperが確かめている。
    // その中身（email・名前など）はAIの処理へ使わない。
    // 振り返りの所有権はserver側でまだ確かめられないため、
    // reflectionEntryId を「確認済み」として扱わない。
    (req: Request) => handleReflectionThinking(req, { provider }),
  ),
};
