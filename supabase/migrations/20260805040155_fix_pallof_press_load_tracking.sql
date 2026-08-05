-- fix_pallof_press_load_tracking
--
-- Pallof press logged progress never wrote back to the seed (auto_load=false,
-- increment_lb=null). Real load has climbed 15 -> 20 -> 30 -> 40 while the seed
-- still read 15, and reps were pinned at exactly 10 (no progression signal).
--
-- This migration enables load tracking on the exercise and resets the seed +
-- rep range on both of the user's prescriptions.
--
-- Scope: exercise matched by NAME (verified unique). The two template_exercises
-- rows are both owned by user 98251473-2fc9-4254-a4f9-6dc86135c1b2 — one in
-- 'Block 1 — Foundation', one in 'Block 2 — Variation', both in the day
-- 'Day B · Knee / single-leg'. They are distinct prescriptions, not duplicates;
-- both are updated, neither is deleted. No rows are deleted in this migration,
-- and no session / session_exercise / session_set rows are read or modified.

-- 0) Precondition guard: abort if 'Pallof press' is referenced by any template
--    NOT owned by the target user (is-distinct-from also catches null-owner
--    mesocycles). Migrations run in a transaction, so RAISE aborts everything.
do $$
begin
  if exists (
    select 1
    from public.template_exercises te
    join public.exercises e          on e.id  = te.exercise_id
    join public.template_blocks tb   on tb.id = te.block_id
    join public.workout_templates wt on wt.id = tb.template_id
    join public.mesocycles m         on m.id  = wt.mesocycle_id
    where e.name = 'Pallof press'
      and m.user_id is distinct from '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  ) then
    raise exception
      'Aborting: Pallof press is referenced by a template not owned by user 98251473-2fc9-4254-a4f9-6dc86135c1b2';
  end if;
end $$;

-- 1) exercises row 'Pallof press': enable load tracking; append cues idempotently.
--    array(subquery) appends only cues not already present, in order — an
--    UPDATE ... FROM (VALUES ...) would append just one element per row.
update public.exercises e
set auto_load    = true,
    increment_lb = 5,
    cues = e.cues || array(
      select v.c
      from (values
        ('Cable stack numbers are machine-specific — log which station you used if you switch', 1),
        ('Press straight out from the sternum and resist rotation; the load should never turn you', 2),
        ('Keep the ribs down and hips square through the whole press', 3)
      ) as v(c, ord)
      where not (v.c = any(e.cues))
      order by v.ord
    )
where e.name = 'Pallof press';

-- 2) Both 'Pallof press' prescriptions (Block 1 + Block 2, Day B, target user):
--    reset seed to the real working load and open the rep range.
--    target_sets, per_side, sort_order, and block placement are left untouched.
update public.template_exercises te
set seed_weight      = 40,
    seed_is_estimate = false,
    target_reps_low  = 8,
    target_reps_high = 12
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
join public.exercises oe         on oe.name = 'Pallof press'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and m.name in ('Block 1 — Foundation', 'Block 2 — Variation')
  and wt.name = 'Day B · Knee / single-leg';
