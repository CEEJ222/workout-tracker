-- snapshot_exercise_id_on_session_exercises
--
-- The fix CLAUDE.md lists as "Planned": snapshot exercise identity onto
-- session_exercises at session creation, the same way session_sets already
-- snapshots target_reps_low / target_reps_high.
--
-- Until now a session's exercise identity was resolved at READ time by walking
-- session_exercises -> template_exercises -> exercises. That made history a
-- function of live, mutable template config: repointing template_exercises
-- .exercise_id silently rewrote (and merged) past sessions. That is exactly the
-- 2026-08-05 Block 1 incident, repaired in 20260815043113 and now blocked by the
-- template_exercises_forbid_repoint trigger (20260815043900).
--
-- The trigger prevents the bad write. This makes the bad write harmless.
--
-- Left NULLABLE deliberately: a later migration can tighten to NOT NULL once
-- start_session has been the only writer for long enough that nothing writes
-- null. `on delete restrict` matches the existing posture that a row with
-- history cannot be deleted out from under it.

-- 1) The column.
alter table public.session_exercises
  add column exercise_id uuid null
    references public.exercises (id) on delete restrict;

comment on column public.session_exercises.exercise_id is
  'Exercise identity snapshotted at session creation. Read this, NOT the join '
  'through template_exercises — that join resolves against live template config '
  'and makes history mutable. Populated by start_session(). Nullable only until '
  'a later migration tightens it.';

-- 2) Backfill from the template row.
--    Correct as of now: the four contaminated Block 1 rows were repaired in
--    20260815043113, so template_exercises.exercise_id currently agrees with
--    what each historical session actually was. This backfill freezes that
--    agreement in place; it must not be re-run after any future repoint.
update public.session_exercises se
set exercise_id = te.exercise_id
from public.template_exercises te
where te.id = se.template_exercise_id
  and se.exercise_id is null;

-- 3) Verification guard: every row must have resolved. Migrations run in a
--    transaction, so this aborts the whole migration if the backfill was partial.
do $$
declare
  v_total   bigint;
  v_filled  bigint;
begin
  select count(*), count(exercise_id) into v_total, v_filled
  from public.session_exercises;

  if v_total <> v_filled then
    raise exception
      'Backfill incomplete: % of % session_exercises rows have exercise_id',
      v_filled, v_total;
  end if;

  raise notice 'Backfilled % of % session_exercises rows', v_filled, v_total;
end $$;

-- 4) Index: history/analytics group by this column.
create index if not exists session_exercises_exercise_id_idx
  on public.session_exercises (exercise_id);

-- 5) start_session populates it on insert.
--    Preserved exactly: security invoker (no SECURITY DEFINER), search_path = '',
--    and the `te.retired_at is null` filter. Only the two additions below differ
--    from the prior definition.
--
--    NOTE: this definition is superseded two minutes later by
--    20260815052849_start_session_restore_returning_clause.sql, which restores
--    the original `returning id into v_se`. Kept verbatim here so the migration
--    history replays exactly as it was applied.
create or replace function public.start_session(p_template_id uuid)
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  v_session uuid;
  v_se uuid;
  rx record;
begin
  insert into public.sessions (user_id, template_id)
  values (auth.uid(), p_template_id)
  returning id into v_session;

  for rx in
    select te.id, te.exercise_id, te.target_sets, te.target_reps_low, te.target_reps_high
    from public.template_exercises te
    join public.template_blocks tb on tb.id = te.block_id
    where tb.template_id = p_template_id
      and te.retired_at is null
    order by tb.sort_order, te.sort_order
  loop
    insert into public.session_exercises (session_id, template_exercise_id, exercise_id)
    values (v_session, rx.id, rx.exercise_id);

    v_se := (select id from public.session_exercises
             where session_id = v_session and template_exercise_id = rx.id);

    insert into public.session_sets
      (session_exercise_id, set_number, target_reps_low, target_reps_high)
    select v_se, g, rx.target_reps_low, rx.target_reps_high
    from generate_series(1, rx.target_sets) as g;
  end loop;

  return v_session;
end;
$function$;
