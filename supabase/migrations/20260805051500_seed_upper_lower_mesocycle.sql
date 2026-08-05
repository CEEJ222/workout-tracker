-- seed_upper_lower_mesocycle
--
-- Seeds 'Block 3 — Upper/Lower' for user 98251473-2fc9-4254-a4f9-6dc86135c1b2:
-- the mesocycle, four day-templates, their blocks, and every prescription.
-- Runs AFTER add_new_exercises_for_upper_lower (which creates DB Lateral Raise,
-- Standing Calf Raise, Leg Press (quad bias), Deep squat + ankle rock, and
-- Scap pull-up / band lat primer; 'Dynamic leg swings' already existed).
--
-- Exercise matching is EXACT and CASE-SENSITIVE (plain `=`). The library holds
-- near-duplicates that differ only by case/wording — 'Dead bug' vs 'Dead Bug',
-- 'Single-arm DB row' vs 'Single-Arm Dumbbell Row'. The lowercase variants are
-- this user's; the Title Case variants are Betsy's. The guard below aborts if any
-- referenced name does not resolve to EXACTLY ONE row, so a rename or a missing
-- prerequisite fails loudly instead of silently grabbing the wrong row or
-- dropping the prescription.
--
-- Everything is scoped to this mesocycle; nothing in Block 1, Block 2, or Betsy's
-- rows is read or written, and user_settings is left untouched (the later archive
-- migration flips the active block). No UUIDs are hardcoded. All inserts are
-- guarded with NOT EXISTS so the migration is safe to re-run.
--
-- Row-count note: this seeds 1 mesocycle, 4 templates, 15 blocks, and 47
-- template_exercises (warm-ups total 23: Days 1/3/4 have 6 rows, Day 2 has 5).

-- 0) Guard: every referenced exercise name must resolve to exactly one row.
do $$
declare
  offenders text;
begin
  select string_agg(v.name || ' (found ' || c.cnt || ')', ', ' order by v.name)
    into offenders
  from (values
    ('Easy cardio raise'), ('Dynamic leg swings'),
    ('Banded X-Walks / Lateral Band Walks'), ('Thoracic ext + open-book'),
    ('Prone Y raise'), ('Cable external rotation'), ('Wall slide (protract)'),
    ('Deep squat + ankle rock'), ('Scap pull-up / band lat primer'),
    ('Barbell Hip Thrust'), ('Neutral-grip DB bench / low incline'),
    ('Rear-foot-elevated split squat'), ('Neutral-grip pull-up'),
    ('B-stance / single-leg RDL (heavier)'), ('Seated Leg Curl'),
    ('Single-arm DB row'), ('Cable Chest Fly (managed range)'),
    ('Incline DB press'), ('Batwing row'), ('45-Degree Back Extension'),
    ('Side plank'), ('Suitcase carry'), ('DB Lateral Raise'),
    ('Cable Curl (straight or EZ bar)'), ('Cable Triceps Pushdown (rope)'),
    ('Leg Press (quad bias)'), ('Cossack squat'), ('Standing Calf Raise'),
    ('Pallof press'), ('Dead bug'), ('Reverse Pec Deck (rear delt)'),
    ('Scaption (full-can)')
  ) as v(name)
  cross join lateral (
    select count(*) as cnt from public.exercises e where e.name = v.name
  ) c
  where c.cnt <> 1;

  if offenders is not null then
    raise exception
      'Block 3 seed aborted — exercise names not resolving to exactly one row: %',
      offenders;
  end if;
end $$;

-- 1) Mesocycle.
insert into public.mesocycles (name, sort_order, user_id, archived_at)
select 'Block 3 — Upper/Lower', 3, '98251473-2fc9-4254-a4f9-6dc86135c1b2', null
where not exists (
  select 1 from public.mesocycles
  where name = 'Block 3 — Upper/Lower'
    and user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
);

-- 2) Four day-templates.
insert into public.workout_templates (name, sort_order, mesocycle_id)
select v.name, v.sort_order, m.id
from (values
  ('Day 1 · Lower — hip dominant', 0),
  ('Day 2 · Upper — press bias', 1),
  ('Day 3 · Lower — knee dominant', 2),
  ('Day 4 · Upper — pull bias', 3)
) as v(name, sort_order)
join public.mesocycles m
  on m.name = 'Block 3 — Upper/Lower'
 and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
where not exists (
  select 1 from public.workout_templates wt
  where wt.mesocycle_id = m.id and wt.name = v.name
);

