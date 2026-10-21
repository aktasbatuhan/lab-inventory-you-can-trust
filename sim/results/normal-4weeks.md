# Simulation report: normal

28 simulated days from 2026-09-07, 768 designs a week, 4 targets (EGFR, PDL1, HER2, IL6R), 8 experiment(s), seed 7. Loading the recorded calls took 9.7 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-10-04 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 3 | 0 | 0% |
| consumable | 3 | 0 | 0 | 0% |
| dna | 1300 | 1676 | 96 | 3% |
| reagent | 6 | 9 | 12 | 44% |
| sample_protein | 51 | 1103 | 1150 | 50% |
| target | 11 | 18 | 0 | 0% |
| all | 1371 | 2809 | 1258 | 23% |

## Where things are

Of 122 tubes, plates, bottles and boxes that both sides agree exist, 122 are recorded in the right spot, 0 in the right place but the wrong box or slot, 0 in the wrong place altogether and 0 with no place recorded. The system still thinks 5 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 118224.0 | 120136.0 | +1912.0 |
| consumable | pieces | 800.0 | 800.0 | +0.0 |
| dna | µL | 141274.2 | 136992.0 | -4282.2 |
| reagent | µL | 1338229.3 | 1337176.0 | -1053.3 |
| sample_protein | µL | 3774.7 | 4608.0 | +833.3 |
| target:egfr | µL | 422.4 | 420.0 | -2.4 |
| target:her2 | µL | 246.6 | 245.0 | -1.6 |
| target:il6r | µL | 211.7 | 210.0 | -1.7 |
| target:pdl1 | µL | 139.9 | 140.0 | +0.1 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 359 of 1621 | 0 | 1 | 0 | 1 | 3.8 |
| day 14 (2026-09-20 23:00) | 840 of 3524 | 0 | 3 | 0 | 5 | 8.6 |
| day 21 (2026-09-27 23:00) | 1570 of 5436 | 0 | 3 | 0 | 7 | 14.0 |
| end (2026-10-04 23:00) | 1258 of 5438 | 0 | 5 | 0 | 8 | 17.1 |

Flags at the last checkpoint: negative balance 1, robot step assumed 5, seen after it left 2.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| discard_unscanned | 5 | 0 | 0 | 0 | 0 | 5 |
| late_sync | 22 | 0 | 0 | 2 | 20 | 0 |
| move_unscanned | 3 | 0 | 0 | 0 | 3 | 0 |
| robot_step_missing | 5 | 0 | 0 | 5 | 0 | 0 |
| step_unrecorded | 1 | 0 | 0 | 0 | 1 | 0 |
| typo_big | 1 | 0 | 0 | 0 | 1 | 0 |
| typo_small | 1 | 0 | 0 | 1 | 0 | 0 |
| all | 38 | 0 | 0 | 8 | 25 | 5 |

Late entries (22) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- BLI-00094 kept on the bench for a re-read; the rule recorded it as thrown away (E00015). No flag at the end; the record ended right.

Caught, for example:

- E00003 robot_step_missing: expression plate prep step 229 (C137/D1 to C139/H1) done but missing from the log. Flag: robot step assumed (run 1 step 229 finished without a log line; recorded as done by rule).
- E00008 robot_step_missing: split-GFP plate prep and read step 268 (C153/N7 to C155/N7) done but missing from the log. Flag: robot step assumed (run 8 step 268 finished without a log line; recorded as done by rule).
- E00009 robot_step_missing: BLI binding step 79 (C153/N13 to C166/G7) done but missing from the log. Flag: robot step assumed (run 12 step 79 finished without a log line; recorded as done by rule).
- E00010 late_sync: use of BUF-00065 written down 2.9 h after it happened. Flag: seen after it left (liquid recorded in or out at 2026-09-16 14:37:54+01 but recorded as discard at 2026-09-16 14:06:00+01).

Missed, for example:

- E00004 discard_unscanned: ALQ-00056-004 thrown away without a scan.
- E00012 discard_unscanned: PURE-00033-004 thrown away without a scan.
- E00014 discard_unscanned: ALQ-00013-002 thrown away without a scan.
- E00033 discard_unscanned: SEN-00063 thrown away without a scan.
