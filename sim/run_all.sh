#!/usr/bin/env bash
# Run every dice simulation the results folder reports on: one week and four
# weeks, each with the normal and the bad-week noise. Same environment as run.sh.
set -euo pipefail
cd "$(dirname "$0")"

./run.sh

for preset in normal bad_week; do
  python3 simulate.py --preset "$preset" --days 28 --designs-per-week 768 --targets 4
  python3 score.py "out/$preset"
  cp "out/$preset/report.md" "results/$preset-4weeks.md"
  rm -rf "out/$preset-4weeks"
  cp -R "out/$preset" "out/$preset-4weeks"
done
echo "all simulations scored; reports in sim/results/"
