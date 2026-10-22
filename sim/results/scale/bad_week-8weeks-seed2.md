# Simulation report: bad_week

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 2. Loading the recorded calls took 88.0 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 3 | 0 | 0% |
| consumable | 0 | 0 | 1 | 100% |
| dna | 7357 | 8186 | 585 | 4% |
| reagent | 1 | 17 | 26 | 59% |
| sample_protein | 76 | 1172 | 1824 | 59% |
| target | 19 | 38 | 0 | 0% |
| all | 7453 | 9416 | 2436 | 13% |

## Where things are

Of 328 tubes, plates, bottles and boxes that both sides agree exist, 309 are recorded in the right spot, 2 in the right place but the wrong box or slot, 17 in the wrong place altogether and 0 with no place recorded. The system still thinks 20 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 252998.1 | 264968.0 | +11969.9 |
| consumable | pieces | 96.0 | 128.0 | +32.0 |
| dna | µL | 722985.8 | 738218.8 | +15233.0 |
| reagent | µL | 220367.5 | 621140.6 | +400773.1 |
| sample_protein | µL | 4314.4 | 5568.0 | +1253.6 |
| target:cd47 | µL | 248.2 | 245.0 | -3.2 |
| target:egfr | µL | 211.8 | 175.0 | -36.8 |
| target:her2 | µL | 319.1 | 326.0 | +6.9 |
| target:il6r | µL | 419.8 | 420.0 | +0.2 |
| target:pdl1 | µL | 386.8 | 385.0 | -1.8 |
| target:tnfa | µL | 423.8 | 385.0 | -38.8 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 270 of 3171 | 22 | 1 | 1 | 73 | 45.2 |
| day 14 (2026-09-20 23:00) | 1157 of 7368 | 25 | 6 | 0 | 70 | 128.8 |
| day 21 (2026-09-27 23:00) | 2378 of 10045 | 26 | 10 | 0 | 68 | 156.5 |
| day 28 (2026-10-04 23:00) | 1996 of 11607 | 29 | 12 | 0 | 84 | 192.1 |
| day 35 (2026-10-11 23:00) | 1529 of 12000 | 14 | 12 | 0 | 67 | 248.6 |
| day 42 (2026-10-18 23:00) | 1575 of 14691 | 16 | 16 | 0 | 77 | 325.5 |
| day 49 (2026-10-25 23:00) | 2290 of 16621 | 19 | 19 | 0 | 94 | 34.5 |
| end (2026-11-01 23:00) | 2436 of 19305 | 19 | 20 | 0 | 101 | 16.6 |

Flags at the last checkpoint: location uncertain 13, negative balance 7, robot step assumed 74, seen after it left 7.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 6 | 0 | 0 | 4 | 2 | 0 |
| discard_unscanned | 21 | 0 | 0 | 6 | 0 | 15 |
| duplicate_delivery | 2 | 0 | 2 | 0 | 0 | 0 |
| duplicate_label | 2 | 0 | 2 | 0 | 0 | 0 |
| late_sync | 197 | 0 | 0 | 15 | 182 | 0 |
| move_unscanned | 164 | 0 | 0 | 9 | 135 | 20 |
| robot_log_late | 5 | 0 | 0 | 0 | 5 | 0 |
| robot_step_missing | 74 | 0 | 0 | 74 | 0 | 0 |
| step_unrecorded | 96 | 1 | 0 | 2 | 80 | 13 |
| supplier_short_fill | 2 | 0 | 0 | 0 | 2 | 0 |
| typo_big | 7 | 1 | 0 | 0 | 5 | 1 |
| typo_small | 21 | 0 | 0 | 3 | 16 | 2 |
| wrong_position | 2 | 0 | 0 | 0 | 0 | 2 |
| all | 599 | 2 | 4 | 113 | 427 | 53 |

Late entries (197) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- Freezer F80-1 failed at night; 19 boxes moved to Freezer F80-3 in a hurry (E00010). No flag at the end; the record ended right.
- TP-00099 kept on the bench for a re-read; the rule recorded it as thrown away (E00074). No flag at the end; the record ended right.
- GFP-00110 kept on the bench for a re-read; the rule recorded it as thrown away (E00088). No flag at the end; the record ended right.
- BLI-00119 kept on the bench for a re-read; the rule recorded it as thrown away (E00110). No flag at the end; the record ended right.
- TP-00120 kept on the bench for a re-read; the rule recorded it as thrown away (E00111). No flag at the end; the record ended right.
- TP-00135 kept on the bench for a re-read; the rule recorded it as thrown away (E00147). No flag at the end; the record ended right.
- GFP-00143 kept on the bench for a re-read; the rule recorded it as thrown away (E00163). No flag at the end; the record ended right.
- TP-00293 kept on the bench for a re-read; the rule recorded it as thrown away (E00431). Flagged: seen after it left.
- TP-00297 kept on the bench for a re-read; the rule recorded it as thrown away (E00439). No flag at the end; the record ended right.
- BLI-00306 kept on the bench for a re-read; the rule recorded it as thrown away (E00453). No flag at the end; the record ended right.
- BLI-00347 kept on the bench for a re-read; the rule recorded it as thrown away (E00531). No flag at the end; the record ended right.
- supplier shipped lot S90 of target:egfr twice; both vials are real (E00542). No flag at the end; the record ended right.
- GFP-00376 kept on the bench for a re-read; the rule recorded it as thrown away (E00580). No flag at the end; the record ended right.
- BLI-00387 kept on the bench for a re-read; the rule recorded it as thrown away (E00603). No flag at the end; the record ended right.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 1, for example "records say -1072 volume, more was taken than was there".
- seen after it left: 4, for example "liquid recorded in or out at 2026-09-23 14:12:42+01 but recorded as discard at 2026-09-23 14:06:00+01".

Caught, for example:

- E00006 robot_step_missing: expression plate prep step 65 (C171/F5 to C175/K9) done but missing from the log. Flag: robot step assumed (run 1 step 65 finished without a log line; recorded as done by rule).
- E00007 robot_step_missing: expression plate prep step 212 (C173/B8 to C175/D15) done but missing from the log. Flag: robot step assumed (run 1 step 212 finished without a log line; recorded as done by rule).
- E00008 robot_step_missing: expression plate prep step 269 (C173/G5 to C175/N9) done but missing from the log. Flag: robot step assumed (run 1 step 269 finished without a log line; recorded as done by rule).
- E00012 move_unscanned: box BOX-00014 moved to Freezer F80-3 during the freezer rescue without a scan. Flag: location uncertain (not found in the last count and not seen since).

Missed, for example:

- E00017 move_unscanned: box BOX-00024 moved to Freezer F80-3 during the freezer rescue without a scan.
- E00021 move_unscanned: box BOX-00048 moved to Freezer F80-3 during the freezer rescue without a scan.
- E00024 move_unscanned: box BOX-00065 moved to Freezer F80-3 during the freezer rescue without a scan.
- E00025 move_unscanned: box BOX-00067 moved to Freezer F80-3 during the freezer rescue without a scan.

Refused at entry, for example: E00001: duplicate key value violates unique constraint "event_external_ref_key"; E00194: duplicate key value violates unique constraint "event_external_ref_key"; E00265: barcode ALQ-00068-003 is already on a live container