-- 3) Blocks (Day 3 has no superset).
insert into public.template_blocks (template_id, type, label, sort_order)
select wt.id, v.type::public.block_type, v.label, v.sort_order
from (values
  ('Day 1 · Lower — hip dominant', 'circuit',  'Warm-up · circuit', 0),
  ('Day 1 · Lower — hip dominant', 'single',   'Primary',           1),
  ('Day 1 · Lower — hip dominant', 'superset', 'Superset',          2),
  ('Day 1 · Lower — hip dominant', 'single',   'Accessories',       3),
  ('Day 2 · Upper — press bias',   'circuit',  'Warm-up · circuit', 0),
  ('Day 2 · Upper — press bias',   'single',   'Primary',           1),
  ('Day 2 · Upper — press bias',   'superset', 'Superset',          2),
  ('Day 2 · Upper — press bias',   'single',   'Accessories',       3),
  ('Day 3 · Lower — knee dominant','circuit',  'Warm-up · circuit', 0),
  ('Day 3 · Lower — knee dominant','single',   'Primary',           1),
  ('Day 3 · Lower — knee dominant','single',   'Accessories',       3),
  ('Day 4 · Upper — pull bias',    'circuit',  'Warm-up · circuit', 0),
  ('Day 4 · Upper — pull bias',    'single',   'Primary',           1),
  ('Day 4 · Upper — pull bias',    'superset', 'Superset',          2),
  ('Day 4 · Upper — pull bias',    'single',   'Accessories',       3)
) as v(template_name, type, label, sort_order)
join public.mesocycles m
  on m.name = 'Block 3 — Upper/Lower'
 and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
join public.workout_templates wt
  on wt.mesocycle_id = m.id and wt.name = v.template_name
where not exists (
  select 1 from public.template_blocks tb
  where tb.template_id = wt.id and tb.label = v.label
);

-- 4) Prescriptions. RIR (1/2) only on Primary and Superset rows; null elsewhere.
insert into public.template_exercises
  (block_id, exercise_id, pair_label, target_sets, target_reps_low, target_reps_high,
   target_rir_low, target_rir_high, per_side, seed_weight, seed_is_estimate, sort_order)
select tb.id, ex.id, v.pair_label, v.target_sets, v.reps_low, v.reps_high,
       v.rir_low, v.rir_high, v.per_side, v.seed_weight, v.seed_is_estimate, v.ex_sort
