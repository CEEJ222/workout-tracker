-- Fill the rest_seconds gap in Betsy's Block C. 16 of 23 working slots resolved
-- to null, including every day's primary lift.
--
-- Rule, extending the one applied in the rest_seconds migration. Betsy's block
-- has one flat `single` block per day with no role labels, so slots are
-- classified by position and RIR target:
--   slot 0 heavy compound (hip thrust, hack squat, leg press)  -> 150s
--   secondary compound / working lift (target_rir_low = 1)     -> 90s
--   isolation & pump work (target_rir_low = 0)                 ->  45s
--   unloaded core (no RIR target)                              ->  45s
--
-- 90s rather than CJ's 75s for secondary compounds: his 75s slots are superset
-- members where the alternating partner supplies extra recovery. Betsy's block
-- has no supersets, so each set rests on its own.

update public.template_exercises set rest_seconds = v.secs
from (values
  -- Day 1 · Lower — hip dominant
  ('75dd8cc5-b5f1-4dfc-8222-0c5eb9ccaa51', 150), -- Machine Hip Thrust (primary)
  ('107b80db-a6b5-4c34-a0de-0338c99874a4',  90), -- Dumbbell Romanian Deadlift
  ('9826b611-fc4a-4625-b6ea-bb434d87f4cb',  45), -- Standing Cable Hip Abduction
  ('273537b8-4345-4138-9e20-b693957d7f59',  45), -- Dead Bug
  -- Day 2 · Upper — pull / posture
  ('1cf619a5-5d84-4a48-8e87-2ce4360b7ad7',  90), -- Lat Pulldown
  ('f14b171a-4484-459d-a12e-81bf96b1b3ee',  90), -- Seated Cable Row
  ('ed72de55-e7a7-4685-b027-7f015190b127',  90), -- Dumbbell Shoulder Press
  ('45a511f1-1f26-4667-a102-9c49eda42280',  45), -- Incline Dumbbell Curl
  ('a8589015-176b-412e-8960-3acda5c60dea',  45), -- Half-Kneeling Pallof Press
  -- Day 3 · Lower — knee dominant
  ('62bf7d14-9cb0-43bf-8b37-be6ce0bdf5eb', 150), -- Hack Squat (primary)
  ('31e15c64-a205-4d3e-9c58-c9c651bb94d6',  90), -- DB Bulgarian Split Squat
  ('03cd01d6-4115-4f20-a408-415804fe537c',  90), -- Single-Arm Dumbbell Row
  ('f24a7613-a3f9-45fe-b12e-68e7c91d1021',  45), -- Forearm Plank
  -- Day 4 · Glute emphasis + upper
  ('1e0971c7-9afa-4f60-8c98-8642b1ee9bd5', 150), -- Leg Press glute bias (primary)
  ('307b81ab-4028-4e66-ad7a-cd8216cc2a32',  90), -- Dumbbell Reverse Lunge
  ('91d0904a-3a2e-43ec-a9fa-780d92cb286d',  45), -- Seated Hip Abduction Machine
  ('3ac64c69-7917-429d-9ffe-b0efb54720a1',  45)  -- Cable Face Pull
) as v(id, secs)
where public.template_exercises.id = v.id::uuid;
