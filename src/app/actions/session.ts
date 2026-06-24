"use server";

import { redirect } from "next/navigation";
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
