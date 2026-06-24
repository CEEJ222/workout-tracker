-- Mesocycle (training block) above the day-templates
create table public.mesocycles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null default 0
);
alter table public.mesocycles enable row level security;
create policy "mesocycles_select_authenticated"
  on public.mesocycles for select to authenticated using (true);

insert into public.mesocycles (name, sort_order) values
  ('Block 1 — Foundation', 1),
  ('Block 2 — Variation', 2);

-- Each day-template belongs to a block
alter table public.workout_templates
  add column mesocycle_id uuid references public.mesocycles(id);

update public.workout_templates
  set mesocycle_id = (select id from public.mesocycles where name = 'Block 1 — Foundation');

alter table public.workout_templates
  alter column mesocycle_id set not null;

-- Per-user active block
create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_mesocycle_id uuid references public.mesocycles(id)
);
alter table public.user_settings enable row level security;
create policy "user_settings_own"
  on public.user_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Default the existing user(s) to Block 1
insert into public.user_settings (user_id, active_mesocycle_id)
  select distinct user_id, (select id from public.mesocycles where name = 'Block 1 — Foundation')
  from public.sessions
on conflict (user_id) do nothing;
