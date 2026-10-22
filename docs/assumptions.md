# Assumptions

The brief said to bake assumptions into the submission rather than wait for answers, and that the assumptions themselves are useful signal. These are the ones the design depends on. Almost all of them are rows of data, not code: changing one is an insert into a rules table, and questions about the past keep using the old value.

Where something came from Adaptyv's public material (website, docs, papers, job posts), the source is in `journal/agent-runs/adaptyv-lab.md`. Error rates and container numbers are sourced in `journal/agent-runs/research.md`.

## About the lab

- **One site today, a second soon.** Everything sits in one tree of places (site, room, freezer, shelf, rack, box, slot). Adaptyv's job posts mention a London lab opening in Q4 2026; that's one more place at the top of the tree, and moving material between sites is a move plus a shipment.
- **Robots log what they did, step by step.** Adaptyv drives its liquid handlers from Python (PyLabRobot), so we assume a robot run can write each transfer to the inventory as it happens, next to the worklist it was given. A run that finishes normally is assumed to have done its plan (decision D10).
- **People scan, mostly.** Containers carry barcodes and people have handheld scanners, some of which store scans and upload later. Moves typed in by hand are allowed but count as "placed, not confirmed".
- **Experiment planning is a separate system.** The inventory stores its experiment ids on runs, so lineage can reach an experiment and a customer, but it doesn't plan, reserve or order.
- **Customers send protein sequences, not material.** DNA is ordered from Twist or made in-house. A customer shipping their own target is handled as an ordinary delivery.
- **"ABE / ART format" on the target stock tube in the workflow diagram.** We couldn't find what it means. It's kept as a free-text label on the tube until we know.

## About material

- **Each delivery is its own batch.** Two deliveries of the same supplier lot are two lots, each waiting for its own QC (decision D2). Vials split from a checked lot inherit its QC.
- **Targets need QC before use; nothing else does by default.** Which kinds need QC is a setting on the material kind.
- **Amounts are kept in one unit per dimension.** Volume in µL, mass in µg, pieces for consumables, activity units for enzymes. Concentration is a separate measurement, never an amount.

## Numbers the brief didn't give

All of these are placeholder rules in `seed/01_reference_data.sql`, with a note on each saying it's our guess.

| What | Value we used | Why |
|---|---|---|
| Target shelf life, frozen | 3 years | Brief says "many years" |
| Thawed target in the fridge | 7 days in total | Common supplier guidance for reconstituted protein |
| Target on the bench | 8 hours in total | A working day |
| Freeze-thaw limit for targets | 3 | Sources say 1 to 5; set per protein and supplier (D7) |
| GFP stock once in the fridge | 1 month in total | The usual buffer month from the brief |
| Reagents | 2 years | Brief says "varies, typically long" |
| Expression plate's 2 weeks | Counted from the expression run | Brief gives the length, not the start |
| Dead volume | 2 µL (96-well) to 20 µL (Echo source plate), 5 µL in a 1.5 mL tube, 10 µL in a matrix tube | Vendor sheets and lab rules of thumb; thin for some formats |
| Plate formats | 96 for DNA and BLI target plates, 384 for expression and split-GFP | Not public; 8 µL expression reactions suggest 384 |

Storage rules are time budgets: a month in the fridge means a month of fridge time in total, and going back into the freezer pauses the clock (decision D9).

## About people and mistakes

The simulation's error rates come from published human-reliability and clinical-lab studies, because nobody has measured lab inventory accuracy directly. The main ones: a wrong tube scanned about once in 2,000 scans, 3.7% of typed values wrong (0.5% off by more than 20%), a step forgotten 0.3 to 1% of the time. The "bad week" setting multiplies these by about ten.
