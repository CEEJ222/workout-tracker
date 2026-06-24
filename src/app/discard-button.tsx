"use client";

import { useState } from "react";
import { discardSession } from "@/app/actions/session";

/**
 * Discards an in-progress session behind an explicit two-step confirm: the
 * first tap reveals Delete / Cancel, and only the Delete submit actually runs
 * the server action. No reliance on preventDefault to cancel a form submit.
 */
export function DiscardButton({
  sessionId,
  label,
}: {
  sessionId: string;
  label: string;
}) {
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        type="button"
        onClick={() => setConfirming(true)}
        aria-label={`Discard ${label}`}
        className="rounded-lg border border-line bg-card px-2 py-1 text-[12px] text-ink-3 active:bg-field"
      >
        Discard
      </button>
    );
  }

  return (
    <div className="flex items-center gap-1.5">
      <form action={discardSession}>
        <input type="hidden" name="sessionId" value={sessionId} />
        <button
          type="submit"
          aria-label={`Confirm discard ${label}`}
          className="rounded-lg bg-amber px-2 py-1 text-[12px] font-semibold text-white"
        >
          Delete
        </button>
      </form>
      <button
        type="button"
        onClick={() => setConfirming(false)}
        className="rounded-lg border border-line bg-card px-2 py-1 text-[12px] text-ink-2"
      >
        Cancel
      </button>
    </div>
  );
}
