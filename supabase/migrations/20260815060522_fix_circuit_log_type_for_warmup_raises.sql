-- fix_circuit_log_type_for_warmup_raises
--
-- 'Prone Bench Y-T-W Raises' and 'Band/Cable Pull-Apart' are log_type
-- 'sets_weight' but sit in warm-up circuit blocks, where CircuitRow only
-- renders a weight input for 'done_check_weight'. Their load could never be
-- logged.
--
-- WHY THEY ENDED UP THIS WAY. Not a typo. In Betsy's Block B both were working
-- accessories in a `single` block with real seed weights (Pull-Apart 10 lb,
-- Y-T-W 2 lb), where 'sets_weight' was correct. Block C reuses the same
-- exercises rows as warm-up circuit rows — and log_type lives on `exercises`,
-- so the working-accessory setting followed them into the warm-up. This is the
-- same defect as rest_seconds one migration ago: a per-SLOT property stored
-- per-EXERCISE. See the note at the bottom.
--
-- WHY log_type AND NOT CircuitRow. Teaching CircuitRow to render weight for
-- 'sets_weight' would look like a fix and quietly lose data. CircuitRow renders
-- card.sets[0] only, by design — a circuit is logged as "done, at roughly this
-- load", not per set. Both rows are target_sets = 2, so set 2 would have no
-- input at all and silently stay null. 'done_check_weight' is the established
-- convention for exactly this case: Cable external rotation is also target_sets
-- = 2 in a circuit and captures one load for the exercise. Matching it keeps
-- these two consistent with the only other loaded warm-up in the schema instead
-- of inventing a second pattern.
--
-- SAFETY. Neither exercise has ever been logged: 0 done sets, 0 sets with a
-- weight, 0 sets with reps, across every block including archived ones. The
-- Block B `single` slots that justified 'sets_weight' are archived and unlogged,
-- so nothing loses a capability it was using.

update public.exercises
set log_type = 'done_check_weight'
where name in ('Prone Bench Y-T-W Raises', 'Band/Cable Pull-Apart');

-- Guard: exactly the two intended rows, and no circuit row left on 'sets_weight'.
do $$
declare
  v_updated int;
  v_stragglers int;
begin
  select count(*) into v_updated
  from public.exercises
  where name in ('Prone Bench Y-T-W Raises', 'Band/Cable Pull-Apart')
    and log_type = 'done_check_weight';

  if v_updated <> 2 then
    raise exception 'Expected 2 exercises on done_check_weight, found %', v_updated;
  end if;

  select count(*) into v_stragglers
  from public.template_exercises te
  join public.template_blocks tb on tb.id = te.block_id
  join public.exercises e on e.id = te.exercise_id
  where tb.type = 'circuit' and e.log_type = 'sets_weight';

  if v_stragglers <> 0 then
    raise exception 'Still % circuit rows on sets_weight', v_stragglers;
  end if;
end $$;

-- FOLLOW-UP, deliberately NOT done here.
-- log_type is role-dependent in exactly the way rest_seconds was: the same
-- movement is a loaded accessory in one slot and an unloaded primer in another.
-- The durable fix is a nullable template_exercises.log_type override resolved as
-- coalesce(te.log_type, e.log_type), matching the rest_seconds pattern. Doing it
-- now would be a schema change beyond the reported bug, so it is recorded rather
-- than applied. Note that exercises rows are shared between athletes, so this
-- column carries the same cross-user coupling flagged in
-- add_template_exercises_rest_seconds.