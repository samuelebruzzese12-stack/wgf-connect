#!/usr/bin/env bash
# Applica shim + migrazioni + seed a un database PostgreSQL 16 pulito ed esegue i test di sicurezza.
# Uso: PGHOST=/tmp PGPORT=54329 PGUSER=postgres ./scripts/test_db.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="${TEST_DB:-wgf_test}"
psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
run() { psql -q -t -A -v ON_ERROR_STOP=1 -d "$DB" -f "$1"; }
run "$ROOT/backend/supabase/tests/00_supabase_shim.sql"
for f in "$ROOT"/backend/supabase/migrations/*.sql; do echo "→ migrazione $(basename "$f")"; run "$f"; done
run "$ROOT/backend/supabase/seed/seed_test_data.sql"
for f in "$ROOT"/backend/supabase/tests/[1-9]*.sql; do echo "→ test $(basename "$f")"; run "$f"; done
echo "TUTTI I TEST DATABASE SUPERATI"
