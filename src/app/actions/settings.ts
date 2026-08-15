"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireUser } from "@/lib/auth/session";
import type { Database } from "@/lib/supabase/database.types";

type ThemePreference = Database["public"]["Enums"]["theme_preference"];
const THEMES: ThemePreference[] = ["system", "light", "dark"];

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

/**
 * Set the user's theme preference.
 *
 * Upserts the same user_settings row the block selection uses — one settings
 * row per user, extended rather than duplicated. Because the upsert names only
 * user_id and theme, an existing active_mesocycle_id is left untouched (and
 * vice versa for setActiveMesocycle), so the two settings cannot clobber each
 * other.
 *
 * The value is validated against the enum rather than passed through: this
 * arrives from a form submission, and a bad value should be a rejected write,
 * not a 500 from Postgres.
 *
 * Revalidates the layout, not just "/" — the theme is applied on <html> in the
 * root layout, so every route's markup changes, not only the page you toggled
 * from.
 */
export async function setTheme(formData: FormData) {
  const value = String(formData.get("theme") ?? "");
  if (!THEMES.includes(value as ThemePreference)) {
    throw new Error(`Invalid theme: ${value}`);
  }
  const theme = value as ThemePreference;

  const user = await requireUser();
  const supabase = await createClient();

  const { error } = await supabase
    .from("user_settings")
    .upsert({ user_id: user.id, theme }, { onConflict: "user_id" });
  if (error) throw error;

  revalidatePath("/", "layout");
}
