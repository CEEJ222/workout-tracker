import Link from "next/link";
import { requireUser } from "@/lib/auth/session";
import { logout } from "@/lib/auth/actions";
import {
  getMesocycles,
  getActiveMesocycleId,
  getDayRotation,
  getWorkoutPlan,
  getLastWorkout,
  getInProgressSessions,
  getThemePreference,
  rankDays,
  type DayRotation,
} from "@/lib/queries";
import { ThemeToggle } from "@/app/theme-toggle";
import { startSession } from "@/app/actions/session";
import { DiscardButton } from "@/app/discard-button";
import { BlockSwitcher } from "@/app/block-switcher";
import { DayPicker, type PickerDay } from "@/app/day-picker";

export default async function Home() {
  await requireUser();
  const [mesocycles, activeMesocycleId, inProgress, theme] = await Promise.all([
    getMesocycles(),
    getActiveMesocycleId(),
    getInProgressSessions(),
    getThemePreference(),
  ]);

  // The active block's days — however many it has. Block A ran 3, Block C runs
  // 4; nothing here assumes a count.
  const rotation = await getDayRotation(activeMesocycleId);
  const ranked = rankDays(rotation);
  const recommended = ranked[0] ?? null;

  // A block nobody has trained yet is a real state, not an edge case: every day
  // ties at zero, so no staleness reason exists to show. Betsy's Block C sits
  // here today. The page answers differently rather than dressing up a tie.
  const coldStart =
    rotation.length > 0 && rotation.every((d) => d.completedCount === 0);

  const [plan, lastWorkout] = await Promise.all([
    recommended ? getWorkoutPlan(recommended.id) : null,
    coldStart ? null : getLastWorkout(rotation.map((d) => d.id)),
  ]);

  const blockName =
    mesocycles.find((m) => m.id === activeMesocycleId)?.name ?? "Training block";

  const otherDays: PickerDay[] = ranked
    .filter((d) => d.id !== recommended?.id)
    .map((d) => {
      const [day, focus] = splitName(d.name);
      return { id: d.id, day, focus, meta: dayMeta(d) };
    });

  const [recommendedDay, recommendedFocus] = recommended
    ? splitName(recommended.name)
    : ["", ""];

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 z-10 flex items-start justify-between gap-3 border-b border-line bg-card px-[18px] pb-3.5 pt-4">
        <div className="min-w-0">
          <div className="text-[11px] uppercase tracking-[0.06em] text-ink-3">
            Training block
          </div>
          {/* Static text, not tabs. Each athlete has exactly one unarchived
              block, so tabs offered a choice that never existed. */}
          <h1 className="mt-0.5 text-[17px] font-medium leading-snug tracking-[-0.01em]">
            {blockName}
          </h1>
        </div>
        <div className="flex shrink-0 items-center gap-1.5">
          <ThemeToggle current={theme} />
          <Link
            href="/history"
            className="rounded-lg border border-line bg-field px-2.5 py-1.5 text-[12px] text-ink-2"
          >
            History
          </Link>
          <form action={logout}>
            <button
              type="submit"
              className="rounded-lg border border-line bg-field px-2.5 py-1.5 text-[12px] text-ink-2"
            >
              Sign out
            </button>
          </form>
        </div>
      </header>

      <main className="flex flex-1 flex-col gap-2.5 px-3 py-4">
        {inProgress.length > 0 && (
          <section className="flex flex-col gap-2">
            <div className="mx-1.5 text-[11px] uppercase tracking-[0.06em] text-ink-3">
              In progress
            </div>
            {inProgress.map((s) => {
              const name = s.workout_templates?.name ?? "Workout";
              // A single-sided rule, not a tinted panel: urgency here is
              // positional (it sits at the top) and structural, so it does not
              // need to spend a colour. Left borders are never rounded — a
              // radius on one side reads as a rendering mistake.
              return (
                <div
                  key={s.id}
                  className="flex items-center justify-between gap-2 border-l-2 border-ink py-1 pl-3.5 pr-1"
                >
                  <Link href={`/session/${s.id}`} className="min-w-0 flex-1">
                    <div className="text-[15px] font-medium text-ink">
                      {name}
                    </div>
                    <div className="mt-0.5 text-[12px] text-ink-3">
                      Started {formatDate(s.started_at)}
                    </div>
                  </Link>
                  <div className="flex shrink-0 items-center gap-2">
                    <Link
                      href={`/session/${s.id}`}
                      className="text-[13px] text-ink-2"
                    >
                      Resume →
                    </Link>
                    <DiscardButton sessionId={s.id} label={name} />
                  </div>
                </div>
              );
            })}
          </section>
        )}

        {/* Only a real choice gets a control. One block means no switcher. */}
        {mesocycles.length > 1 && (
          <BlockSwitcher
            mesocycles={mesocycles}
            activeId={activeMesocycleId}
            hasInProgress={inProgress.length > 0}
          />
        )}

        {recommended && plan && (
          <section className="mt-1 flex flex-col gap-2">
            <div className="mx-1.5 text-[11px] uppercase tracking-[0.06em] text-ink-3">
              Your next workout
            </div>
            {/* Separation by surface fill, not by an outline. A 2px ring is a
                second visual system competing with the one filled button; the
                fill says "this one" quietly enough. */}
            <div className="rounded-card bg-card px-4 py-4">
              {recommendedDay && (
                <div className="text-[11px] uppercase tracking-[0.06em] text-ink-3">
                  {recommendedDay}
                </div>
              )}
              <div className="mt-1 text-[22px] font-medium leading-tight tracking-[-0.01em] text-ink">
                {recommendedFocus}
              </div>

              {/* Never recommend silently. Without the reason this is just a
                  sorted list wearing a heavier weight. */}
              <div className="mt-1.5 text-[12px] text-ink-2">
                {recommendationReason(recommended, rotation, coldStart)}
              </div>

              <div className="mt-3.5 border-t border-line pt-3.5">
                {coldStart ? (
                  // No history to count against, so lead with the lift and the
                  // number they'll be asked to put on the bar.
                  plan.firstExercise ? (
                    <div className="flex gap-7">
                      {plan.firstExercise.seedWeight != null && (
                        <Stat
                          value={`${formatWeight(plan.firstExercise.seedWeight)} lb`}
                          label="to start"
                        />
                      )}
                      <Stat value={plan.firstExercise.name} label="first lift" />
                    </div>
                  ) : (
                    <div className="text-[12px] text-ink-3">
                      Ready when you are.
                    </div>
                  )
                ) : (
                  <div className="flex gap-7">
                    <Stat value={plan.exerciseCount} label="exercises" />
                    <Stat value={plan.totalTargetSets} label="sets" />
                    {plan.firstExercise && (
                      <Stat
                        value={plan.firstExercise.name}
                        label="starts with"
                      />
                    )}
                  </div>
                )}
              </div>

              {/* The one filled button on the screen. Everything else is a text
                  link or a hairline row, so this needs no colour to be found. */}
              <form action={startSession} className="mt-4">
                <input type="hidden" name="templateId" value={recommended.id} />
                <button
                  type="submit"
                  className="w-full rounded-lg bg-ink px-4 py-3 text-[15px] font-medium text-on-ink active:opacity-90"
                >
                  Start workout
                </button>
              </form>
            </div>
          </section>
        )}

        <DayPicker days={otherDays} />

        {lastWorkout && (
          <section className="mt-1 flex flex-col gap-2">
            <div className="mx-1.5 text-[11px] uppercase tracking-[0.06em] text-ink-3">
              Your last workout
            </div>
            <div className="rounded-card bg-card px-4 py-4">
              <div className="flex items-baseline justify-between gap-3">
                <div className="min-w-0 text-[15px] font-medium text-ink">
                  {splitName(lastWorkout.dayName)[1]}
                </div>
                <div className="shrink-0 text-[12px] text-ink-3">
                  {relativeDay(lastWorkout.completedAt)}
                </div>
              </div>

              {/* Backward-looking counterpart to the next-up stats. No duration:
                  see getLastWorkout. */}
              <div className="mt-3.5 flex gap-7 border-t border-line pt-3.5">
                <Stat value={lastWorkout.setsDone} label="sets" />
                <Stat
                  value={
                    lastWorkout.averageRir != null
                      ? lastWorkout.averageRir.toFixed(1)
                      : "—"
                  }
                  label="avg RIR"
                />
                <Stat
                  value={lastWorkout.loadsIncreased}
                  label={lastWorkout.loadsIncreased === 1 ? "load up" : "loads up"}
                />
              </div>

              {/* Load direction is one of the two things colour is spent on, so
                  it goes on the numerals themselves — not a tinted panel behind
                  them. The exercise name stays neutral: it isn't the signal. */}
              {lastWorkout.biggestGain && (
                <div className="mt-3 text-[12px] text-ink-2">
                  <span className="text-ink">
                    {lastWorkout.biggestGain.exerciseName}
                  </span>{" "}
                  <span className="tabular-nums text-up">
                    {formatWeight(lastWorkout.biggestGain.from)} →{" "}
                    {formatWeight(lastWorkout.biggestGain.to)} lb
                  </span>
                </div>
              )}

              {/* "View session", not "repeat": offering to redo the last
                  workout would pull against the rotation the hero just
                  recommended. */}
              <Link
                href={`/session/${lastWorkout.sessionId}`}
                className="mt-4 block w-full rounded-lg border border-line px-4 py-2.5 text-center text-[13px] text-ink-2"
              >
                View session
              </Link>
            </div>
          </section>
        )}

        {coldStart && (
          <section className="mt-1 flex flex-col gap-2">
            <div className="mx-1.5 text-[11px] uppercase tracking-[0.06em] text-ink-3">
              Progress
            </div>
            <div className="rounded-card bg-card px-4 py-4 text-[12px] leading-relaxed text-ink-2">
              No sessions yet. Trends appear after your first few workouts.
            </div>
          </section>
        )}

        {/* Progressing/stalled counts and the volume-imbalance callout belong
            here, and are deliberately not built yet. Stall detection has real
            confounders (documented in CLAUDE.md — mixed-convention weight
            history and increment_lb being a snapshot rather than a rule), and a
            bare count with no exercise names is not something anyone can act
            on. Left out rather than shipped misleading. */}
      </main>
    </div>
  );
}

