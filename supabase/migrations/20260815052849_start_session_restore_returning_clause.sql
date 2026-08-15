-- start_session_restore_returning_clause
--
-- The previous migration (snapshot_exercise_id_on_session_exercises) needlessly
-- rewrote the session_exercises insert to use a follow-up SELECT to recover the
-- new id. That is slower and quietly depends on (session_id, template_exercise_id)
-- being unique, which nothing enforces.
--
-- This restores the original `returning id into v_se` form. The only intended
-- differences from the pre-snapshot definition remain: te.exercise_id is
-- selected, and exercise_id is populated on insert.
--
-- Preserved exactly: security invoker (no SECURITY DEFINER), search_path = '',
-- and the `te.retired_at is null` filter.

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
    values (v_session, rx.id, rx.exercise_id)
    returning id into v_se;

    insert into public.session_sets
      (session_exercise_id, set_number, target_reps_low, target_reps_high)
    select v_se, g, rx.target_reps_low, rx.target_reps_high
    from generate_series(1, rx.target_sets) as g;
  end loop;

  return v_session;
end;
$function$;
