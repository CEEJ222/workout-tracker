-- restrict_session_exercises_updates
--
-- session_exercises.exercise_id is now history-bearing: it is the snapshotted
-- identity that getWeightHistory, getPainTimeline and complete_session all read.
-- The RLS policy on this table is FOR ALL, so a signed-in client could UPDATE
-- its own exercise_id and rewrite its own history — the same class of damage as
-- the 2026-08-05 template repoint, just reached from the other side.
--
-- Two layers, because the two realistic attack surfaces are different.
--
-- LAYER 1 — column privileges, for the client.
-- The app writes exactly three columns on this table (session-view.tsx
-- persistExercise: done, pain_severity, note). Postgres column-level UPDATE
-- grants express that directly, with no trigger and no per-row cost. RLS still
-- decides WHICH rows; this decides WHICH COLUMNS.
--
-- INSERT is untouched, so start_session (security invoker) still writes
-- session_id / template_exercise_id / exercise_id on creation. SELECT is
-- untouched. DELETE is untouched — discarding a session deletes from `sessions`
-- and cascades.
--
-- Note the fail-closed consequence: any column added to this table in future is
-- NOT updatable by the client until explicitly granted. That is the safer
-- default for a table that now stores history, but it will look like a bug to
-- whoever adds the next column, so it is stated here.
--
-- LAYER 2 — a trigger, for migration authoring.
-- Column grants do not restrain service_role or postgres, and CLAUDE.md is
-- explicit that the original contamination arrived "via service role / MCP,
-- i.e. migration authoring" — a human or model writing SQL directly. That is
-- the route the bug actually took, so it needs the same guard
-- template_exercises_forbid_repoint uses, including the same transaction-scoped
-- GUC escape hatch for deliberate repair.

-- ── Layer 1: column-level UPDATE privileges ────────────────────────────────
revoke update on public.session_exercises from authenticated, anon;

grant update (done, pain_severity, note)
  on public.session_exercises
  to authenticated, anon;

-- ── Layer 2: forbid exercise_id rewrites from any role ─────────────────────
create or replace function public.forbid_session_exercise_repoint()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if new.exercise_id is distinct from old.exercise_id
     and coalesce(current_setting('app.allow_exercise_repoint', true), 'off') <> 'on'
  then
    raise exception
      'Refusing to change exercise_id on session_exercises row % — this is the '
      'snapshotted identity of a logged session. Changing it rewrites history: '
      'the session would be relabeled and merged into another exercise''s chart '
      'series. If this is a deliberate history repair, run '
      '"set local app.allow_exercise_repoint = ''on'';" inside the same transaction.',
      old.id
      using errcode = 'raise_exception';
  end if;
  return new;
end;
$function$;

drop trigger if exists session_exercises_forbid_repoint on public.session_exercises;

create trigger session_exercises_forbid_repoint
  before update on public.session_exercises
  for each row
  execute function public.forbid_session_exercise_repoint();

comment on function public.forbid_session_exercise_repoint() is
  'Blocks UPDATEs that change session_exercises.exercise_id, the snapshotted '
  'exercise identity of a logged session. Same shape and same GUC escape hatch '
  'as forbid_repoint_with_history() on template_exercises. Guards the '
  'service-role / migration-authoring route that column grants cannot reach.';