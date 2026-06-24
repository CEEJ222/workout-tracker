"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { completeWorkout } from "@/app/actions/session";
import { formatRest } from "@/lib/rest";
import type {
  SessionDetail,
  SessionBlock,
  ExerciseCard,
} from "@/lib/session-detail";
import type { Database } from "@/lib/supabase/database.types";

type PainSeverity = Database["public"]["Enums"]["pain_severity"];

type ExUiState = { done: boolean; note: string; pain: PainSeverity | null };

type RestTimer = {
  key: number; // bumped on (re)start so the bar remounts and re-ticks
  startedAt: number; // epoch ms; remaining is always derived from this
  durationSeconds: number;
  exerciseName: string;
};

export function SessionView({ detail }: { detail: SessionDetail }) {
  const supabase = useMemo(() => createClient(), []);
  const [saveError, setSaveError] = useState(false);

  const allCards = useMemo(
    () => detail.blocks.flatMap((b) => b.exercises),
    [detail],
  );

  const [exState, setExState] = useState<Record<string, ExUiState>>(() =>
    Object.fromEntries(
      allCards.map((c) => [
        c.sessionExerciseId,
        { done: c.done, note: c.note ?? "", pain: c.painSeverity },
      ]),
    ),
  );
  const [setDone, setSetDone] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(
      allCards.flatMap((c) => c.sets.map((s) => [s.id, s.done])),
    ),
  );

  // ── Rest timer (Phase 9) ──────────────────────────────────────────────────
  // A pure UI layer, fully decoupled from logging: only one rest runs at a
  // time, its state lives here in React (no storage), and every browser-API
  // call below is wrapped so a timer failure can never block or corrupt a
  // set/session write. Remaining time is derived from `startedAt`, never from a
  // tick that pauses when the tab backgrounds.
  const [restTimer, setRestTimer] = useState<RestTimer | null>(null);
  // AudioContext, unlocked on the user's tap (so the end-of-rest beep can play
  // even though it fires outside a gesture). Browsers may still block it — the
  // visible timer is the always-present fallback.
  const audioRef = useRef<AudioContext | null>(null);

  function primeAudio() {
    try {
      const Ctx =
        window.AudioContext ??
        (window as unknown as { webkitAudioContext?: typeof AudioContext })
          .webkitAudioContext;
      if (!Ctx) return;
      audioRef.current ??= new Ctx();
      if (audioRef.current.state === "suspended") void audioRef.current.resume();
    } catch {
      /* audio is best-effort */
    }
  }

  function startRestTimer(card: ExerciseCard) {
    if (card.restSeconds == null) return; // warm-up / no guidance → no timer
    try {
      primeAudio();
      setRestTimer({
        key: Date.now(),
        startedAt: Date.now(),
        durationSeconds: card.restSeconds,
        exerciseName: card.name,
      });
    } catch {
      /* never let a timer hiccup interfere with logging */
    }
  }

  // Fires once when a rest reaches zero: sound + vibration where supported,
  // each guarded independently; the bar's "Rest's up" state is the silent
  // fallback that always shows.
  function fireRestCue() {
    try {
      if (audioRef.current) playBeep(audioRef.current);
    } catch {
      /* ignore */
    }
    try {
      navigator.vibrate?.([120, 60, 120]);
    } catch {
      /* ignore */
    }
  }

  // Progress counts working exercises only (warm-up circuit excluded).
  const workingIds = useMemo(
    () =>
      detail.blocks
        .filter((b) => b.type !== "circuit")
        .flatMap((b) => b.exercises.map((e) => e.sessionExerciseId)),
    [detail],
  );
  const logged = workingIds.filter((id) => exState[id]?.done).length;
  const total = workingIds.length;
  const pct = total > 0 ? Math.round((logged / total) * 100) : 0;

  async function persistSet(
    setId: string,
    patch: Database["public"]["Tables"]["session_sets"]["Update"],
  ) {
    const { error } = await supabase
      .from("session_sets")
      .update(patch)
      .eq("id", setId);
    if (error) setSaveError(true);
  }

  async function persistExercise(
    seId: string,
    patch: Database["public"]["Tables"]["session_exercises"]["Update"],
  ) {
    const { error } = await supabase
      .from("session_exercises")
      .update(patch)
      .eq("id", seId);
    if (error) setSaveError(true);
  }

  // ── handlers ────────────────────────────────────────────────────────────
  function toggleExerciseDone(card: ExerciseCard) {
    const next = !exState[card.sessionExerciseId].done;
    setExState((p) => ({
      ...p,
      [card.sessionExerciseId]: { ...p[card.sessionExerciseId], done: next },
    }));
    persistExercise(card.sessionExerciseId, { done: next });
  }

  function toggleSetDone(card: ExerciseCard, setId: string) {
    const next = !setDone[setId];
    const nextMap = { ...setDone, [setId]: next };
    setSetDone(nextMap);
    persistSet(setId, { done: next });

    // Checking a set off starts the rest countdown (un-checking does not).
    if (next) startRestTimer(card);

    // An exercise card is "done" once all its sets are done.
    const allDone = card.sets.every((s) => nextMap[s.id]);
    if (exState[card.sessionExerciseId].done !== allDone) {
      setExState((p) => ({
        ...p,
        [card.sessionExerciseId]: { ...p[card.sessionExerciseId], done: allDone },
      }));
      persistExercise(card.sessionExerciseId, { done: allDone });
    }
  }

  function setPain(card: ExerciseCard, sev: PainSeverity) {
    const next = exState[card.sessionExerciseId].pain === sev ? null : sev;
    setExState((p) => ({
      ...p,
      [card.sessionExerciseId]: { ...p[card.sessionExerciseId], pain: next },
    }));
    persistExercise(card.sessionExerciseId, { pain_severity: next });
  }

  function setNote(card: ExerciseCard, value: string) {
    const trimmed = value.trim();
    setExState((p) => ({
      ...p,
      [card.sessionExerciseId]: { ...p[card.sessionExerciseId], note: trimmed },
    }));
    persistExercise(card.sessionExerciseId, { note: trimmed || null });
  }

  const handlers = {
    persistSet,
    toggleExerciseDone,
    toggleSetDone,
    setPain,
    setNote,
  };

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 z-10 border-b border-line bg-card px-[18px] pb-3.5 pt-4">
        <Link href="/" className="text-[12px] text-ink-2">
          ← Days
        </Link>
        <div className="mt-1.5 flex items-baseline justify-between">
          <h1 className="text-[21px] font-semibold tracking-[-0.01em]">
            {detail.templateName}
          </h1>
          <span className="text-[13px] text-ink-2">
            {formatDate(detail.startedAt)}
          </span>
        </div>
        <div className="mt-3 h-1 overflow-hidden rounded-full bg-line-2">
          <span
            className="block h-full rounded-full bg-ink transition-all"
            style={{ width: `${pct}%` }}
          />
        </div>
        <div className="mt-1.5 text-[11px] text-ink-3">
          {logged} of {total} exercises logged
        </div>
      </header>

      <main className="px-3 pb-4 pt-1">
        {detail.blocks.map((block) => (
          <BlockGroup
            key={block.id}
            block={block}
            exState={exState}
            setDone={setDone}
            handlers={handlers}
          />
        ))}

        {detail.status === "in_progress" ? (
          <form action={completeWorkout} className="px-1 pb-10 pt-4">
            <input type="hidden" name="sessionId" value={detail.id} />
            <button
              type="submit"
              className="w-full rounded-card bg-ink py-3.5 text-[15px] font-semibold text-white active:opacity-90"
            >
              Complete workout
            </button>
          </form>
        ) : (
          <div className="px-1 pb-10 pt-5 text-center text-[13px] text-ink-2">
            Completed{" "}
            {detail.completedAt ? formatDate(detail.completedAt) : ""}
          </div>
        )}
      </main>

      {restTimer && (
        <RestTimerBar
          key={restTimer.key}
          timer={restTimer}
          onComplete={fireRestCue}
          onReset={() =>
            setRestTimer((t) =>
              t ? { ...t, key: Date.now(), startedAt: Date.now() } : t,
            )
          }
          onDismiss={() => setRestTimer(null)}
        />
      )}

      {saveError && (
        <div className="sticky bottom-0 bg-amber px-4 py-2 text-center text-[12px] text-white">
          Couldn&rsquo;t save a change — check your connection.
        </div>
      )}
    </div>
  );
}

