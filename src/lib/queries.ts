import { createClient } from "@/lib/supabase/server";

/** The three day-templates, in program order. */
export async function getTemplates() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("workout_templates")
    .select("id, name, sort_order")
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
