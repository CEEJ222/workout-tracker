-- Record the "total weight moved" convention on every dumbbell-loaded exercise,
-- in both description and as the first cue so it surfaces in the log UI.
-- Also finish the increment_lb sweep: rack steps 2.5 per hand up to 20 lb, then 5.
--   two-DB above 40 lb total -> 10 ; two-DB at/below 40 -> 5 ; one-DB above 20 -> 5

-- ---------- TWO-DUMBBELL EXERCISES ----------
update exercises
set description = description || ' Log TOTAL weight moved: both dumbbells summed (two 25s = 50).',
    cues = array_prepend('Log TOTAL weight: both dumbbells summed (two 25s = 50).', cues)
where id in (
  '3c9392f7-2920-43a7-abdc-5c00eb49769e', -- Chest-Supported Dumbbell Row
  'a06a62a7-a56e-4483-b9ed-886b05da6bd9', -- Chest-supported incline DB row
  '66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c', -- Dumbbell Bulgarian Split Squat
  '5fd79726-53a3-47d4-b074-5a6d57948b98', -- Dumbbell Reverse Lunge
  '88513369-c1a3-4565-9ebe-b7dd3a5a2a4d', -- Dumbbell Romanian Deadlift
  '4ca03254-32d4-472f-9d68-ca19140ae41b', -- Dumbbell Shoulder Press (seated)
  'cfb27746-56c3-4197-a488-ebf92fe42c69', -- Incline DB press
  '8f1b4ded-99b3-47bb-9181-7ca1a506301d', -- Incline Dumbbell Curl
  '23854acb-b1dd-4e44-8565-2bbf41210f46', -- Neutral-grip DB bench / low incline
  '3d164e4f-eef3-4e3d-95bb-e194a2b6f1f6', -- Neutral-grip DB floor press
  '7f5ea840-a4e2-4d5a-95e7-9d4b48d8fba8', -- Scaption (full-can)
  '6e3220e1-92da-4688-9486-532951eb7dbd', -- B-stance / single-leg RDL (heavier)
  '1063ef1c-7ce1-40b4-851d-386087d818b9', -- B-stance single-leg RDL
  'ee7c493e-c03a-418b-b2c1-edbb8f82f80a', -- Rear-foot-elevated split squat
  '03e946ae-d6dc-480d-b857-af955939161a'  -- Reverse lunge
);

-- ---------- SINGLE-IMPLEMENT (one DB in hand) ----------
update exercises
set description = description || ' Log TOTAL weight moved: one dumbbell, so log what is in your hand (a 50 = 50).',
    cues = array_prepend('Log TOTAL weight: one dumbbell, log what is in your hand.', cues)
where id in (
  '14ad2960-dab1-4617-a0de-ae3f255f4d1a', -- Batwing row (one-handed)
  '6753098f-43d0-40fc-9c96-278458ae02db', -- Single-arm DB row
  'c41ab282-0e2e-4afe-9a1e-8b14c7d8f404', -- Single-Arm Dumbbell Row
  '095dd98d-0f5d-407d-bf91-8d14a684760d', -- Single-Leg Romanian Deadlift (DB)
  '3a022b2d-4d2e-4658-aa9d-73441152fde9', -- Single-leg RDL
  '082dccbe-c9a0-4ad8-8bd4-6cb869387a32', -- Heel-Elevated Goblet Squat
  'e29b3187-9e9c-4908-91d6-2f03a08264b4', -- Suitcase carry
  '534bea7d-cd9e-46ff-bda8-81aac097476d', -- Cossack squat
  'bbfef5ef-12c8-4e32-83e3-434ca3e98517', -- Single-leg hip thrust
  '009f5351-9d4d-43b7-b65e-f4d1231e3122'  -- 45-Degree Back Extension (held plate/DB)
);

-- ---------- MIXED IMPLEMENT: flag explicitly ----------
update exercises
set description = description || ' If loading with dumbbells, log TOTAL weight moved (both summed). Keep the implement consistent within a block.',
    cues = array_prepend('If using dumbbells, log TOTAL weight (both summed).', cues)
where id = 'ffc43453-364e-485f-b7de-247d14673308'; -- Standing Calf Raise

-- ---------- increment_lb: remaining DB exercises ----------
update exercises set increment_lb = 10 where id in (
  '3c9392f7-2920-43a7-abdc-5c00eb49769e', -- Chest-Supported DB Row
  '66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c', -- DB Bulgarian Split Squat (50 total)
  '5fd79726-53a3-47d4-b074-5a6d57948b98', -- DB Reverse Lunge (50 total)
  '88513369-c1a3-4565-9ebe-b7dd3a5a2a4d', -- DB Romanian Deadlift
  '03e946ae-d6dc-480d-b857-af955939161a'  -- Reverse lunge
);

-- two-DB currently at/below 40 lb total -> 5 (revisit if seeds land above 40)
update exercises set increment_lb = 5 where id in (
  '4ca03254-32d4-472f-9d68-ca19140ae41b', -- DB Shoulder Press (40 total)
  '8f1b4ded-99b3-47bb-9181-7ca1a506301d'  -- Incline Dumbbell Curl (30 total)
);

-- one-DB above 20 lb -> 5
update exercises set increment_lb = 5 where id in (
  'c41ab282-0e2e-4afe-9a1e-8b14c7d8f404', -- Single-Arm Dumbbell Row (30)
  '082dccbe-c9a0-4ad8-8bd4-6cb869387a32', -- Heel-Elevated Goblet Squat (53)
  '3a022b2d-4d2e-4658-aa9d-73441152fde9', -- Single-leg RDL
  'bbfef5ef-12c8-4e32-83e3-434ca3e98517'  -- Single-leg hip thrust
);
