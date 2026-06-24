-- ============================================================================
-- Workout Tracker — program seed (Phase 3)
--
-- Loads the read-only program: the shared warm-up circuit and Days A / B / C
-- from the build spec. Idempotent and atomic: it clears the four program
-- tables first (the RESTRICT foreign keys from user-data tables will block the
-- delete — and abort the whole block — if any sessions/progress reference the
-- program, so re-seeding can never silently nuke logged data), then reinserts.
--
-- Apply with the Supabase CLI (`supabase db reset` runs this automatically) or
-- by executing this file against the project. Re-running is safe on a fresh
-- program.
--
-- Notes on inference (the spec pins log_type only for the warm-up):
--   * log_type 'sets_weight'        → loaded exercises (per-set weight grid).
--   * log_type 'done_check'         → bodyweight / timed work (checkbox only).
--   * log_type 'done_check_weight'  → the one warm-up item that logs weight.
--   * target_sets stores the LOWER bound of a "3–4 sets" prescription.
--   * target_reps_low/high double as seconds (planks/holds) or metres (carries)
--     where the prescription is time/distance rather than reps.
--   * "B-stance single-leg RDL" (Day A) and "B-stance / single-leg RDL
--     (heavier)" (Day C) are intentionally SEPARATE exercises so their
--     auto-progression tracks independently at their different working loads.
-- ============================================================================

do $$
declare
  t_a uuid;  -- Day A template
  t_b uuid;  -- Day B template
  t_c uuid;  -- Day C template
  blk uuid;  -- current block being filled
