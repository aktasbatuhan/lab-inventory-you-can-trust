#!/usr/bin/env bash
# Build a fresh database and run every scenario test.
#
#   ./run.sh            build and test
#   ./run.sh demo       build, load the demo lab and open psql
#   ./run.sh examples   build the demo lab and save every query's answer to queries/examples/
#
# Needs PostgreSQL 14+ client and server tools on PATH (or set PG_BIN), and a
# server reachable through the usual PG* environment variables.
set -euo pipefail
cd "$(dirname "$0")"

PSQL="${PG_BIN:+$PG_BIN/}psql"
DB="${INV_DB:-inventory_test}"

"$PSQL" -q -d postgres -c "drop database if exists $DB" -c "create database $DB" >/dev/null
load() { "$PSQL" -q -v ON_ERROR_STOP=1 -d "$DB" -f "$1" >/dev/null; }

for f in schema/*.sql; do load "$f"; done
load seed/01_reference_data.sql
load tests/_helpers.sql

if [[ "${1:-}" == "demo" ]]; then
  load seed/02_demo_lab.sql
  exec "$PSQL" -d "$DB"
fi

if [[ "${1:-}" == "examples" ]]; then
  load seed/02_demo_lab.sql
  for q in queries/q*.sql; do
    "$PSQL" -v ON_ERROR_STOP=1 -d "$DB" -f "$q" > "queries/examples/$(basename "$q" .sql).txt" 2>&1
    echo "wrote queries/examples/$(basename "$q" .sql).txt"
  done
  exit 0
fi

pass=0; fail=0
for f in tests/[0-9]*.sql; do
  if out=$("$PSQL" -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f" 2>&1); then
    echo "pass  $(basename "$f")"; pass=$((pass + 1))
  else
    echo "FAIL  $(basename "$f")"; echo "$out" | grep -E 'ERROR|DETAIL|CONTEXT' | head -5 | sed 's/^/      /'
    fail=$((fail + 1))
  fi
done
echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
