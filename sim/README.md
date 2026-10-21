# The simulated lab

A small program that runs a pretend version of Adaptyv's lab for a week or a
month and keeps two notebooks. Notebook A is what really happened: every tube,
plate and bottle, what is in it, where it sits, when it went in the bin.
Notebook B is what people, robots and imports wrote down, with the kinds of
mistakes real people make. The inventory database only ever sees notebook B.
Afterwards we ask the database what it thinks and compare its answers with
notebook A: how far off is it, and did its flags catch the mistakes?

## Running it

```
sim/run.sh                                                   # both presets, 1 week, 48 designs, 2 targets
sim/run.sh --days 28 --designs-per-week 768 --targets 4      # bigger: 4 weeks, 8 experiments
```

It needs Python 3 (standard library only) and the same PostgreSQL setup as the
top-level `run.sh`: `PG_BIN`, `PGHOST`, `PGPORT`, `PGUSER`. The database is
`INV_DB` (default `inv_sim_agent`) and is dropped and rebuilt for each preset.

For each preset it writes `sim/out/<preset>/`:

- `recorded.sql`: notebook B, the record API calls (`select receive(...)`,
  `select move(...)`), to load after `schema/*.sql` and `seed/01_reference_data.sql`.
  A small `sim` schema maps the simulation's names (C12, L40) to database ids
  so the scorer can line things up. The inventory itself never reads it.
- `truth.json`: notebook A at a few checkpoints (every second day on short runs,
  every week on long ones).
- `errors.jsonl`: every mistake that was rolled, with an id, who made it, what
  it touched, and whether someone corrected it later.
- `report.md` and `score.json`: the comparison.

`sim/out/` is not kept in git. The reports are copied to `sim/results/`.

The pieces can be run on their own:

```
python3 sim/simulate.py --preset bad_week --days 28 --designs-per-week 768 --targets 4 --seed 3
python3 sim/score.py sim/out/bad_week                # --no-load to reuse a loaded database, --last-only for big runs
```

## The files

- `world.py` is notebook A and nothing else. It holds containers, lots, places
  and the physics of the lab (pipettes and robots a few percent off, open plates
  losing water, liquid stuck below the dead volume). It has a plain API:
  `register`, `move`, `receive`, `transfer`, `take`, `split`, `make`,
  `reconstitute`, `discard`, `look`, `read_label`, `contents`,
  `condition_history`, `clock`/`advance`, `snapshot`. It knows nothing about
  recording or mistakes, so the AI-agent lab in `agents/` can drive the same
  world through its tools.
- `simulate.py` is the dice lab. Its people, robots and supplier act on the
  world, and separately write notebook B, rolling for mistakes as they go.
- `presets.py` holds the error rates for the two presets.
- `score.py` compares one World snapshot with the database. `compare(snapshot, db)`
  only needs the snapshot and the `sim.cmap`/`sim.lmap` tables, so the agent lab
  can reuse it unchanged.
- `params/*.json` are `noise-model.yaml` and `lab-profile.yaml` converted once by
  `convert_params.py` (which needs PyYAML; nothing else does).

## What it models

The binding workflow from the brief, scaled from `lab-profile.yaml`:

- **The supplier** delivers Twist DNA plates 5 to 10 days after ordering, target
  vials, water, buffer components, PURE expression kits and BLI sensors.
  Sometimes late, sometimes short-filled (the vial holds less than the packing
  slip says), and sometimes the same vial really arrives twice.
- **Lab operations** books deliveries in, QCs each target vial (5% fail, from
  the noise model), splits passed vials into four 45 µL aliquots in a fresh box
  at -80, makes loading buffer every Monday and running buffer and GFP stock when
  they run low, throws out expression plates after two weeks, orders when stock is
  low, and counts one place every Friday.
- **Production scientists** reconstitute the DNA plate well by well, run the
  Hamilton to build the expression plate (2 µL DNA plus 6 µL PURE mix per well,
  8 µL reactions, A7), then split-GFP, then one BLI run per 96 designs. Target
  plates are pipetted by hand from aliquots; partly used aliquots go back to the
  box and are used first next time. 10% of BLI runs are re-run a few days later.
- **Robots** run from worklists. The worklist goes in as planned transfers, and
  the robot log comes back as one transfer per step.
- **The rules actor** is the database's own defaults: `finish_run` records
  single-use plates as thrown away (D6) and fills in steps missing from a log (D10).
- **LabOS** writes one `make()` per well when expression finishes: DNA and mix
  become protein, a new lot per design.

Each action changes notebook A, and then the person or machine writes notebook B.
The mistakes they can make, all logged in `errors.jsonl`:

| Mistake | normal | bad_week | Where the number comes from |
|---|---|---|---|
| Move not scanned | 1% | 15% | noise model `step_not_recorded`, top of range ("moves are the most likely to be skipped"); bad: LOC agents |
| Use or transfer not recorded | 0.5% | 10% | noise model `step_not_recorded`; bad: RCV `forget_buffer_lot` |
| Wrong tube scanned | 0.05% | 0.5% | noise model `wrong_container_scanned`; bad: XFER `wrong_source_scan` |
| Wrong slot recorded | 0.3% | 2% | noise model `wrong_position_selected`; bad: LOC `slot_order_swap` |
| Typed number off (any / by more than 20%) | 3.7% / 0.5% | 5% / 1% | noise model `manual_value_mistyped`, `manual_value_badly_wrong` |
| Delivery booked twice | 0.2% | 3% | noise model; bad: RCV-011. Half are retries with the same delivery note, half a second person without it |
| Thrown away without a scan | 2% | 15% | noise model (assumption); bad: RCV `dispose_without_record` |
| Label printed with a barcode already in use | 0.1% | 0.5% | noise model `label_error` |
| Count marks a tube "not found" that is there | 0.2% | 3% | noise model rack no-read; bad: LOC `missed_item` |
| Entry typed up later than it happened | 5%, 1 to 8 h | 15%, 1 h to 3 days | our assumption; bad: RCV `delay_import` |
| Robot log line missing | 0.05% per step | 0.2% | our assumption; bad: XFER `skip_well` |
| Whole robot log uploaded late | 1% of runs | 5% | XFER `robot_log_import_fail`; bad: `import_plan_instead_of_log` |
| Supplier short fill / duplicate shipment / late | 1% / 0.5% / 10% | 5% / 2% / 30% | our assumptions |
| Single-use plate kept after the rule binned it | 1% | 5% | our assumption |
| Freezer failure | 0.1 per freezer per year | 0.75 | noise model; bad: LOC and LIFE agents |

`normal` follows decision D8: rates from `noise-model.yaml`, which come from
published human-reliability and clinical-lab figures. `bad_week` uses the
scenario agents' much higher guesses (see the noise_ref note in
`scenarios/clusters.md`) as the top of a sweep.

People also notice some of their own mistakes later and record a fix: half of
the badly mistyped numbers, 5% of the small ones, 30% of wrong-tube scans, 60%
of double bookings (RCV-011's "detected within a day"), 20% of forgotten uses.
These are our guesses, the same in both presets. Nobody in the sim reads
`flags()` and acts on it, so the report shows what the flags would let a person
find, not what they did find.

Physics in notebook A: hand pipetting 0.8% CV, robots 3% CV plus a bias of up to
±5% per robot per week (noise model), lidded plates on a deck lose 0.3 µL per
well per hour, edges twice that and corners four times (noise model,
`lidded_384_bench`). Dead volumes are the seed's.

## What it doesn't model

- Things nobody ever registers: a tube made on the bench and never labelled
  doesn't exist in either notebook's comparison.
- The procurement and data-review roles beyond "order when low" and "10% of BLI
  runs are re-run".
- SPR, thermostability and the other assays; only the binding workflow runs.
- Mistakes in imports (plate maps) other than a retried import, and mistakes in
  QC results.
- People reacting to flags. A real lab manager would fix many flagged items in
  the weekly review.
- Concentrations: amounts are µL (or µg for dry DNA before it is dissolved).
- Freeze-thaw damage. Thaws are counted by the system, but nothing in notebook A
  goes bad because of them.
- Several sites, shipping out, returns.

## How the report reads

Amounts are compared per container and lot, only where both notebooks agree the
container still exists. "Exact" means within 0.5%. Robot pipetting noise alone
puts most robot-filled wells into "within 10%", so "off by more than 10%" is the
column to watch.

Each mistake ends in one of five places: corrected by someone, refused by the
database when it was typed in, flagged by `flags()`, no lasting harm (nothing
flagged it, but by the end the numbers and places it touched match the lab,
usually because a later scan overwrote it), or silently wrong. The scorer is
deliberately strict about "flagged": a flag has to point at a container or lot
the mistake touched.

Truth-usable applies the system's own rules (QC, expiry with the D9 time
budgets, dead volume) to what really happened, so the usable comparison measures
recording, not a difference in rules.

## Speed

A one-week default run records about 500 calls, loads in 0.2 s and scores in a
few seconds. The 4-week run at 768 designs a week records about 23,000 calls and
loads in about 12 s, but scoring its four checkpoints takes about 7 minutes: at
the last checkpoint `usable()` takes about 90 s and `flags()` about 75 s. The
reasons are in `journal/agent-runs/schema-gaps-sim.md`, item 1. Use
`--last-only` to score just the final checkpoint.

## Results

See `results/normal.md` and `results/bad_week.md` (default week) and
`results/normal-4weeks.md` and `results/bad_week-4weeks.md` (4 weeks, 768
designs a week, 4 targets, seed 7).
