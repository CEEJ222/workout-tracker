-- Archive Betsy's Blocks A and B now that Block C is active and confirmed rendering.
-- Same shape as CJ's 2026-08-05 archive (archive_legacy_blocks_and_activate_upper_lower):
-- one shared timestamp, sort_order left untouched, all session history preserved.
-- Block C is already active in user_settings, so no repoint is needed here.

update public.mesocycles
set archived_at = now()
where user_id = '062fd8bd-96e5-40b0-812c-2886c06fd284'
  and name in ('Block A — Weeks 1-7', 'Block B — Weeks 8-14')
  and archived_at is null;
