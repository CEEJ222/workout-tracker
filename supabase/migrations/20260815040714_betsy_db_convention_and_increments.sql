-- Betsy: restate DB progress rows in "total weight moved" and fix two increments
-- that fall at/below the 40 lb two-DB threshold (15s and 20s per hand).

update exercises set increment_lb = 5 where id in (
  '66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c', -- DB Bulgarian Split Squat (30 total = 15s)
  '5fd79726-53a3-47d4-b074-5a6d57948b98'  -- DB Reverse Lunge (40 total = 20s)
);

update user_exercise_progress set current_weight = 70, is_estimate = false
 where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
   and exercise_id = '88513369-c1a3-4565-9ebe-b7dd3a5a2a4d'; -- DB Romanian Deadlift 95 -> 70

update user_exercise_progress set current_weight = 40, is_estimate = false
 where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
   and exercise_id = '4ca03254-32d4-472f-9d68-ca19140ae41b'; -- DB Shoulder Press 30 -> 40

update user_exercise_progress set current_weight = 30, is_estimate = false
 where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
   and exercise_id = '66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c'; -- DB Bulgarian Split Squat 25 -> 30

update user_exercise_progress set current_weight = 30, is_estimate = false
 where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
   and exercise_id = 'c41ab282-0e2e-4afe-9a1e-8b14c7d8f404'; -- Single-Arm DB Row 35 -> 30
