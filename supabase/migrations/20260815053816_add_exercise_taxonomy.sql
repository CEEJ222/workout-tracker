-- Exercise taxonomy: enables volume-by-muscle and movement-pattern balance
-- analysis (hamstring vs quad dominance, push/pull ratio, vertical vs horizontal
-- pull, glute max vs glute med).
--
-- primary_muscle is the SINGLE muscle a set is credited to. Compound lifts
-- credit their prime mover only; secondary contribution is deliberately not
-- modeled, because fractional crediting needs a set-level weighting table and
-- this schema has no place for it yet.
--
-- Warm-up work is excluded from analytics via template_blocks.type = 'circuit',
-- not via these columns — the same exercise can be a warm-up in one day and a
-- working exercise in another.

create type public.muscle_group as enum (
  'glute_max','glute_med','quads','hamstrings','calves','adductors',
  'chest','lats','upper_back','rear_delt','side_delt','front_delt',
  'biceps','triceps','core','erectors','rotator_cuff'
);

create type public.movement_pattern as enum (
  'hinge','squat','lunge','horizontal_push','vertical_push',
  'horizontal_pull','vertical_pull','hip_abduction','isolation',
  'carry','core','mobility'
);

alter table public.exercises
  add column primary_muscle public.muscle_group null,
  add column movement_pattern public.movement_pattern null,
  add column is_unilateral boolean not null default false;

comment on column public.exercises.primary_muscle is
  'Single prime mover this exercise credits volume to. Null = warm-up/mobility '
  'work not counted in volume analysis.';
comment on column public.exercises.movement_pattern is
  'Movement pattern for balance analysis (push/pull ratio, hinge vs squat, '
  'vertical vs horizontal pull).';
comment on column public.exercises.is_unilateral is
  'True if performed one limb at a time. Distinct from template_exercises.per_side, '
  'which governs rep counting for a specific prescription.';

update public.exercises set primary_muscle = v.pm::public.muscle_group,
                            movement_pattern = v.mp::public.movement_pattern,
                            is_unilateral = v.uni
