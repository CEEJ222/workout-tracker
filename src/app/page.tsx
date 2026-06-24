import Link from "next/link";
import { requireUser } from "@/lib/auth/session";
import { logout } from "@/lib/auth/actions";
import {
  getMesocycles,
  getActiveMesocycleId,
  getTemplates,
  getInProgressSessions,
} from "@/lib/queries";
import { startSession } from "@/app/actions/session";
import { DiscardButton } from "@/app/discard-button";
import { BlockSwitcher } from "@/app/block-switcher";

export default async function Home() {
  await requireUser();
  const [mesocycles, activeMesocycleId, inProgress] = await Promise.all([
    getMesocycles(),
    getActiveMesocycleId(),
    getInProgressSessions(),
  ]);
  // Only the active block's three days.
  const templates = await getTemplates(activeMesocycleId);

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 flex items-start justify-between border-b border-line bg-card px-[18px] pb-3.5 pt-4">
        <div>
          <div className="text-[11px] uppercase tracking-[0.12em] text-ink-3">
            Workout
          </div>
          <h1 className="mt-0.5 text-[21px] font-semibold tracking-[-0.01em]">
            Pick a day
          </h1>
        </div>
        <div className="flex items-center gap-1.5">
          <Link
            href="/history"
            className="rounded-lg border border-line bg-field px-2.5 py-1.5 text-[12px] text-ink-2"
          >
            History
          </Link>
          <form action={logout}>
            <button
              type="submit"
              className="rounded-lg border border-line bg-field px-2.5 py-1.5 text-[12px] text-ink-2"
            >
              Sign out
            </button>
          </form>
        </div>
      </header>

      <main className="flex flex-1 flex-col gap-2.5 px-3 py-4">
        {inProgress.length > 0 && (
          <section className="flex flex-col gap-2">
            <div className="mx-1.5 text-[11px] uppercase tracking-[0.1em] text-ink-3">
              In progress
            </div>
            {inProgress.map((s) => {
              const name = s.workout_templates?.name ?? "Workout";
              return (
                <div
                  key={s.id}
                  className="flex items-center justify-between gap-2 rounded-card border border-line bg-amber-bg px-4 py-3"
                >
                  <Link href={`/session/${s.id}`} className="min-w-0 flex-1">
                    <div className="text-[15px] font-semibold text-ink">
                      {name}
                    </div>
                    <div className="text-[12px] text-ink-2">
                      Started {formatDate(s.started_at)}
                    </div>
                  </Link>
                  <div className="flex shrink-0 items-center gap-2">
                    <Link
                      href={`/session/${s.id}`}
                      className="text-[13px] font-medium text-amber"
                    >
                      Resume →
                    </Link>
                    <DiscardButton sessionId={s.id} label={name} />
                  </div>
                </div>
              );
            })}
          </section>
        )}

        <BlockSwitcher
          mesocycles={mesocycles}
          activeId={activeMesocycleId}
          hasInProgress={inProgress.length > 0}
        />

        <section className="flex flex-col gap-2.5">
          <div className="mx-1.5 mt-1 text-[11px] uppercase tracking-[0.1em] text-ink-3">
            Start a day
          </div>
          {templates.map((t) => {
            const [day, focus] = splitName(t.name);
            return (
              <form key={t.id} action={startSession}>
                <input type="hidden" name="templateId" value={t.id} />
                <button
                  type="submit"
                  className="flex w-full items-center justify-between rounded-card border border-line bg-card px-4 py-4 text-left active:bg-field"
                >
                  <div>
                    <div className="text-[11px] uppercase tracking-[0.08em] text-ink-3">
                      {day}
                    </div>
                    <div className="mt-0.5 text-[17px] font-semibold text-ink">
                      {focus}
                    </div>
                  </div>
                  <span className="text-[13px] font-medium text-ink-2">
                    Start →
                  </span>
                </button>
              </form>
            );
          })}
        </section>
      </main>
    </div>
  );
}

/** "Day A · Hinge" → ["Day A", "Hinge"]; falls back to the whole name. */
function splitName(name: string): [string, string] {
  const parts = name.split("·").map((s) => s.trim());
  if (parts.length >= 2) {
    return [parts[0], parts.slice(1).join(" · ")];
  }
  return ["", name];
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}
