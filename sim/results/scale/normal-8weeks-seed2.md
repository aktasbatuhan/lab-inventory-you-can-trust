# Simulation report: normal

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 2. Loading the recorded calls took 98.6 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 1 | 1 | 1 | 33% |
| consumable | 1 | 0 | 0 | 0% |
| dna | 7589 | 8155 | 384 | 2% |
| reagent | 2 | 6 | 43 | 84% |
| sample_protein | 79 | 957 | 2420 | 70% |
| target | 15 | 29 | 0 | 0% |
| all | 7687 | 9148 | 2848 | 14% |

## Where things are

Of 325 tubes, plates, bottles and boxes that both sides agree exist, 325 are recorded in the right spot, 0 in the right place but the wrong box or slot, 0 in the wrong place altogether and 0 with no place recorded. The system still thinks 8 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 420641.5 | 421704.0 | +1062.5 |
| consumable | pieces | 384.0 | 384.0 | +0.0 |
| dna | µL | 702437.6 | 692345.5 | -10092.1 |
| reagent | µL | 145827.8 | 145842.1 | +14.3 |
| sample_protein | µL | 5552.7 | 6720.0 | +1167.3 |
| target:cd47 | µL | 388.2 | 385.0 | -3.2 |
| target:egfr | µL | 106.1 | 105.0 | -1.1 |
| target:her2 | µL | 278.0 | 280.0 | +2.0 |
| target:il6r | µL | 422.1 | 420.0 | -2.1 |
| target:pdl1 | µL | 71.3 | 70.0 | -1.3 |
| target:tnfa | µL | 282.9 | 280.0 | -2.9 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 287 of 3171 | 0 | 1 | 0 | 5 | 49.5 |
| day 14 (2026-09-20 23:00) | 1760 of 7370 | 0 | 2 | 1 | 11 | 13.8 |
| day 21 (2026-09-27 23:00) | 2674 of 10432 | 1 | 3 | 0 | 19 | 18.9 |
| day 28 (2026-10-04 23:00) | 2876 of 11984 | 1 | 3 | 0 | 19 | 15.8 |
| day 35 (2026-10-11 23:00) | 1523 of 12758 | 0 | 3 | 0 | 23 | 22.3 |
| day 42 (2026-10-18 23:00) | 2727 of 15832 | 1 | 6 | 0 | 32 | 30.4 |
| day 49 (2026-10-25 23:00) | 2300 of 18522 | 1 | 8 | 0 | 41 | 17.4 |
| end (2026-11-01 23:00) | 2848 of 19683 | 0 | 8 | 0 | 48 | 18.7 |

Flags at the last checkpoint: negative balance 9, robot step assumed 20, seen after it left 19.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| discard_unscanned | 8 | 0 | 0 | 0 | 0 | 8 |
| duplicate_label | 1 | 0 | 1 | 0 | 0 | 0 |
| late_sync | 61 | 0 | 0 | 1 | 60 | 0 |
| move_unscanned | 11 | 0 | 0 | 0 | 11 | 0 |
| robot_log_late | 2 | 0 | 0 | 0 | 2 | 0 |
| robot_step_missing | 20 | 0 | 0 | 20 | 0 | 0 |
| step_unrecorded | 3 | 0 | 0 | 1 | 2 | 0 |
| typo_big | 5 | 2 | 0 | 1 | 2 | 0 |
| typo_small | 23 | 0 | 0 | 4 | 16 | 3 |
| all | 134 | 2 | 1 | 27 | 93 | 11 |

Late entries (61) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- Freezer F80-2 failed at night; 4 boxes moved to Freezer F80-3 in a hurry (E00006). No flag at the end; the record ended right.
- TP-00151 kept on the bench for a re-read; the rule recorded it as thrown away (E00034). No flag at the end; the record ended right.
- TP-00173 kept on the bench for a re-read; the rule recorded it as thrown away (E00044). No flag at the end; the record ended right.
- supplier shipped lot S112 of target:tnfa twice; both vials are real (E00134). No flag at the end; the record ended right.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 6, for example "records say -20100 volume, more was taken than was there".
- seen after it left: 15, for example "liquid recorded in or out at 2026-09-11 14:37:54+01 but recorded as discard at 2026-09-11 14:06:00+01".

Caught, for example:

- E00004 robot_step_missing: split-GFP plate prep and read step 44 (C179/G15 to C180/G15) done but missing from the log. Flag: robot step assumed (run 2 step 44 finished without a log line; recorded as done by rule).
- E00005 robot_step_missing: expression plate prep step 629 (C130 to C185/J9) done but missing from the log. Flag: robot step assumed (run 3 step 629 finished without a log line; recorded as done by rule).
- E00011 robot_step_missing: split-GFP plate prep and read step 166 (C185/K20 to C192/K20) done but missing from the log. Flag: robot step assumed (run 7 step 166 finished without a log line; recorded as done by rule).
- E00015 robot_step_missing: expression plate prep step 687 (C27 to C209/D6) done but missing from the log. Flag: robot step assumed (run 15 step 687 finished without a log line; recorded as done by rule).

Missed, for example:

- E00013 discard_unscanned: ALQ-00025-001 thrown away without a scan.
- E00018 discard_unscanned: ALQ-00066-003 thrown away without a scan.
- E00048 discard_unscanned: ALQ-00021-001 thrown away without a scan.
- E00061 typo_small: amount received into PURE-00214: typed 8201.7 instead of 7500.

Refused at entry, for example: E00076: barcode TW-223 is already on a live container
