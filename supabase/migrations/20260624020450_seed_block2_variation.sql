-- 1) Block 2 exercise variations
insert into public.exercises (name, description, cues, log_type, auto_load, increment_lb) values
('Barbell RDL','Barbell Romanian deadlift — Block 2 hinge primary.',ARRAY['Hinge from the hips, bar close to the legs, soft knees.','Feel the hamstrings load; stop when your back wants to round.','~2 reps in reserve; controlled lower.'],'sets_weight',true,5),
('Half-kneeling landmine press','Single-arm landmine press from a half-kneeling base.',ARRAY['Half-kneeling locks your base so the press is all shoulder.','Press up and slightly forward; let the blade wrap at the top.','3s lower; stop short of any pinch.'],'sets_weight',true,2.5),
('Chest-supported incline DB row','Chest-supported dumbbell row on an incline bench.',ARRAY['Chest on the pad takes your low back out of it.','Row the elbow down-and-back; pause at the top.','Right side does its own work.'],'sets_weight',true,2.5),
('Single-leg RDL','True single-leg Romanian deadlift.',ARRAY['Balance on one leg, hinge, hips square — do not let the free hip open.','Slow and controlled; control beats range.','Light to start.'],'sets_weight',true,2.5),
('Reverse lunge','Reverse (step-back) lunge.',ARRAY['Step back, drop the back knee under control, drive through the front heel.','Torso tall.','Easier on the knee than a forward lunge.'],'sets_weight',true,2.5),
('Neutral-grip lat pulldown','Neutral-grip cable lat pulldown.',ARRAY['Neutral grip; pull to the upper chest.','Control the bar back up — no leaning way back.','Keep ribs down.'],'sets_weight',true,5),
('Neutral-grip DB floor press','Neutral-grip dumbbell floor press.',ARRAY['Floor caps the range so the shoulder cannot over-extend at the bottom.','Neutral grip, elbows about 45 degrees, controlled.','Ideal while the shoulder is irritable.'],'sets_weight',true,2.5),
('Single-leg hip thrust','Single-leg hip thrust.',ARRAY['One foot down; ribs down; posterior tilt at the top — do not arch the low back.','Full lockout, slow lower.','Much lighter than the bilateral version.'],'sets_weight',true,2.5),
('Trap-bar RDL (high handles)','Trap-bar Romanian deadlift using the high handles.',ARRAY['High handles shorten the range — hinge, push the hips back, soft knees.','Heaviest hinge of the week.','~2 reps in reserve; controlled.'],'sets_weight',true,5),
('Half-kneeling single-arm cable row','Half-kneeling single-arm cable row.',ARRAY['Half-kneeling kills the body english so the back does the work.','Elbow down-and-back; ribs down; no twist.','Right side independent.'],'sets_weight',true,5),
('Neutral-grip push-up (controlled range)','Neutral-grip push-up through a controlled range.',ARRAY['Hands neutral on handles or dumbbells; elbows tracking back, not flared.','Stop short of the deep bottom; spread the shoulder blades at the top.','Progress reps, not load.'],'sets_weight',false,null),
('Slider leg curl','Slider / valslide hamstring curl.',ARRAY['Heels on sliders, hips up in a bridge; slide the feet out and curl back under control.','Keep the hips from sagging.','The eccentric is the point — go slow.'],'done_check',false,null);

-- 2) Block 2 day-templates (copy Block 1 names/order)
insert into public.workout_templates (name, sort_order, mesocycle_id)
select wt.name, wt.sort_order, (select id from public.mesocycles where name='Block 2 — Variation')
from public.workout_templates wt
where wt.mesocycle_id = (select id from public.mesocycles where name='Block 1 — Foundation');

-- 3) Block 2 blocks (map Block 1 -> Block 2 template by name)
insert into public.template_blocks (template_id, type, label, sort_order)
select t2.id, tb.type, tb.label, tb.sort_order
from public.template_blocks tb
join public.workout_templates t1 on t1.id = tb.template_id
 and t1.mesocycle_id = (select id from public.mesocycles where name='Block 1 — Foundation')
join public.workout_templates t2 on t2.mesocycle_id = (select id from public.mesocycles where name='Block 2 — Variation')
 and t2.name = t1.name;

-- 4) Block 2 template_exercises (copy Block 1, swap compound lifts)
with swap(old_name, new_name, new_seed, new_per_side) as (values
  ('Trap-bar deadlift','Barbell RDL',155::numeric,null::boolean),
  ('Landmine press','Half-kneeling landmine press',40,null),
  ('Batwing row','Chest-supported incline DB row',45,null),
  ('B-stance single-leg RDL','Single-leg RDL',40,null),
  ('Rear-foot-elevated split squat','Reverse lunge',30,null),
  ('Neutral-grip pull-up','Neutral-grip lat pulldown',90,null),
  ('Neutral-grip DB bench / low incline','Neutral-grip DB floor press',50,null),
  ('Barbell / B-stance hip thrust','Single-leg hip thrust',25,true),
  ('B-stance / single-leg RDL (heavier)','Trap-bar RDL (high handles)',165,false),
  ('Single-arm DB row','Half-kneeling single-arm cable row',50,null),
  ('Incline DB press','Neutral-grip push-up (controlled range)',null,null),
  ('Nordic hamstring curl (band-assisted)','Slider leg curl',null,null)
)
insert into public.template_exercises
 (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order)
select
  b2.id,
  coalesce(ne.id, te.exercise_id),
  te.pair_label, te.target_sets, te.target_reps_low, te.target_reps_high,
  coalesce(s.new_per_side, te.per_side),
  case when s.old_name is not null then s.new_seed else te.seed_weight end,
  case when s.old_name is not null then (s.new_seed is not null) else te.seed_is_estimate end,
  te.sort_order
from public.template_exercises te
join public.template_blocks b1 on b1.id = te.block_id
join public.workout_templates t1 on t1.id = b1.template_id
 and t1.mesocycle_id = (select id from public.mesocycles where name='Block 1 — Foundation')
join public.workout_templates t2 on t2.mesocycle_id = (select id from public.mesocycles where name='Block 2 — Variation')
 and t2.name = t1.name
join public.template_blocks b2 on b2.template_id = t2.id and b2.label = b1.label
join public.exercises oe on oe.id = te.exercise_id
left join swap s on s.old_name = oe.name
left join public.exercises ne on ne.name = s.new_name;
