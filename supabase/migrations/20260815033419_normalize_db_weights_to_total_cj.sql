-- Normalize CJ's dumbbell logging to the "total weight moved" convention.
-- Two exercises flipped from total -> per-dumbbell on 2026-07-10 (confirmed by
-- user notes "50 on each side" and "10 on each arm so 20 really").
-- Scope: CJ only (98251473-2fc9-4254-a4f9-6dc86135c1b2). Betsy's data untouched.

-- 1. Scaption: fix the 2026-07-24 data-entry typo (100 -> 10) BEFORE doubling.
update session_sets ss
set actual_weight = 10
from session_exercises se
join template_exercises te on te.id = se.template_exercise_id
join exercises e on e.id = te.exercise_id
join sessions s on s.id = se.session_id
where ss.session_exercise_id = se.id
  and e.name = 'Scaption (full-can)'
  and s.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and ss.actual_weight = 100;

-- 2. Double per-dumbbell entries from 2026-07-10 onward -> total.
update session_sets ss
set actual_weight = ss.actual_weight * 2
from session_exercises se
join template_exercises te on te.id = se.template_exercise_id
join exercises e on e.id = te.exercise_id
join sessions s on s.id = se.session_id
where ss.session_exercise_id = se.id
  and e.name in ('Incline DB press', 'Scaption (full-can)')
  and s.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and s.started_at >= '2026-07-10'
  and ss.actual_weight is not null;

-- 3. Correct progress rows to total, snapping to real dumbbell loads.
--    Two-DB total must be even multiples of 5 (5 lb rack steps per hand above 20 lb).
update user_exercise_progress set current_weight = 100
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = 'cfb27746-56c3-4197-a488-ebf92fe42c69'; -- Incline DB press

update user_exercise_progress set current_weight = 20
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = '7f5ea840-a4e2-4d5a-95e7-9d4b48d8fba8'; -- Scaption (full-can)

-- 4. Snap weights auto_load walked to loads that do not exist on a rack.
update user_exercise_progress set current_weight = 50
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = '6753098f-43d0-40fc-9c96-278458ae02db'; -- Single-arm DB row 52.5 -> 50

update user_exercise_progress set current_weight = 80
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = '6e3220e1-92da-4688-9486-532951eb7dbd'; -- B-stance/SL RDL (heavier) 82.5 -> 80

update user_exercise_progress set current_weight = 50
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = '1063ef1c-7ce1-40b4-851d-386087d818b9'; -- B-stance single-leg RDL 52.5 -> 50

update user_exercise_progress set current_weight = 80
 where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
   and exercise_id = 'ee7c493e-c03a-418b-b2c1-edbb8f82f80a'; -- RFE split squat 82.5 -> 80

-- 5. increment_lb: rack steps 2.5 up to 20 lb per hand, 5 lb above.
--    One-DB exercise above 20 lb  -> 5
--    Two-DB exercise above 40 lb total -> 10
--    Two-DB exercise at/below 40 lb total -> 5
update exercises set increment_lb = 10 where id in (
  'cfb27746-56c3-4197-a488-ebf92fe42c69', -- Incline DB press (100 total)
  '23854acb-b1dd-4e44-8565-2bbf41210f46', -- Neutral-grip DB bench / low incline (100)
  '6e3220e1-92da-4688-9486-532951eb7dbd', -- B-stance / single-leg RDL (heavier) (80)
  '1063ef1c-7ce1-40b4-851d-386087d818b9', -- B-stance single-leg RDL (50)
  'ee7c493e-c03a-418b-b2c1-edbb8f82f80a', -- Rear-foot-elevated split squat (80)
  'a06a62a7-a56e-4483-b9ed-886b05da6bd9', -- Chest-supported incline DB row (two-DB)
  '3d164e4f-eef3-4e3d-95bb-e194a2b6f1f6'  -- Neutral-grip DB floor press (two-DB)
);

update exercises set increment_lb = 5 where id in (
  '7f5ea840-a4e2-4d5a-95e7-9d4b48d8fba8', -- Scaption, two-DB, 20 total (<=40)
  '14ad2960-dab1-4617-a0de-ae3f255f4d1a', -- Batwing row, ONE-handed, 50
  '6753098f-43d0-40fc-9c96-278458ae02db', -- Single-arm DB row, one DB, 50
  '095dd98d-0f5d-407d-bf91-8d14a684760d'  -- Single-Leg Romanian Deadlift (DB), one DB
);
