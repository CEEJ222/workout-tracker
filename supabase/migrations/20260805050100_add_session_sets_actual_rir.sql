-- add_session_sets_actual_rir
--
-- Adds a nullable actual RIR (reps in reserve) to each logged set — the recorded
-- counterpart to template_exercises.target_rir_low / target_rir_high, which so
-- far have no logged counterpart. Nullable with no default, so all existing
-- session_sets rows stay NULL and nothing breaks. No existing row is touched.
--
-- No CHECK constraint added: this schema uses none (constrained value domains are
-- modelled with enum types, not CHECK constraints), so a 0-10 range check would
-- not match existing conventions and is intentionally skipped per instruction.
-- The 0-10 range is enforced in the app's RIR input instead.

alter table public.session_sets
  add column actual_rir smallint null;
