# Simulation report: bad_week

28 simulated days from 2026-09-07, 768 designs a week, 4 targets (EGFR, PDL1, HER2, IL6R), 8 experiment(s), seed 7. Loading the recorded calls took 9.7 s.

Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, and compares it with what was really in the lab. "Exact" means within 0.5% (rounding and nothing else); pipetting noise alone puts robot-filled wells in the "within 10%" group.

## Amounts, per container and lot, at the last checkpoint (2026-10-04 23:00)

| Kind | Exact | Within 10% | Off by more | Share off |
|---|---|---|---|---|
| buffer | 0 | 2 | 1 | 33% |
| consumable | 3 | 0 | 1 | 25% |
| dna | 1322 | 1750 | 0 | 0% |
| reagent | 5 | 9 | 17 | 55% |
| sample_protein | 2 | 421 | 2265 | 84% |
| target | 6 | 12 | 0 | 0% |
| all | 1338 | 2194 | 2284 | 39% |

## Where things are

Of 114 tubes, plates, bottles and boxes that both sides agree exist, 110 are recorded in the right spot, 4 in the right place but the wrong box or slot, 0 in the wrong place altogether and 0 with no place recorded. The system still thinks 4 containers exist that were really thrown away, and thinks 0 were thrown away that are still in the lab.

## Usable amounts: system against truth

Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. A gap here is what a planner would get wrong.

| What | Unit | Really usable | System says | Difference |
|---|---|---|---|---|
| buffer | µL | 62378.6 | 61896.0 | -482.6 |
| consumable | pieces | 800.0 | 864.0 | +64.0 |
| dna | µL | 141453.3 | 132480.0 | -8973.3 |
| reagent | µL | 1337537.5 | 1334611.2 | -2926.3 |
| sample_protein | µL | 2973.1 | 4032.0 | +1058.9 |
| target:egfr | µL | 106.5 | 105.0 | -1.5 |
| target:her2 | µL | 0.0 | 0.0 | +0.0 |
| target:il6r | µL | 282.8 | 280.0 | -2.8 |
| target:pdl1 | µL | 212.6 | 210.0 | -2.6 |

## Over time

| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |
|---|---|---|---|---|---|---|
| day 7 (2026-09-13 23:00) | 359 of 1237 | 1 | 2 | 0 | 2 | 2.9 |
| day 14 (2026-09-20 23:00) | 1131 of 3149 | 3 | 4 | 0 | 11 | 8.6 |
| day 21 (2026-09-27 23:00) | 1755 of 5444 | 8 | 4 | 0 | 14 | 14.3 |
| end (2026-10-04 23:00) | 2284 of 5816 | 4 | 4 | 0 | 25 | 18.0 |

Flags at the last checkpoint: location uncertain 4, robot step assumed 18, seen after it left 3.

## The injected mistakes, and what became of them

Every mistake is in errors.jsonl with an id. "Corrected" means someone noticed and recorded a fix. "Refused at entry" means the database said no straight away, which is self-evident to whoever typed it. "Flagged" means flags() points at the container or lot. "No lasting harm" means nothing flagged it, but by the end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "Silently wrong" means the record is still wrong and nothing says so.

| Mistake | Count | corrected | refused at entry | flagged | no lasting harm | silently wrong |
|---|---|---|---|---|---|---|
| count_missed | 3 | 0 | 0 | 2 | 1 | 0 |
| discard_unscanned | 5 | 0 | 0 | 3 | 0 | 2 |
| late_sync | 54 | 0 | 0 | 4 | 50 | 0 |
| move_unscanned | 48 | 0 | 0 | 0 | 48 | 0 |
| robot_log_late | 5 | 0 | 0 | 0 | 5 | 0 |
| robot_step_missing | 18 | 0 | 0 | 18 | 0 | 0 |
| step_unrecorded | 29 | 2 | 0 | 0 | 21 | 6 |
| typo_small | 4 | 0 | 0 | 0 | 1 | 3 |
| wrong_position | 4 | 0 | 0 | 0 | 0 | 4 |
| all | 170 | 2 | 0 | 27 | 126 | 15 |

Late entries (54) can only hurt in between: by the end they have all arrived, so they mostly land in "no lasting harm". Their cost shows in the earlier checkpoints, which ask what the system said at the time.

Things that really happened and were recorded correctly, but look like mistakes:

- TP-00081 kept on the bench for a re-read; the rule recorded it as thrown away (E00039). No flag at the end; the record ended right.
- TP-00113 kept on the bench for a re-read; the rule recorded it as thrown away (E00099). No flag at the end; the record ended right.
- TP-00149 kept on the bench for a re-read; the rule recorded it as thrown away (E00161). No flag at the end; the record ended right.
- BLI-00150 kept on the bench for a re-read; the rule recorded it as thrown away (E00164). Flagged: seen after it left.

Caught, for example:

- E00001 discard_unscanned: BUF-00064 thrown away without a scan. Flag: location uncertain (not found in the last count and not seen since).
- E00008 robot_step_missing: expression plate prep step 223 (C137/C7 to C139/F13) done but missing from the log. Flag: robot step assumed (run 1 step 223 finished without a log line; recorded as done by rule).
- E00027 discard_unscanned: BUF-00066 thrown away without a scan. Flag: location uncertain (not found in the last count and not seen since).
- E00029 robot_step_missing: expression plate prep step 426 (C55 to C154/G11) done but missing from the log. Flag: robot step assumed (run 7 step 426 finished without a log line; recorded as done by rule).

Missed, for example:

- E00002 typo_small: volume made in BUF-00066: typed 54199.2 instead of 50000.
- E00015 step_unrecorded: transfer from ALQ-00017-002 into C144/C1 not recorded.
- E00016 step_unrecorded: transfer from ALQ-00017-002 into C144/G1 not recorded.
- E00017 discard_unscanned: ALQ-00017-002 thrown away without a scan.
