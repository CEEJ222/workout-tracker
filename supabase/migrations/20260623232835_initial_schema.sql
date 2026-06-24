-- ============================================================================
-- Workout Tracker — initial schema (Phase 2)
--
-- Program tables (exercises, workout_templates, template_blocks,
-- template_exercises) are read-only seed data: SELECT-only to authenticated
-- users; writes happen via the service role (seed script, Phase 3).
--
-- User-data tables (sessions, session_exercises, session_sets,
-- user_exercise_progress) are RLS-scoped so a user can only touch their own
-- rows. session_exercises / session_sets have no user_id column (per spec) so
-- ownership is enforced through their parent session.
-- ============================================================================

-- ── Enums ───────────────────────────────────────────────────────────────────
create type log_type as enum ('sets_weight', 'done_check', 'done_check_weight');
create type block_type as enum ('circuit', 'superset', 'single');
create type session_status as enum ('in_progress', 'completed');
create type pain_severity as enum ('mild', 'sharp');

-- ============================================================================
-- PROGRAM TABLES (read-only in v1)
-- ============================================================================

-- The movement library.
create table exercises (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text,
  cues         text[] not null default '{}',
  log_type     log_type not null,
  auto_load    boolean not null default false,
  -- Step for auto-progress (e.g. 5 bilateral, 2.5 per-hand DB). Null when
  -- auto_load is false. Enforced: increment must accompany auto_load.
  increment_lb numeric,
  constraint exercises_increment_requires_auto_load
    check ((auto_load and increment_lb is not null) or (not auto_load))
);

create table workout_templates (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  sort_order integer not null default 0
);

-- Groups exercises within a day (circuit / superset / single).
create table template_blocks (
  id          uuid primary key default gen_random_uuid(),
  template_id uuid not null references workout_templates (id) on delete cascade,
  type        block_type not null,
  label       text not null,
  sort_order  integer not null default 0
);

-- An exercise's prescription inside a block.
create table template_exercises (
  id               uuid primary key default gen_random_uuid(),
  block_id         uuid not null references template_blocks (id) on delete cascade,
  exercise_id      uuid not null references exercises (id),
  pair_label       text,                 -- e.g. "A1", "A2"; null for non-paired
  target_sets      integer not null,
  target_reps_low  integer not null,
  target_reps_high integer not null,
  per_side         boolean not null default false,
  seed_weight      numeric,              -- nullable; bodyweight/band = null
  seed_is_estimate boolean not null default false,
  sort_order       integer not null default 0
);

create index template_blocks_template_id_idx on template_blocks (template_id);
create index template_exercises_block_id_idx on template_exercises (block_id);
create index template_exercises_exercise_id_idx on template_exercises (exercise_id);

-- ============================================================================
-- USER-DATA TABLES (RLS-scoped)
-- ============================================================================

-- One logged workout instance.
create table sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  template_id  uuid not null references workout_templates (id),
  started_at   timestamptz not null default now(),
  completed_at timestamptz,             -- captures the day it was done
  status       session_status not null default 'in_progress'
);

-- Per-exercise record within a session. Holds the single note + pain flag.
create table session_exercises (
  id                   uuid primary key default gen_random_uuid(),
  session_id           uuid not null references sessions (id) on delete cascade,
  template_exercise_id uuid not null references template_exercises (id),
  note                 text,
  pain_severity        pain_severity,   -- null = no pain
  done                 boolean not null default false
);

-- Per-set log.
create table session_sets (
  id                  uuid primary key default gen_random_uuid(),
  session_exercise_id uuid not null references session_exercises (id) on delete cascade,
  set_number          integer not null,
  -- Rep targets snapshotted at session creation (program could change later).
  target_reps_low     integer not null,
  target_reps_high    integer not null,
  actual_weight       numeric,
  actual_reps         integer,
  done                boolean not null default false
);

-- Current suggested weight per exercise; drives the "Suggested" badge and
-- auto-progress. One row per (user, exercise).
create table user_exercise_progress (
  user_id            uuid not null references auth.users (id) on delete cascade,
  exercise_id        uuid not null references exercises (id),
  current_weight     numeric,
  is_estimate        boolean not null default true,
  last_pain_severity pain_severity,
  updated_at         timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

create index sessions_user_id_idx on sessions (user_id);
create index sessions_user_status_idx on sessions (user_id, status);
create index session_exercises_session_id_idx on session_exercises (session_id);
create index session_exercises_template_exercise_id_idx on session_exercises (template_exercise_id);
create index session_sets_session_exercise_id_idx on session_sets (session_exercise_id);

-- Keep updated_at fresh on every progress upsert/update.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger user_exercise_progress_set_updated_at
  before update on user_exercise_progress
  for each row execute function set_updated_at();

-- ============================================================================
-- ROW-LEVEL SECURITY
-- ============================================================================

alter table exercises               enable row level security;
alter table workout_templates       enable row level security;
alter table template_blocks         enable row level security;
alter table template_exercises      enable row level security;
alter table sessions                enable row level security;
alter table session_exercises       enable row level security;
alter table session_sets            enable row level security;
alter table user_exercise_progress  enable row level security;

-- Program tables: read-only to any authenticated user. No write policies, so
-- inserts/updates/deletes are denied for normal users; the seed script writes
-- via the service role, which bypasses RLS.
create policy "Program readable by authenticated"
  on exercises for select to authenticated using (true);
create policy "Program readable by authenticated"
  on workout_templates for select to authenticated using (true);
create policy "Program readable by authenticated"
  on template_blocks for select to authenticated using (true);
create policy "Program readable by authenticated"
  on template_exercises for select to authenticated using (true);

-- sessions: owner-only (direct user_id).
create policy "Own sessions"
  on sessions for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- user_exercise_progress: owner-only (direct user_id).
create policy "Own progress"
  on user_exercise_progress for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- session_exercises: ownership flows through the parent session.
create policy "Own session_exercises"
  on session_exercises for all to authenticated
  using (
    exists (
      select 1 from sessions s
      where s.id = session_exercises.session_id
        and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from sessions s
      where s.id = session_exercises.session_id
        and s.user_id = (select auth.uid())
    )
  );

-- session_sets: ownership flows through session_exercise -> session.
create policy "Own session_sets"
  on session_sets for all to authenticated
  using (
    exists (
      select 1
      from session_exercises se
      join sessions s on s.id = se.session_id
      where se.id = session_sets.session_exercise_id
        and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from session_exercises se
      join sessions s on s.id = se.session_id
      where se.id = session_sets.session_exercise_id
        and s.user_id = (select auth.uid())
    )
  );
