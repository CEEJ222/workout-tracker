"use client";

export function PrintButton() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="rounded-lg border border-line bg-field px-3 py-1.5 text-[12px] text-ink-2"
    >
      Print / save PDF
    </button>
  );
}
