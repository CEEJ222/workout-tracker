-- Betsy Block C: 4-day glute & posture block, single block replacing Blocks A/B.
do $$
declare
  v_user uuid := '062fd8bd-96e5-40b0-812c-2886c06fd284';
  v_meso uuid; t1 uuid; t2 uuid; t3 uuid; t4 uuid;
  w1 uuid; w2 uuid; w3 uuid; w4 uuid;
  m1 uuid; m2 uuid; m3 uuid; m4 uuid;
  -- exercise ids
  ex_cardio   uuid := '3fa2e1a3-59bb-472f-afee-115c83118bf9'; -- Easy cardio raise
  ex_swings   uuid := '26f48a01-88ef-4ee9-ab48-2f54184af0ae'; -- Dynamic leg swings
  ex_xwalk    uuid := 'cc50b745-063c-4290-bed1-dc7373ad05f6'; -- Banded X-Walks
  ex_pullapart uuid := '03f9d2cd-c273-4783-8c6b-782363831c42'; -- Band/Cable Pull-Apart
  ex_wallslide uuid := 'f4c134c9-54a1-49a4-86f1-e00e03c045a4'; -- Wall slide (protract)
  ex_ytw      uuid := 'acdee471-650e-472f-83e7-5268c6a90751'; -- Prone Bench Y-T-W Raises
  ex_hipthrust uuid := '5f8cfd9e-6b2b-4a5a-9206-82919b27843b'; -- Machine Hip Thrust
  ex_rdl      uuid := '88513369-c1a3-4565-9ebe-b7dd3a5a2a4d'; -- DB Romanian Deadlift
  ex_cableabd uuid := '6467a792-434b-497f-a17d-b66e74529615'; -- Standing Cable Hip Abduction
  ex_backext  uuid := '009f5351-9d4d-43b7-b65e-f4d1231e3122'; -- 45-Degree Back Extension
  ex_deadbug  uuid := '60c659a1-c283-4242-ae22-ed5c2f18f779'; -- Dead Bug
  ex_pulldown uuid := 'c05d28f5-4832-4933-a650-da951018754a'; -- Lat Pulldown
  ex_cablerow uuid := '6f9de57d-138f-4bab-afc0-b3a70c0979dd'; -- Seated Cable Row
  ex_ohp      uuid := '4ca03254-32d4-472f-9d68-ca19140ae41b'; -- DB Shoulder Press
  ex_revpec   uuid := '45fad97f-856d-4946-809b-39d6e389b2bc'; -- Reverse Pec Deck
  ex_curl     uuid := '8f1b4ded-99b3-47bb-9181-7ca1a506301d'; -- Incline Dumbbell Curl
  ex_pushdown uuid := 'c110f243-e843-4bf5-8c47-9883ef213993'; -- Cable Triceps Pushdown
  ex_pallof   uuid := '308bebaf-967b-403a-8507-98c5e0d7284f'; -- Half-Kneeling Pallof Press
  ex_hack     uuid;
  ex_bss      uuid := '66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c'; -- DB Bulgarian Split Squat
  ex_legcurl  uuid := '06ab6cee-2a51-4bd4-9fde-d20d8b600b2b'; -- Seated Leg Curl
  ex_sarow    uuid := 'c41ab282-0e2e-4afe-9a1e-8b14c7d8f404'; -- Single-Arm Dumbbell Row
  ex_plank    uuid := 'ffe777a2-e46a-4876-9239-dee4ba10f656'; -- Forearm Plank
  ex_legpress uuid := '271e539e-7b7d-4571-bbc0-1bd33b6f3c25'; -- Leg Press (glute bias)
  ex_lunge    uuid := '5fd79726-53a3-47d4-b074-5a6d57948b98'; -- DB Reverse Lunge
  ex_seatabd  uuid := '1799f56d-42eb-4fae-9e92-219a982c33dd'; -- Seated Hip Abduction Machine
  ex_facepull uuid := 'ba854cbe-e91b-46cf-b8e5-7e52657676b9'; -- Cable Face Pull
  ex_calf     uuid := 'ffc43453-364e-485f-b7de-247d14673308'; -- Standing Calf Raise
