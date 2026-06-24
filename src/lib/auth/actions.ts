"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type LoginState = { error: string } | undefined;

/**
 * Email/password sign-in. Used with `useActionState`, so it takes the previous
 * state and returns an error to display, or redirects on success.
 */
export async function login(
  _prevState: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "Enter your email and password." };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    // Supabase returns "Invalid login credentials" for both bad email and bad
    // password — intentionally vague, so we don't leak which one was wrong.
    return { error: error.message };
  }

  // redirect() throws NEXT_REDIRECT, so it must live outside any try/catch.
  redirect("/");
}

/** Sign out and return to the login screen. */
export async function logout(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