begin
  -- ── Idempotency: clear program data (FK-safe order; RESTRICT protects user data)
  delete from template_exercises;
  delete from template_blocks;
  delete from workout_templates;
  delete from exercises;

  -- ════════════════════════════════════════════════════════════════════════
  -- EXERCISE LIBRARY
  -- ════════════════════════════════════════════════════════════════════════

  insert into exercises (name, description, cues, log_type, auto_load, increment_lb) values
  -- Warm-up circuit (shared, no progression)
  ('Thoracic ext + open-book',
   $t$Mobility for a stiff mid-back so the shoulder blade can actually move — the one area you want more range, not less.$t$,
   array[
     $t$Foam roller under the mid-back; support your head, extend gently over it a few segments.$t$,
     $t$Open-book: side-lying, open the top arm toward the floor, follow your hand with your eyes.$t$,
     $t$Slow, breathing out as you open — no forcing.$t$],
   'done_check', false, null),

  ('Wall slide (protract)',
   $t$Wakes up the serratus — teaches the shoulder blade to rotate up and wrap forward, the motion the right side skips.$t$,
   array[
     $t$Forearms on the wall; slide them up overhead.$t$,
     $t$At the top, push into the wall and reach — let the blades wrap forward.$t$,
     $t$Keep ribs down; don't shrug toward your ears.$t$],
   'done_check', false, null),

  ('Prone Y raise',
   $t$Lower-trap work — the other half of the force couple that rotates the blade upward.$t$,
   array[
     $t$Face-down on a low incline, arms in a Y, thumbs up.$t$,
     $t$Lift with the lower traps, not by shrugging.$t$,
     $t$Light; pause at the top of each rep.$t$],
   'done_check', false, null),

  ('Cable external rotation',
   $t$Cuff endurance for the external rotators — the limited tissue that struggled at 20 lb.$t$,
   array[
     $t$Elbow pinned to your side the whole set.$t$,
     $t$Rotate out slowly; the set ends the moment the elbow drifts.$t$,
     $t$Stay light and high-rep; note any pinch.$t$],
   'done_check_weight', false, null),

  -- Day A
  ('Trap-bar deadlift',
   $t$Your heavy bilateral hinge — the symmetric, progressable load your single-leg work can't give you.$t$,
   array[
     $t$Brace before each rep; push the floor away.$t$,
     $t$Hips and shoulders rise together.$t$,
     $t$Leave ~2 reps in reserve — load lags the muscles on purpose.$t$,
     $t$Controlled lower every rep; no bouncing off the floor.$t$],
   'sets_weight', true, 5),

  ('Landmine press',
   $t$Single-arm press on a forward-and-up arc — your stand-in for overhead pressing. Trains the blade to rotate up as you press.$t$,
   array[
     $t$Press up and slightly forward — not straight overhead.$t$,
     $t$Let the shoulder blade travel and wrap forward at the top.$t$,
     $t$3-second lower; don't slam into lockout.$t$,
     $t$Stop short of any pinch — range is earned, not forced.$t$],
   'sets_weight', true, 2.5),

  ('Batwing row',
   $t$Chest-supported row. The pad holds you steady so the cuff isn't fighting to centre a lax joint while it works.$t$,
   array[
     $t$Pause and own the top of every rep.$t$,
     $t$Drive the elbow down-and-back, not flared up high.$t$,
     $t$Keep ribs down — don't arch to cheat the weight.$t$,
     $t$Right side does its own work; don't let the left take over.$t$],
   'sets_weight', true, 2.5),

  ('B-stance single-leg RDL',
   $t$Single-leg-biased hinge — hamstring and posterior-chain strength with a balance demand the bilateral lifts can't provide.$t$,
   array[
     $t$Hinge from the hip with a soft knee.$t$,
     $t$Back foot lightly down for balance only.$t$,
     $t$Feel the hamstring lengthen; stay controlled.$t$],
   'sets_weight', true, 2.5),

  ('Hip airplane',
   $t$Single-leg balance with slow pelvic rotation — control work for the hip stabilizers.$t$,
   array[
     $t$Hinge on one leg; rotate the pelvis open and closed slowly.$t$,
     $t$Control over range — stop where you can stay stable.$t$],
   'done_check', false, null),

  ('Side plank',
   $t$Lateral-chain and oblique endurance; a place to give the weaker right side extra work.$t$,
   array[
     $t$Stack a clean line, hips up.$t$,
     $t$Give the weaker right side an extra set if needed.$t$,
     $t$Quality over duration.$t$],
   'done_check', false, null),

  ('Suitcase carry',
   $t$Loaded carry for grip, trunk anti-lateral-flexion, and a packed shoulder.$t$,
   array[
     $t$Walk tall — don't tip toward the weight.$t$,
     $t$Ribs down, shoulder packed.$t$],
   'sets_weight', false, null),

  -- Day B
  ('Rear-foot-elevated split squat',
   $t$Front-loaded single-leg strength with the rear foot elevated — your main knee-dominant driver.$t$,
   array[
     $t$Front shin roughly vertical; controlled descent.$t$,
     $t$Drive through the front heel.$t$,
     $t$Torso tall.$t$],
   'sets_weight', true, 2.5),

  ('Neutral-grip pull-up',
   $t$Vertical pull with a shoulder-friendly neutral grip; add load slowly as you get strong.$t$,
   array[
     $t$Neutral grip is the default.$t$,
     $t$Start each rep from a controlled hang — no kipping.$t$,
     $t$Add load slowly.$t$],
   'sets_weight', true, 2.5),

  ('Neutral-grip DB bench / low incline',
   $t$Horizontal press with a neutral grip and a deliberately shallow bottom to spare the shoulder.$t$,
   array[
     $t$Neutral grip, controlled range — no deep bottom; stop short of the exposed stretch.$t$,
     $t$3-second lower.$t$],
   'sets_weight', true, 2.5),

  ('Barbell / B-stance hip thrust',
   $t$Hip-extension power for the glutes with a posterior pelvic tilt at the top.$t$,
   array[
     $t$Ribs down; posterior tilt at the top — don't arch the low back.$t$,
     $t$Chin tucked.$t$,
     $t$Full lockout, controlled lower.$t$],
   'sets_weight', true, 5),

  ('Cossack squat',
   $t$Loaded lateral squat — frontal-plane hip and adductor mobility under control.$t$,
   array[
     $t$Sit into one hip; keep the other leg straight.$t$,
     $t$Controlled frontal-plane range; heel down.$t$],
   'sets_weight', false, null),

  ('Pallof press',
   $t$Anti-rotation core — resist the cable's twist rather than create movement.$t$,
   array[
     $t$Resist the twist — press straight out, don't let the cable rotate you.$t$,
     $t$Slow.$t$],
   'sets_weight', false, null),

  ('Dead bug',
   $t$Anti-extension core — move the limbs while the low back stays pinned flat.$t$,
   array[
     $t$Low back stays flat on the floor the whole time.$t$,
     $t$Slow opposite arm and leg; exhale as you extend.$t$],
   'done_check', false, null),

  -- Day C
  ('B-stance / single-leg RDL (heavier)',
   $t$Heavier single-leg-biased hinge than Day A — same pattern, lower reps, more load.$t$,
   array[
     $t$Heavier than Day A.$t$,
     $t$Hinge, soft knee, controlled.$t$,
     $t$Hips square.$t$],
   'sets_weight', true, 2.5),

  ('Single-arm DB row',
   $t$Unilateral horizontal pull; lets the right side do its own work without the left compensating.$t$,
   array[
     $t$Elbow tracks down-and-back, not flared.$t$,
     $t$Neutral grip.$t$,
     $t$Right side independent — don't let the left compensate.$t$],
   'sets_weight', true, 2.5),

  ('Incline DB press',
   $t$Upper-chest-biased press with a neutral grip and controlled, shallow range.$t$,
   array[
     $t$Neutral grip, upper-chest bias.$t$,
     $t$Controlled range, no deep bottom.$t$,
     $t$3-second lower.$t$],
   'sets_weight', true, 2.5),

  ('Nordic hamstring curl (band-assisted)',
   $t$Eccentric hamstring strength — lower as slowly as you can, using the band to regress.$t$,
   array[
     $t$Hips straight; lower as slowly as you can control.$t$,
     $t$Use the band to regress — these are brutal at first.$t$],
   'done_check', false, null),

  ('Scaption (full-can)',
   $t$Replaces lateral raises — a scapular-plane raise with thumbs up to load the shoulder safely.$t$,
   array[
     $t$Thumb up; raise 30° forward of straight-out.$t$,
     $t$Stop at or below shoulder height.$t$,
     $t$Light.$t$],
   'sets_weight', false, null),

  ('Hollow-body hold',
   $t$Anti-extension hold — ribs down, low back pinned, limbs extended only as far as you can hold the position.$t$,
   array[
     $t$Low back pinned, ribs down.$t$,
     $t$Extend arms and legs only as far as you can keep it flat.$t$],
   'done_check', false, null);

  -- ════════════════════════════════════════════════════════════════════════
  -- TEMPLATES
  -- ════════════════════════════════════════════════════════════════════════
  insert into workout_templates (name, sort_order) values ('Day A · Hinge', 1) returning id into t_a;
  insert into workout_templates (name, sort_order) values ('Day B · Knee / single-leg', 2) returning id into t_b;
  insert into workout_templates (name, sort_order) values ('Day C · Posterior + upper', 3) returning id into t_c;

  -- ──────────────────────────────────────────────────────────────────────
  -- DAY A · Hinge
  -- ──────────────────────────────────────────────────────────────────────
  insert into template_blocks (template_id, type, label, sort_order)
    values (t_a, 'circuit', 'Warm-up · circuit', 0) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Thoracic ext + open-book'), null, 1,  1,  2, false, null, false, 0),
    (blk, (select id from exercises where name = 'Wall slide (protract)'),    null, 2, 10, 10, false, null, false, 1),
    (blk, (select id from exercises where name = 'Prone Y raise'),            null, 2, 12, 15, false, null, false, 2),
    (blk, (select id from exercises where name = 'Cable external rotation'),  null, 2, 12, 15, false,   12,  true, 3);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_a, 'single', 'Primary', 1) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Trap-bar deadlift'), null, 3, 6, 8, false, 175, false, 0);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_a, 'superset', 'Superset · alternate A1/A2', 2) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Landmine press'), 'A1', 3,  8, 10,  true, 45, true, 0),
    (blk, (select id from exercises where name = 'Batwing row'),    'A2', 3, 10, 12, false, 40, true, 1);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_a, 'single', 'Accessories', 3) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'B-stance single-leg RDL'), null, 3,  8, 10,  true,  50, true, 0),
    (blk, (select id from exercises where name = 'Hip airplane'),            null, 2,  5,  6,  true, null, false, 1),
    (blk, (select id from exercises where name = 'Side plank'),              null, 2, 30, 30,  true, null, false, 2),
    (blk, (select id from exercises where name = 'Suitcase carry'),          null, 3, 30, 40,  true,  50, true, 3);

  -- ──────────────────────────────────────────────────────────────────────
  -- DAY B · Knee / single-leg
  -- ──────────────────────────────────────────────────────────────────────
  insert into template_blocks (template_id, type, label, sort_order)
    values (t_b, 'circuit', 'Warm-up · circuit', 0) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Thoracic ext + open-book'), null, 1,  1,  2, false, null, false, 0),
    (blk, (select id from exercises where name = 'Wall slide (protract)'),    null, 2, 10, 10, false, null, false, 1),
    (blk, (select id from exercises where name = 'Prone Y raise'),            null, 2, 12, 15, false, null, false, 2),
    (blk, (select id from exercises where name = 'Cable external rotation'),  null, 2, 12, 15, false,   12,  true, 3);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_b, 'single', 'Primary', 1) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Rear-foot-elevated split squat'), null, 3, 8, 10, true, 25, true, 0);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_b, 'superset', 'Superset · alternate B1/B2', 2) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Neutral-grip pull-up'),               'B1', 3, 6, 10, false, null, false, 0),
    (blk, (select id from exercises where name = 'Neutral-grip DB bench / low incline'), 'B2', 3, 8, 12, false,   50, false, 1);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_b, 'single', 'Accessories', 3) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Barbell / B-stance hip thrust'), null, 3,  8, 10, false, 135, true, 0),
    (blk, (select id from exercises where name = 'Cossack squat'),                 null, 2,  6,  8,  true,  20, true, 1),
    (blk, (select id from exercises where name = 'Pallof press'),                  null, 2, 10, 10,  true,  15, true, 2),
    (blk, (select id from exercises where name = 'Dead bug'),                      null, 2,  8, 10,  true, null, false, 3);

  -- ──────────────────────────────────────────────────────────────────────
  -- DAY C · Posterior + upper balance
  -- ──────────────────────────────────────────────────────────────────────
  insert into template_blocks (template_id, type, label, sort_order)
    values (t_c, 'circuit', 'Warm-up · circuit', 0) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Thoracic ext + open-book'), null, 1,  1,  2, false, null, false, 0),
    (blk, (select id from exercises where name = 'Wall slide (protract)'),    null, 2, 10, 10, false, null, false, 1),
    (blk, (select id from exercises where name = 'Prone Y raise'),            null, 2, 12, 15, false, null, false, 2),
    (blk, (select id from exercises where name = 'Cable external rotation'),  null, 2, 12, 15, false,   12,  true, 3);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_c, 'single', 'Primary', 1) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'B-stance / single-leg RDL (heavier)'), null, 3, 6, 8, true, 60, true, 0);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_c, 'superset', 'Superset · alternate C1/C2', 2) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Single-arm DB row'), 'C1', 3, 8, 12,  true, 50, true,  0),
    (blk, (select id from exercises where name = 'Incline DB press'),  'C2', 3, 8, 12, false, 45, false, 1);

  insert into template_blocks (template_id, type, label, sort_order)
    values (t_c, 'single', 'Accessories', 3) returning id into blk;
  insert into template_exercises (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high, per_side, seed_weight, seed_is_estimate, sort_order) values
    (blk, (select id from exercises where name = 'Nordic hamstring curl (band-assisted)'), null, 3,  5,  8, false, null, false, 0),
    (blk, (select id from exercises where name = 'Scaption (full-can)'),                   null, 2, 12, 15, false,    8, true,  1),
    (blk, (select id from exercises where name = 'Hollow-body hold'),                      null, 2, 20, 30, false, null, false, 2),
    (blk, (select id from exercises where name = 'Suitcase carry'),                        null, 3, 30, 40,  true,   50, true,  3);

end $$;
