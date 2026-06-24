import Link from "next/link";
import { getCompletedSessions } from "@/lib/history";

export default async function SessionLogPage() {
  const sessions = await getCompletedSessions();

  if (sessions.length === 0) {
    return (
      <EmptyState>
        No completed workouts yet. Finish a session and it&rsquo;ll show up here.
      </EmptyState>
    );
  }

  return (
    <ul className="flex flex-col gap-2">
      {sessions.map((s) => (
        <li key={s.id}>
          <Link
            href={`/session/${s.id}`}
            className="flex items-center justify-between rounded-card border border-line bg-card px-4 py-3"
          >
            <div>
              <div className="text-[15px] font-semibold text-ink">
                {s.templateName}
              </div>
              <div className="mt-0.5 text-[12px] text-ink-2">
                {formatDate(s.completedAt)} · {s.exercisesLogged} logged
                {s.painFlags > 0 && (
                  <span className="text-amber">
                    {" "}
                    · {s.painFlags} pain flag{s.painFlags > 1 ? "s" : ""}
                  </span>
                )}
              </div>
            </div>
            <span className="text-[13px] text-ink-3">View →</span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

export function EmptyState({ children }: { children: React.ReactNode }) {
  return (
    <div className="rounded-card border border-line bg-card px-5 py-10 text-center text-[13px] leading-relaxed text-ink-2">
      {children}
    </div>
  );
}

function formatDate(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}
