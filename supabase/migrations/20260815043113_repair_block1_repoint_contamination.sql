-- Repair repoint contamination in CJ's archived Block 1 — Foundation.
--
-- When Block 3 was built (2026-08-05), four template_exercises rows in Block 1
-- were repointed to new exercises instead of new rows being created. Because
-- session_exercises references template_exercise_id (not exercise_id), months of
-- logged history got retroactively relabeled as exercises that were never performed.
--
-- Block 1 is archived; these rows exist only as historical labels. Pointing them
-- back at what was actually performed makes the history truthful. Session data and
-- user_exercise_progress are NOT touched — both are already correct.
--
-- Each identification is corroborated by session notes AND by the surviving
-- user_exercise_progress row for the original exercise.

-- Day A · Hinge: 6-8 reps @ 95-175 lb, notes reference low-back twinge/spasm at
-- lockout. progress row 'Trap-bar deadlift' = 100, updated 2026-08-01
-- (Aug 1 logged 95 + one 5 lb auto_load step). -> Trap-bar deadlift
update template_exercises
set exercise_id = '862af51d-64d7-4616-9e76-7186a110c7c1',
    target_reps_low = 6, target_reps_high = 8
where id = (
  select te.id from template_exercises te
  join template_blocks tb on tb.id = te.block_id
  join workout_templates t on t.id = tb.template_id
  join mesocycles m on m.id = t.mesocycle_id
  where m.name = 'Block 1 — Foundation' and t.name = 'Day A · Hinge'
    and te.exercise_id = '8c810452-ea9a-4654-9acf-3a5edfabfd88' -- Barbell Hip Thrust
);

-- Day B · Knee/single-leg: 8-10 reps @ 95-135 lb, notes say "didn't do b stance
-- did bilateral" / "not b stance did it regular". progress row
-- 'Barbell / B-stance hip thrust' = 120, updated 2026-08-03 (Aug 3 logged 115 + 5).
update template_exercises
set exercise_id = 'b001d7b2-03d8-4bac-a710-17a8ef9f78b7',
    target_reps_low = 8, target_reps_high = 10, seed_weight = null
where id = 'eb61ba9e-7cdd-4b1f-a1af-0975a6c96ecf';

-- Day C · Posterior + upper: target 30-40 (seconds) @ constant 50 lb, note asks
-- "Is weight on one side? Or both? Do you switch sides?" -> Suitcase carry
update template_exercises
set exercise_id = 'e29b3187-9e9c-4908-91d6-2f03a08264b4',
    target_reps_low = 30, target_reps_high = 40
where id = (
  select te.id from template_exercises te
  join template_blocks tb on tb.id = te.block_id
  join workout_templates t on t.id = tb.template_id
  join mesocycles m on m.id = t.mesocycle_id
  where m.name = 'Block 1 — Foundation' and t.name = 'Day C · Posterior + upper'
    and te.exercise_id = '51af94be-8f64-4964-bbbb-70f91f2a0e60' -- Cable Chest Fly
);

-- Day C · Posterior + upper: 5-8 reps, no load ever recorded, note "Difficult"
-- -> Nordic hamstring curl (band-assisted)
update template_exercises
set exercise_id = '10d5237a-7fc9-4cff-a71c-9a95729ffff9',
    target_reps_low = 5, target_reps_high = 8, seed_weight = null
where id = (
  select te.id from template_exercises te
  join template_blocks tb on tb.id = te.block_id
  join workout_templates t on t.id = tb.template_id
  join mesocycles m on m.id = t.mesocycle_id
  where m.name = 'Block 1 — Foundation' and t.name = 'Day C · Posterior + upper'
    and te.exercise_id = '06ab6cee-2a51-4bd4-9fde-d20d8b600b2b' -- Seated Leg Curl
);

-- NOT CHANGED: the Block 1 Pallof press row. Its rep-target mismatch (8-12 vs
-- 10-10) is a template edit, not a repoint — session notes explicitly say
-- "Palof was 40 on the outside pulley system". It was always Pallof press.
