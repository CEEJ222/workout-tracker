-- enable_scaption_load_tracking
--
-- Enable load tracking on the GLOBAL 'Scaption (full-can)' exercise
-- (auto_load true, increment_lb 2.5) so logged progress writes back to the seed.
--
-- Guard: this must stay exclusively user 98251473-2fc9-4254-a4f9-6dc86135c1b2's
-- row before we flip it. Abort if any template NOT owned by that user references
-- it (is-distinct-from also catches null-owner/global mesocycles). Migrations run
-- in a transaction, so RAISE rolls the update back.

do $$
begin
  if exists (
    select 1
    from public.template_exercises te
    join public.exercises e          on e.id = te.exercise_id
    join public.template_blocks tb   on tb.id = te.block_id
    join public.workout_templates wt on wt.id = tb.template_id
    join public.mesocycles m         on m.id = wt.mesocycle_id
    where e.name = 'Scaption (full-can)'
      and m.user_id is distinct from '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  ) then
    raise exception
      'Aborting: Scaption (full-can) is referenced by a template not owned by user 98251473-2fc9-4254-a4f9-6dc86135c1b2';
  end if;
end $$;

update public.exercises
set auto_load    = true,
    increment_lb = 2.5
where name = 'Scaption (full-can)';
