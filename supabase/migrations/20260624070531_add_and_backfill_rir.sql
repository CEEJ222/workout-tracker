-- 1) RIR target columns on the prescription (nullable; pair like rep range)
alter table public.template_exercises
  add column target_rir_low integer,
  add column target_rir_high integer;

-- 2) Betsy's program: backfill from her source file's intensity_RIR values
update public.template_exercises te
set target_rir_low = r.lo, target_rir_high = r.hi
from (values
  ('Barbell Hip Thrust',1,2),
  ('Heel-Elevated Goblet Squat',1,2),
  ('Seated Hip Abduction Machine',0,1),
  ('Chest-Supported Dumbbell Row',1,2),
  ('Cable Face Pull',1,2),
  ('Lat Pulldown (shoulder-width)',1,2),
  ('Seated Cable Row (neutral grip)',1,2),
  ('Dumbbell Shoulder Press (seated, back supported)',1,2),
  ('Incline Dumbbell Curl',0,1),
  ('Cable Triceps Pushdown (rope)',0,1),
  ('Reverse Pec Deck (rear delt)',1,2),
  ('Dumbbell Romanian Deadlift',1,2),
  ('Dumbbell Bulgarian Split Squat',1,2),
  ('Standing Cable Hip Abduction',0,1),
  ('45-Degree Back Extension',1,2),
  ('Single-Arm Dumbbell Row',1,2),
  ('Machine Hip Thrust (or single-leg hip thrust)',1,2),
  ('Leg Press (feet high/wide for glute bias)',1,2),
  ('Seated Hip Abduction Machine (torso leaned forward)',0,1),
  ('Chest-Supported T-Bar / Machine Row',1,2),
  ('Band/Cable Pull-Apart',1,2),
  ('Assisted Pull-Up or Neutral-Grip Pulldown',1,2),
  ('Wide-Grip Seated Row',1,2),
  ('Machine Shoulder Press',1,2),
  ('Cable Curl (straight or EZ bar)',0,1),
  ('Overhead Cable Triceps Extension',0,1),
  ('Prone Bench Y-T-W Raises',1,2),
  ('Single-Leg Romanian Deadlift (DB)',1,2),
  ('Dumbbell Reverse Lunge',1,2),
  ('Banded X-Walks / Lateral Band Walks',0,1),
  ('Seated Leg Curl',0,1),
  ('Half-Kneeling Single-Arm Lat Pulldown (cable)',1,2)
) as r(ex_name, lo, hi)
join public.exercises e on e.name = r.ex_name
join public.workout_templates wt on wt.mesocycle_id in (
  select id from public.mesocycles where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284')
join public.template_blocks tb on tb.template_id = wt.id
where te.exercise_id = e.id and te.block_id = tb.id;

-- 3) Your program: 1-2 RIR on the loaded compounds (auto_load), null elsewhere
update public.template_exercises te
set target_rir_low = 1, target_rir_high = 2
from public.template_blocks tb
join public.workout_templates wt on wt.id = tb.template_id
join public.mesocycles m on m.id = wt.mesocycle_id
where te.block_id = tb.id
  and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and exists (
    select 1 from public.exercises e
    where e.id = te.exercise_id and e.auto_load = true
  );
