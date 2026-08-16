-- CJ's gym has no reverse pec deck machine. His Day 4 slot has never been logged,
-- which is consistent.
--
-- Cable face pull is the substitute rather than a cable reverse fly because it is
-- the only movement in his block that loads EXTERNAL ROTATION outside the warm-up
-- circuit. His rotator_cuff volume is 2.5 fractional and entirely indirect, which
-- matters given frozen-shoulder history. Face pull credits rear_delt 1.0,
-- rotator_cuff 0.5, upper_back 0.5 — it covers the rear delt gap and the cuff gap
-- in the same three sets.
--
-- Retire + insert, not repoint. Correct pattern regardless of whether the old row
-- has sessions.
--
-- NOTE: 'Reverse Pec Deck (rear delt)' is one of the 11 shared exercise ids. It
-- stays in Betsy's Block C, where she HAS logged it (30 lb) and does have the
-- machine. Only CJ's slot is retired.

update public.template_exercises
set retired_at = now()
where id = '7d15c5df-b37e-43c4-8c65-485a6d6133c1'; -- CJ Day 4 · Reverse Pec Deck

insert into public.template_exercises
  (id, block_id, exercise_id, target_sets, target_reps_low, target_reps_high,
   target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate,
   rest_seconds, sort_order)
values
  (gen_random_uuid(), '2f74ad2c-6b18-4e94-b575-9b02d2216ddb',
   'ba854cbe-e91b-46cf-b8e5-7e52657676b9', 3, 12, 15, 0, 1, false, 40, true, 45, 1);

-- Cue the movement for a shoulder-constrained lifter: the value is in the
-- external rotation, which is lost the moment the load gets heavy enough to row.
update public.exercises
set description = 'Rope face pull to the forehead, finishing with the hands wide and the '
                  'knuckles up. Trains rear delt, mid-back and external rotation together. '
                  'Load light enough to actually rotate — it stops being a face pull the '
                  'moment it becomes a row.',
    cues = array[
      'Rope at eye height or slightly above.',
      'Pull to the forehead, elbows high and wide.',
      'Finish with knuckles up — the external rotation IS the exercise.',
      'Light enough to rotate. If it turns into a row, drop the weight.',
      'Pause a beat at the end position.'
    ]
where id = 'ba854cbe-e91b-46cf-b8e5-7e52657676b9';
