"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireUser } from "@/lib/auth/session";

/**
 * Start (or resume) a day. If an in-progress session already exists for this
 * template we resume it rather than creating a duplicate; otherwise the
 * `start_session` RPC atomically creates the session and pre-builds its
 * session_exercises + session_sets from the template. Then navigate to it.
 */
export async function startSession(formData: FormData) {
  const templateId = String(formData.get("templateId") ?? "");
  if (!templateId) {
    throw new Error("Missing template id");
  }

  await requireUser();
  const supabase = await createClient();

  const { data: existing } = await supabase
    .from("sessions")
    .select("id")
    .eq("template_id", templateId)
    .eq("status", "in_progress")
    .order("started_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existing) {
    redirect(`/session/${existing.id}`);
  }

  const { data: sessionId, error } = await supabase.rpc("start_session", {
    p_template_id: templateId,
  });
  if (error) throw error;

  redirect(`/session/${sessionId}`);
}

/**
 * Complete a workout: stamp completed_at and flip status to completed.
 * Phase 7 will additionally run the pain-aware progression here.
 */
export async function completeWorkout(formData: FormData) {
  const sessionId = String(formData.get("sessionId") ?? "");
  if (!sessionId) {
    throw new Error("Missing session id");
  }

  await requireUser();
  const supabase = await createClient();

  // Atomically finalize the session and run the pain-aware progression.
  const { error } = await supabase.rpc("complete_session", {
    p_session_id: sessionId,
  });
  if (error) throw error;

  redirect("/");
}

/**
 * Discard an in-progress session: delete it (cascading to its session_exercises
 * + session_sets) so that day returns to a not-started card. Guarded to
 * in_progress only, so completed history can never be deleted this way.
 */
export async function discardSession(formData: FormData) {
  const sessionId = String(formData.get("sessionId") ?? "");
  if (!sessionId) {
    throw new Error("Missing session id");
  }

  await requireUser();
  const supabase = await createClient();

  const { error } = await supabase
    .from("sessions")
    .delete()
    .eq("id", sessionId)
    .eq("status", "in_progress");
  if (error) throw error;

  revalidatePath("/");
}
