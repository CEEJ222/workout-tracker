@AGENTS.md

# Schema rationale — read before changing the data model

These notes exist because the constraints encode *what* is enforced but not *why*.
Each item below records a decision that looks redundant or removable until you know
the incident behind it. Append this to `CLAUDE.md`.
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
---
## Exercise names are exact and case-sensitive

Lowercase-style names belong to CJ; Title Case names belong to Betsy. Some pairs differ
*only* by case and punctuation — `Single-arm DB row` (CJ) vs `Single-Arm Dumbbell Row`
(Betsy).

Always `where e.name = 'Exact Name'`. Never `ilike` with partial matching — it silently
grabs the other user's row and writes cross-contaminated data.
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
