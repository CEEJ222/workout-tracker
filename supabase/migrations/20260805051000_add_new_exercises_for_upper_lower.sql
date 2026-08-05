-- add_new_exercises_for_upper_lower
--
-- Six global library exercises for the Block 3 (Upper/Lower) seed. Exercises are
-- global (the table has no user_id column), so these are inserted with no owner.
-- Each row is guarded by a case-sensitive name-existence check, so the whole
-- insert is safe to re-run and won't duplicate anything.
--
-- NOTE: 'Dynamic leg swings' already exists in the library (added by
-- 20260624074227_seed_betsy_warmups). Its guard below will skip it, so this
-- migration inserts FIVE new rows, not six — the exercises total goes 77 -> 82.
-- 'Easy cardio raise' and 'Banded X-Walks / Lateral Band Walks' are intentionally
-- not created here; they already exist and are reused by the Block 3 seed.

insert into public.exercises
  (name, description, cues, log_type, auto_load, increment_lb, rest_seconds)
select
  v.name, v.description, v.cues, v.log_type::public.log_type,
  v.auto_load, v.increment_lb, v.rest_seconds
from (values
  ('DB Lateral Raise',
   'Dumbbell lateral raise for the side delts.',
   ARRAY[
     'Lead with the elbow, not the hand.',
     'Stop at shoulder height, not above.',
     'Control the lowering.',
     'Don''t shrug the trap up to move the weight.'
   ],
   'sets_weight', true, 5, 45),

  ('Standing Calf Raise',
   'Standing calf raise — works on a machine, a leg-press sled, or holding dumbbells on a step.',
   ARRAY[
     'Full stretch at the bottom.',
     'Brief pause at the top.',
     'Don''t bounce out of the bottom.'
   ],
   'sets_weight', true, 10, 45),

  ('Leg Press (quad bias)',
   'Leg press with a quad-biased setup — distinct from the glute-bias variation.',
   ARRAY[
     'Feet lower and closer together on the platform.',
     'Knees track over the toes.',
     'Don''t let the lower back round off the pad at the bottom.'
   ],
   'sets_weight', true, 10, 90),

  ('Dynamic leg swings',
   'Front-to-back and lateral swings to open the hips through range.',
   ARRAY[
     'Hold support.',
     'Controlled arc without forcing.',
     'Hips square.'
   ],
   'done_check', false, null, null),

  ('Deep squat + ankle rock',
   'Sit into a deep bodyweight squat and rock the knees forward over the toes.',
   ARRAY[
     'Heels down.',
     'Drive the knees forward over the toes.',
     'Sink into the bottom position.'
   ],
   'done_check', false, null, null),

  ('Scap pull-up / band lat primer',
   'Hang and depress/retract the shoulder blades without bending the elbows.',
   ARRAY[
     'Elbows straight.',
     'Pull the shoulders down and back.',
     'Small, controlled range.'
   ],
   'done_check', false, null, null)
) as v(name, description, cues, log_type, auto_load, increment_lb, rest_seconds)
where not exists (
  select 1 from public.exercises e where e.name = v.name  -- case-sensitive
);
