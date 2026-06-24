import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";

type LogType = Database["public"]["Enums"]["log_type"];
type BlockType = Database["public"]["Enums"]["block_type"];
type PainSeverity = Database["public"]["Enums"]["pain_severity"];

export type SessionSetState = {
  id: string;
  setNumber: number;
  targetRepsLow: number;
  targetRepsHigh: number;
  actualWeight: number | null;
  actualReps: number | null;
  done: boolean;
};

export type ExerciseCard = {
  sessionExerciseId: string;
  templateExerciseId: string;
  exerciseId: string;
  name: string;
  description: string | null;
  cues: string[];
  logType: LogType;
  autoLoad: boolean;
  restSeconds: number | null;
  pairLabel: string | null;
  perSide: boolean;
  targetSets: number;
  targetRepsLow: number;
  targetRepsHigh: number;
  // Suggested weight: from progress, else the template seed.
  suggestedWeight: number | null;
  suggestedIsEstimate: boolean;
  suggestedHeld: boolean; // pain-gated last time → show "held — see note"
  note: string | null;
  painSeverity: PainSeverity | null;
  done: boolean;
  sets: SessionSetState[];
};

export type SessionBlock = {
  id: string;
  type: BlockType;
  label: string;
  exercises: ExerciseCard[];
};

export type SessionDetail = {
  id: string;
  templateName: string;
  status: Database["public"]["Enums"]["session_status"];
  startedAt: string;
  completedAt: string | null;
  blocks: SessionBlock[];
  // Progress is over working exercises only (warm-up circuit excluded).
  workingTotal: number;
  workingLogged: number;
};

/**
 * Assembles the full nested structure the daily page renders: blocks → their
 * template prescriptions → the matching session_exercise (note/pain/done) and
 * its session_sets, plus the suggested weight (user_exercise_progress, falling
 * back to the template seed). Returns null when the session isn't found (RLS
 * scopes this to the signed-in user).
 */
export async function getSessionDetail(
  sessionId: string,
): Promise<SessionDetail | null> {
  const supabase = await createClient();

  const { data: session, error: sErr } = await supabase
    .from("sessions")
    .select(
      "id, status, started_at, completed_at, template_id, workout_templates(name)",
    )
    .eq("id", sessionId)
    .maybeSingle();
  if (sErr) throw sErr;
  if (!session) return null;

  const [{ data: blocks, error: bErr }, { data: ses, error: seErr }, { data: progress, error: pErr }] =
    await Promise.all([
      supabase
        .from("template_blocks")
        .select(
          `id, type, label, sort_order,
           template_exercises (
             id, pair_label, target_sets, target_reps_low, target_reps_high,
             per_side, seed_weight, seed_is_estimate, sort_order,
             exercises ( id, name, description, cues, log_type, auto_load, rest_seconds )
           )`,
        )
        .eq("template_id", session.template_id)
        .order("sort_order"),
      supabase
        .from("session_exercises")
        .select(
          `id, template_exercise_id, note, pain_severity, done,
           session_sets ( id, set_number, target_reps_low, target_reps_high, actual_weight, actual_reps, done )`,
        )
        .eq("session_id", sessionId),
      supabase
        .from("user_exercise_progress")
        .select("exercise_id, current_weight, is_estimate, last_pain_severity"),
    ]);
  if (bErr) throw bErr;
  if (seErr) throw seErr;
  if (pErr) throw pErr;

  const seByTemplateExercise = new Map(
    (ses ?? []).map((se) => [se.template_exercise_id, se]),
  );
  const progressByExercise = new Map(
    (progress ?? []).map((p) => [p.exercise_id, p]),
  );

  let workingTotal = 0;
  let workingLogged = 0;

  const assembledBlocks: SessionBlock[] = (blocks ?? [])
    .sort((a, b) => a.sort_order - b.sort_order)
    .map((block) => {
      const exercises: ExerciseCard[] = [...block.template_exercises]
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((te) => {
          const exercise = te.exercises;
          const se = seByTemplateExercise.get(te.id);
          const prog = progressByExercise.get(exercise.id);

          const hasProgress = prog != null && prog.current_weight != null;
          const suggestedWeight = hasProgress
            ? prog.current_weight
            : te.seed_weight;
          const suggestedIsEstimate = hasProgress
            ? prog.is_estimate
            : te.seed_is_estimate;
          const suggestedHeld = hasProgress
            ? prog.last_pain_severity != null
            : false;

          const sets: SessionSetState[] = (se?.session_sets ?? [])
            .sort((a, b) => a.set_number - b.set_number)
            .map((s) => ({
              id: s.id,
              setNumber: s.set_number,
              targetRepsLow: s.target_reps_low,
              targetRepsHigh: s.target_reps_high,
              actualWeight: s.actual_weight,
              actualReps: s.actual_reps,
              done: s.done,
            }));

          if (block.type !== "circuit") {
            workingTotal += 1;
            if (se?.done) workingLogged += 1;
          }

          return {
            sessionExerciseId: se?.id ?? "",
            templateExerciseId: te.id,
            exerciseId: exercise.id,
            name: exercise.name,
            description: exercise.description,
            cues: exercise.cues,
            logType: exercise.log_type,
            autoLoad: exercise.auto_load,
            restSeconds: exercise.rest_seconds,
            pairLabel: te.pair_label,
            perSide: te.per_side,
            targetSets: te.target_sets,
            targetRepsLow: te.target_reps_low,
            targetRepsHigh: te.target_reps_high,
            suggestedWeight,
            suggestedIsEstimate,
            suggestedHeld,
            note: se?.note ?? null,
            painSeverity: se?.pain_severity ?? null,
            done: se?.done ?? false,
            sets,
          };
        });

      return {
        id: block.id,
        type: block.type,
        label: block.label,
        exercises,
      };
    });

  return {
    id: session.id,
    templateName: session.workout_templates?.name ?? "Workout",
    status: session.status,
    startedAt: session.started_at,
    completedAt: session.completed_at,
    blocks: assembledBlocks,
    workingTotal,
    workingLogged,
  };
}