type Handlers = {
  persistSet: (
    setId: string,
    patch: Database["public"]["Tables"]["session_sets"]["Update"],
  ) => void;
  toggleExerciseDone: (card: ExerciseCard) => void;
  toggleSetDone: (card: ExerciseCard, setId: string) => void;
  setPain: (card: ExerciseCard, sev: PainSeverity) => void;
  setNote: (card: ExerciseCard, value: string) => void;
};

function BlockGroup({
  block,
  exState,
  setDone,
  handlers,
}: {
  block: SessionBlock;
  exState: Record<string, ExUiState>;
  setDone: Record<string, boolean>;
  handlers: Handlers;
}) {
  // The pair labels (e.g. ["A1", "A2"]) for a superset block — used to render
  // each member's rest as "Alternate A1/A2 · …" instead of a flat rest line.
  const supersetLabels =
    block.type === "superset"
      ? block.exercises
          .map((e) => e.pairLabel)
          .filter((l): l is string => l != null)
      : undefined;

  return (
    <section>
      <div className="mx-1.5 mb-2 mt-[18px] flex items-center gap-2 text-[11px] uppercase tracking-[0.1em] text-ink-3">
        <span>{block.label}</span>
        <span className="h-px flex-1 bg-line-2" />
      </div>

      {block.type === "circuit" ? (
        <div className="rounded-card border border-line bg-card">
          {block.exercises.map((card) => (
            <CircuitRow
              key={card.sessionExerciseId}
              card={card}
              done={exState[card.sessionExerciseId]?.done ?? false}
              handlers={handlers}
            />
          ))}
        </div>
      ) : (
        <div className="flex flex-col gap-2.5">
          {block.exercises.map((card) => (
            <ExerciseCardView
              key={card.sessionExerciseId}
              card={card}
              superset={block.type === "superset"}
              supersetLabels={supersetLabels}
              ex={exState[card.sessionExerciseId]}
              setDone={setDone}
              handlers={handlers}
            />
          ))}
        </div>
      )}
    </section>
  );
}

