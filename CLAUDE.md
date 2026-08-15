@AGENTS.md

# Schema rationale — read before changing the data model

These notes exist because the constraints encode *what* is enforced but not *why*.
Each item below records a decision that looks redundant or removable until you know
the incident behind it.

---
## Never repoint `template_exercises.exercise_id` on a row with history

**The rule:** to change an exercise in a block, set `retired_at` on the existing row
and insert a new one. Do *not* update `exercise_id` in place.

**Why it matters more than it looks.** `session_exercises` references
`template_exercise_id`, not `exercise_id`. A session's exercise identity is resolved
at read time by walking `session_exercises → template_exercises → exercises`.
`src/lib/history.ts` does exactly this and keys its series map on `exercises.id`.
So repointing a template row does **not** merely relabel past sessions. It *merges*
them into the new exercise's chart series, and the original exercise's series
disappears entirely if nothing else points at it. History silently changes meaning.

**This already happened.** On 2026-08-05, four rows in CJ's archived
`Block 1 — Foundation` were repointed while building Block 3. Result: five months of
trap-bar deadlifts, B-stance hip thrusts, suitcase carries, and Nordic curls were
absorbed into Barbell Hip Thrust, 45-Degree Back Extension, Cable Chest Fly, and
Seated Leg Curl. It surfaced as a nonsensical weight chart — a line dropping from
115 lb to 10 lb — not as an error. Repaired in `20260815043113`.

**Why the schema pushed toward the mistake.** `session_exercises_template_exercise_id_fkey`
is `ON DELETE NO ACTION`, so a template row with history *cannot* be deleted. With no
delete and no retire flag, `UPDATE exercise_id` was the only way to get an exercise out
of a block. The schema funnelled toward the destructive path.

---
## Why `template_exercises.retired_at` exists

It is the missing third option: remove an exercise from future sessions without
destroying or rewriting its history.

`start_session` filters on `retired_at is null`, so a retired row stops appearing in
new sessions immediately. Its past `session_exercises` keep pointing at it, so history
stays intact and correctly labeled.

**Do not remove this column** because "nothing sets it." Being null everywhere is the
healthy state. It exists so that the correct workflow is available at the moment
someone needs it.

Added in `20260815043900`.

---
## Why the `template_exercises_forbid_repoint` trigger exists

`forbid_repoint_with_history()` raises an exception on any `UPDATE` that changes
`exercise_id` on a row with logged sessions.

**Why a trigger and not just a convention.** RLS on `template_exercises` is SELECT-only,
so the app can't do this anyway — and the app has no such code path. The corruption came
in via **service role / MCP**, i.e. migration authoring. The trigger guards the only
route the bug ever actually took: a human or model writing SQL directly.

**Escape hatch**, for deliberate history repair:

```sql
begin;
  set local app.allow_exercise_repoint = 'on';
  -- repoint here
commit;
```

`set local` is transaction-scoped and cannot leak. A GUC was chosen over
`session_replication_role = replica` because the latter would also disable FK
enforcement — far too much collateral for a targeted override.

**Replay-safe.** The two historical repoint migrations (`20260805023156`,
`20260805054000`) will not fail on a fresh replay: sessions are user data and don't
exist in migrations, so those rows have no history at replay time and the trigger
never fires.

---
## Planned: `session_exercises.exercise_id` (not yet implemented)

**The real fix**, still outstanding. Snapshot the exercise onto `session_exercises` at
session creation, the same way `session_sets` already snapshots `target_reps_low` /
`target_reps_high`.

The schema *already* accepts the principle that a session is a historical record which
must capture what it needs rather than join live to mutable config — it just applied
that principle to rep targets and not to exercise identity. This is a half-finished
pattern, not a missing convention.

Requires frontend work: `start_session` populates it, `history.ts` and
`session-detail.ts` read it instead of joining through `template_exercises`.

**When it lands, it will look redundant.** It is not. It is what makes history
structurally independent of template mutation. The trigger prevents the bad write;
this makes the bad write harmless.

---
## Weights are logged as TOTAL weight moved

Sum every implement in the athlete's hands.

