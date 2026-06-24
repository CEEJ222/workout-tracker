-- Mesocycles owned by Betsy
insert into public.mesocycles (name, sort_order, user_id) values
('Block A — Weeks 1-7', 1, '062fd8bd-96e5-40b0-812c-2886c06fd284'),
('Block B — Weeks 8-14', 2, '062fd8bd-96e5-40b0-812c-2886c06fd284');

-- Day templates (3 per block)
insert into public.workout_templates (name, sort_order, mesocycle_id)
select v.name, v.so, m.id
from (values
  ('Block A — Weeks 1-7','Day 1 · Lower (glute max)',0),
  ('Block A — Weeks 1-7','Day 2 · Upper (back/posture)',1),
  ('Block A — Weeks 1-7','Day 3 · Lower (glute med/ham)',2),
  ('Block B — Weeks 8-14','Day 1 · Lower (glute max)',0),
  ('Block B — Weeks 8-14','Day 2 · Upper (back/posture)',1),
  ('Block B — Weeks 8-14','Day 3 · Lower (glute med/ham)',2)
) as v(block, name, so)
join public.mesocycles m on m.name=v.block and m.user_id='062fd8bd-96e5-40b0-812c-2886c06fd284';

-- One block per day (straight sets), labeled by focus
insert into public.template_blocks (template_id, type, label, sort_order)
select wt.id, 'single', v.label, 0
from (values
  ('Block A — Weeks 1-7',0,'Lower — glute max + posture'),
  ('Block A — Weeks 1-7',1,'Upper — back/posture + arms'),
  ('Block A — Weeks 1-7',2,'Lower — glute med/ham + posture'),
  ('Block B — Weeks 8-14',0,'Lower — glute max + posture'),
  ('Block B — Weeks 8-14',1,'Upper — back/posture + arms'),
  ('Block B — Weeks 8-14',2,'Lower — glute med/ham + posture')
) as v(block, so, label)
join public.mesocycles m on m.name=v.block and m.user_id='062fd8bd-96e5-40b0-812c-2886c06fd284'
join public.workout_templates wt on wt.mesocycle_id=m.id and wt.sort_order=v.so;

