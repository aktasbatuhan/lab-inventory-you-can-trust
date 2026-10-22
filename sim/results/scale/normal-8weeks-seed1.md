# Simulation report: normal

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 1. Loading the recorded calls took 83.4 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 2 | 1 | 33% |
| consumable | 1 | 0 | 0 | 0% |
| dna | 7243 | 8792 | 93 | 1% |
| reagent | 2 | 20 | 26 | 54% |
| sample_protein | 34 | 1131 | 1907 | 62% |
| target | 20 | 27 | 4 | 8% |
| all | 7300 | 9972 | 2031 | 11% |

## Where things are

Of 326 tubes, plates, bottles and boxes that both sides agree exist, 326 are recorded in the right spot, 0 in the right place but the wrong box or slot, 0 in the wrong place altogether and 0 with no place recorded. The system still thinks 4 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 62428.9 | 440136.0 | +377707.1 |
| consumable | pieces | 128.0 | 128.0 | +0.0 |
| dna | µL | 756911.2 | 757084.8 | +173.6 |
| reagent | µL | 188132.2 | 250699.9 | +62567.7 |
| sample_protein | µL | 4701.8 | 5760.0 | +1058.2 |
| target:cd47 | µL | 281.4 | 280.0 | -1.4 |
| target:egfr | µL | 423.0 | 420.0 | -3.0 |
| target:her2 | µL | 420.0 | 420.0 | +0.0 |
| target:il6r | µL | 248.0 | 213.8 | -34.2 |
| target:pdl1 | µL | 282.5 | 280.0 | -2.5 |
| target:tnfa | µL | 142.2 | 140.0 | -2.2 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 310 of 3175 | 0 | 0 | 1 | 3 | 47.8 |
| day 14 (2026-09-20 23:00) | 900 of 7370 | 2 | 0 | 0 | 11 | 12.8 |
| day 21 (2026-09-27 23:00) | 1056 of 9677 | 2 | 1 | 0 | 12 | 14.7 |
| day 28 (2026-10-04 23:00) | 998 of 11228 | 1 | 1 | 0 | 14 | 13.1 |
| day 35 (2026-10-11 23:00) | 903 of 12770 | 1 | 3 | 0 | 19 | 20.6 |
| day 42 (2026-10-18 23:00) | 1634 of 15844 | 0 | 3 | 0 | 21 | 26.6 |
| day 49 (2026-10-25 23:00) | 1931 of 18531 | 0 | 4 | 0 | 31 | 15.3 |
| end (2026-11-01 23:00) | 2031 of 19303 | 0 | 4 | 0 | 33 | 16.1 |

Flags at the last checkpoint: location uncertain 1, negative balance 8, robot step assumed 19, seen after it left 5.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 2 | 0 | 0 | 0 | 2 | 0 |
| discard_unscanned | 4 | 0 | 0 | 1 | 0 | 3 |
| duplicate_label | 1 | 0 | 1 | 0 | 0 | 0 |
| late_sync | 58 | 0 | 0 | 3 | 55 | 0 |
| move_unscanned | 7 | 0 | 0 | 0 | 7 | 0 |
| robot_step_missing | 19 | 0 | 0 | 19 | 0 | 0 |
| step_unrecorded | 2 | 0 | 0 | 0 | 2 | 0 |
| supplier_short_fill | 1 | 0 | 0 | 0 | 1 | 0 |
| typo_big | 4 | 0 | 0 | 4 | 0 | 0 |
| typo_small | 16 | 0 | 0 | 1 | 12 | 3 |
| all | 114 | 0 | 1 | 28 | 79 | 6 |

Late entries (58) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- TP-00107 kept on the bench for a re-read; the rule recorded it as thrown away (E00011). No flag at the end; the record ended right.
- BLI-00131 kept on the bench for a re-read; the rule recorded it as thrown away (E00029). No flag at the end; the record ended right.
- GFP-00368 kept on the bench for a re-read; the rule recorded it as thrown away (E00111). No flag at the end; the record ended right.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 4, for example "records say -50 volume, more was taken than was there".
- seen after it left: 2, for example "liquid recorded in or out at 2026-09-17 10:44:30+01 but recorded as discard at 2026-09-17 10:00:00+01".

Caught, for example:

- E00006 robot_step_missing: expression plate prep step 453 (C127 to C199/K17) done but missing from the log. Flag: robot step assumed (run 9 step 453 finished without a log line; recorded as done by rule).
- E00014 robot_step_missing: split-GFP plate prep and read step 356 (C209/L16 to C218/L16) done but missing from the log. Flag: robot step assumed (run 19 step 356 finished without a log line; recorded as done by rule).
- E00027 typo_big: volume per well from ALQ-00053-002: typed 40 instead of 4. Flag: negative balance (records say -275 volume, more was taken than was there).
- E00032 robot_step_missing: BLI binding step 96 (C250/O23 to C278/H12) done but missing from the log. Flag: robot step assumed (run 42 step 96 finished without a log line; recorded as done by rule).

Missed, for example:

- E00037 typo_small: amount received into TGT-00165: typed 212.5 instead of 200.
- E00042 discard_unscanned: TGT-00165 thrown away without a scan.
- E00067 discard_unscanned: TGT-00238 thrown away without a scan.
- E00068 discard_unscanned: TGT-00266 thrown away without a scan.

Refused at entry, for example: E00066: barcode TW-203 is already on a live container
