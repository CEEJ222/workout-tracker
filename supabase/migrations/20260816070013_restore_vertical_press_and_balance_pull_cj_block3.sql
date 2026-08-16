-- CJ Block 3 had no vertical press at all: front_delt 0 direct / 3.0 fractional,
-- all spillover from horizontal pressing. Landmine press ran in Blocks 1-2 and
-- did not carry forward. Not deliberate.
--
-- Also: Day 4 is labelled "pull bias" but prescribed 6 chest sets (Incline DB
-- press 3 + Cable Chest Fly 3) against 3 lat sets. Fractional lats 4.5 vs
-- upper_back 10.0 — vertical pull under half of horizontal pull.
--
-- Exercise choice is shoulder-constrained. Lawrence et al. 2018 (J Biomech)
-- modelled subacromial supraspinatus compression across glenohumeral planes and
-- found the LOWEST compression during flexion at lower elevation angles. The
-- landmine path is a flexion-biased arc terminating below full overhead — the
-- opposite loading condition to straight overhead pressing. CJ's own data
-- agrees: 15 sets across 5 sessions, 25 -> 32.5 lb, zero pain flags.
--
-- Uses the EXISTING 'Landmine press' row rather than the empty
-- 'Half-kneeling landmine press' duplicate (21982966..., 0 sessions), so the
-- five-session series and its 35 lb progress value stay intact. Starting from
-- the empty row would fragment history — the failure mode repaired in
-- 20260815043113.

-- 1. Name and cue the existing row for the half-kneeling setup.
update public.exercises
set name = 'Landmine press (half-kneeling)',
    description = 'Half-kneeling single-arm landmine press. Flexion-biased arc that '
                  'terminates below full overhead — the lowest-compression pressing '
                  'path for a shoulder that does not tolerate straight overhead work.',
    cues = array[
      'Half-kneeling, opposite knee down from the pressing arm.',
      'Ribs down, glute of the down leg engaged — no lumbar extension to finish the rep.',
      'Press up and slightly across; let the shoulder blade rotate up and around the ribcage.',
      'Stop short of full overhead. Reach, do not shrug.',
      'Stop the set if there is any pinch at the top, not after.'
    ],
    rest_seconds = 90
where id = '2f31e275-037e-488f-9bda-c1c8230a0174';

-- 2. Day 2 Accessories: make room at the front for the press.
update public.template_exercises set sort_order = sort_order + 1
where block_id = 'c5685d27-bbdd-4be4-8827-9b0e4d756088';

insert into public.template_exercises
  (id, block_id, exercise_id, target_sets, target_reps_low, target_reps_high,
   target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate,
   rest_seconds, sort_order)
values
  (gen_random_uuid(), 'c5685d27-bbdd-4be4-8827-9b0e4d756088',
   '2f31e275-037e-488f-9bda-c1c8230a0174', 3, 8, 12, 1, 2, true, 35, false, 90, 0);

-- 3. Offset the added volume: Day 2 scaption 3 -> 2 sets.
--    Side delt stays at 4 weekly sets (2 here + 2 on Day 4).
update public.template_exercises set target_sets = 2
where id = '10d2ef27-f188-4ee2-8026-0fd0957bc8c1';

-- 4. Day 4 is the pull day. Retire the second chest fly slot and give those
--    three sets to vertical pull. Chest drops 12 -> 9 fractional, still the
--    highest-volume muscle in the block, and the lengthened-position fly work
--    added earlier survives on Day 2. RETIRE, do not repoint — the row has
--    logged sessions.
update public.template_exercises
set retired_at = now()
where id = 'a838f8db-79eb-4296-ab2b-3293a35edb2a'; -- Day 4 Cable Chest Fly

insert into public.template_exercises
  (id, block_id, exercise_id, target_sets, target_reps_low, target_reps_high,
   target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate,
   rest_seconds, sort_order)
values
  (gen_random_uuid(), '2f74ad2c-6b18-4e94-b575-9b02d2216ddb',
   '1d0fa119-5970-46b9-aae7-8a74843a1c22', 3, 8, 12, 1, 2, false, 70, true, 90, 0);