| Setup | Logged |
|---|---|
| Two DBs, both arms | 2 × 50 = **100** |
| One DB, one arm | **50** |
| One DB, two hands (goblet) | **50** |
| Two DBs, one leg works (Bulgarian split squat) | 2 × 25 = **50** |

`per_side` governs **reps, not weight**. A Bulgarian split squat is `per_side = true`
(reps each leg) *and* logs the full load carried.

**Why this is written down.** The convention was previously unrecorded, and it drifted:
on 2026-07-10 CJ silently switched from total to per-dumbbell on Incline DB press and
Scaption, and it went unnoticed for a month. Two exercises held the same real load
(50s per hand) recorded as `100` and `50` on adjacent days. Normalized in
`20260815033419`; the convention is now stated in every DB exercise's `description`
and first `cues` entry so it surfaces in the log UI.

**Pre-cutover history is mixed-convention** and must not be compared across the
boundary — CJ before 2026-07-10, Betsy before Block C.

---
## `increment_lb` is a snapshot, not a rule

Rack steps are 2.5 lb up to 20 lb per hand, then 5 lb. Under a total-weight convention
that makes the valid step a *function of current weight and implement count*:

| | at/below threshold | above |
|---|---|---|
| One DB (total = the DB) | 2.5 up to 20 lb | 5 |
| Two DBs (total = 2×) | 5 up to 40 lb total | 10 |

A single numeric column cannot express a step function. Every value is currently correct
for where that lift sits, and becomes **silently wrong** when a lift crosses its
threshold. Nearest to breaking: Scaption at 20 lb total, wrong once it passes 40.

Durable fix would be `exercises.db_count smallint null` (1, 2, or null for non-DB) with
the step computed in the auto-load resolver. Not yet done.

Auto-load has already walked weights to values that don't exist on any rack (52.5, 82.5,
12.5); those were snapped in `20260815033419`.

**A second reason it is inadequate: it is global.** `increment_lb` lives on the
`exercises` row, and that row is shared wherever two users reach the same exercise — see
*Exercise names are exact and case-sensitive*. So it physically cannot hold different rack
steps for two athletes on the same lift. CJ and Betsy both work off 5 lb racks, so every
shared row currently carries one value that is right for both: this is latent, not broken.
But it means the durable fix is probably not `exercises.db_count` alone — `increment_lb`
likely has to move to `template_exercises`, which is user-scoped through its template. Same
argument as the pending `rest_seconds` move.

---
## Exercise names are exact and case-sensitive

**Case is a naming habit, not an ownership boundary.** CJ's templates tend to use
lowercase-style names and Betsy's Title Case, but that is a tendency in how each set of
templates was authored. It does not partition the table. **Do not infer ownership from
case.**

`exercises` is a **shared** table with no owner column. Twelve exercise names appear in
both users' templates, and eleven of those are the *same* `exercise_id` — one row reached
by two users, not a duplicate pair:

45-Degree Back Extension, Barbell Hip Thrust, Seated Leg Curl, Standing Calf Raise,
Cable Triceps Pushdown (rope), Reverse Pec Deck (rear delt), Cable Curl (straight or EZ
bar), Banded X-Walks / Lateral Band Walks, Dynamic leg swings, Easy cardio raise, Wall
slide (protract).

Only `Dead bug` (CJ) / `Dead Bug` (Betsy) are genuinely two separate rows.

**Exact matching is still required.** Always `where e.name = 'Exact Name'`. Never `ilike`
with partial matching. Distinct exercises can be separated by nothing more than case —
`Dead bug` and `Dead Bug` above — or by case plus wording, like `Single-arm DB row` (CJ)
and `Single-Arm Dumbbell Row` (Betsy), which are also two different rows. A loose match
silently grabs the wrong row and writes cross-contaminated data. That hazard is real and
unchanged.

**Isolation is enforced by `mesocycles.user_id` via RLS**, not by anything on `exercises`.
A user reaches an exercise only through their own mesocycle → template → block →
template-exercise chain.

**Per-user state is safe.** `user_exercise_progress` is keyed `(user_id, exercise_id)`, so
a shared exercise still tracks separate loads per user. CJ's Barbell Hip Thrust sits at
125 and Betsy's at 185 on the same `exercise_id`.

