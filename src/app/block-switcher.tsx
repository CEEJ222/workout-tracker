"use client";

import { useState } from "react";
import { setActiveMesocycle } from "@/app/actions/settings";

type Mesocycle = { id: string; name: string; sort_order: number };

/**
 * Switches the active training block. Switching only changes which 3 days the
 * picker shows. If a workout is in progress we require an explicit confirm
 * first (the switch never deletes or changes that session).
 */
export function BlockSwitcher({
  mesocycles,
  activeId,
  hasInProgress,
}: {
  mesocycles: Mesocycle[];
  activeId: string;
  hasInProgress: boolean;
}) {
  const [pendingId, setPendingId] = useState<string | null>(null);
  const pending = mesocycles.find((m) => m.id === pendingId) ?? null;

  return (
    <section>
      <div className="mx-1.5 mb-2 text-[11px] uppercase tracking-[0.1em] text-ink-3">
        Training block
      </div>

      <div className="flex gap-1.5">
        {mesocycles.map((m) => {
          const active = m.id === activeId;

          if (active) {
            return (
              <span
                key={m.id}
                aria-current="true"
                className="flex-1 rounded-lg border border-ink bg-ink px-3 py-2 text-center text-[12px] font-semibold text-white"
              >
                {m.name}
              </span>
            );
          }

          // A switch while a session is in progress goes through the confirm.
          if (hasInProgress) {
            return (
              <button
                key={m.id}
                type="button"
                onClick={() => setPendingId(m.id)}
                className="flex-1 rounded-lg border border-line bg-card px-3 py-2 text-center text-[12px] text-ink-2 active:bg-field"
              >
                {m.name}
              </button>
            );
          }

          // No session in progress → switch immediately.
          return (
            <form key={m.id} action={setActiveMesocycle} className="flex-1">
              <input type="hidden" name="mesocycleId" value={m.id} />
              <button
                type="submit"
                className="w-full rounded-lg border border-line bg-card px-3 py-2 text-center text-[12px] text-ink-2 active:bg-field"
              >
                {m.name}
              </button>
            </form>
          );
        })}
      </div>

      {pending && (
        <div className="mt-2 rounded-card border border-amber bg-amber-bg px-3.5 py-3">
          <p className="text-[12.5px] leading-snug text-ink">
            You have a workout in progress. Switching to <b>{pending.name}</b>{" "}
            only changes which days are shown here — your in-progress session is
            kept and stays in the list.
          </p>
          <div className="mt-2.5 flex gap-2">
            <form action={setActiveMesocycle}>
              <input type="hidden" name="mesocycleId" value={pending.id} />
              <button
                type="submit"
                className="rounded-lg bg-ink px-3 py-1.5 text-[12px] font-semibold text-white"
              >
                Switch block
              </button>
            </form>
            <button
              type="button"
              onClick={() => setPendingId(null)}
              className="rounded-lg border border-line bg-card px-3 py-1.5 text-[12px] text-ink-2"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </section>
  );
}
