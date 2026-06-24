-- Backfill rest_seconds for every exercise by the role it plays in the program,
-- derived structurally from template placement so it covers all training blocks
-- (Block 1, Block 2, and any added later) without naming exercises one by one.
--
-- Role → seconds (matches the build spec and src/lib/rest.ts):
--   warm-up circuit            → null  (no rest line shown)
--   superset member            → 75    (rendered as "alternate" rest)
--   primary lift               → 150   (~2–3 min)
--   loaded accessory (auto)    → 90
--   cuff/scapular/core/etc.    → 45    (auto_load = false)
--
-- Every exercise here fills exactly one role, so the role per exercise is
-- unambiguous. Display-only; no timing logic lives in the database.
update exercises e
set rest_seconds = role.rest
from (
  select distinct on (te.exercise_id)
    te.exercise_id,
    case
      when tb.type = 'circuit'        then null
      when tb.type = 'superset'       then 75
      when tb.label ilike 'primary%'  then 150
      when ex.auto_load               then 90
      else 45
    end as rest
  from template_exercises te
  join template_blocks tb on tb.id = te.block_id
  join exercises ex       on ex.id = te.exercise_id
  order by te.exercise_id
) role
where e.id = role.exercise_id;
