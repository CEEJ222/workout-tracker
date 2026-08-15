-- Prevent the class of corruption repaired in 20260815043113.
--
-- BACKGROUND
-- session_exercises references template_exercise_id, not exercise_id. The history
-- and charting code (src/lib/history.ts) resolves an exercise name by walking
-- session_exercises -> template_exercises -> exercises, and keys its series map on
-- exercises.id. So repointing a template_exercises row that already has logged
-- sessions does not merely relabel history — it MERGES the old sessions into the
-- new exercise's series and the original exercise's series disappears.
--
-- Repointing became the path of least resistance because deletion is already
-- blocked: session_exercises_template_exercise_id_fkey is ON DELETE NO ACTION.
-- With no way to remove a row and no way to retire it, UPDATE was the only move.
-- This migration supplies the missing third option and forbids the destructive one.

-- 1. The missing primitive: retire a template exercise without destroying its history.
alter table public.template_exercises
  add column if not exists retired_at timestamptz null;

comment on column public.template_exercises.retired_at is
  'Set to retire this exercise from future sessions while preserving its logged history. '
  'Retired rows are skipped by start_session. Retire + add a new row instead of '
  'repointing exercise_id — repointing rewrites history (see forbid_repoint_with_history).';

-- 2. Forbid repointing a row that has logged sessions.
create or replace function public.forbid_repoint_with_history()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if new.exercise_id is distinct from old.exercise_id
     and coalesce(current_setting('app.allow_exercise_repoint', true), 'off') <> 'on'
     and exists (
       select 1 from public.session_exercises se
       where se.template_exercise_id = old.id
     )
  then
    raise exception
      'Refusing to change exercise_id on template_exercises row % — it has logged sessions. '
      'Repointing rewrites history: past sessions would be relabeled and merged into the '
      'new exercise''s chart series. Set retired_at on this row and insert a new one instead. '
      'If this is a deliberate history repair, run "set local app.allow_exercise_repoint = ''on'';" '
      'inside the same transaction.',
      old.id
      using errcode = 'raise_exception';
  end if;
  return new;
end;
$function$;

drop trigger if exists template_exercises_forbid_repoint on public.template_exercises;
create trigger template_exercises_forbid_repoint
  before update on public.template_exercises
  for each row
  execute function public.forbid_repoint_with_history();

-- 3. Make retired_at functional. Only added clause is "te.retired_at is null";
--    the rest is byte-identical to the existing definition.
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
    select te.id, te.target_sets, te.target_reps_low, te.target_reps_high
    from public.template_exercises te
    join public.template_blocks tb on tb.id = te.block_id
    where tb.template_id = p_template_id
      and te.retired_at is null
    order by tb.sort_order, te.sort_order
  loop
    insert into public.session_exercises (session_id, template_exercise_id)
    values (v_session, rx.id)
    returning id into v_se;

    insert into public.session_sets
      (session_exercise_id, set_number, target_reps_low, target_reps_high)
    select v_se, g, rx.target_reps_low, rx.target_reps_high
    from generate_series(1, rx.target_sets) as g;
  end loop;

  return v_session;
end;
$function$;
