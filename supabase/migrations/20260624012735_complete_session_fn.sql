-- ============================================================================
-- complete_session(session_id) — finalize a workout and run pain-aware
-- progression (Phase 7), atomically and as the calling user (RLS applies).
--
-- For each logged exercise with auto_load = true:
--   * sharp pain  → back off one increment (floor 0)        [the safety gate]
--   * mild pain   → hold
--   * a clean session at the TOP of the rep range (every set done and every
--     actual_reps >= target_reps_high) → bump one increment
--   * otherwise   → hold
-- last_pain_severity records this session's pain flag. The new weight is based
-- on what was actually lifted (logged actuals are the source of truth), falling
-- back to the prior suggestion, then the template seed. auto_load = false
-- exercises (cuff/scapular/core/carry) never get a weight write; warm-up items
-- are auto_load = false too, so they're excluded naturally.
-- ============================================================================
create or replace function public.complete_session(p_session_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  rec record;
  v_base_actual numeric;
  v_all_top boolean;
  v_existing numeric;
  v_base numeric;
  v_new numeric;
begin
  -- Finalize only if still in progress (and visible to the caller via RLS).
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
    join public.template_exercises te on te.id = se.template_exercise_id
    join public.exercises e on e.id = te.exercise_id
    where se.session_id = p_session_id
      and e.auto_load = true
  loop
    -- Heaviest completed working weight, and whether the whole exercise was
    -- completed at the top of the rep range.
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

    -- No weight basis yet (e.g. bodyweight) → nothing to progress.
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
$$;
