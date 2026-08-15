-- New exercise for Block C, plus a rename now that Betsy is committed to the machine.
-- Safe: the old row has 0 sessions and no user_exercise_progress reference.

insert into exercises (id, name, description, cues, log_type, auto_load, increment_lb, rest_seconds)
values (
  gen_random_uuid(),
  'Hack Squat',
  'Machine squat with the torso supported, allowing deep hip flexion under load. Log PLATE weight only — do not include the sled.',
  array[
    'Log plate weight only — do not include the sled.',
    'Sit into depth; deep hip flexion is the point.',
    'Drive through the whole foot, not just the toes.',
    'Control the descent — no bouncing out of the bottom.'
  ],
  'sets_weight', true, 10, null
);

update exercises
set name = 'Machine Hip Thrust',
    description = 'Loaded hip extension on the hip thrust machine. Drive to full lockout with a posterior pelvic tilt at the top.',
    cues = array[
      'Full lockout, squeeze at the top.',
      'Ribs down — do not arch the low back to finish the rep.',
      'Chin tucked, eyes forward through the rep.',
      'Control the lower; do not drop into the bottom.'
    ]
where id = '5f8cfd9e-6b2b-4a5a-9206-82919b27843b';
