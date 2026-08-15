-- The exercises.rest_seconds comment predates the rest timer and predates the
-- per-slot override column. Both claims in it are now false: rest is no longer
-- display-only, and null no longer means "warm-up circuit" — every slot in every
-- active block now resolves to a value (warm-ups included, at 30s).

comment on column public.exercises.rest_seconds is
  'Per-exercise DEFAULT rest between sets, in seconds. Always read as '
  'coalesce(template_exercises.rest_seconds, exercises.rest_seconds) — never alone. '
  'This row is SHARED between athletes (11 exercise ids appear in both usersّ '
  'templates), so editing it moves both their timers; set the per-slot override '
  'instead when a value is specific to one role or one athlete. Drives both the '
  'displayed label (formatRest) and the actual countdown (startRestTimer); those '
  'two must read the same resolved value.';

comment on column public.template_exercises.rest_seconds is
  'Per-slot rest override, in seconds. Null = inherit exercises.rest_seconds, '
  'which is the healthy state for most slots. Set this when the same movement '
  'needs different rest in different roles (primary vs superset vs accessory) or '
  'for different athletes — template_exercises is user-scoped via '
  'template_blocks -> workout_templates -> mesocycles.user_id, so per-slot and '
  'per-user are the same change.';
