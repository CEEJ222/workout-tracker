import { getSessionSummaries } from "@/lib/session-summary";
import { SessionSummaryCard } from "@/app/session-summary-card";

export default async function SessionLogPage() {
  const sessions = await getSessionSummaries();

  if (sessions.length === 0) {
    return (
      <EmptyState>
        No completed workouts yet. Finish a session and it&rsquo;ll show up here.
      </EmptyState>
    );
  }

  // The same card the homepage uses for "your last workout" — this list is that
  // object repeated, so it reads the volume, effort and load movement off the
  // card instead of making you open each session to find out what happened.
  // Dates are absolute here: you are scanning a timeline, not asking "when was
  // the last one".
  return (
    <ul className="flex flex-col gap-2.5">
      {sessions.map((s) => (
        <li key={s.sessionId}>
          <SessionSummaryCard
            summary={s}
            dateLabel={formatDate(s.completedAt)}
            actionLabel="View session"
            showDayNumber
          />
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
