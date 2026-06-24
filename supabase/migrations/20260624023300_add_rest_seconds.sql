-- Add suggested rest to the movement library — display-only guidance, not a
-- timer (a live countdown is a later, separate phase). The value is seeded by
-- role in seed.sql; null means "no rest line shown" (the warm-up circuit).
-- Formatting (seconds → label) lives in one place: formatRest() in src/lib/rest.ts.
alter table exercises
  add column rest_seconds integer;

comment on column exercises.rest_seconds is
  'Suggested rest between sets, in seconds. Null = no rest guidance shown (warm-up circuit). Display-only in v1; no timing logic.';
