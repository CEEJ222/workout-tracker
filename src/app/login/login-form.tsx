"use client";

import { useActionState } from "react";
import { login } from "@/lib/auth/actions";

export function LoginForm() {
  const [state, action, pending] = useActionState(login, undefined);

  return (
    <form action={action} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1.5">
        <span className="text-[11px] uppercase tracking-[0.06em] text-ink-3">
          Email
        </span>
        <input
          name="email"
          type="email"
          autoComplete="username"
          required
          autoFocus
          className="rounded-lg border border-line bg-field px-3 py-2.5 text-[15px] text-ink outline-none focus-visible:border-ink"
        />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-[11px] uppercase tracking-[0.06em] text-ink-3">
          Password
        </span>
        <input
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="rounded-lg border border-line bg-field px-3 py-2.5 text-[15px] text-ink outline-none focus-visible:border-ink"
        />
      </label>

      {state?.error && (
        <p role="alert" className="text-[13px] text-amber">
          {state.error}
        </p>
      )}

      <button
        type="submit"
        disabled={pending}
        className="mt-1 rounded-lg bg-ink px-3 py-2.5 text-[15px] font-semibold text-white disabled:opacity-60"
      >
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
