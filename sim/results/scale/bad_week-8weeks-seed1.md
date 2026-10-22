# Simulation report: bad_week

56 simulated days from 2026-09-07, 2000 designs a week, 6 targets (EGFR, PDL1, HER2, IL6R, TNFA, CD47), 42 experiment(s), seed 1. Loading the recorded calls took 84.9 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-11-01 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 2 | 0 | 1 | 33% |
| consumable | 1 | 0 | 0 | 0% |
| dna | 7016 | 8323 | 789 | 5% |
| reagent | 1 | 16 | 38 | 69% |
| sample_protein | 87 | 1520 | 1849 | 54% |
| target | 34 | 24 | 0 | 0% |
| all | 7141 | 9883 | 2677 | 14% |

## Where things are

Of 342 tubes, plates, bottles and boxes that both sides agree exist, 326 are recorded in the right spot, 4 in the right place but the wrong box or slot, 12 in the wrong place altogether and 0 with no place recorded. The system still thinks 21 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 404438.7 | 433352.0 | +28913.3 |
| consumable | pieces | 352.0 | 384.0 | +32.0 |
| dna | µL | 739080.3 | 807141.5 | +68061.2 |
| reagent | µL | 208582.7 | 242300.1 | +33717.4 |
| sample_protein | µL | 9122.8 | 10368.0 | +1245.2 |
| target:cd47 | µL | 491.3 | 455.0 | -36.3 |
| target:egfr | µL | 176.5 | 140.0 | -36.5 |
| target:her2 | µL | 247.5 | 245.0 | -2.5 |
| target:il6r | µL | 489.4 | 490.0 | +0.6 |
| target:pdl1 | µL | 386.5 | 385.0 | -1.5 |
| target:tnfa | µL | 244.3 | 245.0 | +0.7 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 312 of 2791 | 1 | 0 | 0 | 13 | 40.7 |
| day 14 (2026-09-20 23:00) | 2279 of 7375 | 12 | 4 | 1 | 44 | 12.6 |
| day 21 (2026-09-27 23:00) | 2764 of 9298 | 13 | 7 | 0 | 46 | 14.7 |
| day 28 (2026-10-04 23:00) | 2623 of 11994 | 9 | 11 | 1 | 64 | 16.3 |
| day 35 (2026-10-11 23:00) | 1187 of 12382 | 9 | 14 | 1 | 72 | 19.6 |
| day 42 (2026-10-18 23:00) | 2314 of 15459 | 9 | 16 | 1 | 93 | 26.9 |
| day 49 (2026-10-25 23:00) | 3166 of 17763 | 18 | 21 | 0 | 99 | 16.1 |
| end (2026-11-01 23:00) | 2677 of 19701 | 16 | 21 | 0 | 107 | 16.6 |

Flags at the last checkpoint: location uncertain 14, negative balance 5, robot step assumed 77, seen after it left 11.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 9 | 0 | 0 | 6 | 3 | 0 |
| discard_unscanned | 22 | 0 | 0 | 7 | 0 | 15 |
| duplicate_label | 1 | 0 | 1 | 0 | 0 | 0 |
| late_sync | 169 | 0 | 0 | 23 | 146 | 0 |
| move_unscanned | 138 | 0 | 0 | 8 | 116 | 14 |
| robot_log_late | 4 | 0 | 0 | 0 | 4 | 0 |
| robot_step_missing | 77 | 0 | 0 | 77 | 0 | 0 |
| step_unrecorded | 99 | 2 | 0 | 0 | 81 | 16 |
| supplier_short_fill | 1 | 0 | 0 | 0 | 1 | 0 |
| typo_big | 9 | 4 | 0 | 0 | 5 | 0 |
| typo_small | 26 | 1 | 0 | 0 | 21 | 4 |
| wrong_position | 4 | 0 | 0 | 1 | 0 | 3 |
| all | 559 | 7 | 1 | 122 | 377 | 52 |

Late entries (169) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- BLI-00119 kept on the bench for a re-read; the rule recorded it as thrown away (E00108). No flag at the end; the record ended right.
- TP-00128 kept on the bench for a re-read; the rule recorded it as thrown away (E00141). No flag at the end; the record ended right.
- BLI-00134 kept on the bench for a re-read; the rule recorded it as thrown away (E00157). No flag at the end; the record ended right.
- GFP-00141 kept on the bench for a re-read; the rule recorded it as thrown away (E00170). No flag at the end; the record ended right.
- TP-00164 kept on the bench for a re-read; the rule recorded it as thrown away (E00210). No flag at the end; the record ended right.
- TP-00171 kept on the bench for a re-read; the rule recorded it as thrown away (E00227). No flag at the end; the record ended right.
- BLI-00236 kept on the bench for a re-read; the rule recorded it as thrown away (E00336). No flag at the end; the record ended right.
- GFP-00258 kept on the bench for a re-read; the rule recorded it as thrown away (E00368). No flag at the end; the record ended right.
- TP-00275 kept on the bench for a re-read; the rule recorded it as thrown away (E00392). No flag at the end; the record ended right.
- TP-00323 kept on the bench for a re-read; the rule recorded it as thrown away (E00458). Flagged: seen after it left.

Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as pipetting a little more than recorded):

- negative balance: 3, for example "records say -11000 volume, more was taken than was there".
- seen after it left: 2, for example "liquid recorded in or out at 2026-09-17 10:44:30+01 but recorded as discard at 2026-09-17 10:00:00+01".

Caught, for example:

- E00009 robot_step_missing: split-GFP plate prep and read step 340 (C179/J8 to C180/J8) done but missing from the log. Flag: robot step assumed (run 2 step 340 finished without a log line; recorded as done by rule).
- E00012 robot_step_missing: expression plate prep step 92 (C175/H8 to C185/O15) done but missing from the log. Flag: robot step assumed (run 3 step 92 finished without a log line; recorded as done by rule).
- E00013 robot_step_missing: expression plate prep step 138 (C176/D6 to C185/G12) done but missing from the log. Flag: robot step assumed (run 3 step 138 finished without a log line; recorded as done by rule).
- E00014 robot_step_missing: expression plate prep step 605 (C66 to C185/F9) done but missing from the log. Flag: robot step assumed (run 3 step 605 finished without a log line; recorded as done by rule).

Missed, for example:

- E00001 step_unrecorded: hepes from HEP-00002 left out of the record for BUF-00084.
- E00002 step_unrecorded: nacl from NAC-00004 left out of the record for BUF-00084.
- E00031 step_unrecorded: took 40000 from BUF-00083 and didn't record it.
- E00055 step_unrecorded: took 40000 from BUF-00083 and didn't record it.

Refused at entry, for example: E00023: barcode WAT-00078 is already on a live container