function CircuitRow({
  card,
  done,
  handlers,
}: {
  card: ExerciseCard;
  done: boolean;
  handlers: Handlers;
}) {
  const [openCues, setOpenCues] = useState(false);
  const firstSet = card.sets[0];

  return (
    <div className="border-t border-line-2 first:border-t-0">
      <div className="flex items-center gap-2.5 px-3.5 py-2.5">
        <DoneBox
          small
          checked={done}
          onToggle={() => handlers.toggleExerciseDone(card)}
          label={`${card.name} done`}
        />
        <div className="min-w-0 flex-1">
          <div className="text-[13.5px] leading-tight">{card.name}</div>
          <div className="text-[12px] text-ink-3">{formatTarget(card)}</div>
        </div>

        {card.logType === "done_check_weight" && firstSet && (
          <div className="flex items-center gap-1.5">
            <input
              type="number"
              inputMode="decimal"
              defaultValue={firstSet.actualWeight ?? ""}
              placeholder={
                card.suggestedWeight != null ? String(card.suggestedWeight) : "lb"
              }
              onBlur={(e) =>
                handlers.persistSet(firstSet.id, {
                  actual_weight: parseWeight(e.target.value),
                })
              }
              className="w-14 rounded-lg border border-dashed border-line bg-field px-1.5 py-1 text-center text-[12px]"
              aria-label="weight"
            />
            <input
              type="number"
              inputMode="numeric"
              defaultValue={firstSet.actualReps ?? ""}
              placeholder="reps"
              onBlur={(e) =>
                handlers.persistSet(firstSet.id, {
                  actual_reps: parseReps(e.target.value),
                })
              }
              className="w-12 rounded-lg border border-dashed border-line bg-field px-1.5 py-1 text-center text-[12px]"
              aria-label="reps"
            />
          </div>
        )}

        <button
          type="button"
          onClick={() => setOpenCues((o) => !o)}
          aria-expanded={openCues}
          aria-label="cues"
          className="shrink-0 px-1.5 py-1 text-[11px] text-ink-3"
        >
          {openCues ? "▲" : "▼"}
        </button>
      </div>
      {openCues && (
        <Cues
          description={card.description}
          cues={card.cues}
          className="px-3.5 pb-3 pl-[42px]"
        />
      )}
    </div>
  );
}

