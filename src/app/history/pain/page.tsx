import { getPainTimeline } from "@/lib/history";
import { EmptyState } from "../page";
import { PrintButton } from "./print-button";

export default async function PainPage() {
  const groups = await getPainTimeline();

  if (groups.length === 0) {
    return (
      <EmptyState>
        No pain flagged yet — good news. Anything you mark Mild or Sharp on an
        exercise shows up here, grouped by movement, to share with a physio.
      </EmptyState>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <p className="text-[12px] text-ink-2">
          Every flagged exercise, newest first.
        </p>
        <PrintButton />
      </div>

      {groups.map((group) => (
        <section key={group.exerciseName}>
          <h2 className="mx-1 mb-1.5 text-[14px] font-semibold text-ink">
            {group.exerciseName}
          </h2>
          <ul className="flex flex-col gap-1.5">
            {group.entries.map((entry, i) => (
              <li
                key={i}
                className="rounded-card border border-line bg-card px-3.5 py-2.5"
              >
                <div className="flex items-center gap-2">
                  <SeverityBadge severity={entry.severity} />
                  <span className="text-[12px] text-ink-2">
                    {formatDate(entry.date)} · {entry.templateName}
                  </span>
                </div>
                {entry.note && (
                  <p className="mt-1.5 text-[13px] leading-snug text-ink">
                    {entry.note}
                  </p>
                )}
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

function SeverityBadge({ severity }: { severity: "mild" | "sharp" }) {
  const sharp = severity === "sharp";
  return (
    <span
      className={`rounded-md px-2 py-0.5 text-[11px] font-semibold uppercase tracking-[0.04em] ${
        sharp ? "bg-amber text-white" : "bg-amber-bg text-amber"
      }`}
    >
      {severity}
    </span>
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
