import Link from "next/link";
import { notFound } from "next/navigation";
import { requireUser } from "@/lib/auth/session";
import { getSessionSummary } from "@/lib/queries";

export default async function SessionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireUser();
  const { id } = await params;
  const summary = await getSessionSummary(id);
  if (!summary) notFound();

  const { session, exercises, sets } = summary;

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 border-b border-line bg-card px-[18px] pb-3.5 pt-4">
        <Link href="/" className="text-[12px] text-ink-2">
          ← Days
        </Link>
        <div className="mt-2 flex items-baseline justify-between">
          <h1 className="text-[21px] font-semibold tracking-[-0.01em]">
            {session.workout_templates?.name ?? "Workout"}
          </h1>
          <span className="text-[13px] text-ink-2">
            {formatDate(session.started_at)}
          </span>
        </div>
      </header>

      <main className="flex flex-1 items-center justify-center px-3 py-6">
        <div className="rounded-card border border-line bg-card px-5 py-8 text-center">
          <p className="text-[15px] font-semibold text-ink">Session ready</p>
          <p className="mt-1.5 text-[13px] leading-relaxed text-ink-2">
            Pre-built {exercises} exercises and {sets} sets from the template.
            Per-set logging and the cues/pain UI land in the next phase.
          </p>
          <p className="mt-3 text-[11px] uppercase tracking-[0.08em] text-ink-3">
            {session.status === "in_progress" ? "In progress" : "Completed"}
          </p>
        </div>
      </main>
    </div>
  );
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}
