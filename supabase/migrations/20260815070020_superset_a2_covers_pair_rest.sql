-- superset_a2_covers_pair_rest
--
-- In a superset you alternate A1 -> A2 with no rest between; the rest belongs
-- after the pair, not between its halves. The app now suppresses the countdown
-- on the leading member and fires it on the final one, so the final member's
-- value has to cover recovery for BOTH exercises.
--
-- 75s was sized for a single exercise that rests on both sides of itself. Once
-- it is the only rest in the pair, it is short. Raised to 120s.
--
-- Set as template_exercises overrides, never on exercises.rest_seconds: these
-- values are specific to the superset role. `Cable Chest Fly (managed range)`
-- also appears as a Day 4 accessory at 45s, and `Seated Leg Curl` appears in
-- Betsy's Day 3 at 75s — editing the shared global row would move both.
--
-- The leading members stay at 75 deliberately. That value no longer renders a
-- countdown (formatRest returns countdownSeconds = null for a non-final pair
-- member), but it is left in place so the slot still resolves to a real number
-- if the pair is ever broken up into two straight-set slots.
--
-- Addressed by id — pair_label alone is not unique across templates, and
-- exercise names are case-sensitive and shared between athletes.

update public.template_exercises set rest_seconds = 120
where id in (
  'b82e7f67-d4de-4b51-8927-0047384e5692',  -- A2 · Seated Leg Curl        · Day 1 (was 75)
  '1d25e304-4668-48e7-a2c2-dd1b90896b0d',  -- B2 · Cable Chest Fly        · Day 2 (was 75)
  '076b509a-68a4-4467-b28e-0f37e3ed4b2d'   -- D2 · Batwing row            · Day 4 (was null, inherited 75)
);

-- Guard: exactly the three final members at 120, and every leading member still
-- resolving to 75. Migrations run in a transaction, so a miss aborts the lot.
do $$
declare
  v_final int;
  v_leading_not_75 int;
begin
  select count(*) into v_final
  from public.template_exercises te
  join public.template_blocks tb on tb.id = te.block_id
  where tb.type = 'superset' and te.pair_label like '%2' and te.rest_seconds = 120;

  if v_final <> 3 then
    raise exception 'Expected 3 superset final members at 120s, found %', v_final;
  end if;

  select count(*) into v_leading_not_75
  from public.template_exercises te
  join public.template_blocks tb on tb.id = te.block_id
  join public.exercises e on e.id = te.exercise_id
  join public.workout_templates t on t.id = tb.template_id
  join public.mesocycles m on m.id = t.mesocycle_id
  where tb.type = 'superset' and te.pair_label like '%1'
    and m.archived_at is null and te.retired_at is null
    and coalesce(te.rest_seconds, e.rest_seconds) <> 75;

  if v_leading_not_75 <> 0 then
    raise exception '% superset leading members no longer resolve to 75s', v_leading_not_75;
  end if;
end $$;