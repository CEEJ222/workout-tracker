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

/** A session header plus pre-built exercise/set counts, or null if not found. */
export async function getSessionSummary(sessionId: string) {
  const supabase = await createClient();

  const { data: session, error } = await supabase
    .from("sessions")
    .select(
      "id, started_at, completed_at, status, template_id, workout_templates(name)",
    )
    .eq("id", sessionId)
    .maybeSingle();
  if (error) throw error;
  if (!session) return null;

  const { count: exercises } = await supabase
    .from("session_exercises")
    .select("id", { count: "exact", head: true })
    .eq("session_id", sessionId);

  const { count: sets } = await supabase
    .from("session_sets")
    .select("id, session_exercises!inner(session_id)", {
      count: "exact",
      head: true,
    })
    .eq("session_exercises.session_id", sessionId);

  return { session, exercises: exercises ?? 0, sets: sets ?? 0 };
}
