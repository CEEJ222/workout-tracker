-- ============================================================================
-- start_session(template_id) — atomically create an in-progress session and
-- pre-build its session_exercises + session_sets from the template (Phase 5).
--
-- SECURITY INVOKER so it runs as the calling user: RLS still applies, the
-- session is owned by auth.uid(), and the whole thing is one transaction (no
-- half-built sessions). search_path is pinned empty; every object is schema-
-- qualified (security lint 0011).
-- ============================================================================
create or replace function public.start_session(p_template_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_session uuid;
  v_se uuid;
  rx record;  -- loop variable; must not collide with the table alias below
begin
  insert into public.sessions (user_id, template_id)
  values (auth.uid(), p_template_id)
  returning id into v_session;

  for rx in
    select te.id, te.target_sets, te.target_reps_low, te.target_reps_high
    from public.template_exercises te
    join public.template_blocks tb on tb.id = te.block_id
    where tb.template_id = p_template_id
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
$$;
