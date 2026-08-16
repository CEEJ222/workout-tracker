-- Correction to 20260815...restore_vertical_press: CJ's 15 logged sets
-- (25 -> 32.5 lb) were STANDING landmine press, not half-kneeling. The previous
-- migration renamed that row to "(half-kneeling)" and seeded the new Day 2 slot
-- from its 35 lb progress value. Both were wrong.
--
-- Half-kneeling removes leg drive and narrows the base, adding an anti-rotation
-- demand — press-able load drops roughly 20%. Carrying 35 forward would have
-- started a shoulder-constrained movement well above a tolerable load.
--
-- These are separate series, not one: same pattern, different loads. Same shape
-- as Betsy's barbell vs machine hip thrust. The standing row keeps its five
-- sessions; half-kneeling starts on its own row with its own progression.
--
-- The Day 2 slot has no logged sessions yet, so repointing it is permitted by
-- template_exercises_forbid_repoint.

-- 1. Restore the standing row to its true identity. History is standing.
update public.exercises
set name = 'Landmine press (standing)',
    description = 'Standing single-arm landmine press. Flexion-biased arc terminating '
                  'below full overhead. Logged history 2026-06-27 to 2026-08-01 is this '
                  'variation: 25 -> 32.5 lb, no pain flags.',
    cues = array[
      'Stagger the stance, brace before the press.',
      'Press up and slightly across the body.',
      'Stop short of full overhead. Reach, do not shrug.',
      'Stop the set at any pinch at the top, not after.'
    ],
    rest_seconds = 90
where id = '2f31e275-037e-488f-9bda-c1c8230a0174';

-- 2. Set up the half-kneeling row properly.
update public.exercises
set description = 'Half-kneeling single-arm landmine press. Removes leg drive and adds an '
                  'anti-rotation demand, so load runs roughly 20% below the standing '
                  'variation — progress it independently. Lowest-compression pressing path '
                  'for a shoulder that does not tolerate straight overhead work '
                  '(flexion bias, terminates below full overhead).',
    cues = array[
      'Opposite knee down from the pressing arm.',
      'Ribs down, down-side glute engaged — no lumbar extension to finish the rep.',
      'Press up and slightly across; let the shoulder blade rotate up and around the ribcage.',
      'Stop short of full overhead. Reach, do not shrug.',
      'Stop the set at any pinch at the top, not after.'
    ],
    rest_seconds = 90,
    primary_muscle = 'front_delt',
    movement_pattern = 'vertical_push',
    is_unilateral = true
where id = '21982966-89f0-4d85-a102-989b59283aca';

-- 3. Point the new Day 2 slot at half-kneeling, seeded conservatively from the
--    standing history (32.5 x 10-12 -> 25 half-kneeling) as an estimate.
update public.template_exercises
set exercise_id = '21982966-89f0-4d85-a102-989b59283aca',
    seed_weight = 25,
    seed_is_estimate = true
where block_id = 'c5685d27-bbdd-4be4-8827-9b0e4d756088'
  and exercise_id = '2f31e275-037e-488f-9bda-c1c8230a0174';