from (values
  -- ── Day 1 · Lower — hip dominant ──
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Easy cardio raise',                 null::text, 1, 1, 1,  null::int, null::int, false, null::numeric, false, 0),
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Dynamic leg swings',                null, 1, 10, 10, null, null, true,  null, false, 1),
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Banded X-Walks / Lateral Band Walks',null, 2, 12, 15, null, null, true,  null, false, 2),
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Thoracic ext + open-book',          null, 1, 1, 2,  null, null, false, null, false, 3),
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Prone Y raise',                     null, 2, 12, 15, null, null, false, null, false, 4),
  ('Day 1 · Lower — hip dominant','Warm-up · circuit','Cable external rotation',           null, 2, 12, 15, null, null, false, 12,   true,  5),
  ('Day 1 · Lower — hip dominant','Primary','Barbell Hip Thrust',                          null, 3, 8, 10, 1, 2, false, 115, false, 0),
  ('Day 1 · Lower — hip dominant','Superset','B-stance / single-leg RDL (heavier)',        'A1', 3, 6, 8,  1, 2, true,  70,  false, 0),
  ('Day 1 · Lower — hip dominant','Superset','Seated Leg Curl',                            'A2', 3, 8, 12, 1, 2, false, 60,  true,  1),
  ('Day 1 · Lower — hip dominant','Accessories','45-Degree Back Extension',                null, 3, 10, 12, null, null, false, 10,  true,  0),
  ('Day 1 · Lower — hip dominant','Accessories','Side plank',                              null, 2, 30, 30, null, null, true,  null, false, 1),
  ('Day 1 · Lower — hip dominant','Accessories','Suitcase carry',                          null, 3, 30, 40, null, null, true,  50,  false, 2),

  -- ── Day 2 · Upper — press bias ──
  ('Day 2 · Upper — press bias','Warm-up · circuit','Easy cardio raise',        null, 1, 1, 1,  null, null, false, null, false, 0),
  ('Day 2 · Upper — press bias','Warm-up · circuit','Thoracic ext + open-book', null, 1, 1, 2,  null, null, false, null, false, 1),
  ('Day 2 · Upper — press bias','Warm-up · circuit','Wall slide (protract)',    null, 2, 10, 10, null, null, false, null, false, 2),
  ('Day 2 · Upper — press bias','Warm-up · circuit','Prone Y raise',            null, 2, 12, 15, null, null, false, null, false, 3),
  ('Day 2 · Upper — press bias','Warm-up · circuit','Cable external rotation',  null, 2, 12, 15, null, null, false, 12,   true,  4),
  ('Day 2 · Upper — press bias','Primary','Neutral-grip DB bench / low incline',null, 3, 8, 12, 1, 2, false, 50, false, 0),
  ('Day 2 · Upper — press bias','Superset','Single-arm DB row',                 'B1', 3, 8, 12, 1, 2, true,  50, false, 0),
  ('Day 2 · Upper — press bias','Superset','Cable Chest Fly (managed range)',   'B2', 3, 10, 15, 1, 2, false, 20, true,  1),
  ('Day 2 · Upper — press bias','Accessories','DB Lateral Raise',               null, 3, 12, 20, null, null, false, 10, true,  0),
  ('Day 2 · Upper — press bias','Accessories','Cable Curl (straight or EZ bar)',null, 3, 8, 12, null, null, false, 30, true,  1),
  ('Day 2 · Upper — press bias','Accessories','Cable Triceps Pushdown (rope)',  null, 3, 10, 15, null, null, false, 30, true,  2),

  -- ── Day 3 · Lower — knee dominant (no superset) ──
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Easy cardio raise',        null, 1, 1, 1,  null, null, false, null, false, 0),
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Dynamic leg swings',       null, 1, 10, 10, null, null, true,  null, false, 1),
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Deep squat + ankle rock',  null, 1, 8, 10, null, null, false, null, false, 2),
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Thoracic ext + open-book', null, 1, 1, 2,  null, null, false, null, false, 3),
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Prone Y raise',            null, 2, 12, 15, null, null, false, null, false, 4),
  ('Day 3 · Lower — knee dominant','Warm-up · circuit','Cable external rotation',  null, 2, 12, 15, null, null, false, 12,   true,  5),
  ('Day 3 · Lower — knee dominant','Primary','Rear-foot-elevated split squat',     null, 3, 8, 10, 1, 2, true,  25, false, 0),
  ('Day 3 · Lower — knee dominant','Accessories','Leg Press (quad bias)',          null, 3, 10, 12, null, null, false, 180, true,  0),
  ('Day 3 · Lower — knee dominant','Accessories','Cossack squat',                  null, 2, 8, 12, null, null, true,  20,  false, 1),
  ('Day 3 · Lower — knee dominant','Accessories','Standing Calf Raise',            null, 3, 10, 15, null, null, false, 90,  true,  2),
  ('Day 3 · Lower — knee dominant','Accessories','Pallof press',                   null, 2, 8, 12, null, null, true,  40,  false, 3),
  ('Day 3 · Lower — knee dominant','Accessories','Dead bug',                       null, 2, 8, 10, null, null, true,  null, false, 4),

  -- ── Day 4 · Upper — pull bias ──
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Easy cardio raise',              null, 1, 1, 1,  null, null, false, null, false, 0),
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Thoracic ext + open-book',       null, 1, 1, 2,  null, null, false, null, false, 1),
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Wall slide (protract)',          null, 2, 10, 10, null, null, false, null, false, 2),
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Prone Y raise',                  null, 2, 12, 15, null, null, false, null, false, 3),
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Cable external rotation',        null, 2, 12, 15, null, null, false, 12,   true,  4),
  ('Day 4 · Upper — pull bias','Warm-up · circuit','Scap pull-up / band lat primer', null, 1, 8, 10, null, null, false, null, false, 5),
  ('Day 4 · Upper — pull bias','Primary','Neutral-grip pull-up',                     null, 3, 5, 8,  1, 2, false, null, false, 0),
  ('Day 4 · Upper — pull bias','Superset','Incline DB press',                        'D1', 3, 8, 12, 1, 2, false, 50, false, 0),
  ('Day 4 · Upper — pull bias','Superset','Batwing row',                             'D2', 3, 10, 12, 1, 2, false, 40, false, 1),
  ('Day 4 · Upper — pull bias','Accessories','Cable Chest Fly (managed range)',      null, 3, 10, 15, null, null, false, 20, true,  0),
  ('Day 4 · Upper — pull bias','Accessories','Reverse Pec Deck (rear delt)',         null, 2, 12, 15, null, null, false, 50, true,  1),
  ('Day 4 · Upper — pull bias','Accessories','Scaption (full-can)',                  null, 2, 12, 15, null, null, false, 8,  false, 2)
) as v(template_name, block_label, exercise_name, pair_label,
       target_sets, reps_low, reps_high, rir_low, rir_high,
       per_side, seed_weight, seed_is_estimate, ex_sort)
join public.mesocycles m
  on m.name = 'Block 3 — Upper/Lower'
 and m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
join public.workout_templates wt
  on wt.mesocycle_id = m.id and wt.name = v.template_name
join public.template_blocks tb
  on tb.template_id = wt.id and tb.label = v.block_label
join public.exercises ex
  on ex.name = v.exercise_name          -- EXACT, case-sensitive
where not exists (
  select 1 from public.template_exercises te
  where te.block_id = tb.id and te.exercise_id = ex.id
);
