#!/usr/bin/env bash
# Run the dice lab for both noise presets, score each one, and keep the reports.
#
#   sim/run.sh                                   1 week, 48 designs, 2 targets (the default)
#   sim/run.sh --days 28 --designs-per-week 768 --targets 4
#
# Extra arguments go to simulate.py. Needs Python 3 and the same PostgreSQL
# setup as ../run.sh (PG_BIN, PGHOST, PGPORT, PGUSER). The database is INV_DB,
# default inv_sim_agent, and is rebuilt for each preset.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p results
for preset in normal bad_week; do
  python3 simulate.py --preset "$preset" "$@"
  python3 score.py "out/$preset"
  cp "out/$preset/report.md" "results/$preset.md"
done
