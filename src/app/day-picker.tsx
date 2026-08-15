"use client";

import { useState } from "react";
import { startSession } from "@/app/actions/session";

export type PickerDay = {
  id: string;
  /** "Day 2" — the program's label for this slot. */
  day: string;
  /** "Upper — press bias" — what it actually trains. */
  focus: string;
  /** Pre-formatted history, e.g. "5d · 1×" or "never". */
  meta: string;
};

/**
 * The rest of the block, folded away.
 *
 * Collapsed by default so the page makes one recommendation instead of
 * presenting a menu — the whole point of the redesign. Expanding is React
 * state, not a CSS-only disclosure, so the chevron and the rows can never
 * disagree about whether the list is open. Nothing is persisted: the collapsed
 * state is the intended starting point on every visit, so there is nothing to
 * remember (and no storage is used anywhere in this app).
 */
export function DayPicker({ days }: { days: PickerDay[] }) {
  const [open, setOpen] = useState(false);
  if (days.length === 0) return null;

  return (
    <section>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center justify-between rounded-card border border-line bg-card px-4 py-3 text-left active:bg-field"
      >
        <span className="text-[13px] font-medium text-ink-2">
          Select another day
        </span>
        <svg
          viewBox="0 0 16 16"
          aria-hidden="true"
          className={`h-4 w-4 shrink-0 text-ink-3 transition-transform ${
            open ? "rotate-180" : ""
          }`}
        >
          <path
            d="M4 6l4 4 4-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>

      {open && (
        <div className="mt-1.5 flex flex-col gap-1.5">
          {days.map((d) => (
            <form key={d.id} action={startSession}>
              <input type="hidden" name="templateId" value={d.id} />
              <button
                type="submit"
                className="flex w-full items-center justify-between gap-3 rounded-card border border-line bg-card px-4 py-3 text-left active:bg-field"
              >
                <span className="min-w-0">
                  <span className="block truncate text-[14px] font-medium text-ink">
                    {d.focus}
                  </span>
                  {d.day && (
                    <span className="block text-[11px] uppercase tracking-[0.08em] text-ink-3">
                      {d.day}
                    </span>
                  )}
                </span>
                <span className="shrink-0 text-[12px] tabular-nums text-ink-3">
                  {d.meta}
                </span>
              </button>
            </form>
          ))}
        </div>
      )}
    </section>
  );
}
