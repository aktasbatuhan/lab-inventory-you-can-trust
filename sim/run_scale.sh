#!/usr/bin/env bash
# The dice lab at Adaptyv's real throughput: 8 weeks, 2,000 designs a week,
# 8 targets, three random seeds for each noise preset. Same environment as run.sh.
# Reports go to results/scale/; run summarise_scale.py afterwards for one table.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p results/scale

for preset in normal bad_week; do
  for seed in 1 2 3; do
    name="$preset-8weeks-seed$seed"
    python3 simulate.py --preset "$preset" --days 56 --designs-per-week 2000 --targets 8 --seed "$seed" --out "out/$name"
    python3 score.py "out/$name"
    cp "out/$name/report.md" "results/scale/$name.md"
    echo "scored $name"
  done
done
