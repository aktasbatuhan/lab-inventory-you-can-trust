# Simulation report: bad_week

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 3. Loading the recorded calls took 85.7 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 1 | 2 | 67% |
| consumable | 1 | 0 | 0 | 0% |
| dna | 7064 | 8579 | 485 | 3% |
| reagent | 3 | 17 | 25 | 56% |
| sample_protein | 6 | 471 | 1443 | 75% |
| target | 17 | 34 | 0 | 0% |
| all | 7091 | 9102 | 1955 | 11% |

## Where things are

Of 319 tubes, plates, bottles and boxes that both sides agree exist, 302 are recorded in the right spot, 2 in the right place but the wrong box or slot, 15 in the wrong place altogether and 0 with no place recorded. The system still thinks 26 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 128556.3 | 251464.0 | +122907.7 |
| consumable | pieces | 384.0 | 416.0 | +32.0 |
| dna | µL | 757912.8 | 769708.8 | +11796.0 |
| reagent | µL | 576343.8 | 580629.7 | +4285.9 |
| sample_protein | µL | 1878.4 | 2496.0 | +617.6 |
| target:cd47 | µL | 492.8 | 490.0 | -2.8 |
| target:egfr | µL | 245.7 | 245.0 | -0.7 |
| target:her2 | µL | 386.6 | 385.0 | -1.6 |
| target:il6r | µL | 317.2 | 315.0 | -2.2 |
| target:pdl1 | µL | 318.8 | 245.0 | -73.8 |
| target:tnfa | µL | 0.0 | 0.0 | +0.0 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 495 of 2793 | 3 | 0 | 0 | 9 | 36.8 |
| day 14 (2026-09-20 23:00) | 1390 of 6988 | 25 | 4 | 0 | 29 | 105.0 |
| day 21 (2026-09-27 23:00) | 1916 of 10053 | 29 | 5 | 0 | 39 | 10.0 |
| day 28 (2026-10-04 23:00) | 1734 of 11993 | 26 | 12 | 0 | 57 | 237.3 |
| day 35 (2026-10-11 23:00) | 1884 of 13533 | 10 | 14 | 3 | 82 | 300.3 |
| day 42 (2026-10-18 23:00) | 1612 of 15452 | 13 | 19 | 0 | 89 | 28.4 |
| day 49 (2026-10-25 23:00) | 1969 of 18154 | 17 | 24 | 0 | 117 | 15.6 |
| end (2026-11-01 23:00) | 1955 of 18148 | 17 | 26 | 0 | 121 | 16.3 |

Flags at the last checkpoint: location uncertain 21, negative balance 8, robot step assumed 73, seen after it left 19.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 7 | 0 | 0 | 6 | 1 | 0 |
| discard_unscanned | 27 | 0 | 0 | 13 | 0 | 14 |
| duplicate_label | 2 | 0 | 2 | 0 | 0 | 0 |
| late_sync | 175 | 0 | 0 | 19 | 156 | 0 |
| move_unscanned | 145 | 0 | 0 | 10 | 123 | 12 |
| robot_log_late | 5 | 0 | 0 | 0 | 5 | 0 |
| robot_step_missing | 73 | 0 | 0 | 73 | 0 | 0 |
| step_unrecorded | 112 | 4 | 0 | 5 | 86 | 17 |
| supplier_short_fill | 4 | 0 | 0 | 0 | 4 | 0 |
| typo_big | 7 | 2 | 0 | 1 | 4 | 0 |
| typo_small | 21 | 2 | 0 | 2 | 16 | 1 |
| wrong_position | 2 | 0 | 0 | 0 | 0 | 2 |
| wrong_scan | 1 | 1 | 0 | 0 | 0 | 0 |
| all | 581 | 9 | 2 | 129 | 395 | 46 |

Late entries (175) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- BLI-00093 kept on the bench for a re-read; the rule recorded it as thrown away (E00034). No flag at the end; the record ended right.
- Freezer F80-1 failed at night; 19 boxes moved to Freezer F80-3 in a hurry (E00168). No flag at the end; the record ended right.
- TP-00161 kept on the bench for a re-read; the rule recorded it as thrown away (E00194). No flag at the end; the record ended right.
- BLI-00173 kept on the bench for a re-read; the rule recorded it as thrown away (E00238). No flag at the end; the record ended right.
- BLI-00241 kept on the bench for a re-read; the rule recorded it as thrown away (E00335). No flag at the end; the record ended right.
- TP-00288 kept on the bench for a re-read; the rule recorded it as thrown away (E00397). No flag at the end; the record ended right.
- BLI-00310 kept on the bench for a re-read; the rule recorded it as thrown away (E00422). Flagged: seen after it left.
- BLI-00313 kept on the bench for a re-read; the rule recorded it as thrown away (E00429). No flag at the end; the record ended right.
- TP-00314 kept on the bench for a re-read; the rule recorded it as thrown away (E00430). No flag at the end; the record ended right.
- BLI-00403 kept on the bench for a re-read; the rule recorded it as thrown away (E00577). No flag at the end; the record ended right.
- BLI-00407 kept on the bench for a re-read; the rule recorded it as thrown away (E00590). No flag at the end; the record ended right.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 2, for example "records say -73380 volume, more was taken than was there".
- seen after it left: 12, for example "liquid recorded in or out at 2026-09-17 14:12:42+01 but recorded as discard at 2026-09-17 14:00:00+01".

Caught, for example:

- E00004 robot_step_missing: expression plate prep step 106 (C172/A10 to C179/A20) done but missing from the log. Flag: robot step assumed (run 1 step 106 finished without a log line; recorded as done by rule).
- E00005 robot_step_missing: expression plate prep step 608 (C70 to C179/F15) done but missing from the log. Flag: robot step assumed (run 1 step 608 finished without a log line; recorded as done by rule).
- E00006 robot_step_missing: expression plate prep step 724 (C70 to C179/J8) done but missing from the log. Flag: robot step assumed (run 1 step 724 finished without a log line; recorded as done by rule).
- E00014 robot_step_missing: expression plate prep step 345 (C178/E9 to C181/J18) done but missing from the log. Flag: robot step assumed (run 3 step 345 finished without a log line; recorded as done by rule).

Missed, for example:

- E00007 wrong_position: TW-011 put in slot 1 but recorded as slot 2.
- E00075 step_unrecorded: transfer from ALQ-00023-002 into C221/C1 not recorded.
- E00076 step_unrecorded: transfer from ALQ-00023-002 into C221/H1 not recorded.
- E00077 discard_unscanned: ALQ-00023-002 thrown away without a scan.

Refused at entry, for example: E00044: barcode ALQ-00070-003 is already on a live container; E00222: barcode KIT-00026 is already on a live container