**Per-exercise CONFIG is shared wherever the id is shared.** `rest_seconds`,
`increment_lb`, `cues`, `auto_load`, and the taxonomy columns (`primary_muscle`,
`movement_pattern`, `is_unilateral`, `log_type`) all live on `exercises`. Changing any of
them affects **both** users. This is the reason `rest_seconds` is moving to
`template_exercises`, which is user-scoped via its template.

**And the shared set is not just warm-ups** — which is what makes shared config genuinely
dangerous rather than cosmetic. Six of the eleven shared rows are loaded working lifts
carrying live auto-load config right now: 45-Degree Back Extension, Barbell Hip Thrust,
Cable Curl (straight or EZ bar), Cable Triceps Pushdown (rope), and Seated Leg Curl at
`increment_lb` 5, plus Standing Calf Raise at 10 — which is also the only shared row with
a non-null `rest_seconds` (45). Changing `rest_seconds` or `increment_lb` on any of those
changes it for **both athletes, mid-block**. The other five shared rows (Banded X-Walks,
Dynamic leg swings, Easy cardio raise, Reverse Pec Deck (rear delt), Wall slide) carry no
auto-load config, so those are the harmless case.

---
## Read before write

The live database has drifted ahead of local migration files repeatedly. Before writing
SQL against any column not explicitly confirmed in the current session, inspect
`information_schema.columns`. Assumptions about schema shape have caused repeated
misreads.

Migrations applied via MCP `apply_migration` self-stamp their own remote version
timestamp, which differs from any local filename. This is harmless for this project
(it does not use `supabase db push`) but means version-based reconciliation will report
drift.

---
## Detecting repoint damage

Logged sets whose recorded rep target disagrees with their template row's current
target — a signal the template was edited or repointed after those sessions:

```sql
select m.name as block, t.name as day, e.name as now_labeled_as,
       te.target_reps_low || '-' || te.target_reps_high as template_says,
       ss.target_reps_low || '-' || ss.target_reps_high as sets_recorded,
       count(*) as n_sets
from session_sets ss
join session_exercises se on se.id = ss.session_exercise_id
join template_exercises te on te.id = se.template_exercise_id
join template_blocks tb on tb.id = te.block_id
join workout_templates t on t.id = tb.template_id
join mesocycles m on m.id = t.mesocycle_id
join exercises e on e.id = te.exercise_id
where (ss.target_reps_low, ss.target_reps_high)
      is distinct from (te.target_reps_low, te.target_reps_high)
group by 1, 2, 3, 4, 5;
```

**This is a screening tool, not a verdict.** It flags any divergence, so a plain
rep-target edit looks identical to a repoint. Confirm each hit against session notes and
against the surviving `user_exercise_progress` row for the suspected original exercise —
progress rows are written at log time and survive later repointing, which is what made
three of the four 2026-08-05 identifications provable rather than guessed.

---

## Rest is resolved per-slot, not per-exercise

**The rule:** read a rest value as `coalesce(template_exercises.rest_seconds,
exercises.rest_seconds)`. Never read `exercises.rest_seconds` alone, and set the per-slot
column — not the global one — whenever a value is specific to one role or one athlete.

**The mechanism.** Both columns are live: `exercises.rest_seconds integer null` is the
per-exercise default, `template_exercises.rest_seconds smallint null` is the per-slot
override. Resolution happens in application code, not in a view or a function.
`src/lib/session-detail.ts` selects `rest_seconds` from both tables and collapses them where
it builds each `ExerciseCard`. It resolves against the snapshotted identity from
`session_exercises`, falling back to the template join, so rest resolves against the exercise
the session actually recorded. The single resolved number then feeds two consumers that
behave differently: `formatRest` in `src/lib/rest.ts` renders the label, and `startRestTimer`
in `src/app/session/[id]/session-view.tsx` runs the countdown, returning early when the
resolved value is null. Both column comments state this rule; read them before touching
either.

