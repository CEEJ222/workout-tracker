import Link from "next/link";
import type { SessionSummary } from "@/lib/session-summary";

/**
 * A number and what it counts. Numbers are the interface here, so the value
 * leads at 18px in primary text and the label sits under it, small and muted —
 * hierarchy from size and weight rather than from colour.
 */
export function Stat({
  value,
  label,
}: {
  value: string | number;
  label: string;
}) {
  return (
    <div className="min-w-0">
      <div className="truncate text-[18px] font-medium leading-tight tabular-nums text-ink">
        {value}
      </div>
      <div className="mt-0.5 truncate text-[12px] text-ink-3">{label}</div>
    </div>
  );
}

/**
 * One completed session, summarized on the card rather than behind a tap.
 *
 * Shared by the homepage's "your last workout" and the history list, which are
 * the same object shown twice. The only differences are how the date reads —
 * relative on the homepage where "yesterday" is the useful framing, absolute in
 * history where you are scanning a timeline — and what the footer action says.
 * Both are props rather than two components.
 */
export function SessionSummaryCard({
  summary,
  dateLabel,
  actionLabel,
  showDayNumber = false,
}: {
  summary: SessionSummary;
  dateLabel: string;
  actionLabel: string;
  /** History lists many days, so it needs the "Day 2" prefix to tell them apart. */
  showDayNumber?: boolean;
}) {
  const [day, focus] = splitName(summary.dayName);

  return (
    <div className="rounded-card bg-card px-4 py-4">
      <div className="flex items-baseline justify-between gap-3">
        <div className="min-w-0">
          {showDayNumber && day && (
            <div className="text-[11px] uppercase tracking-[0.06em] text-ink-3">
              {day}
            </div>
          )}
          <div className="truncate text-[15px] font-medium text-ink">
            {focus}
          </div>
        </div>
        <div className="shrink-0 text-[12px] text-ink-3">{dateLabel}</div>
      </div>

      {/* No duration: see getSessionSummaries. */}
      <div className="mt-3.5 flex gap-7 border-t border-line pt-3.5">
        <Stat value={summary.setsDone} label="sets" />
        <Stat
          value={
            summary.averageRir != null ? summary.averageRir.toFixed(1) : "—"
          }
          label="avg RIR"
        />
        {/* "heavier", not "progressed": this counts lifts that went up against
            their own last session, which is a fact. Progression is a claim
            about a trend, and the stall detection that would justify it is
            deliberately not built (see CLAUDE.md). */}
        <Stat value={summary.loadsIncreased} label="heavier" />
      </div>

      {/* Load direction is one of the two things colour is spent on, so it goes
          on the numerals themselves — not a tinted panel behind them. The
          exercise name stays neutral: it isn't the signal. */}
      {summary.biggestGain && (
        <div className="mt-3 text-[12px] text-ink-2">
          <span className="text-ink">{summary.biggestGain.exerciseName}</span>{" "}
          <span className="tabular-nums text-up">
            {formatWeight(summary.biggestGain.from)} →{" "}
            {formatWeight(summary.biggestGain.to)} lb
          </span>
        </div>
      )}

      {/* Pain is the other. A count is not a severity, so this stays neutral —
          the severity itself is coloured on the Pain tab, where it is named. */}
      {summary.painFlags > 0 && (
        <div className="mt-1.5 text-[12px] text-ink-3">
          {summary.painFlags} pain flag{summary.painFlags > 1 ? "s" : ""}
        </div>
      )}

      <Link
        href={`/session/${summary.sessionId}`}
        className="mt-4 block w-full rounded-lg border border-line px-4 py-2.5 text-center text-[13px] text-ink-2"
      >
        {actionLabel}
      </Link>
    </div>
  );
}

/** "Day A · Hinge" → ["Day A", "Hinge"]; falls back to the whole name. */
function splitName(name: string): [string, string] {
  const parts = name.split("·").map((s) => s.trim());
  if (parts.length >= 2) {
    return [parts[0], parts.slice(1).join(" · ")];
  }
  return ["", name];
}

function formatWeight(lb: number): string {
  return Number.isInteger(lb) ? String(lb) : lb.toFixed(1);
}
