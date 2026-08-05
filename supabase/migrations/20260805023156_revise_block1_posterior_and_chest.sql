-- revise_block1_posterior_and_chest
--
-- Scope: mesocycle 'Block 1 — Foundation', user 98251473-2fc9-4254-a4f9-6dc86135c1b2 ONLY.
-- Every template_exercises write below joins back to that mesocycle + user so Block 2
-- and Betsy's program (user 062fd8bd-96e5-40b0-812c-2886c06fd284) are never touched.
--
-- Exceptions (intentional, see changes 6-8): cue appends on GLOBAL exercises rows that
-- Betsy's templates also reference. cues are shared library metadata; we only ever APPEND
-- a cue string that is not already present, and never overwrite or drop an existing cue.
--
-- Exercises are matched by NAME against the live library (verified unique) — no hardcoded
-- exercise UUIDs. Repoints are UPDATEs to existing template_exercises rows, so their ids
-- (and therefore every session_exercise / session_set that points at them) stay intact.
-- No session, session_exercise, or session_set rows are read or modified.
--
-- Note: the exercises table has no user_id column — the library is global by construction,
-- so change 1's "global row" is satisfied simply by inserting with no ownership column.

-- 1) New global exercise: Cable Chest Fly (managed range).
--    Guarded by a name-existence check so re-running is safe.
insert into public.exercises (name, description, cues, log_type, auto_load, increment_lb, rest_seconds)
select
  'Cable Chest Fly (managed range)',
  'Horizontal adduction at a cable station. The arms sweep together in an arc with the elbows held at a fixed, slightly bent angle, so the shoulder does the work rather than the elbow. The outer range is deliberately managed: the chest is loaded near full length without driving the shoulder into end-range extension.',
  ARRAY[
    'Set a soft, fixed elbow bend and hold that angle for the whole rep',
    'Sweep the hands together in an arc — this is not a press',
    'Stop the outward range with the hands roughly in line with the torso, not behind it',
    'Control the outward phase for 2-3 seconds; the stretch is the point',
    'Widen the outer stop before you add weight — range progresses first',
    'Brief squeeze at the top without letting the shoulders shrug up'
  ],
  'sets_weight', true, 5, 60
where not exists (
  select 1 from public.exercises where name = 'Cable Chest Fly (managed range)'
);

-- 2) Day A · Hinge / Primary: repoint 'Trap-bar deadlift' -> 'Barbell Hip Thrust'.
--    (sort_order left untouched to preserve sequencing within the block.)
update public.template_exercises te
set exercise_id      = (select id from public.exercises where name = 'Barbell Hip Thrust'),
    target_sets      = 3,
    target_reps_low  = 8,
    target_reps_high = 10,
    target_rir_low   = 1,
    target_rir_high  = 2,
    seed_weight      = 115,
    seed_is_estimate = false,
    per_side         = false
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
join public.exercises oe         on oe.name = 'Trap-bar deadlift'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.name    = 'Block 1 — Foundation'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name   = 'Day A · Hinge'
  and tb.label  = 'Primary';

-- 3) Day B · Knee / single-leg / Accessories: repoint 'Barbell / B-stance hip thrust'
--    -> '45-Degree Back Extension'. No RIR target.
update public.template_exercises te
set exercise_id      = (select id from public.exercises where name = '45-Degree Back Extension'),
    target_sets      = 3,
    target_reps_low  = 10,
    target_reps_high = 12,
    target_rir_low   = null,
    target_rir_high  = null,
    seed_weight      = 10,
    seed_is_estimate = true,
    per_side         = false
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
join public.exercises oe         on oe.name = 'Barbell / B-stance hip thrust'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.name    = 'Block 1 — Foundation'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name   = 'Day B · Knee / single-leg'
  and tb.label  = 'Accessories';

-- 4) Day B · Knee / single-leg / Accessories: INSERT 'Cable Chest Fly (managed range)'
--    as a new final row (sort_order = current max + 1). No RIR target.
--    Guarded by NOT EXISTS so re-running does not duplicate it.
insert into public.template_exercises
  (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high,
   target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate, sort_order)
