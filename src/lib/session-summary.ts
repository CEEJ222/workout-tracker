import { createClient } from "@/lib/supabase/server";

/** A load that went up between two sessions of the same exercise. */
export type LoadGain = { exerciseName: string; from: number; to: number };

/** What one completed session produced, read back off the log. */
export type SessionSummary = {
  sessionId: string;
  templateId: string;
  dayName: string;
  completedAt: string;
  setsDone: number;
  averageRir: number | null;
  loadsIncreased: number;
  biggestGain: LoadGain | null;
  painFlags: number;
};

/**
 * Every completed session, summarized, newest first.
 *
 * This exists as one function because the homepage's "your last workout" card
 * and the history list are the same summary rendered twice. Computing them
 * separately invites the two to drift — the more so because the load
 * comparison depends on session ordering, which is easy to get subtly
 * different in two places.
 *
 * Deliberately absent: duration. `completed_at - started_at` is not a workout
 * length — sessions stay open until the app is next opened, so real values
 * (51-68 min) sit in the same column as 8,753-minute ones with nothing to tell
 * them apart. An unusable number rendered confidently is worse than none.
 *
 * Exercise identity comes from the `session_exercises.exercise_id` snapshot,
 * never a join through `template_exercises` — see CLAUDE.md. Editing a template
 * must not reach back and relabel what was already logged.
 *
 * RLS scopes this to the signed-in user; no user id appears here.
 */
export async function getSessionSummaries(): Promise<SessionSummary[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("sessions")
    .select(
      `id, template_id, completed_at,
       workout_templates ( name ),
       session_exercises (
         exercise_id, pain_severity,
         exercises ( name ),
         template_exercises ( template_blocks ( type ) ),
         session_sets ( actual_weight, actual_rir, done )
       )`,
    )
    .eq("status", "completed")
    .order("completed_at", { ascending: true });
  if (error) throw error;

  const sessions = (data ?? []).filter((s) => s.completed_at != null);

  type Row = (typeof sessions)[number];
  type SE = Row["session_exercises"][number];

  // Heaviest completed set per exercise, per session — the same "one point per
  // session" reduction the weight chart uses, so the two never disagree.
  const topWeight = (se: SE) => {
    const weights = se.session_sets
      .filter((s) => s.done && s.actual_weight != null)
      .map((s) => s.actual_weight as number);
    return weights.length > 0 ? Math.max(...weights) : null;
  };
  // Warm-up circuits are not working volume. Excluding them also keeps the load
  // comparison sane — a 12 lb cable external rotation in a warm-up is not a
  // data point about pressing strength. Block type is read through the template
  // join, which is safe: a repoint changes the exercise, not the block's type.
  const isWorking = (se: SE) =>
    se.template_exercises?.template_blocks?.type !== "circuit";

  // Walk history forward once, remembering each exercise's previous top load.
  // Ascending order is what makes "did this go up" answerable at all, so the
  // summaries are built in that direction and reversed at the end.
  const previousTop = new Map<string, number>();
  const summaries: SessionSummary[] = [];

  for (const session of sessions) {
    const working = session.session_exercises.filter(isWorking);

    let setsDone = 0;
    let rirTotal = 0;
    let rirCount = 0;
    let loadsIncreased = 0;
    let biggestGain: LoadGain | null = null;

    for (const se of working) {
      for (const set of se.session_sets) {
        if (!set.done) continue;
        setsDone += 1;
        if (set.actual_rir != null) {
          rirTotal += set.actual_rir;
          rirCount += 1;
        }
      }

      const top = topWeight(se);
      const exerciseId = se.exercise_id;
      const prior = exerciseId != null ? previousTop.get(exerciseId) : undefined;

      // A first-ever appearance has nothing to improve on, so it is not a gain
      // — only a genuine increase over a previous session counts.
      if (top != null && prior != null && top > prior) {
        loadsIncreased += 1;
        if (
          biggestGain == null ||
          top - prior > biggestGain.to - biggestGain.from
        ) {
          biggestGain = {
            exerciseName: se.exercises?.name ?? "Exercise",
            from: prior,
            to: top,
          };
        }
      }

      if (top != null && exerciseId != null) previousTop.set(exerciseId, top);
    }

    summaries.push({
      sessionId: session.id,
      templateId: session.template_id,
      dayName: session.workout_templates?.name ?? "Workout",
      completedAt: session.completed_at as string,
      setsDone,
      averageRir: rirCount > 0 ? rirTotal / rirCount : null,
      loadsIncreased,
      biggestGain,
      // Pain is counted across the whole session, warm-ups included: a flag
      // raised during a warm-up is still a flag.
      painFlags: session.session_exercises.filter((se) => se.pain_severity != null)
        .length,
    });
  }

  return summaries.reverse();
}
