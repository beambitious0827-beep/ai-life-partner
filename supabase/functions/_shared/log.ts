/**
 * ログの決まりごと。
 *
 * 振り返りの本文はHumanのprivate contentである。
 * ログへ出してよいのは、追跡ID・結果の種類・status・所要時間だけ。
 *
 * 出してはいけないもの：
 * feelingText / noticedText / 生成された材料の本文 /
 * Authorization header / JWT / request payload全文 / provider secret。
 *
 * requestやpayloadをそのまま渡せる関数は、ここに用意しない。
 * 渡せる形にしておくと、いつか渡してしまうためである。
 */

export type ThinkingLogEvent = {
  /** 追跡のためのID。取り出せなかった場合はnull。 */
  readonly requestId: string | null;
  /** 何が起きたかの分類。Humanの言葉は含まない。 */
  readonly outcome: string;
  readonly status: number;
  readonly durationMs: number;
};

/**
 * ログ1行を組み立てる。
 *
 * 組み立てだけを切り出してあるので、
 * 何が出るのかをテストから確かめられる。
 */
export function formatThinkingLogEvent(event: ThinkingLogEvent): string {
  return JSON.stringify({
    fn: "reflection-thinking",
    requestId: event.requestId,
    outcome: event.outcome,
    status: event.status,
    durationMs: event.durationMs,
  });
}
