-- replace_lateral_raise_with_scaption
--
-- 'DB Lateral Raise' (Block 3, Day 2 Accessories) provokes shoulder pain for
-- user 98251473-2fc9-4254-a4f9-6dc86135c1b2. Replace it with the scapular-plane
-- variant 'Scaption (full-can)' already in the library, then remove the now-unused
-- exercise row. Scoped to this user's Block 3 only — nothing in Block 1/2 or
-- Betsy's data is touched. Names matched EXACT + case-sensitive.

-- 0a) Both exercise names must resolve to exactly one row.
do $$
begin
  if (select count(*) from public.exercises where name = 'DB Lateral Raise') <> 1 then
    raise exception 'Aborting: DB Lateral Raise did not resolve to exactly one exercise row';
  end if;
  if (select count(*) from public.exercises where name = 'Scaption (full-can)') <> 1 then
    raise exception 'Aborting: Scaption (full-can) did not resolve to exactly one exercise row';
  end if;
end $$;

-- 0b) Scaption must stay exclusively this user's before we flip its flags.
do $$
begin
  if exists (
    select 1
    from public.template_exercises te
    join public.exercises e          on e.id = te.exercise_id
    join public.template_blocks tb   on tb.id = te.block_id
    join public.workout_templates wt on wt.id = tb.template_id
    join public.mesocycles m         on m.id = wt.mesocycle_id
    where e.name = 'Scaption (full-can)'
      and m.user_id is distinct from '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  ) then
    raise exception
      'Aborting: Scaption (full-can) is referenced by a template not owned by user 98251473-2fc9-4254-a4f9-6dc86135c1b2';
  end if;
end $$;

-- 0c) Exactly one Day 2 Accessories 'DB Lateral Raise' row to repoint.
do $$
declare n int;
begin
  select count(*) into n
  from public.template_exercises te
  join public.exercises e          on e.id = te.exercise_id
  join public.template_blocks tb   on tb.id = te.block_id
  join public.workout_templates wt on wt.id = tb.template_id
  join public.mesocycles m         on m.id = wt.mesocycle_id
  where e.name = 'DB Lateral Raise'
    and m.name = 'Block 3 — Upper/Lower'
    and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
    and wt.name = 'Day 2 · Upper — press bias'
    and tb.label = 'Accessories';
  if n <> 1 then
    raise exception 'Aborting: expected exactly one Day 2 Accessories DB Lateral Raise row, found %', n;
  end if;
end $$;

-- 1) Repoint Day 2 Accessories: DB Lateral Raise -> Scaption (full-can).
update public.template_exercises te
set exercise_id      = (select id from public.exercises where name = 'Scaption (full-can)'),
    target_sets      = 3,
    target_reps_low  = 12,
    target_reps_high = 15,
    target_rir_low   = null,
    target_rir_high  = null,
    per_side         = false,
    seed_weight      = 10,
    seed_is_estimate = false
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id = wt.mesocycle_id
join public.exercises oe         on oe.name = 'DB Lateral Raise'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.name = 'Block 3 — Upper/Lower'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name = 'Day 2 · Upper — press bias'
  and tb.label = 'Accessories';

-- 2) Scaption load tracking (idempotent — already enabled in a prior migration).
update public.exercises
set auto_load    = true,
    increment_lb = 2.5
where name = 'Scaption (full-can)';

-- 3) Delete 'DB Lateral Raise' ONLY if fully unreferenced after the repoint:
--    no template_exercises, no session history, no user_exercise_progress.
do $$
declare te_refs int; hist int; prog int;
begin
  select count(*) into te_refs
  from public.template_exercises te
  join public.exercises e on e.id = te.exercise_id
  where e.name = 'DB Lateral Raise';

  select count(*) into hist
  from public.session_exercises se
  join public.template_exercises te on te.id = se.template_exercise_id
  join public.exercises e on e.id = te.exercise_id
  where e.name = 'DB Lateral Raise';

  select count(*) into prog
  from public.user_exercise_progress uep
  join public.exercises e on e.id = uep.exercise_id
  where e.name = 'DB Lateral Raise';

  if te_refs <> 0 or hist <> 0 or prog <> 0 then
    raise exception
      'Aborting delete: DB Lateral Raise still referenced (template_exercises=%, session history=%, progress=%)',
      te_refs, hist, prog;
  end if;

  delete from public.exercises where name = 'DB Lateral Raise';
end $$;
