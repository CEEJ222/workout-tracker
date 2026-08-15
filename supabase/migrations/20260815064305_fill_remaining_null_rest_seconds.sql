-- Every slot gets a timer. This closes the last 38 nulls across both athletes'
-- active blocks.
--
-- Set at the template_exercises level rather than on exercises, because these
-- same exercise rows also appear as working slots elsewhere and must not
-- inherit a warm-up rest value. (Pallof press, Scaption, Dead bug, Band/Cable
-- Pull-Apart and Prone Y-T-W all serve both roles.)
--
-- Warm-up circuits: 30s. Long enough to change position or grab a band, short
-- enough that the prep block doesn't stall.

update public.template_exercises te
set rest_seconds = 30
from public.template_blocks tb, public.workout_templates t, public.mesocycles m
where tb.id = te.block_id
  and t.id = tb.template_id
  and m.id = t.mesocycle_id
  and m.archived_at is null
  and tb.type = 'circuit'
  and te.rest_seconds is null;

-- The one working slot still resolving to null. Isolation arm work, matches the
-- 45s used for every other accessory-tier slot.
update public.template_exercises
set rest_seconds = 45
where id = '48d45538-26a4-4210-9630-950c50edc071'; -- Cable Curl, CJ Accessories