begin
  select id into ex_hack from exercises where name = 'Hack Squat';

  insert into mesocycles (id, name, sort_order, user_id)
  values (gen_random_uuid(), 'Block C — Glute & Posture', 3, v_user)
  returning id into v_meso;

  insert into workout_templates (id, name, sort_order, mesocycle_id)
  values (gen_random_uuid(), 'Day 1 · Lower — hip dominant', 0, v_meso) returning id into t1;
  insert into workout_templates (id, name, sort_order, mesocycle_id)
  values (gen_random_uuid(), 'Day 2 · Upper — pull / posture', 1, v_meso) returning id into t2;
  insert into workout_templates (id, name, sort_order, mesocycle_id)
  values (gen_random_uuid(), 'Day 3 · Lower — knee dominant', 2, v_meso) returning id into t3;
  insert into workout_templates (id, name, sort_order, mesocycle_id)
  values (gen_random_uuid(), 'Day 4 · Glute emphasis + upper', 3, v_meso) returning id into t4;

  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t1, 'circuit', 'Warm-up · circuit', 0) returning id into w1;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t1, 'single', 'Lower — hip dominant', 1) returning id into m1;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t2, 'circuit', 'Warm-up · circuit', 0) returning id into w2;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t2, 'single', 'Upper — pull / posture', 1) returning id into m2;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t3, 'circuit', 'Warm-up · circuit', 0) returning id into w3;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t3, 'single', 'Lower — knee dominant', 1) returning id into m3;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t4, 'circuit', 'Warm-up · circuit', 0) returning id into w4;
  insert into template_blocks (id, template_id, type, label, sort_order)
  values (gen_random_uuid(), t4, 'single', 'Glute emphasis + upper', 1) returning id into m4;

  insert into template_exercises
    (id, block_id, exercise_id, target_sets, target_reps_low, target_reps_high,
     target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate, sort_order)
  values
  -- Day 1 warm-up
  (gen_random_uuid(), w1, ex_cardio, 1, 1, 1, null, null, false, null, false, 0),
  (gen_random_uuid(), w1, ex_swings, 1, 10, 10, null, null, true, null, false, 1),
  (gen_random_uuid(), w1, ex_xwalk, 2, 12, 15, null, null, true, null, false, 2),
  -- Day 1 main
  (gen_random_uuid(), m1, ex_hipthrust, 4, 6, 10, 1, 2, false, 225, false, 0),
  (gen_random_uuid(), m1, ex_rdl, 3, 8, 12, 1, 2, false, 70, false, 1),
  (gen_random_uuid(), m1, ex_cableabd, 3, 12, 20, 0, 1, true, 15, false, 2),
  (gen_random_uuid(), m1, ex_backext, 3, 10, 15, 1, 2, false, 25, false, 3),
  (gen_random_uuid(), m1, ex_deadbug, 3, 8, 10, null, null, true, null, false, 4),
  -- Day 2 warm-up
  (gen_random_uuid(), w2, ex_cardio, 1, 1, 1, null, null, false, null, false, 0),
  (gen_random_uuid(), w2, ex_pullapart, 2, 15, 20, null, null, false, null, false, 1),
  (gen_random_uuid(), w2, ex_wallslide, 2, 10, 10, null, null, false, null, false, 2),
  (gen_random_uuid(), w2, ex_ytw, 2, 10, 12, null, null, false, null, false, 3),
  -- Day 2 main
  (gen_random_uuid(), m2, ex_pulldown, 3, 8, 12, 1, 2, false, 70, false, 0),
  (gen_random_uuid(), m2, ex_cablerow, 3, 8, 12, 1, 2, false, 85, false, 1),
  (gen_random_uuid(), m2, ex_ohp, 3, 8, 12, 1, 2, false, 40, false, 2),
  (gen_random_uuid(), m2, ex_revpec, 3, 12, 20, 0, 1, false, 30, false, 3),
  (gen_random_uuid(), m2, ex_curl, 2, 8, 12, 0, 1, false, 30, false, 4),
  (gen_random_uuid(), m2, ex_pushdown, 2, 10, 15, 0, 1, false, 25, false, 5),
  (gen_random_uuid(), m2, ex_pallof, 3, 10, 12, null, null, true, 15, false, 6),
  -- Day 3 warm-up
  (gen_random_uuid(), w3, ex_cardio, 1, 1, 1, null, null, false, null, false, 0),
  (gen_random_uuid(), w3, ex_swings, 1, 10, 10, null, null, true, null, false, 1),
  (gen_random_uuid(), w3, ex_xwalk, 2, 12, 15, null, null, true, null, false, 2),
  -- Day 3 main
  (gen_random_uuid(), m3, ex_hack, 4, 8, 12, 1, 2, false, 140, false, 0),
  (gen_random_uuid(), m3, ex_bss, 3, 8, 12, 1, 2, true, 30, false, 1),
  (gen_random_uuid(), m3, ex_legcurl, 3, 8, 12, 1, 2, false, 50, true, 2),
  (gen_random_uuid(), m3, ex_sarow, 3, 8, 12, 1, 2, true, 30, false, 3),
  (gen_random_uuid(), m3, ex_plank, 3, 30, 45, null, null, false, null, false, 4),
  -- Day 4 warm-up
  (gen_random_uuid(), w4, ex_cardio, 1, 1, 1, null, null, false, null, false, 0),
  (gen_random_uuid(), w4, ex_swings, 1, 10, 10, null, null, true, null, false, 1),
  (gen_random_uuid(), w4, ex_xwalk, 2, 12, 15, null, null, true, null, false, 2),
  (gen_random_uuid(), w4, ex_pullapart, 2, 15, 20, null, null, false, null, false, 3),
  -- Day 4 main
  (gen_random_uuid(), m4, ex_legpress, 3, 10, 15, 1, 2, false, 180, true, 0),
  (gen_random_uuid(), m4, ex_lunge, 3, 8, 12, 1, 2, true, 40, false, 1),
  (gen_random_uuid(), m4, ex_seatabd, 3, 15, 20, 0, 1, false, 230, false, 2),
  (gen_random_uuid(), m4, ex_backext, 3, 10, 15, 1, 2, false, 25, false, 3),
  (gen_random_uuid(), m4, ex_facepull, 3, 15, 20, 1, 2, false, 25, false, 4),
  (gen_random_uuid(), m4, ex_calf, 3, 10, 15, 0, 1, false, 90, true, 5);

  update user_settings set active_mesocycle_id = v_meso where user_id = v_user;
end $$;
