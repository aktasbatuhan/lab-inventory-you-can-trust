# Simulation report: normal

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 3. Loading the recorded calls took 102.6 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 3 | 0 | 0% |
| consumable | 0 | 0 | 1 | 100% |
| dna | 7233 | 8415 | 480 | 3% |
| reagent | 1 | 17 | 43 | 70% |
| sample_protein | 68 | 1635 | 1369 | 45% |
| target | 19 | 37 | 0 | 0% |
| all | 7321 | 10107 | 1893 | 10% |

## Where things are

Of 350 tubes, plates, bottles and boxes that both sides agree exist, 347 are recorded in the right spot, 0 in the right place but the wrong box or slot, 3 in the wrong place altogether and 0 with no place recorded. The system still thinks 5 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 350081.0 | 366664.0 | +16583.0 |
| consumable | pieces | 0.0 | 1.9 | +1.9 |
| dna | µL | 738385.9 | 781355.2 | +42969.3 |
| reagent | µL | 93781.3 | 92834.0 | -947.3 |
| sample_protein | µL | 5286.7 | 6336.0 | +1049.3 |
| target:cd47 | µL | 387.8 | 385.0 | -2.8 |
| target:egfr | µL | 69.6 | 70.0 | +0.4 |
| target:her2 | µL | 248.1 | 245.0 | -3.1 |
| target:il6r | µL | 350.1 | 350.0 | -0.1 |
| target:pdl1 | µL | 563.4 | 560.0 | -3.4 |
| target:tnfa | µL | 352.2 | 350.0 | -2.2 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 607 of 3559 | 2 | 1 | 0 | 4 | 51.6 |
| day 14 (2026-09-20 23:00) | 2734 of 7372 | 3 | 1 | 0 | 8 | 14.4 |
| day 21 (2026-09-27 23:00) | 3215 of 10440 | 2 | 3 | 0 | 12 | 170.7 |
| day 28 (2026-10-04 23:00) | 2770 of 11997 | 1 | 4 | 0 | 17 | 251.1 |
| day 35 (2026-10-11 23:00) | 1942 of 13152 | 2 | 4 | 0 | 24 | 308.0 |
| day 42 (2026-10-18 23:00) | 2199 of 15463 | 2 | 4 | 0 | 26 | 31.5 |
| day 49 (2026-10-25 23:00) | 1903 of 18165 | 4 | 5 | 0 | 32 | 17.8 |
| end (2026-11-01 23:00) | 1893 of 19321 | 3 | 5 | 0 | 49 | 19.5 |

Flags at the last checkpoint: location uncertain 1, negative balance 11, robot step assumed 21, seen after it left 16.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| discard_unscanned | 5 | 0 | 0 | 1 | 0 | 4 |
| duplicate_label | 2 | 0 | 2 | 0 | 0 | 0 |
| late_sync | 84 | 0 | 0 | 5 | 79 | 0 |
| move_unscanned | 19 | 0 | 0 | 0 | 16 | 3 |
| robot_log_late | 3 | 0 | 0 | 0 | 3 | 0 |
| robot_step_missing | 21 | 0 | 0 | 21 | 0 | 0 |
| step_unrecorded | 3 | 0 | 0 | 0 | 3 | 0 |
| supplier_short_fill | 1 | 0 | 0 | 0 | 1 | 0 |
| typo_big | 4 | 2 | 0 | 1 | 1 | 0 |
| typo_small | 18 | 1 | 0 | 4 | 12 | 1 |
| all | 160 | 3 | 2 | 32 | 115 | 8 |

Late entries (84) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- BLI-00128 kept on the bench for a re-read; the rule recorded it as thrown away (E00025). No flag at the end; the record ended right.
- TP-00442 kept on the bench for a re-read; the rule recorded it as thrown away (E00155). No flag at the end; the record ended right.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 7, for example "records say -10000 volume, more was taken than was there".
- seen after it left: 13, for example "liquid recorded in or out at 2026-09-11 14:37:54+01 but recorded as discard at 2026-09-11 14:06:00+01".

Caught, for example:

- E00002 robot_step_missing: expression plate prep step 14 (C171/B2 to C179/C3) done but missing from the log. Flag: robot step assumed (run 1 step 14 finished without a log line; recorded as done by rule).
- E00003 robot_step_missing: expression plate prep step 739 (C70 to C179/L14) done but missing from the log. Flag: robot step assumed (run 1 step 739 finished without a log line; recorded as done by rule).
- E00005 robot_step_missing: split-GFP plate prep and read step 103 (C185/A14 to C192/A14) done but missing from the log. Flag: robot step assumed (run 7 step 103 finished without a log line; recorded as done by rule).
- E00023 robot_step_missing: BLI binding step 17 (C233/C9 to C249/B5) done but missing from the log. Flag: robot step assumed (run 29 step 17 finished without a log line; recorded as done by rule).

Missed, for example:

- E00009 discard_unscanned: ALQ-00025-003 thrown away without a scan.
- E00047 discard_unscanned: ALQ-00072-004 thrown away without a scan.
- E00050 discard_unscanned: ALQ-00049-001 thrown away without a scan.
- E00081 move_unscanned: TW-142 moved to RACK-D1 without a scan.

Refused at entry, for example: E00027: barcode BOX-00014 is already on a live container; E00161: barcode TW-172 is already on a live container