**Null on the two sides means different things, and only one is healthy.** Null on
`template_exercises.rest_seconds` means "inherit the exercise default" — the normal state for
the **12 of 84** active slots that legitimately want the global value. Null on *both* is a
gap, not a valid state for any slot: `formatRest` returns null, no rest line renders, and
`startRestTimer` never fires. Every exercise gets a timer, warm-ups included; there is no
slot type for which "no rest guidance" is the intended design. All 84 slots across both
athletes' active blocks currently resolve to a value — **zero nulls**. Treat any null-on-both
as a bug to fill.

**Do not drop `exercises.rest_seconds`.** It is not vestigial; it is still authoritative as
the fallback and supplies the resolved value for those 12 slots. Dropping it would force an
override row on every slot, including the many that want the same number everywhere. The
global column expresses "this movement usually rests this long"; the per-slot column
expresses "in this slot it does not."

**Why it matters more than it looks.** `exercises` rows are shared between athletes — eleven
exercise ids appear in both CJ's and Betsy's templates, listed under *Exercise names are exact
and case-sensitive*. Editing `exercises.rest_seconds` silently moves *both* athletes' timers.
`template_exercises` is user-scoped through `template_blocks` → `workout_templates` →
`mesocycles.user_id`, so an override reaches exactly one person. Per-slot and per-user are the
same change.

**What breaks if it's violated.** Nothing errors — the timer silently runs the wrong duration.
Worse, the label and countdown can disagree: `formatRest` returns the
`Alternate A1/A2 · ~60–90s` string for any superset member and ignores the number entirely,
while `startRestTimer` uses the number. `B-stance / single-leg RDL (heavier)` displayed
`~60–90s` while counting down **150s**, because its `exercises.rest_seconds` carried the
primary-lift value and it sits in a superset. It now carries a slot override of 75 against a
global default of 150.

**This already happened, and the athlete found it before the schema did.** No data was
corrupted and there is no repair migration. It surfaced through session notes between
2026-08-07 and 2026-08-15: "Needs timer" (`Barbell Hip Thrust`, null), "No timer after"
(`Seated Leg Curl`, null), "Add timer to this one" (`45-Degree Back Extension`, null), "Timer
is very long" (`B-stance / single-leg RDL (heavier)`, 150 in a superset). On 2026-08-12 CJ
wrote the diagnosis directly: *"Alternative is to attach the timer to the set type instead of
the exercise."*

**Status: APPLIED REMOTELY**, across six migrations. `20260815060336`
(`add_template_exercises_rest_seconds`) added the column and set the first 15 overrides;
`20260815064057` (`seed_betsy_block_c_rest_seconds`) covered Betsy's slots; `20260815064305`
(`fill_remaining_null_rest_seconds`) closed the last 38; `20260815064442` and `20260815064450`
replaced both column comments; `20260815064923` (`fix_cj_primary_slot_rest_overrides`)
corrected two Primary slots. **72 of 84** active slots now carry an explicit override.