-- Prescriptions (38)
with p(block, day_so, ex_name, sets, rl, rh, per_side, seed, est, ord) as (values
 ('Block A — Weeks 1-7',0,'Barbell Hip Thrust',3,8,12,false,95::numeric,true,0),
 ('Block A — Weeks 1-7',0,'Heel-Elevated Goblet Squat',3,8,12,false,25,true,1),
 ('Block A — Weeks 1-7',0,'Seated Hip Abduction Machine',3,12,20,false,40,true,2),
 ('Block A — Weeks 1-7',0,'Chest-Supported Dumbbell Row',3,10,15,false,20,true,3),
 ('Block A — Weeks 1-7',0,'Cable Face Pull',3,15,20,false,15,true,4),
 ('Block A — Weeks 1-7',0,'Dead Bug',3,8,10,true,null,false,5),
 ('Block A — Weeks 1-7',1,'Lat Pulldown (shoulder-width)',3,8,12,false,55,true,0),
 ('Block A — Weeks 1-7',1,'Seated Cable Row (neutral grip)',3,10,15,false,55,true,1),
 ('Block A — Weeks 1-7',1,'Dumbbell Shoulder Press (seated, back supported)',3,8,12,false,15,true,2),
 ('Block A — Weeks 1-7',1,'Incline Dumbbell Curl',3,10,15,false,10,true,3),
 ('Block A — Weeks 1-7',1,'Cable Triceps Pushdown (rope)',3,10,15,false,25,true,4),
 ('Block A — Weeks 1-7',1,'Reverse Pec Deck (rear delt)',3,15,20,false,null,false,5),
 ('Block A — Weeks 1-7',1,'Half-Kneeling Pallof Press',3,10,12,true,10,true,6),
 ('Block A — Weeks 1-7',2,'Dumbbell Romanian Deadlift',3,8,12,false,25,true,0),
 ('Block A — Weeks 1-7',2,'Dumbbell Bulgarian Split Squat',3,8,12,true,10,true,1),
 ('Block A — Weeks 1-7',2,'Standing Cable Hip Abduction',3,12,20,true,10,true,2),
 ('Block A — Weeks 1-7',2,'45-Degree Back Extension',3,12,15,false,null,false,3),
 ('Block A — Weeks 1-7',2,'Single-Arm Dumbbell Row',3,10,15,true,25,true,4),
 ('Block A — Weeks 1-7',2,'Forearm Plank',3,20,40,false,null,false,5),
 ('Block B — Weeks 8-14',0,'Machine Hip Thrust (or single-leg hip thrust)',3,8,12,false,null,false,0),
 ('Block B — Weeks 8-14',0,'Leg Press (feet high/wide for glute bias)',3,10,15,false,null,false,1),
 ('Block B — Weeks 8-14',0,'Seated Hip Abduction Machine (torso leaned forward)',3,12,20,false,40,true,2),
 ('Block B — Weeks 8-14',0,'Chest-Supported T-Bar / Machine Row',3,10,15,false,null,false,3),
 ('Block B — Weeks 8-14',0,'Band/Cable Pull-Apart',3,15,25,false,10,true,4),
 ('Block B — Weeks 8-14',0,'Bird Dog',3,8,10,true,null,false,5),
 ('Block B — Weeks 8-14',1,'Assisted Pull-Up or Neutral-Grip Pulldown',3,6,10,false,null,false,0),
 ('Block B — Weeks 8-14',1,'Wide-Grip Seated Row',3,10,15,false,null,false,1),
 ('Block B — Weeks 8-14',1,'Machine Shoulder Press',3,8,12,false,null,false,2),
 ('Block B — Weeks 8-14',1,'Cable Curl (straight or EZ bar)',3,10,15,false,null,false,3),
 ('Block B — Weeks 8-14',1,'Overhead Cable Triceps Extension',3,10,15,false,null,false,4),
 ('Block B — Weeks 8-14',1,'Prone Bench Y-T-W Raises',2,10,12,false,2,true,5),
 ('Block B — Weeks 8-14',1,'Cable Anti-Rotation Chop',3,10,12,true,null,false,6),
 ('Block B — Weeks 8-14',2,'Single-Leg Romanian Deadlift (DB)',3,8,12,true,15,true,0),
 ('Block B — Weeks 8-14',2,'Dumbbell Reverse Lunge',3,10,12,true,10,true,1),
 ('Block B — Weeks 8-14',2,'Banded X-Walks / Lateral Band Walks',3,12,15,true,null,false,2),
 ('Block B — Weeks 8-14',2,'Seated Leg Curl',3,10,15,false,null,false,3),
 ('Block B — Weeks 8-14',2,'Half-Kneeling Single-Arm Lat Pulldown (cable)',3,10,15,true,null,false,4),
 ('Block B — Weeks 8-14',2,'Ab Wheel / Cable Fallout',3,6,10,false,null,false,5)
)
insert into public.template_exercises
 (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order)
select tb.id, e.id, null, p.sets, p.rl, p.rh, p.per_side, p.seed, p.est, p.ord
from p
join public.mesocycles m on m.name=p.block and m.user_id='062fd8bd-96e5-40b0-812c-2886c06fd284'
join public.workout_templates wt on wt.mesocycle_id=m.id and wt.sort_order=p.day_so
join public.template_blocks tb on tb.template_id=wt.id
join public.exercises e on e.name=p.ex_name;

-- Default her active block to Block A
insert into public.user_settings (user_id, active_mesocycle_id)
select '062fd8bd-96e5-40b0-812c-2886c06fd284', m.id
from public.mesocycles m
where m.name='Block A — Weeks 1-7' and m.user_id='062fd8bd-96e5-40b0-812c-2886c06fd284'
on conflict (user_id) do nothing;
