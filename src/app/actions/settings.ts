"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireUser } from "@/lib/auth/session";

/**
 * Set the user's active training block. Upserts user_settings; switching only
 * changes which block's days the picker shows — it never touches program rows
 * or any in-progress session.
 */
export async function setActiveMesocycle(formData: FormData) {
  const mesocycleId = String(formData.get("mesocycleId") ?? "");
  if (!mesocycleId) {
    throw new Error("Missing mesocycle id");
  }

  const user = await requireUser();
  const supabase = await createClient();

  const { error } = await supabase
    .from("user_settings")
    .upsert(
      { user_id: user.id, active_mesocycle_id: mesocycleId },
      { onConflict: "user_id" },
    );
  if (error) throw error;

  revalidatePath("/");
}
