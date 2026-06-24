import { redirect } from "next/navigation";
import { getUser } from "@/lib/auth/session";
import { LoginForm } from "./login-form";

export default async function LoginPage() {
  // Already signed in → skip the form.
  if (await getUser()) {
    redirect("/");
  }

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col justify-center px-5 py-10">
      <div className="mb-6">
        <div className="text-[11px] uppercase tracking-[0.12em] text-ink-3">
          Workout
        </div>
        <h1 className="mt-0.5 text-[21px] font-semibold tracking-[-0.01em]">
          Sign in
        </h1>
        <p className="mt-1 text-[13px] text-ink-2">
          Personal workout tracker — one account.
        </p>
      </div>

      <div className="rounded-card border border-line bg-card p-5">
        <LoginForm />
      </div>
    </div>
  );
}
