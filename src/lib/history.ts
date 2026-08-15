import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";

type PainSeverity = Database["public"]["Enums"]["pain_severity"];

// getCompletedSessions lived here and returned a thinner summary (logged count
// + pain flags). It is gone: the session list now renders the same card as the
// homepage, so both read from `getSessionSummaries`, and keeping a second,
// slightly-different summary around is how the two drift apart.

export type WeightSeries = {
  exerciseId: string;
  exerciseName: string;
  points: { date: string; weight: number }[];
};

/**
 * Per-exercise logged-weight history across completed sessions. One point per
 * session = the heaviest completed working set for that exercise that day.
 */
export async function getWeightHistory(): Promise<WeightSeries[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("sessions")
    .select(
      `completed_at,
       session_exercises (
         exercises ( id, name ),
         session_sets ( actual_weight, done )
       )`,
    )
    .eq("status", "completed")
    .order("completed_at", { ascending: true });
  if (error) throw error;

  const byExercise = new Map<string, WeightSeries>();

  for (const session of data ?? []) {
    const date = session.completed_at;
    if (!date) continue;
    for (const se of session.session_exercises) {
      // The identity snapshotted at session creation — NOT a join through
      // template_exercises, which resolves against live template config and
      // would let a template edit retroactively rewrite this chart.
      const exercise = se.exercises;
      if (!exercise) continue;
      const weights = se.session_sets
        .filter((s) => s.done && s.actual_weight != null)
        .map((s) => s.actual_weight as number);
      if (weights.length === 0) continue;

      const series = byExercise.get(exercise.id) ?? {
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        points: [],
      };
      series.points.push({ date, weight: Math.max(...weights) });
      byExercise.set(exercise.id, series);
    }
  }

  return [...byExercise.values()].sort((a, b) =>
    a.exerciseName.localeCompare(b.exerciseName),
  );
}

export type PainEntry = {
  date: string;
  severity: PainSeverity;
  note: string | null;
  templateName: string;
};

export type PainByExercise = {
  exerciseName: string;
  entries: PainEntry[];
};

/**
 * Every logged pain flag, grouped by exercise and ordered most-recent-first —
 * the view to hand a physio. Includes in-progress sessions (pain is pain),
 * dated by completion when available, else session start.
 */
export async function getPainTimeline(): Promise<PainByExercise[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("sessions")
    .select(
      `started_at, completed_at, workout_templates(name),
       session_exercises (
         note, pain_severity,
         exercises ( name )
       )`,
    )
    .order("started_at", { ascending: false });
  if (error) throw error;

  const byExercise = new Map<string, PainByExercise>();

  for (const session of data ?? []) {
    const date = session.completed_at ?? session.started_at;
    const templateName = session.workout_templates?.name ?? "Workout";
    for (const se of session.session_exercises) {
      if (se.pain_severity == null) continue;
      // Snapshotted identity — see getWeightHistory.
      const name = se.exercises?.name ?? "Exercise";
      const group = byExercise.get(name) ?? { exerciseName: name, entries: [] };
      group.entries.push({
        date,
        severity: se.pain_severity,
        note: se.note,
        templateName,
      });
      byExercise.set(name, group);
    }
  }

  // Sort each group's entries newest-first, and groups by their most recent flag.
  const groups = [...byExercise.values()].map((g) => ({
    ...g,
    entries: g.entries.sort((a, b) => b.date.localeCompare(a.date)),
  }));
  return groups.sort((a, b) =>
    (b.entries[0]?.date ?? "").localeCompare(a.entries[0]?.date ?? ""),
  );
}
