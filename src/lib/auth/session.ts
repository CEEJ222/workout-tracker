import { cache } from "react";
import { redirect } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

/**
 * Returns the authenticated Supabase user, or null. Memoized per request with
 * React's `cache` so multiple callers in one render don't each hit the network.
 *
 * Uses `getUser()` (not `getSession()`) so the token is verified against the
 * Supabase Auth server rather than trusted from the cookie.
 */
export const getUser = cache(async (): Promise<User | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

/**
 * Auth guard for protected Server Components, Server Actions, and Route
 * Handlers. Redirects to /login when there is no session. The proxy already
 * gates navigation, but verifying here too keeps each entry point secure on its
 * own (server actions POST to their route and must not rely on the proxy alone).
 */
export async function requireUser(): Promise<User> {
  const user = await getUser();
  if (!user) {
    redirect("/login");
  }
  return user;
}
