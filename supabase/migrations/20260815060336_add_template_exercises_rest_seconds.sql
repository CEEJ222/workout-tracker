-- add_template_exercises_rest_seconds
--
-- Rest is a property of the SLOT, not of the exercise.
--
-- exercises.rest_seconds forced one number to serve every role an exercise
-- plays. Neutral-grip DB bench carries 75 (a superset value) but IS the Primary
-- on Day 2; B-stance / single-leg RDL carries 150 (a primary value) but sits in
-- a superset. Six exercises in active blocks fill more than one role. The
-- athlete noticed before the schema did — session notes read "Needs timer",
-- "No timer after", "Add timer to this one", "Timer is very long", and on
-- 2026-08-12: "Alternative is to attach the timer to the set type instead of
-- the exercise."
--
-- template_exercises is already the prescription-level table: target_rir_low/high,
-- seed_weight and per_side all live here precisely because they are per-slot.
-- rest_seconds joins them. Resolution is coalesce(te.rest_seconds, e.rest_seconds),
-- so every existing exercises.rest_seconds keeps working as the default and no
-- backfill is required.
--
-- SECOND CONSEQUENCE — this also makes rest per-USER.
-- exercises rows are shared: eleven exercise ids appear in both CJ's and Betsy's
-- templates (45-Degree Back Extension, Banded X-Walks / Lateral Band Walks,
-- Barbell Hip Thrust, Cable Curl, Cable Triceps Pushdown, Dynamic leg swings,
-- Easy cardio raise, Reverse Pec Deck, Seated Leg Curl, Standing Calf Raise,
-- Wall slide). Any edit to exercises.rest_seconds silently moves BOTH athletes'
-- timers. template_exercises is user-scoped through template_blocks ->
-- workout_templates -> mesocycles.user_id, so an override here reaches exactly
-- one athlete. Per-slot and per-user are the same change.
--
-- The identical argument will eventually apply to exercises.increment_lb: it is
-- shared the same way, and CLAUDE.md already records that it is a snapshot
-- rather than a rule (the valid step is a function of current weight and
-- implement count). When that is fixed, it belongs here too, not on exercises.

alter table public.template_exercises
  add column rest_seconds smallint null;

comment on column public.template_exercises.rest_seconds is
  'Per-slot rest override. Resolve as coalesce(te.rest_seconds, e.rest_seconds). '
  'Null means "inherit the exercise default". Set this rather than '
  'exercises.rest_seconds whenever the value is specific to one role or one '
  'athlete — exercises rows are shared between users, template_exercises rows '
  'are not.';

-- ── Per-slot overrides ──────────────────────────────────────────────────────
-- Rule applied, stated so it can be re-derived rather than guessed at later:
--   * an explicit Primary slot            -> 150s
--   * a working lift (target_rir_low = 1) -> 75s
--   * isolation / pump / core (rir 0/null)-> 45s
--
-- CJ's blocks label slots directly (Primary / Superset / Accessories). Betsy's
-- Block C is one flat `single` block per day with no role labels, so her slots
-- are classified by their RIR target, which is the signal that actually
-- distinguishes her working lifts from her pump work.
--
-- Rows are addressed by id: these are exact, already-verified prescriptions and
-- name matching is explicitly hazardous in this schema (CJ vs Betsy names differ
-- only by case in places).

-- CJ · Block 3 — Upper/Lower
update public.template_exercises set rest_seconds = 150 where id = '3a0c99ab-ba75-4eae-a4a2-b77ff2ebf77d'; -- Barbell Hip Thrust · Day 1 Primary
update public.template_exercises set rest_seconds = 75  where id = '76a33644-29b8-4fd3-ae94-8f2288c2089e'; -- B-stance / single-leg RDL · Day 1 Superset  ("Timer is very long")
update public.template_exercises set rest_seconds = 75  where id = 'b82e7f67-d4de-4b51-8927-0047384e5692'; -- Seated Leg Curl · Day 1 Superset            ("No timer after")
update public.template_exercises set rest_seconds = 45  where id = '2ef1b764-1b0a-4943-ad77-c036571190a4'; -- 45-Degree Back Extension · Day 1 Accessories ("Add timer to this one")
update public.template_exercises set rest_seconds = 75  where id = '1d25e304-4668-48e7-a2c2-dd1b90896b0d'; -- Cable Chest Fly · Day 2 Superset
update public.template_exercises set rest_seconds = 45  where id = '4e4e5c9e-2a44-4407-8b86-d8075997662b'; -- Cable Triceps Pushdown · Day 2 Accessories
update public.template_exercises set rest_seconds = 45  where id = 'e1d782d5-b2b7-4641-9264-0437f44a1cbf'; -- Standing Calf Raise · Day 3 Accessories
update public.template_exercises set rest_seconds = 45  where id = 'a838f8db-79eb-4296-ab2b-3293a35edb2a'; -- Cable Chest Fly · Day 4 Accessories
update public.template_exercises set rest_seconds = 45  where id = '7d15c5df-b37e-43c4-8c65-485a6d6133c1'; -- Reverse Pec Deck · Day 4 Accessories

-- Betsy · Block C — Glute & Posture
update public.template_exercises set rest_seconds = 75  where id = '9f3f9628-ba54-4168-8f28-eafa89cb32ae'; -- 45-Degree Back Extension · Day 1 slot 3 (rir 1)
update public.template_exercises set rest_seconds = 45  where id = '8f1f1d6d-2271-4b6f-875d-b544d28df6dd'; -- Reverse Pec Deck · Day 2 slot 3 (rir 0)
update public.template_exercises set rest_seconds = 45  where id = 'b0c50c75-0488-470d-98df-e8a624aa7321'; -- Cable Triceps Pushdown · Day 2 slot 5 (rir 0)
update public.template_exercises set rest_seconds = 75  where id = '414dce26-99a6-4e2d-9156-679bf5347b26'; -- Seated Leg Curl · Day 3 slot 2 (rir 1)
update public.template_exercises set rest_seconds = 75  where id = '81304df0-3bcc-4c19-abc6-241d40dce9a3'; -- 45-Degree Back Extension · Day 4 slot 3 (rir 1)
update public.template_exercises set rest_seconds = 45  where id = '9603e399-40ea-42c1-a66f-0939af37c781'; -- Standing Calf Raise · Day 4 slot 5 (rir 0)

-- Guard: all fifteen intended rows must have landed.
do $$
declare v_n int;
begin
  select count(*) into v_n
  from public.template_exercises
  where rest_seconds is not null;

  if v_n <> 15 then
    raise exception 'Expected 15 per-slot rest overrides, found %', v_n;
  end if;
end $$;