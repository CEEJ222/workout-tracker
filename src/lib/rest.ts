/**
 * Suggested-rest formatting — the single place the seconds → label logic lives.
 *
 * Display only: this turns the stored `exercises.rest_seconds` into the static
 * guidance line shown on each exercise card. There is no timer here. A live
 * countdown is a separate, later phase; keep timing logic out of this module.
 *
 * Roles map to seconds in the seed (primary 150, superset 75, accessory 90,
 * cuff/scapular/core/carry/balance 45, warm-up null).
 */

export type RestGuidance = {
  /** The line to render, e.g. "Rest ~2–3 min" or "Alternate A1/A2 · ~60–90s". */
  text: string;
  /** True for superset "alternate" rest (the partner set is the rest). */
  alternate: boolean;
};

/**
 * Builds the rest line for a card. Returns null when no line should show
 * (rest_seconds is null — the warm-up circuit).
 *
 * For a superset member, pass the block's pair labels (e.g. ["A1", "A2"]) and
 * the rest is rendered as "alternate" guidance instead of a flat rest value —
 * the rest between paired movements is the partner's working set.
 */
export function formatRest(
  restSeconds: number | null,
  supersetLabels?: string[] | null,
): RestGuidance | null {
  if (restSeconds == null) return null;

  if (supersetLabels && supersetLabels.length >= 2) {
    return {
      text: `Alternate ${supersetLabels.join("/")} · ~60–90s`,
      alternate: true,
    };
  }

  return { text: `Rest ${formatRestSeconds(restSeconds)}`, alternate: false };
}

/** Seconds → a human, slightly-rounded rest label. */
function formatRestSeconds(seconds: number): string {
  if (seconds >= 150) return "~2–3 min";
  if (seconds >= 90) return "~90s";
  if (seconds >= 60) return "~60–90s";
  return `~${seconds}s`;
}