select
  tb.id,
  (select id from public.exercises where name = 'Cable Chest Fly (managed range)'),
  null, 3, 10, 15, null, null, false, 20, true,
  coalesce(max(te.sort_order), -1) + 1
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
left join public.template_exercises te on te.block_id = tb.id
where m.name    = 'Block 1 — Foundation'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name   = 'Day B · Knee / single-leg'
  and tb.label  = 'Accessories'
  and not exists (
    select 1
    from public.template_exercises te2
    join public.exercises ex2 on ex2.id = te2.exercise_id
    where te2.block_id = tb.id
      and ex2.name = 'Cable Chest Fly (managed range)'
  )
group by tb.id;

-- 5) Day C · Posterior + upper / Accessories: repoint 'Suitcase carry'
--    -> 'Cable Chest Fly (managed range)'. Clears the per_side flag the carry used.
--    Scoped to Day C by template name (Day A also has a 'Suitcase carry' — leave it alone).
update public.template_exercises te
set exercise_id      = (select id from public.exercises where name = 'Cable Chest Fly (managed range)'),
    target_sets      = 3,
    target_reps_low  = 10,
    target_reps_high = 15,
    target_rir_low   = null,
    target_rir_high  = null,
    seed_weight      = 20,
    seed_is_estimate = true,
    per_side         = false
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
join public.exercises oe         on oe.name = 'Suitcase carry'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.name    = 'Block 1 — Foundation'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name   = 'Day C · Posterior + upper'
  and tb.label  = 'Accessories';

-- 6) Day C · Posterior + upper / Accessories: repoint 'Nordic hamstring curl (band-assisted)'
--    -> 'Seated Leg Curl'.
update public.template_exercises te
set exercise_id      = (select id from public.exercises where name = 'Seated Leg Curl'),
    target_sets      = 3,
    target_reps_low  = 8,
    target_reps_high = 12,
    target_rir_low   = 1,
    target_rir_high  = 2,
    seed_weight      = 60,
    seed_is_estimate = true,
    per_side         = false
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m         on m.id  = wt.mesocycle_id
join public.exercises oe         on oe.name = 'Nordic hamstring curl (band-assisted)'
where te.block_id    = tb.id
  and te.exercise_id = oe.id
  and m.name    = 'Block 1 — Foundation'
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and wt.name   = 'Day C · Posterior + upper'
  and tb.label  = 'Accessories';

-- 6b) Append cues to GLOBAL 'Seated Leg Curl' (shared with Betsy — intentional).
--     Only missing cues are appended, in order; existing cues are preserved.
update public.exercises e
set cues = e.cues || array(
  select v.c
  from (values
    ('Lower for about 3 seconds — the eccentric is where the adaptation comes from', 1),
    ('Keep the hips settled back in the seat so the hamstring stays at length', 2),
    ('Let the knee straighten fully at the top of each rep', 3)
  ) as v(c, ord)
  where not (v.c = any(e.cues))
  order by v.ord
)
where e.name = 'Seated Leg Curl';

-- 7) Append cues to GLOBAL 'Barbell Hip Thrust' (shared with Betsy — intentional).
update public.exercises e
set cues = e.cues || array(
  select v.c
  from (values
    ('Chin tucked and ribs down — the motion comes from the hips, not the lower back', 1),
    ('Drive through the heels and finish with the hips level, not hyperextended', 2),
    ('Hold a beat at lockout before lowering', 3)
  ) as v(c, ord)
  where not (v.c = any(e.cues))
  order by v.ord
)
where e.name = 'Barbell Hip Thrust';

-- 8) Append cues to GLOBAL '45-Degree Back Extension' (shared with Betsy — intentional).
update public.exercises e
set cues = e.cues || array(
  select v.c
  from (values
    ('Hinge at the hips and finish with the torso in line with the legs — no cranking past level', 1),
    ('Pick neutral spine or a controlled round-back and stay consistent set to set', 2),
    ('Add load at the chest only once the bodyweight version is smooth for all reps', 3)
  ) as v(c, ord)
  where not (v.c = any(e.cues))
  order by v.ord
)
where e.name = '45-Degree Back Extension';
