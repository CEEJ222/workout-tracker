"use client";

import { useState } from "react";
import type { LoadGain } from "@/lib/session-summary";

/**
 * The lifts that went up, collapsed to the largest with the rest a tap away.
 *
 * Only this fragment is a client component: the card around it stays
 * server-rendered, so expanding costs no extra data and no round trip — the
 * full list is already in the markup, just not shown.
 *
 * Two are shown before asking for a tap. One is a headline; two reads as a
 * pattern and covers most sessions outright, so the control only appears when
 * there is genuinely more to see. The point of expanding is to answer "what
 * else moved?" without opening the session, which is the whole reason this is
 * here rather than behind the View link. Nothing is persisted — collapsed is
 * the right starting state every time, and this app stores nothing in the
 * browser.
 */
const COLLAPSED_COUNT = 2;

export function GainList({ gains }: { gains: LoadGain[] }) {
  const [expanded, setExpanded] = useState(false);
  if (gains.length === 0) return null;

  const shown = expanded ? gains : gains.slice(0, COLLAPSED_COUNT);
  const hidden = gains.length - COLLAPSED_COUNT;

  return (
    <div className="mt-3 flex flex-col gap-1.5">
      {shown.map((g) => (
        <div key={g.exerciseName} className="text-[12px] text-ink-2">
          {/* Load direction is one of the two things colour is spent on, so it
              goes on the numerals. The exercise name isn't the signal. */}
          <span className="text-ink">{g.exerciseName}</span>{" "}
          <span className="tabular-nums text-up">
            {formatWeight(g.from)} → {formatWeight(g.to)} lb
          </span>
        </div>
      ))}

      {hidden > 0 && (
        <button
          type="button"
          onClick={() => setExpanded((o) => !o)}
          aria-expanded={expanded}
          className="self-start text-[12px] text-ink-3 underline underline-offset-2"
        >
          {expanded ? "Show less" : `+${hidden} more heavier`}
        </button>
      )}
    </div>
  );
}

function formatWeight(lb: number): string {
  return Number.isInteger(lb) ? String(lb) : lb.toFixed(1);
}
