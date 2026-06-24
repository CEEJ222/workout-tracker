import { requireUser } from "@/lib/auth/session";
import { logout } from "@/lib/auth/actions";

export default async function Home() {
  const user = await requireUser();

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 flex items-start justify-between border-b border-line bg-card px-[18px] pb-3.5 pt-4">
        <div>
          <div className="text-[11px] uppercase tracking-[0.12em] text-ink-3">
            Workout
          </div>
          <h1 className="mt-0.5 text-[21px] font-semibold tracking-[-0.01em]">
            Workout Tracker
          </h1>
        </div>
        <form action={logout}>
          <button
            type="submit"
            className="rounded-lg border border-line bg-field px-2.5 py-1.5 text-[12px] text-ink-2"
          >
            Sign out
          </button>
        </form>
      </header>

      <main className="flex flex-1 items-center justify-center px-3 py-6">
        <div className="rounded-card border border-line bg-card px-5 py-8 text-center">
          <p className="text-[15px] font-semibold text-ink">You&rsquo;re in</p>
          <p className="mt-1.5 text-[13px] leading-relaxed text-ink-2">
            Signed in as {user.email}. The day picker and session logging arrive
            in the next phases.
          </p>
        </div>
      </main>
    </div>
  );
}
