-- 1) New warm-up exercises (only the two that don't exist; band/wall moves are reused)
insert into public.exercises (name, description, cues, log_type, auto_load, increment_lb, rest_seconds) values
('Easy cardio raise','2-3 min of light bike, row, or incline walk to raise core temperature before lifting.',ARRAY['Easy conversational pace','Build gradually','Just get warm, not tired'],'done_check',false,null,null),
('Dynamic leg swings','Front-to-back and lateral leg swings to open the hips through range before lower-body work.',ARRAY['Hold support','Controlled arc, no forcing','Hips square'],'done_check',false,null,null);

-- 2) Bump Betsy's existing working blocks from sort_order 0 -> 1 (scoped to her only)
update public.template_blocks tb
set sort_order = 1
from public.workout_templates wt
join public.mesocycles m on m.id = wt.mesocycle_id
where tb.template_id = wt.id
  and m.user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
  and tb.sort_order = 0;

-- 3) Insert a warm-up circuit block at sort_order 0 for each of her 6 days
insert into public.template_blocks (template_id, type, label, sort_order)
select wt.id, 'circuit', 'Warm-up · circuit', 0
from public.workout_templates wt
join public.mesocycles m on m.id = wt.mesocycle_id
where m.user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284';

-- 4) Warm-up exercises: lower days get cardio/leg swings/band walk; upper days get cardio/pull-apart/wall slide
with wu(day_kind, ex_name, sets, rl, rh, per_side, ord) as (values
  ('lower','Easy cardio raise',1,1,1,false,0),
  ('lower','Dynamic leg swings',1,10,10,true,1),
  ('lower','Lateral band walk',2,12,15,true,2),
  ('upper','Easy cardio raise',1,1,1,false,0),
  ('upper','Band pull-apart',2,15,20,false,1),
  ('upper','Wall slide (protract)',2,10,10,false,2)
)
insert into public.template_exercises
 (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order)
select tb.id, ex.id, null, wu.sets, wu.rl, wu.rh, wu.per_side, null, false, wu.ord
from wu
join public.exercises ex on ex.name = case wu.ex_name
   when 'Lateral band walk' then 'Banded X-Walks / Lateral Band Walks'
   when 'Band pull-apart' then 'Band/Cable Pull-Apart'
   else wu.ex_name end
join public.workout_templates wt
  on wt.mesocycle_id in (select id from public.mesocycles where user_id='062fd8bd-96e5-40b0-812c-2886c06fd284')
join public.template_blocks tb
  on tb.template_id = wt.id and tb.type = 'circuit' and tb.sort_order = 0 and tb.label = 'Warm-up · circuit'
where (wu.day_kind = 'lower' and (wt.name like 'Day 1%' or wt.name like 'Day 3%'))
   or (wu.day_kind = 'upper' and wt.name like 'Day 2%');
