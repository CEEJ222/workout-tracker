import { createClient } from "@/lib/supabase/server";
import { getUser } from "@/lib/auth/session";

/**
 * The training blocks (mesocycles) the current user can see, in order. RLS
 * scopes this to their own blocks plus any global ones — no app-side filtering.
 */
export async function getMesocycles() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("mesocycles")
    .select("id, name, sort_order")
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

  // No active block chosen yet → default to the lowest-sort_order visible block
  // (ordered by id as a stable tiebreaker).
  const { data: first, error } = await supabase
    .from("mesocycles")
    .select("id")
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