/**
 * A number and what it counts. Numbers are the interface here, so the value
 * leads at 18px in primary text and the label sits under it, small and muted —
 * hierarchy from size and weight rather than from colour.
 */
function Stat({
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
 * Why this day, in one line. Always rendered — a recommendation the athlete
 * can't audit is indistinguishable from an arbitrary one.
 */
function recommendationReason(
  day: DayRotation,
  all: DayRotation[],
  coldStart: boolean,
): string {
  if (coldStart) return "Start here";
  if (day.completedCount === 0) return "never trained";

  const fewest = Math.min(...all.map((d) => d.completedCount));
  // "least trained" only means something when the days actually differ. When
  // every day sits on the same count, say the count instead of implying a gap
  // that isn't there.
  const uniform = all.every((d) => d.completedCount === fewest);
  const lead = uniform
    ? `done ${day.completedCount}×`
    : "least trained";
  const since = day.lastCompletedAt ? relativeDay(day.lastCompletedAt) : null;
  return since ? `${lead} · ${since}` : lead;
}

/** Compact history for a day-list row: "5d · 1×", or "never". */
function dayMeta(day: DayRotation): string {
  if (day.completedCount === 0 || !day.lastCompletedAt) return "never";
  return `${daysSince(day.lastCompletedAt)}d · ${day.completedCount}×`;
}

/** "Day A · Hinge" → ["Day A", "Hinge"]; falls back to the whole name. */
function splitName(name: string): [string, string] {
  const parts = name.split("·").map((s) => s.trim());
  if (parts.length >= 2) {
    return [parts[0], parts.slice(1).join(" · ")];
  }
  return ["", name];
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

/**
 * Whole calendar days between then and now.
 *
 * Calendar days, not elapsed hours: a session finished last night reads "1 day
 * ago" rather than "0" merely because 23 hours haven't passed.
 *
 * Counted in the rendering timezone, not UTC, so this agrees with the
 * `toLocaleDateString` output elsewhere on the page. Counting in UTC put an
 * evening session on the following calendar day, which showed a workout
 * finished at 7:30pm as "today" directly above a banner dating it "Fri, Aug
 * 14" — the two lines contradicting each other about the same evening.
 */
function daysSince(iso: string): number {
  const day = 24 * 60 * 60 * 1000;
  const then = new Date(iso);
  const now = new Date();
  const startOfDay = (d: Date) =>
    new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  return Math.max(0, Math.round((startOfDay(now) - startOfDay(then)) / day));
}

function relativeDay(iso: string): string {
  const days = daysSince(iso);
  if (days === 0) return "today";
  if (days === 1) return "yesterday";
  return `${days} days ago`;
}

function formatWeight(lb: number): string {
  return Number.isInteger(lb) ? String(lb) : lb.toFixed(1);
}
