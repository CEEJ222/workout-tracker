-- 1) Ownership column on mesocycles (null = shared/global)
alter table public.mesocycles
  add column user_id uuid references auth.users(id) on delete cascade;

-- 2) Backfill existing blocks to the sole current user
update public.mesocycles
  set user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  where user_id is null;

-- 3) Ownership-aware SELECT policies (own OR global), cascading through the hierarchy
drop policy "mesocycles_select_authenticated" on public.mesocycles;
create policy "mesocycles_select_owned_or_global" on public.mesocycles
  for select to authenticated
  using (user_id = auth.uid() or user_id is null);

drop policy "Program readable by authenticated" on public.workout_templates;
create policy "workout_templates_select_visible" on public.workout_templates
  for select to authenticated
  using (exists (
    select 1 from public.mesocycles m
    where m.id = workout_templates.mesocycle_id
      and (m.user_id = auth.uid() or m.user_id is null)
  ));

drop policy "Program readable by authenticated" on public.template_blocks;
create policy "template_blocks_select_visible" on public.template_blocks
  for select to authenticated
  using (exists (
    select 1 from public.workout_templates wt
    join public.mesocycles m on m.id = wt.mesocycle_id
    where wt.id = template_blocks.template_id
      and (m.user_id = auth.uid() or m.user_id is null)
  ));

drop policy "Program readable by authenticated" on public.template_exercises;
create policy "template_exercises_select_visible" on public.template_exercises
  for select to authenticated
  using (exists (
    select 1 from public.template_blocks tb
    join public.workout_templates wt on wt.id = tb.template_id
    join public.mesocycles m on m.id = wt.mesocycle_id
    where tb.id = template_exercises.block_id
      and (m.user_id = auth.uid() or m.user_id is null)
  ));
-- exercises policy ("Program readable by authenticated", using true) intentionally left as global library
