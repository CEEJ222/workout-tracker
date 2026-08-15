import { createClient } from "@/lib/supabase/server";
import { getUser } from "@/lib/auth/session";
import type { Database } from "@/lib/supabase/database.types";
import {
  getSessionSummaries,
  type SessionSummary,
} from "@/lib/session-summary";

/**
 * The training blocks (mesocycles) the current user can see, in order. RLS
 * scopes this to their own blocks plus any global ones; we additionally hide
 * soft-archived blocks (archived_at is not null) so the block switcher only ever
 * lists active programs. Past sessions of an archived block still render — the
 * history read path doesn't go through here.
 */
export async function getMesocycles() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("mesocycles")
    .select("id, name, sort_order")
    .is("archived_at", null)
    .order("sort_order")
    .order("id");
  if (error) throw error;
  return data;
}

/**
 * The user's active training block id.
 *
 * Reads user_settings.active_mesocycle_id. When the user has no settings row
 * yet, defaults to the lowest-sort_order block *visible to them* (RLS already
 * limits the candidates to their own + global blocks) and persists that choice
 * by creating their user_settings row. This runs during the home page's dynamic
 * render; the write is a create-if-missing (it never clobbers an existing
 * choice, so a rare concurrent first-load is harmless).
 */
export async function getActiveMesocycleId(): Promise<string> {
  const supabase = await createClient();

  const { data: settings } = await supabase
    .from("user_settings")
    .select("active_mesocycle_id")
    .maybeSingle();
  if (settings?.active_mesocycle_id) {
    return settings.active_mesocycle_id;
  }

  // No active block chosen yet → default to the lowest-sort_order visible,
  // non-archived block (ordered by id as a stable tiebreaker). Filtering on
  // archived_at here keeps a first-time user off an archived program.
  const { data: first, error } = await supabase
    .from("mesocycles")
    .select("id")
    .is("archived_at", null)
    .order("sort_order")
    .order("id")
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!first) throw new Error("No training blocks defined");

  // Persist the default so the switcher reflects a concrete selection. The PK
  // is user_id, so we supply it explicitly; ignoreDuplicates makes this a pure
  // create-if-missing that won't overwrite a row set by a concurrent request.
  const user = await getUser();
  if (user) {
    const { error: insertError } = await supabase
      .from("user_settings")
      .upsert(
        { user_id: user.id, active_mesocycle_id: first.id },
        { onConflict: "user_id", ignoreDuplicates: true },
      );
    if (insertError) throw insertError;
  }

  return first.id;
}

export type ThemePreference = Database["public"]["Enums"]["theme_preference"];

/**
 * The user's theme preference, read on the server so the first paint is already
 * correct.
 *
 * Never throws and never redirects: the root layout renders for signed-out
 * visitors too (the login screen), and a theme lookup is not a reason to fail a
 * page. Anything unexpected falls back to 'system', which defers to the device
 * — the same thing a brand-new user gets.
 */
export async function getThemePreference(): Promise<ThemePreference> {
  const supabase = await createClient();
  const { data } = await supabase.from("user_settings").select("theme").maybeSingle();
  return data?.theme ?? "system";
}

/** The day-templates for one training block, in program order. */
export async function getTemplates(mesocycleId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("workout_templates")
    .select("id, name, sort_order")
    .eq("mesocycle_id", mesocycleId)
    .order("sort_order");
  if (error) throw error;
  return data;
}

/**
 * One day of the active block, carrying the two facts the rotation rule needs:
 * how often it has been trained and when it was last trained.
 */
export type DayRotation = {
  id: string;
  name: string;
  sortOrder: number;
  completedCount: number;
  lastCompletedAt: string | null;
};

/**
 * The active block's days, each with its completed-session history.
 *
 * The embedded `sessions` is a LEFT join on purpose: PostgREST filters embedded
 * rows *without* dropping the parent (that would need `!inner`), so a day that
 * has never been performed still comes back — with an empty array — instead of
 * vanishing. That is the whole point here: a never-performed day is precisely
 * the one the rotation should surface first, so it must survive the join.
 *
 * User isolation is RLS's job (on sessions and mesocycles), which is why this
 * filters on mesocycle_id alone and never mentions a user id.
 */