function ExerciseCardView({
  card,
  superset,
  supersetLabels,
  ex,
  setDone,
  handlers,
}: {
  card: ExerciseCard;
  superset: boolean;
  supersetLabels?: string[];
  ex: ExUiState;
  setDone: Record<string, boolean>;
  handlers: Handlers;
}) {
  const [openCues, setOpenCues] = useState(false);
  const [openNote, setOpenNote] = useState(false);
  const weighted = card.logType !== "done_check";
  const hasMarker = ex.pain != null || ex.note.length > 0;
  const rest = formatRest(card.restSeconds, superset ? supersetLabels : null);

  return (
    <div
      className={`overflow-hidden rounded-card border border-line bg-card ${
        superset ? "border-l-[3px] border-l-ink" : ""
      }`}
    >
      <div className="flex items-start justify-between gap-2.5 px-[15px] pb-2.5 pt-3">
        <div className="min-w-0">
          <div className="text-[15px] font-semibold leading-tight">
            {card.pairLabel && (
              <span className="mr-1.5 text-[11px] font-bold text-ink-3">
                {card.pairLabel}
              </span>
            )}
            {card.name}
          </div>
          <div className="mt-0.5 text-[12px] text-ink-2">
            {formatTarget(card)}
          </div>
          {rest && (
            <div className="mt-1 text-[11px] text-ink-3">{rest.text}</div>
          )}
        </div>
        {card.suggestedWeight != null && (
          <div className="shrink-0 text-right">
            <div className="text-[15px] font-semibold">
              {card.suggestedWeight} lb
            </div>
            <div className="text-[10px] uppercase tracking-[0.06em] text-ink-3">
              Suggested
            </div>
            {card.suggestedHeld ? (
              <div className="text-[10px] text-amber">held — see note</div>
            ) : card.suggestedIsEstimate ? (
              <div className="text-[10px] text-ink-2">est.</div>
            ) : null}
          </div>
        )}
      </div>

      <div className="border-t border-line-2">
        <button
          type="button"
          onClick={() => setOpenCues((o) => !o)}
          aria-expanded={openCues}
          className="flex w-full items-center gap-2 px-[15px] py-2 text-left text-[12.5px] text-ink-2"
        >
          <span>ⓘ How to do it</span>
          <span className="ml-auto text-[11px]">{openCues ? "▲" : "▼"}</span>
        </button>
        {openCues && (
          <Cues
            description={card.description}
            cues={card.cues}
            className="px-[15px] pb-3"
          />
        )}
      </div>

      <div className="px-[15px] py-1">
        {card.sets.map((s) => (
          <div
            key={s.id}
            className={`grid items-center gap-2 border-t border-line-2 py-1.5 first:border-t-0 ${
              weighted
                ? "grid-cols-[42px_1fr_46px_72px_28px]"
                : "grid-cols-[42px_1fr_28px]"
            }`}
          >
            <span className="text-[11px] text-ink-3">Set {s.setNumber}</span>
            <span className="text-[13px] text-ink-2">
              <b className="font-semibold text-ink">{repRange(s)}</b>
              {weighted ? " reps" : ""}
            </span>
            {weighted && (
              <>
                <input
                  type="number"
                  inputMode="numeric"
                  defaultValue={s.actualReps ?? ""}
                  placeholder={String(s.targetRepsHigh)}
                  onBlur={(e) =>
                    handlers.persistSet(s.id, {
                      actual_reps: parseReps(e.target.value),
                    })
                  }
                  aria-label={`set ${s.setNumber} reps`}
                  className="w-full rounded-lg border border-dashed border-line bg-field px-1 py-1.5 text-center text-[13px]"
                />
                <input
                  type="number"
                  inputMode="decimal"
                  defaultValue={s.actualWeight ?? ""}
                  placeholder={
                    card.suggestedWeight != null
                      ? String(card.suggestedWeight)
                      : "wt"
                  }
                  onBlur={(e) =>
                    handlers.persistSet(s.id, {
                      actual_weight: parseWeight(e.target.value),
                    })
                  }
                  aria-label={`set ${s.setNumber} weight`}
                  className="w-full rounded-lg border border-dashed border-line bg-field px-1.5 py-1.5 text-center text-[13px]"
                />
              </>
            )}
            <DoneBox
              checked={setDone[s.id] ?? false}
              onToggle={() => handlers.toggleSetDone(card, s.id)}
              label={`set ${s.setNumber} done`}
            />
          </div>
        ))}
      </div>

      <div className="border-t border-line-2">
        <button
          type="button"
          onClick={() => setOpenNote((o) => !o)}
          aria-expanded={openNote}
          className="flex w-full items-center gap-2 px-[15px] py-2.5 text-left text-[12.5px] text-ink-3"
        >
          <span>＋ Note / pain</span>
          {!openNote && hasMarker && (
            <span className="ml-auto flex min-w-0 items-center gap-1.5 text-[11px]">
              {ex.pain && (
                <>
                  <span className="h-[7px] w-[7px] rounded-full bg-amber" />
                  <span className="font-semibold capitalize text-amber">
                    {ex.pain}
                  </span>
                </>
              )}
              {ex.note && (
                <span className="max-w-[120px] truncate text-ink-2">
                  · {ex.note}
                </span>
              )}
            </span>
          )}
          <span className={`text-[11px] ${hasMarker && !openNote ? "" : "ml-auto"}`}>
            {openNote ? "▲" : "▼"}
          </span>
        </button>
        {openNote && (
          <div className="px-[15px] pb-3.5">
            <div className="mb-2.5 flex gap-1.5">
              {(["mild", "sharp"] as const).map((sev) => (
                <button
                  key={sev}
                  type="button"
                  onClick={() => handlers.setPain(card, sev)}
                  className={`flex-1 rounded-lg border py-1.5 text-[12px] capitalize ${
                    ex.pain === sev
                      ? "border-amber bg-amber text-white"
                      : "border-line bg-field text-ink-2"
                  }`}
                >
                  {sev}
                </button>
              ))}
            </div>
            <textarea
              defaultValue={ex.note}
              onBlur={(e) => handlers.setNote(card, e.target.value)}
              rows={2}
              placeholder="Anything to note — pain location, form, how it felt…"
              className="w-full resize-none rounded-lg border border-dashed border-line bg-field px-2.5 py-2 text-[13px]"
            />
          </div>
        )}
      </div>
    </div>
  );
}

