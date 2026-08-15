/**
 * Rest guidance — the single place a resolved rest value becomes BOTH the label
 * and the countdown.
 *
 * The seconds handed in are already resolved as
 * `coalesce(template_exercises.rest_seconds, exercises.rest_seconds)`; that
 * happens in `src/lib/session-detail.ts`. This module never reads either column.
 *
 * Why one function returns both: they used to be computed independently and
 * drifted. A superset member rendered a hardcoded "~60–90s" while the timer ran
 * whatever the exercise default happened to be — 150s for
 * `B-stance / single-leg RDL (heavier)`, which is what CJ logged as "Timer is
 * very long". Returning `text` and `countdownSeconds` from one call makes that
 * class of bug unrepresentable: a new branch sets both or neither.
 *
 * The label must always bracket the countdown. `formatRestSeconds` guarantees
 * this by construction — see the note on it.
 */

/** Where a card sits inside a superset pair, for rest purposes. */
export type PairPosition =
  /** Not in a superset block, or a lone member with no partner. */
  | { kind: "none" }
  /**
   * A leading member (A1 of A1/A2). You go straight into the partner, so this
   * card starts no countdown at all — the rest belongs after the pair.
   */
  | { kind: "leading"; nextLabel: string }
  /** The final member (A2 of A1/A2). Its rest covers the whole pair. */
  | { kind: "final"; labels: string[] };

export type RestGuidance = {
  /** The line to render, e.g. "Rest ~2 min" or "Straight into A2 — no rest". */
  text: string;
  /**
   * Seconds the countdown runs when this card's last set is checked, or null
   * when this card starts no timer. Null is a real state, not "unknown": a
   * leading superset member deliberately has no rest after it.
   */
  countdownSeconds: number | null;
};

/**
 * Builds the rest line and the countdown for a card. Returns null only when no
 * rest value resolved at all — which should not happen in an active block, where
 * every slot resolves to a number.
 */
export function formatRest(
  restSeconds: number | null,
  pair: PairPosition = { kind: "none" },
): RestGuidance | null {
  if (restSeconds == null) return null;

  // Leading member: no rest between the halves of a pair. The value still
  // resolves to a number upstream; we deliberately do not count it down.
  if (pair.kind === "leading") {
    return {
      text: `Straight into ${pair.nextLabel} — no rest`,
      countdownSeconds: null,
    };
  }

  if (pair.kind === "final") {
    return {
      text: `Rest ${formatRestSeconds(restSeconds)} after ${pair.labels.join("+")}`,
      countdownSeconds: restSeconds,
    };
  }

  return {
    text: `Rest ${formatRestSeconds(restSeconds)}`,
    countdownSeconds: restSeconds,
  };
}

/**
 * Seconds → a label that always contains the value it describes.
 *
 * Anything at or below 90s is shown exactly, so there is nothing to bracket.
 * Above that we switch to minutes: whole minutes render exactly ("~2 min"), and
 * anything in between renders the minute range that straddles it ("~2–3 min"
 * for 150s). The previous version bucketed 90–149s all to "~90s", which made the
 * label disagree with a 120s countdown.
 */
function formatRestSeconds(seconds: number): string {
  if (seconds <= 90) return `~${seconds}s`;
  if (seconds % 60 === 0) return `~${seconds / 60} min`;
  const lo = Math.floor(seconds / 60);
  return `~${lo}–${lo + 1} min`;
}