export async function getDayRotation(
  mesocycleId: string,
): Promise<DayRotation[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("workout_templates")
    .select("id, name, sort_order, sessions(completed_at)")
    .eq("mesocycle_id", mesocycleId)
    .eq("sessions.status", "completed")
    .order("sort_order");
  if (error) throw error;

  return (data ?? []).map((t) => {
    // Count every completed session, but date the day only from rows that
    // actually carry a completed_at — the count and the recency answer
    // different questions and must not be derived from the same filter.
    const stamps = t.sessions
      .map((s) => s.completed_at)
      .filter((d): d is string => d != null)
      .sort();
    return {
      id: t.id,
      name: t.name,
      sortOrder: t.sort_order,
      completedCount: t.sessions.length,
      lastCompletedAt: stamps.at(-1) ?? null,
    };
  });
}

/**
 * The rotation rule, in one place: fewest completed sessions first, then least
 * recently completed, then program order.
 *
 * Program order is not decoration — it is what resolves a cold start. A block
 * whose every day sits at zero ties on both real signals, and without the final
 * tiebreak the "recommendation" would be whatever order the rows arrived in.
 * Falling through to sort_order makes that case deterministic: Day 1.
 */
export function rankDays(days: DayRotation[]): DayRotation[] {
  return [...days].sort((a, b) => {
    if (a.completedCount !== b.completedCount) {
      return a.completedCount - b.completedCount;
    }
    const aLast = a.lastCompletedAt ? Date.parse(a.lastCompletedAt) : 0;
    const bLast = b.lastCompletedAt ? Date.parse(b.lastCompletedAt) : 0;
    if (aLast !== bLast) return aLast - bLast;
    return a.sortOrder - b.sortOrder;
  });
}

/** What a day is about to ask of you, read off the template. */
export type WorkoutPlan = {
  exerciseCount: number;
  totalTargetSets: number;
  firstExercise: { name: string; seedWeight: number | null } | null;
};

/**
 * The forward-looking shape of one day: how many working exercises, how many
 * target sets, and which lift opens it.
 *
 * Warm-up circuits are excluded throughout — they are not working volume, and
 * counting them would inflate every number on the card and hand back a mobility
 * drill as "the first exercise". Retired prescriptions are excluded too, which
 * keeps these counts honest against what `start_session` will actually build:
 * it filters on `retired_at is null` for the same reason.
 */
export async function getWorkoutPlan(templateId: string): Promise<WorkoutPlan> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("template_blocks")
    .select(
      `type, sort_order,
       template_exercises (
         sort_order, target_sets, seed_weight, retired_at,
         exercises ( name )
       )`,
    )
    .eq("template_id", templateId)
    .neq("type", "circuit")
    .order("sort_order");
  if (error) throw error;

  const prescriptions = (data ?? [])
    .sort((a, b) => a.sort_order - b.sort_order)
    .flatMap((block) =>
      [...block.template_exercises]
        .filter((te) => te.retired_at == null)
        .sort((a, b) => a.sort_order - b.sort_order),
    );

  const first = prescriptions[0];
  return {
    exerciseCount: prescriptions.length,
    totalTargetSets: prescriptions.reduce((n, te) => n + te.target_sets, 0),
    firstExercise: first
      ? { name: first.exercises.name, seedWeight: first.seed_weight }
      : null,
  };
}

/** The current user's in-progress sessions, most recent first (for "resume"). */
export async function getInProgressSessions() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("sessions")
    .select("id, started_at, template_id, workout_templates(name)")
    .eq("status", "in_progress")
    .order("started_at", { ascending: false });
  if (error) throw error;
  return data;
}


/**
 * The most recent completed session in the active block.
 *
 * The summarizing itself lives in `getSessionSummaries`, because the history
 * list renders the same summary and the two must not drift. This only picks
 * which one the homepage means.
 *
 * Scoped to the active block's days: a freshly-started block has no last
 * workout, and that is the truthful answer even when older blocks are full of
 * history. Returns null in that case so the caller can omit the card.
 */
export async function getLastWorkout(
  templateIds: string[],
): Promise<SessionSummary | null> {
  if (templateIds.length === 0) return null;
  const summaries = await getSessionSummaries();
  return summaries.find((s) => templateIds.includes(s.templateId)) ?? null;
}