| resolved | slots | where |
|---|---|---|
| `30` | 37 | warm-up circuit — every `template_blocks.type = 'circuit'` row |
| `45` | 23 | isolation / core / pump |
| `75` | 9 | 6 superset members + 3 `single` slots (all Betsy's) |
| `90` | 8 | secondary compound |
| `150` | 7 | primary heavy compound — all four of CJ's `Primary` slots, plus Betsy's Day 1, 3 and 4 first slots |

Betsy's Day 2 first slot is `Lat Pulldown (shoulder-width)` at 90, and that is correct: a
pulldown is not a heavy compound, and her blocks carry no role labels, so "first slot" is not
the same as "primary tier."

**Auditing rest requires two checks, not one.** Completeness and correctness are different
properties, and checking only the first is how wrong values survive.

1. Does every slot resolve to a value?
2. Does each resolved value match the slot's *role*?

Check 1 passing means no timer is missing. It says nothing about whether the timer is right.
A slot inheriting a global default is indistinguishable from one carrying a deliberate
override unless you look at **which column supplied the number**. After
`fill_remaining_null_rest_seconds` closed the last 38 nulls, two of CJ's four `Primary` slots
still resolved to 75 by inheriting a superset-tier `exercises.rest_seconds` default — the DB
bench slot being the exact one that prompted CJ's 2026-08-12 note. Filling nulls made the
defect invisible rather than fixing it: no longer missing, just wrong.

The audit query must surface which column supplied the value — select `te.rest_seconds` and
`e.rest_seconds` separately alongside the `coalesce`, plus `target_rir_low` and `auto_load`.
A working slot (`target_rir_low = 1`, `auto_load = true`) resolving through the exercise
default rather than a slot override is the pattern to inspect: nobody decided that number for
that slot. Like the repoint detector above, this flags candidates, not verdicts — CJ's Day 3
`Primary` (`Rear-foot-elevated split squat`) inherits its 150 from the global row and is
correct as it stands.

**The two Primary overrides are load-bearing.** `Neutral-grip DB bench / low incline` (Day 2)
and `Neutral-grip pull-up` (Day 4) each carry an explicit `template_exercises.rest_seconds =
150` even though 150 is already the primary tier. Their `exercises.rest_seconds` is still
`75`, so deleting the override drops both back to 75 and silently restores the original
defect. `20260815064923` fixed them per-slot rather than by editing the shared global row —
which is the pattern this entry prescribes.

---

## `session_exercises` is write-restricted

**The rule:** never `UPDATE session_exercises.exercise_id`. The app may write only `done`,
`pain_severity`, and `note` on this table.

**The mechanism is grants and a trigger — not the RLS policy.** Three layers stack, and only
one is RLS. The row policy is `FOR ALL` and **unchanged**; it decides *which rows* — the
session must belong to `auth.uid()`. Column-level `GRANT` decides *which columns*:
`authenticated` and `anon` hold `UPDATE` on exactly `done, note, pain_severity`, while
`SELECT` and `INSERT` still cover all seven columns. Above both, the trigger
`session_exercises_forbid_repoint` (`BEFORE UPDATE ... FOR EACH ROW`) calls
`forbid_session_exercise_repoint()`, which raises whenever `new.exercise_id is distinct from
old.exercise_id`.

**Why both.** Column grants do not restrain `service_role` or `postgres`, and this file
already records that the original contamination arrived via **service role / MCP**, i.e.
migration authoring — a human or model writing SQL directly. That is the one route grants
cannot reach, so the trigger covers it. The grant covers the client cheaply, with no per-row
cost.

**What a violation produces — it errors, it does not corrupt.** A client `UPDATE` touching a
non-granted column fails with a permission-denied error, surfaced by PostgREST as a 403; the
write does not partially apply. A repoint from any role, `service_role` included, aborts the
statement with `forbid_session_exercise_repoint()`'s message, which names the row id and
states that changing it would relabel the session and merge it into another exercise's chart
series.

**Escape hatch**, for deliberate history repair — identical in shape to
`template_exercises_forbid_repoint`, and sharing the same GUC so one override covers a repair
that must touch both tables:

```sql
begin;
  set local app.allow_exercise_repoint = 'on';
  -- repoint here
commit;
```

`set local` is transaction-scoped and cannot leak.

**Why this column is worth guarding.** `session_exercises.exercise_id` is the snapshotted
identity that `src/lib/history.ts` reads in both `getWeightHistory` — keying its series map on
`exercise.id` — and `getPainTimeline`, and that `complete_session` joins on to resolve the
progression write-back target. Rewriting one row silently moves a session's sets into a
different chart series, and can move a `user_exercise_progress.current_weight` onto the wrong
lift, which then becomes next session's suggested weight. Nothing errors; the numbers change
meaning.

**This is preventive — there was no `session_exercises` incident.** Do not read the 2026-08-05
event into this entry. That corruption came through `template_exercises.exercise_id` and was
repaired in `20260815043113`. This guard closes the *symmetric* hole that opened the moment
`session_exercises.exercise_id` became history-bearing: the same damage, reached from the
other side.

**Status: APPLIED REMOTELY as `20260815060545`** (`restrict_session_exercises_updates`).

**Still outstanding, and deliberately so.** `INSERT` still grants `exercise_id`, and the
trigger is `BEFORE UPDATE` only — it does not guard `INSERT`. In practice `start_session()` is
the only insert path and the RLS `WITH CHECK` still requires the session to belong to the
caller, so a fabricated row cannot be attached to someone else's session; but a client could
in principle insert into its own session with an arbitrary `exercise_id`. Note also the
fail-closed consequence: **any column added to this table in future is not updatable by the
client until explicitly granted** — the right default for a table that stores history, but it
will look like a bug to whoever adds the next column.

**Supersedes `## Planned: session_exercises.exercise_id (not yet implemented)`.** That
section's heading is now false — the snapshot landed in `20260815052833`, `20260815052849` and
`20260815060144`, and `session_exercises` currently holds 357 rows with 0 null `exercise_id`.
Its body is still worth reading, particularly the closing note that the column would look
redundant once it landed. The retitle is deferred to keep this change append-only; do it in a
follow-up, not here.

---

## `log_type` is per-exercise but role-dependent

**The rule:** before changing `exercises.log_type`, check every slot that exercise occupies —
the column is global, and the same movement can be a loaded accessory in one slot and an
unloaded primer in another.

**This is the same shape of problem as `rest_seconds`.** `exercises.log_type` is `not null` on
the global row; there is **no** `log_type` column on `template_exercises` or on
`session_exercises`. Three exercises currently occupy both circuit and working slots:

| exercise | circuit slots | working slots | current `log_type` |
|---|---|---|---|
| `Banded X-Walks / Lateral Band Walks` | 8 | 1 | `done_check` |
| `Band/Cable Pull-Apart` | 4 | 1 | `done_check_weight` |
| `Prone Bench Y-T-W Raises` | 1 | 1 | `done_check_weight` |

**Two things currently keep it latent, and neither is a fix.** First, all three working slots
sit in Betsy's archived `Block B — Weeks 8-14`; no working slot for any of the three is in an
active block. Second, `done_check_weight` degrades gracefully in both contexts where
`sets_weight` does not: `ExerciseCardView` treats anything other than `done_check` as weighted
and renders full per-set reps and weight inputs, while `CircuitRow` renders a compact weight
box for `done_check_weight` specifically. `done_check_weight` is the only value that renders
sensibly on both sides of the block-type divide, which is why it was the correct fix rather
than a workaround. Neither fact survives a future block that reuses one of these as a working
accessory.

**What breaks if it's violated.** No error — the input simply does not render, so the load is
silently uncapturable and the set records `actual_weight = null` forever. Nothing warns, and
no history view distinguishes "never loaded" from "load not recordable".

**This already happened, and produced no bad data only by luck.** On 2026-08-15, `Prone Bench
Y-T-W Raises` and `Band/Cable Pull-Apart` were found in Block C warm-up circuits with
`log_type = 'sets_weight'`, which `CircuitRow` renders no weight input for at all. They were
not typos: in Block B both were working accessories in a `single` block with real seed weights,
where `sets_weight` was correct — and because `log_type` lives on `exercises`, that setting
followed them into the warm-up when Block C reused the same rows. No load was lost, because none
was ever captured: `Prone Bench Y-T-W Raises` has no logged sets at all, and `Band/Cable
Pull-Apart` has 8 set rows carrying zero recorded weights and zero recorded reps — which is
the silent failure this entry describes, not evidence that it did not happen. There is no
repair migration.

**Status: the immediate fix is APPLIED REMOTELY as `20260815060522`**
(`fix_circuit_log_type_for_warmup_raises`), which set both to `done_check_weight`, matching
`Cable external rotation` — the other loaded warm-up, also `target_sets = 2` in a circuit. No
circuit row anywhere remains on `sets_weight`. Teaching `CircuitRow` to render `sets_weight`
was rejected: it renders the first set only, by design, so a 2-set row would have shown one
input and silently discarded set 2 — a fix that looks like a fix and loses data.

**The durable fix is PLANNED and not applied.** A nullable `template_exercises.log_type`
override, resolved as `coalesce(te.log_type, e.log_type)`, exactly mirroring the `rest_seconds`
pattern in `20260815060336`. Until it lands, `exercises.log_type` carries the same
cross-athlete coupling as `rest_seconds` did: it is a shared-row column, so changing it for one
athlete's slot changes it for the other's.
