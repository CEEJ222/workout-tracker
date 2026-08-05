-- add_mesocycle_archived_at
--
-- Adds a nullable soft-archive timestamp to mesocycles. The column ships NULL for
-- every existing row, so behaviour is unchanged until the app filters on it.
-- Nothing is archived here.
--
-- No index added: partial indexes are not used anywhere in this schema, and
-- mesocycles currently carries only its primary key (there is no user_id index).
-- A partial index on (user_id) WHERE archived_at IS NULL would not match the
-- existing indexing style, so it is intentionally skipped per instruction.

alter table public.mesocycles
  add column archived_at timestamptz null;
