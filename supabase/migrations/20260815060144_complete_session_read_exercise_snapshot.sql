-- complete_session_read_exercise_snapshot
--
-- complete_session resolved the exercise for progression write-back by joining
-- session_exercises -> template_exercises -> exercises, i.e. through live,
-- mutable template config. That is the same read-through-config pattern the
-- session_exercises.exercise_id snapshot (20260815052833) exists to retire.
--
-- It now joins exercises directly on se.exercise_id. template_exercises is
-- still joined, but only for te.seed_weight, which is genuinely a property of
-- the prescription rather than of the exercise.
--
-- Verified equivalent on current data before applying: the loop's row-set
-- resolved both ways is identical (148 rows, 0 rows exclusive to either side,
-- 0 session_exercises with a null snapshot), so this changes no existing
-- user_exercise_progress value.
--
-- Note on the nullable snapshot: se.exercise_id is still nullable, so an inner
-- join means a null-snapshot row would be skipped by the auto-load loop rather
-- than mis-attributed. Skipping is the safe failure here — it declines to write
-- progress instead of writing it against the wrong exercise. start_session
-- always populates the column and the backfill left none null.
--
-- Preserved exactly: security invoker (no SECURITY DEFINER), search_path = '',
-- and every branch of the auto-load logic (pain gating, all-sets-at-top
-- progression, seed/existing fallback chain, the upsert).

create or replace function public.complete_session(p_session_id uuid)
returns void
language plpgsql
set search_path to ''
as $function$
declare
  rec record;
  v_base_actual numeric;
  v_all_top boolean;
  v_existing numeric;
  v_base numeric;
  v_new numeric;
begin
  update public.sessions
    set status = 'completed', completed_at = now()
    where id = p_session_id and status = 'in_progress';

  for rec in
    select se.id as se_id,
           se.pain_severity,
           e.id as exercise_id,
           e.increment_lb,
           te.seed_weight
    from public.session_exercises se
    join public.exercises e on e.id = se.exercise_id
    join public.template_exercises te on te.id = se.template_exercise_id
    where se.session_id = p_session_id
      and e.auto_load = true
  loop
    select
      max(ss.actual_weight) filter (where ss.done and ss.actual_weight is not null),
      (count(*) > 0)
        and bool_and(coalesce(ss.done, false))
        and bool_and(coalesce(ss.actual_reps >= ss.target_reps_high, false))
    into v_base_actual, v_all_top
    from public.session_sets ss
    where ss.session_exercise_id = rec.se_id;

    select current_weight into v_existing
    from public.user_exercise_progress
    where user_id = auth.uid() and exercise_id = rec.exercise_id;

    v_base := coalesce(v_base_actual, v_existing, rec.seed_weight);

    if v_base is null then
      continue;
    end if;

    if rec.pain_severity = 'sharp' then
      v_new := greatest(v_base - rec.increment_lb, 0);
    elsif rec.pain_severity = 'mild' then
      v_new := v_base;
    elsif v_all_top then
      v_new := v_base + rec.increment_lb;
    else
      v_new := v_base;
    end if;

    insert into public.user_exercise_progress
      (user_id, exercise_id, current_weight, is_estimate, last_pain_severity, updated_at)
    values
      (auth.uid(), rec.exercise_id, v_new, false, rec.pain_severity, now())
    on conflict (user_id, exercise_id) do update
      set current_weight = excluded.current_weight,
          is_estimate = false,
          last_pain_severity = excluded.last_pain_severity,
          updated_at = now();
  end loop;
end;
$function$;