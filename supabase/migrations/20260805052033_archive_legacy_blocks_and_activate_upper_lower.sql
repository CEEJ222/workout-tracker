-- archive_legacy_blocks_and_activate_upper_lower
--
-- !!! ORDERING PREREQUISITE !!!
-- Run this ONLY AFTER the app filter is deployed. As of writing, two things this
-- migration depends on do not yet exist in the database and must be in place first
-- (both expected from the app-filter deploy):
--   * column  public.mesocycles.archived_at   (referenced by steps 0/1/2)
--   * mesocycle 'Block 3 — Upper/Lower' for this user (step 3 aborts without it)
-- If applied before those exist, step 0 (or the archived_at references) will error
-- and the whole migration rolls back — which is the intended safety behavior.
--
-- Scope: user 98251473-2fc9-4254-a4f9-6dc86135c1b2 only. Betsy's rows
-- (user 062fd8bd-96e5-40b0-812c-2886c06fd284) are never referenced. Nothing is
-- deleted; legacy blocks are soft-archived via archived_at. Mesocycles are
-- matched by NAME — no hardcoded UUIDs. No session data is touched.

-- 0) Abort unless an ACTIVE 'Block 3 — Upper/Lower' exists for this user.
--    Covers both required abort conditions (missing OR archived) in one check.
--    Migrations run in a transaction, so RAISE rolls everything back.
do $$
begin
  if not exists (
    select 1
    from public.mesocycles
    where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
      and name = 'Block 3 — Upper/Lower'
      and archived_at is null
  ) then
    raise exception
      'Aborting: active "Block 3 — Upper/Lower" not found for user 98251473-2fc9-4254-a4f9-6dc86135c1b2 (missing or already archived)';
  end if;
end $$;

-- 1) Soft-archive the two legacy blocks. `and archived_at is null` keeps this
--    idempotent — a re-run will not overwrite the original archive timestamp.
update public.mesocycles
set archived_at = now()
where user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
  and name in ('Block 1 — Foundation', 'Block 2 — Variation')
  and archived_at is null;

-- 2) Point the user's active mesocycle at 'Block 3 — Upper/Lower' (by name).
--    The user_settings row exists (PK user_id); this is a plain update.
update public.user_settings us
set active_mesocycle_id = (
  select m.id
  from public.mesocycles m
  where m.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2'
    and m.name = 'Block 3 — Upper/Lower'
    and m.archived_at is null
)
where us.user_id = '98251473-2fc9-4254-a4f9-6dc86135c1b2';
