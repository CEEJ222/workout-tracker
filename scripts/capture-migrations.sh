#!/usr/bin/env bash
#
# Capture applied migrations from the remote database into supabase/migrations/.
#
# Why this exists: migrations are applied remotely (MCP / dashboard), and
# apply_migration self-stamps its own version timestamp. Without a direct
# database connection the only way to recover the SQL is to read it back
# through an API and retype it — slow and error-prone. This does it in one
# command and checksums the result.
#
# Setup (once):
#   brew install libpq && brew link --force libpq
#   Supabase dashboard -> Connect (top bar) -> Session pooler -> URI
#   Add to .env.local:  SUPABASE_DB_URL=postgresql://...
#
# Usage:
#   ./scripts/capture-migrations.sh           # capture anything missing locally
#   ./scripts/capture-migrations.sh --check   # report drift, write nothing
#   ./scripts/capture-migrations.sh 20260815060144 [...]   # re-capture specific versions
#
# NOTE: this never runs `supabase db push` or `db reset`. It only reads.

set -euo pipefail

cd "$(dirname "$0")/.."
MIGRATIONS_DIR="supabase/migrations"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

command -v psql >/dev/null || {
  echo "psql not found. Run: brew install libpq && brew link --force libpq" >&2
  exit 1
}

[ -f .env.local ] || { echo ".env.local not found" >&2; exit 1; }
DB_URL="$(grep -m1 '^SUPABASE_DB_URL=' .env.local | cut -d= -f2- || true)"
[ -n "$DB_URL" ] || {
  echo "SUPABASE_DB_URL is unset in .env.local (see setup notes in this script)" >&2
  exit 1
}

CHECK_ONLY=false
[ "${1:-}" = "--check" ] && { CHECK_ONLY=true; shift; }

q() { psql "$DB_URL" -At -v ON_ERROR_STOP=1 -c "$1"; }

# `statements[1]` holds the full migration body. psql -At appends one newline
# per row, so strip exactly one to get the stored bytes back verbatim.
capture() {
  local version="$1" name md5_remote dest
  name="$(q "select name from supabase_migrations.schema_migrations where version='$version'")"
  [ -n "$name" ] || { echo "  $version: not found remotely" >&2; return 1; }

  md5_remote="$(q "select md5(statements[1]) from supabase_migrations.schema_migrations where version='$version'")"
  dest="$MIGRATIONS_DIR/${version}_${name}.sql"

  q "select statements[1] from supabase_migrations.schema_migrations where version='$version'" \
    | perl -0pe 's/\n\z//' > "$dest"

  local md5_local
  md5_local="$(md5 -q "$dest" 2>/dev/null || md5sum "$dest" | cut -d' ' -f1)"
  if [ "$md5_local" != "$md5_remote" ]; then
    echo "  ✗ $version  CHECKSUM MISMATCH (local $md5_local, remote $md5_remote)" >&2
    return 1
  fi
  echo "  ✓ $version  $name  ($(wc -c < "$dest" | tr -d ' ') bytes)"
}

if [ $# -gt 0 ]; then
  echo "Re-capturing ${#} specified migration(s):"
  for v in "$@"; do capture "$v"; done
  exit 0
fi

# Pair remote rows to local files by NAME, not by version.
#
# apply_migration self-stamps its own timestamp, so a migration authored locally
# as 20260805050000_add_mesocycle_archived_at.sql is stored remotely as
# 20260805202441 with the same name. Matching on version alone would classify
# those as "missing" and write a second copy of a migration that is already
# captured — duplicating it in the replay order. Name is the stable identity.
missing=""
drift=""
while IFS='|' read -r version name; do
  [ -n "$version" ] || continue
  if [ -f "$MIGRATIONS_DIR/${version}_${name}.sql" ]; then
    continue                                   # captured, stamps agree
  fi
  local_twin="$(ls -1 "$MIGRATIONS_DIR" 2>/dev/null | grep -E "^[0-9]{14}_${name}\.sql$" || true)"
  if [ -n "$local_twin" ]; then
    drift="${drift}${local_twin%%_*} -> ${version}  ${name}"$'\n'
  else
    missing="${missing}${version}"$'\n'
  fi
done < <(q "select version || '|' || name from supabase_migrations.schema_migrations order by version")

missing="$(printf '%s' "$missing" | sed '/^$/d')"
drift="$(printf '%s' "$drift" | sed '/^$/d')"

if [ -n "$drift" ]; then
  echo "Stamp drift — captured, but the local filename carries a different timestamp"
  echo "than the remote version. Same migration; fixing it is a rename decision, not"
  echo "a re-capture. Nothing is rewritten here."
  printf '%s\n' "$drift" | sed 's/^/  /'
  echo
fi

if [ -z "$missing" ]; then
  echo "Up to date: every remote migration has a local file."
  exit 0
fi

if $CHECK_ONLY; then
  echo "Missing locally:"
  printf '%s\n' "$missing" | sed 's/^/  /'
  exit 1
fi

echo "Capturing $(printf '%s\n' "$missing" | wc -l | tr -d ' ') missing migration(s):"
for v in $missing; do capture "$v"; done
