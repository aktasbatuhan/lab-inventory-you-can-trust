# Simulation report: bad_week

7 simulated days from 2026-09-07, 48 designs a week, 2 targets (EGFR, PDL1), 1 experiment(s), seed 7. Loading the recorded calls took 0.2 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-09-13 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 3 | 0 | 0 | 0% |
| consumable | 5 | 0 | 0 | 0% |
| dna | 26 | 22 | 0 | 0% |
| reagent | 16 | 17 | 0 | 0% |
| sample_protein | 2 | 44 | 2 | 4% |
| target | 7 | 16 | 0 | 0% |
| all | 59 | 99 | 2 | 1% |

## Where things are

Of 78 tubes, plates, bottles and boxes that both sides agree exist, 78 are recorded in the right spot, 0 in the right place but the wrong box or slot, 0 in the wrong place altogether and 0 with no place recorded. The system still thinks 0 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 434958.5 | 434696.0 | -262.5 |
| consumable | pieces | 1888.0 | 1888.0 | +0.0 |
| dna | µL | 2204.9 | 2208.0 | +3.1 |
| reagent | µL | 2388439.9 | 2388192.0 | -247.9 |
| sample_protein | µL | 140.2 | 144.0 | +3.8 |
| target:egfr | µL | 419.2 | 385.0 | -34.2 |
| target:pdl1 | µL | 388.3 | 350.0 | -38.3 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 2 (2026-09-08 23:00) | 0 of 113 | 0 | 0 | 0 | 0 | 0.2 |
| day 4 (2026-09-10 23:00) | 2 of 160 | 0 | 0 | 0 | 1 | 0.5 |
| day 6 (2026-09-12 23:00) | 2 of 160 | 0 | 0 | 0 | 3 | 0.5 |
| end (2026-09-13 23:00) | 2 of 160 | 0 | 0 | 0 | 3 | 0.4 |

Flags at the last checkpoint: location uncertain 2, robot step assumed 1.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 2 | 0 | 0 | 2 | 0 | 0 |
| late_sync | 1 | 0 | 0 | 0 | 1 | 0 |
| move_unscanned | 1 | 0 | 0 | 0 | 1 | 0 |
| robot_step_missing | 1 | 0 | 0 | 1 | 0 | 0 |
| step_unrecorded | 2 | 0 | 0 | 0 | 2 | 0 |
| all | 7 | 0 | 0 | 3 | 4 | 0 |

Late entries (1) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Caught, for example:

- E00002 robot_step_missing: expression plate prep step 47 (C99/D11 to C100/G21) done but missing from the log. Flag: robot step assumed (run 1 step 47 finished without a log line; recorded as done by rule).
- E00006 count_missed: ALQ-00013-001 is in Freezer F80-1 but the count marked it not found. Flag: location uncertain (not found in the last count and not seen since).
- E00007 count_missed: ALQ-00038-004 is in Freezer F80-1 but the count marked it not found. Flag: location uncertain (not found in the last count and not seen since).