function Cues({
  description,
  cues,
  className,
}: {
  description: string | null;
  cues: string[];
  className?: string;
}) {
  return (
    <div className={className}>
      {description && (
        <p className="mb-2 text-[12.5px] leading-relaxed text-ink-2">
          {description}
        </p>
      )}
      <ul className="flex list-disc flex-col gap-1.5 pl-4">
        {cues.map((c, i) => (
          <li key={i} className="text-[12.5px] leading-snug text-ink">
            {c}
          </li>
        ))}
      </ul>
    </div>
  );
}

function DoneBox({
  checked,
  onToggle,
  label,
  small,
}: {
  checked: boolean;
  onToggle: () => void;
  label: string;
  small?: boolean;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label}
      onClick={onToggle}
      className={`mx-auto flex items-center justify-center rounded-[7px] border text-[14px] ${
        small ? "h-5 w-5" : "h-6 w-6"
      } ${checked ? "border-ink bg-ink text-white" : "border-line text-transparent"}`}
    >
      ✓
    </button>
  );
}

function repRange(s: { targetRepsLow: number; targetRepsHigh: number }): string {
  return s.targetRepsLow === s.targetRepsHigh
    ? `${s.targetRepsLow}`
    : `${s.targetRepsLow}–${s.targetRepsHigh}`;
}

function formatTarget(card: ExerciseCard): string {
  const reps =
    card.targetRepsLow === card.targetRepsHigh
      ? `${card.targetRepsLow}`
      : `${card.targetRepsLow}–${card.targetRepsHigh}`;
  const base = `${card.targetSets} × ${reps}${card.perSide ? " / side" : ""}`;
  const rir = formatRir(card);
  return rir ? `${base} · ${rir}` : base;
}

