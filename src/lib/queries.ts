import { createClient } from "@/lib/supabase/server";

/** All training blocks (mesocycles), in order. */
export async function getMesocycles() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("mesocycles")
    .select("id, name, sort_order")
    .order("sort_order");
  if (error) throw error;
  return data;
}

/**
 * The user's active training block. Falls back to the lowest-sort_order block
 * when the user has no user_settings row yet.
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

  const { data: first, error } = await supabase
    .from("mesocycles")
    .select("id")
    .order("sort_order")
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!first) throw new Error("No training blocks defined");
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
