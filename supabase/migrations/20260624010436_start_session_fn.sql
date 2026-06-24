create or replace function public.start_session(p_template_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_session uuid;
  v_se uuid;
  te record;
begin
  insert into public.sessions (user_id, template_id)
  values (auth.uid(), p_template_id)
  returning id into v_session;

  for te in
    select te.id, te.target_sets, te.target_reps_low, te.target_reps_high
    from public.template_exercises te
    join public.template_blocks tb on tb.id = te.block_id
    where tb.template_id = p_template_id
    order by tb.sort_order, te.sort_order
  loop
    insert into public.session_exercises (session_id, template_exercise_id)
    values (v_session, te.id)
    returning id into v_se;

    insert into public.session_sets
      (session_exercise_id, set_number, target_reps_low, target_reps_high)
    select v_se, g, te.target_reps_low, te.target_reps_high
    from generate_series(1, te.target_sets) as g;
  end loop;

  return v_session;
end;
$$;