/**
 * RIR (reps-in-reserve) guidance, e.g. "1–2 RIR" or "2 RIR". Returns null when
 * the prescription has no RIR target (warm-ups, core, carries, cuff/scapular
 * work) so nothing extra is rendered. Display-only — RIR is never logged.
 */
function formatRir(card: ExerciseCard): string | null {
  if (card.targetRirLow == null) return null;
  const range =
    card.targetRirHigh == null || card.targetRirLow === card.targetRirHigh
      ? `${card.targetRirLow}`
      : `${card.targetRirLow}–${card.targetRirHigh}`;
  return `${range} RIR`;
}

function parseWeight(v: string): number | null {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : null;
}

function parseReps(v: string): number | null {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

// ── Rest timer bar (Phase 9) ─────────────────────────────────────────────────
// Remounted on every (re)start via a `key`, so its state initialises fresh. The
// remaining time is recomputed from `startedAt` on each tick and whenever the
// tab becomes visible again — a backgrounded/locked screen that throttles the
// interval can't make it drift. `onComplete` fires exactly once at zero.
function RestTimerBar({
  timer,
  onComplete,
  onReset,
  onDismiss,
}: {
  timer: RestTimer;
  onComplete: () => void;
  onReset: () => void;
  onDismiss: () => void;
}) {
  const { startedAt, durationSeconds, exerciseName } = timer;
  const remainingAt = () =>
    Math.max(0, durationSeconds - Math.floor((Date.now() - startedAt) / 1000));

  const [remaining, setRemaining] = useState(remainingAt);

  // Keep the cue callback current without re-running the ticking effect.
  const onCompleteRef = useRef(onComplete);
  useEffect(() => {
    onCompleteRef.current = onComplete;
  });

  useEffect(() => {
    let fired = false;
    const sync = () => {
      const r = remainingAt();
      setRemaining(r);
      if (r <= 0 && !fired) {
        fired = true;
        onCompleteRef.current();
      }
    };
    sync();
    const id = setInterval(sync, 250);
    const onVisible = () => {
      if (document.visibilityState === "visible") sync();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", onVisible);
    };
    // startedAt/durationSeconds are stable for the bar's lifetime (a reset
    // remounts via key), so this runs once per rest.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startedAt, durationSeconds]);

  const done = remaining <= 0;

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-0 z-20 flex justify-center px-3 pb-3">
      <div
        className={`pointer-events-auto flex w-full max-w-[420px] items-center gap-3 rounded-card border px-4 py-3 shadow-[0_8px_30px_rgba(0,0,0,0.18)] ${
          done ? "border-amber bg-amber text-white" : "border-line bg-card"
        }`}
        role="status"
        aria-live="polite"
      >
        <div className="min-w-0 flex-1">
          <div
            className={`text-[10px] uppercase tracking-[0.08em] ${
              done ? "text-white/80" : "text-ink-3"
            }`}
          >
            {done ? "Rest's up" : "Resting"} · {exerciseName}
          </div>
          <div
            className={`font-mono text-[22px] font-semibold leading-tight tabular-nums ${
              done ? "text-white" : "text-ink"
            }`}
          >
            {formatClock(remaining)}
          </div>
        </div>
        <button
          type="button"
          onClick={onReset}
          className={`rounded-lg border px-3 py-1.5 text-[12px] font-medium ${
            done
              ? "border-white/60 text-white"
              : "border-line bg-field text-ink-2"
          }`}
        >
          Reset
        </button>
        <button
          type="button"
          onClick={onDismiss}
          className={`rounded-lg border px-3 py-1.5 text-[12px] font-medium ${
            done ? "border-white bg-white text-amber" : "border-ink bg-ink text-white"
          }`}
        >
          {done ? "Dismiss" : "Skip"}
        </button>
      </div>
    </div>
  );
}

function formatClock(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

// A short, soft beep via Web Audio. The context is unlocked on the user's tap
// (primeAudio) so this can sound when the rest ends outside a gesture.
function playBeep(ctx: AudioContext): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.type = "sine";
  osc.frequency.value = 880;
  const t = ctx.currentTime;
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.2, t + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.45);
  osc.start(t);
  osc.stop(t + 0.45);
}