from (values
  -- hip dominant / glute max
  ('009f5351-9d4d-43b7-b65e-f4d1231e3122','glute_max','hinge',false),        -- 45-Degree Back Extension
  ('b001d7b2-03d8-4bac-a710-17a8ef9f78b7','glute_max','hinge',false),        -- Barbell / B-stance hip thrust
  ('8c810452-ea9a-4654-9acf-3a5edfabfd88','glute_max','hinge',false),        -- Barbell Hip Thrust
  ('5f8cfd9e-6b2b-4a5a-9206-82919b27843b','glute_max','hinge',false),        -- Machine Hip Thrust
  ('bbfef5ef-12c8-4e32-83e3-434ca3e98517','glute_max','hinge',true),         -- Single-leg hip thrust
  ('271e539e-7b7d-4571-bbc0-1bd33b6f3c25','glute_max','squat',false),        -- Leg Press (glute bias)
  -- hamstrings
  ('a97f31c5-cfb4-4a4b-aca9-aff7087456de','hamstrings','hinge',false),       -- Barbell RDL
  ('88513369-c1a3-4565-9ebe-b7dd3a5a2a4d','hamstrings','hinge',false),       -- Dumbbell Romanian Deadlift
  ('4f187d24-b0fa-4fe6-b58c-12f41bee80f2','hamstrings','hinge',false),       -- Trap-bar RDL (high handles)
  ('6e3220e1-92da-4688-9486-532951eb7dbd','hamstrings','hinge',true),        -- B-stance / single-leg RDL (heavier)
  ('1063ef1c-7ce1-40b4-851d-386087d818b9','hamstrings','hinge',true),        -- B-stance single-leg RDL
  ('3a022b2d-4d2e-4658-aa9d-73441152fde9','hamstrings','hinge',true),        -- Single-leg RDL
  ('095dd98d-0f5d-407d-bf91-8d14a684760d','hamstrings','hinge',true),        -- Single-Leg RDL (DB)
  ('06ab6cee-2a51-4bd4-9fde-d20d8b600b2b','hamstrings','isolation',false),   -- Seated Leg Curl
  ('10d5237a-7fc9-4cff-a71c-9a95729ffff9','hamstrings','isolation',false),   -- Nordic hamstring curl
  ('90a22782-8b35-4bf1-9388-c6322b89cdaf','hamstrings','isolation',false),   -- Slider leg curl
  -- quads
  ('8f354967-8152-49ef-96a8-d52cec2027bf','quads','squat',false),            -- Hack Squat
  ('f6e838ec-fcd5-4a68-8bf0-99dce91e4aba','quads','squat',false),            -- Leg Press (quad bias)
  ('082dccbe-c9a0-4ad8-8bd4-6cb869387a32','quads','squat',false),            -- Heel-Elevated Goblet Squat
  ('66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c','quads','lunge',true),             -- DB Bulgarian Split Squat
  ('ee7c493e-c03a-418b-b2c1-edbb8f82f80a','quads','lunge',true),             -- Rear-foot-elevated split squat
  ('5fd79726-53a3-47d4-b074-5a6d57948b98','quads','lunge',true),             -- Dumbbell Reverse Lunge
  ('03e946ae-d6dc-480d-b857-af955939161a','quads','lunge',true),             -- Reverse lunge
  -- posterior chain bilateral
  ('862af51d-64d7-4616-9e76-7186a110c7c1','erectors','hinge',false),         -- Trap-bar deadlift
  -- glute med / abduction
  ('1799f56d-42eb-4fae-9e92-219a982c33dd','glute_med','hip_abduction',false),-- Seated Hip Abduction Machine
  ('27029387-e3d2-4687-a940-256c9b728fdf','glute_med','hip_abduction',false),-- Seated Hip Abduction (leaned)
  ('6467a792-434b-497f-a17d-b66e74529615','glute_med','hip_abduction',true), -- Standing Cable Hip Abduction
  -- adductors / calves
  ('534bea7d-cd9e-46ff-bda8-81aac097476d','adductors','lunge',true),         -- Cossack squat
  ('ffc43453-364e-485f-b7de-247d14673308','calves','isolation',false),       -- Standing Calf Raise
  -- chest / push
  ('51af94be-8f64-4964-bbbb-70f91f2a0e60','chest','isolation',false),        -- Cable Chest Fly
  ('cfb27746-56c3-4197-a488-ebf92fe42c69','chest','horizontal_push',false),  -- Incline DB press
  ('23854acb-b1dd-4e44-8565-2bbf41210f46','chest','horizontal_push',false),  -- Neutral-grip DB bench
  ('3d164e4f-eef3-4e3d-95bb-e194a2b6f1f6','chest','horizontal_push',false),  -- Neutral-grip DB floor press
  ('b58864f0-f8e5-4a31-989d-234c2a17ee43','chest','horizontal_push',false),  -- Neutral-grip push-up
  -- vertical push
  ('4ca03254-32d4-472f-9d68-ca19140ae41b','front_delt','vertical_push',false),-- DB Shoulder Press
  ('4c3af91b-50fa-4c73-9702-74a5ad8f4cc3','front_delt','vertical_push',false),-- Machine Shoulder Press
  ('2f31e275-037e-488f-9bda-c1c8230a0174','front_delt','vertical_push',true), -- Landmine press
  ('21982966-89f0-4d85-a102-989b59283aca','front_delt','vertical_push',true), -- Half-kneeling landmine press
  -- vertical pull -> lats
  ('c05d28f5-4832-4933-a650-da951018754a','lats','vertical_pull',false),     -- Lat Pulldown
  ('1d0fa119-5970-46b9-aae7-8a74843a1c22','lats','vertical_pull',false),     -- Neutral-grip lat pulldown
  ('70172133-ebe0-46bd-86fe-0366b8cb9968','lats','vertical_pull',false),     -- Neutral-grip pull-up
  ('79ccd8c6-8bcb-42f4-b422-7b40bd568e1e','lats','vertical_pull',false),     -- Assisted Pull-Up / Pulldown
  ('b1c1fafe-b2d1-4361-b512-ef866997d176','lats','vertical_pull',true),      -- Half-Kneeling SA Lat Pulldown
  -- horizontal pull -> upper_back
  ('14ad2960-dab1-4617-a0de-ae3f255f4d1a','upper_back','horizontal_pull',true),  -- Batwing row (one-handed)
  ('3c9392f7-2920-43a7-abdc-5c00eb49769e','upper_back','horizontal_pull',false), -- Chest-Supported DB Row
  ('a06a62a7-a56e-4483-b9ed-886b05da6bd9','upper_back','horizontal_pull',false), -- Chest-supported incline DB row
  ('9d548fdb-2f31-4542-a9cf-a79498ee7111','upper_back','horizontal_pull',false), -- Chest-Supported T-Bar/Machine Row
  ('6f9de57d-138f-4bab-afc0-b3a70c0979dd','upper_back','horizontal_pull',false), -- Seated Cable Row
  ('9f96a86d-6a99-428e-9be4-a5c8218519b8','upper_back','horizontal_pull',false), -- Wide-Grip Seated Row
  ('6753098f-43d0-40fc-9c96-278458ae02db','upper_back','horizontal_pull',true),  -- Single-arm DB row
  ('c41ab282-0e2e-4afe-9a1e-8b14c7d8f404','upper_back','horizontal_pull',true),  -- Single-Arm Dumbbell Row
  ('440db5a9-f0de-4651-8b08-e88bfcf2a73f','upper_back','horizontal_pull',true),  -- Half-kneeling SA cable row
  -- rear delt / cuff / side delt
  ('45fad97f-856d-4946-809b-39d6e389b2bc','rear_delt','isolation',false),    -- Reverse Pec Deck
  ('ba854cbe-e91b-46cf-b8e5-7e52657676b9','rear_delt','isolation',false),    -- Cable Face Pull
  ('03f9d2cd-c273-4783-8c6b-782363831c42','rear_delt','isolation',false),    -- Band/Cable Pull-Apart
  ('acdee471-650e-472f-83e7-5268c6a90751','rear_delt','isolation',false),    -- Prone Bench Y-T-W Raises
  ('7f5ea840-a4e2-4d5a-95e7-9d4b48d8fba8','side_delt','isolation',false),    -- Scaption (full-can)
  ('43b8499b-c425-4a5c-8ecb-ca105853f3e6','rotator_cuff','isolation',true),  -- Cable external rotation
  -- arms
  ('5a181655-f558-470f-b02c-39bda5d293b3','biceps','isolation',false),       -- Cable Curl
  ('8f1b4ded-99b3-47bb-9181-7ca1a506301d','biceps','isolation',false),       -- Incline Dumbbell Curl
  ('c110f243-e843-4bf5-8c47-9883ef213993','triceps','isolation',false),      -- Cable Triceps Pushdown
  ('004564f6-7f5f-4ca6-a7e0-bf2e88718920','triceps','isolation',false),      -- Overhead Cable Triceps Ext
  -- core
  ('16f385c1-297e-479c-a6d6-3a257cdd8f2e','core','core',false),             -- Pallof press
  ('308bebaf-967b-403a-8507-98c5e0d7284f','core','core',true),              -- Half-Kneeling Pallof Press
  ('b6f6afac-1bdb-4d75-9061-b0b0d954592c','core','core',true),              -- Cable Anti-Rotation Chop
  ('ffe777a2-e46a-4876-9239-dee4ba10f656','core','core',false),             -- Forearm Plank
  ('e3905dc1-4d73-496d-816b-9c27909c45c8','core','core',false),             -- Ab Wheel / Cable Fallout
  ('af01b27a-eef0-46a4-99e5-07cc5822fffb','core','core',false),             -- Hollow-body hold
  ('50c94fbb-2874-45a9-935b-80a346588c71','core','core',true),              -- Side plank
  ('c2b344f3-d1e5-42f3-aba4-639243672ffd','core','core',false),             -- Dead bug (CJ)
  ('60c659a1-c283-4242-ae22-ed5c2f18f779','core','core',false),             -- Dead Bug (Betsy)
  ('f88b0112-f858-4277-8e4d-81e7a4632d81','core','core',true),              -- Bird Dog
  ('e29b3187-9e9c-4908-91d6-2f03a08264b4','core','carry',true)              -- Suitcase carry
) as v(id, pm, mp, uni)
where public.exercises.id = v.id::uuid;

-- Warm-up / mobility work: movement_pattern only, primary_muscle stays null so
-- it never counts toward volume even if it appears outside a circuit block.
update public.exercises set movement_pattern = 'mobility'
where id in (
  '3fa2e1a3-59bb-472f-afee-115c83118bf9', -- Easy cardio raise
  '26f48a01-88ef-4ee9-ab48-2f54184af0ae', -- Dynamic leg swings
  'cc50b745-063c-4290-bed1-dc7373ad05f6', -- Banded X-Walks
  'f4c134c9-54a1-49a4-86f1-e00e03c045a4', -- Wall slide (protract)
  '8fa9f5c8-f4a0-4d70-95f8-f97f7a264574', -- Thoracic ext + open-book
  'e6a2a385-121b-43c6-98e5-1f4939a96555', -- Prone Y raise
  'bd538aa3-471d-4816-9239-229b2dae326c', -- Scap pull-up / band lat primer
  '9d08d992-c380-42bb-a000-e41b68bbf4c4', -- Deep squat + ankle rock
  '7bb0b7af-0fcd-4b38-aec3-864b9aa0e24f'  -- Hip airplane
);
