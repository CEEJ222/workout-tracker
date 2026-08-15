-- Two of CJ's four Primary slots were resolving to 75s by inheriting a global
-- exercises.rest_seconds default, not by any deliberate per-slot decision.
--
-- This is the ORIGINAL defect, not a leftover null. Neutral-grip DB bench is the
-- exact slot that prompted CJ's 2026-08-12 note: "I think this timer should be
-- longer right? Since this is the primary workout for the day." Its exercise
-- default of 75 is a superset-tier value; it is the Day 2 Primary. Neutral-grip
-- pull-up on Day 4 is the same shape.
--
-- Filling nulls (20260815064305) closed every missing timer but never audited the
-- non-null resolutions against slot role, so these two survived as wrong-but-present
-- values. Both are target_rir_low = 1, auto_load = true — genuine heavy primaries.

update public.template_exercises set rest_seconds = 150
where id in (
  '0442e606-0731-4e0f-a6ff-b65d7bdcd8d6', -- CJ Day 2 Primary · Neutral-grip DB bench / low incline
  'fbc26bff-3775-40c5-8a94-7118145573e4'  -- CJ Day 4 Primary · Neutral-grip pull-up
);
