-- Stray non-ASCII character in the previous comment ("users'" was mangled).
comment on column public.exercises.rest_seconds is
  'Per-exercise DEFAULT rest between sets, in seconds. Always read as '
  'coalesce(template_exercises.rest_seconds, exercises.rest_seconds) — never alone. '
  'This row is SHARED between athletes (11 exercise ids appear in both athletes '
  'templates), so editing it moves both their timers; set the per-slot override '
  'instead when a value is specific to one role or one athlete. Drives both the '
  'displayed label (formatRest) and the actual countdown (startRestTimer); those '
  'two must read the same resolved value.';
