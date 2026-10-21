# Scenario clusters

We grouped the 244 draft scenarios in `catalog.yaml` into 29 themes. Each scenario has one cluster, even when it touches two, so we picked the one it tests hardest. 33 scenarios are near copies of a better version and point to it with `duplicate_of`. Most of those come from the Binding walk-through (XFER-BIND), which retells receiving and transfer stories that other agents had already written, and from ASK, which asks about the same events the other areas create. The count in the table includes duplicates. The ids after "copies:" are the duplicates.

The clusters roughly follow material through the lab: arriving, being identified, moving between containers, sitting in places, ageing, being thrown away or leaving, and then the questions people ask about all of it.

| Cluster | What it's about | Scenario ids | Count |
|---|---|---|---|
| receiving_and_qc | Material arrives, waits on hold, and QC lets it in or keeps it out. | RCV-001, RCV-003, RCV-004, RCV-010, RCV-012, RCV-013, RCV-024, RCV-027, RCV-029, RCV-033, RCV-038; copies: XFER-BIND-06 | 12 |
| lot_identity | Telling one batch from another when lot numbers, suppliers and names collide. | RCV-016, RCV-018, RCV-034, RCV-040, EDGE-025, EDGE-035; copies: RCV-017 | 7 |
| double_entry | The same real event gets recorded twice: a delivery, a robot log, a retried upload. | RCV-011, EDGE-023; copies: XFER-029 | 3 |
| barcode_is_not_container | Labels fall off, get typed by hand, get reused or printed twice, so the barcode can't be the tube's identity. | RCV-019, RCV-020, RCV-021, LOC-005, LOC-006, LOC-007, LOC-008, LOC-027, LOC-034, LOC-039, EDGE-011; copies: XFER-027, ASK-032 | 13 |
| amount_kinds | Amounts come as mass, volume, concentration or unknown, and they change kind when powder becomes liquid. | RCV-002, RCV-005, XFER-014, XFER-BIND-10, EDGE-006, EDGE-028, EDGE-036; copies: RCV-009, XFER-BIND-02, XFER-BIND-07 | 10 |
| split_conservation | Splitting and drawing from a tube can't create liquid, and two people can't spend the same microlitres. | XFER-001, XFER-003, XFER-028, EDGE-009, EDGE-012; copies: RCV-037 | 6 |
| losses_and_dead_volume | Liquid that is gone or out of reach without anyone using it: dead volume, tip losses, evaporation. | XFER-004, XFER-023, XFER-026, EDGE-029; copies: LIFE-034 | 5 |
| well_level_transfers | Hand and robot transfers into and between plates, one well at a time. | XFER-002, XFER-007, XFER-011, XFER-012, XFER-015, XFER-018, XFER-019, XFER-024, XFER-BIND-04, XFER-BIND-08, XFER-BIND-09, XFER-BIND-12; copies: XFER-BIND-03, XFER-BIND-11 | 14 |
| plate_wells | A plate is one container but each well holds its own material, status and history. | RCV-006, RCV-007, RCV-028, RCV-035, XFER-031, EDGE-005; copies: XFER-BIND-01, XFER-022 | 8 |
| robot_run_partial | Robot and instrument runs that stop halfway or report something other than the plan. | XFER-009, XFER-010, ASK-039, EDGE-019, EDGE-022; copies: XFER-008 | 6 |
| made_material | Making something new from inputs: buffers, expressed protein, in-house DNA and targets. | RCV-022, RCV-023, XFER-016, XFER-020; copies: XFER-BIND-05, LIFE-038 | 6 |
| mixed_contents | What's inside a container changes or mixes: pooled wells, top-ups, refills, a plate whose DNA becomes protein. | XFER-013, XFER-021, XFER-032, EDGE-002, EDGE-004, EDGE-034 | 6 |
| wrong_container | The work happened, but against the wrong tube or plate, or with the plate turned round. | RCV-008, XFER-005, LOC-019, EDGE-024; copies: XFER-006 | 5 |
| places_and_moves | Freezers, racks, boxes and slots, and how things move between them. | LOC-001, LOC-002, LOC-003, LOC-004, LOC-012, LOC-013, LOC-015, LOC-021, LOC-022, LOC-026, LOC-028, LOC-035, EDGE-021; copies: EDGE-003 | 14 |
| location_confidence | The recorded place is a claim from the last scan, and it goes stale when moves aren't scanned. | LOC-009, LOC-011, LOC-014, LOC-016, LOC-024, LOC-030, LOC-033, LOC-038, ASK-011, ASK-033; copies: ASK-009, ASK-010 | 12 |
| physical_count | Someone counts what's really there and it doesn't match the records. | LOC-010, LOC-020, LOC-023, LOC-037, LOC-040; copies: ASK-021 | 6 |
| late_facts | Facts arrive late, out of order, back-dated, or with confusing clock times. | RCV-036, RCV-039, LOC-029, ASK-017, ASK-019, EDGE-008, EDGE-010, EDGE-018, EDGE-038; copies: LOC-025, LIFE-036 | 11 |
| corrections_and_history | Fixing mistakes without erasing them, and showing who changed what. | XFER-030, LIFE-039, ASK-016, ASK-018, ASK-020, ASK-026, ASK-027, EDGE-007, EDGE-020 | 9 |
| expiry_clocks | Each container can have several expiry clocks, started by different events, and the earliest wins. | RCV-030, RCV-031, XFER-017, LIFE-001, LIFE-002, LIFE-003, LIFE-005, LIFE-006, LIFE-007, LIFE-010, LIFE-014, LIFE-016, LIFE-031, ASK-008, EDGE-026, EDGE-037; copies: LOC-031, LIFE-030, LIFE-037, ASK-007 | 20 |
| storage_exposure | Freeze-thaw cycles, warm freezers, benches overnight and broken cold chains. | RCV-014, LIFE-008, LIFE-009, LIFE-011, LIFE-012, LIFE-013, LIFE-024, LIFE-029, LIFE-033, ASK-024, EDGE-015; copies: LOC-032 | 12 |
| usable_reasons | Why something that exists can't be used, with every reason listed and each one cleared on its own. | RCV-032, LIFE-015, LIFE-035, ASK-001, ASK-002, ASK-025, ASK-038, EDGE-014, EDGE-027, EDGE-031 | 10 |
| disposal_with_contents | Containers thrown away with material inside, on purpose, by rule, by mistake or without a scan. | LOC-036, LIFE-004, LIFE-017, LIFE-018, LIFE-019, LIFE-020, ASK-035, EDGE-016, EDGE-032; copies: XFER-BIND-13 | 10 |
| leaves_the_lab | Material shipped to customers, partners or another site, and sometimes sent back. | LOC-017, LOC-018, LIFE-021, LIFE-022, ASK-040, EDGE-013; copies: LIFE-023 | 7 |
| counted_consumables | Tips, plates, sensors and chips that are counted, not measured, and some of which wear out or expire. | RCV-025, RCV-026, XFER-025, LIFE-025, LIFE-026, LIFE-040, ASK-029, EDGE-030 | 8 |
| new_material_types | A new kind of material arrives with rules and units we haven't seen. | LIFE-028, EDGE-017 | 2 |
| lineage_forward | A batch turns out bad, and we need everything made from it and every result it touched. | RCV-015, LIFE-027, ASK-012, ASK-013, ASK-034, EDGE-001, EDGE-033; copies: LIFE-032 | 8 |
| lineage_backward | Starting from a result or a well, find exactly what went into it. | ASK-006, ASK-014, ASK-015, ASK-031 | 4 |
| planning_numbers | Numbers the planning system and re-run planners need, including for future dates. | ASK-003, ASK-004, ASK-005, ASK-028, ASK-030; copies: XFER-BIND-14 | 6 |
| lab_reports | Looking back over months: waste cost, error rates by person or robot, cost per experiment, supplier quality. | ASK-022, ASK-023, ASK-036, ASK-037 | 4 |

## A note on noise_ref

53 scenarios got a `noise_ref`. In almost every case the agents set "forgot to record it" rates far above what the research found. The noise model's `step_not_recorded` is 0.3 to 1 percent per step, while the drafts use 3 to 40 percent for things like forgetting to scan a child tube, skipping a scan on the way back to the freezer, or leaving out a buffer lot. Some of that gap may be real: forgetting the solvent lot is a habit, not a slip, and the human-reliability tables weren't measured in research labs. But the sim should start from the noise model and treat the agents' higher numbers as the top of a sweep. Other mismatches: freezer failure (agents used 0.5 and 1 per year, the model says about 0.1), frosted barcodes (0.15 for -80 tubes against a top of 0.08), rack no-reads (0.03 against a top of 0.01), a robot misreading a plate barcode (0.003 against about 0.000005 for a true misdecode), and evaporation on an open plate (0.2 to 0.6 µL per hour against a measured 0.9).

## Design pressure

What each cluster forces in the data model, and where the agents didn't agree.

### receiving_and_qc

A lot needs a status that starts as "on hold" and only a recorded QC result can change it, and a failed lot stays in the records. A QC retest is a second result that replaces the first, not an overwrite.

### lot_identity

A lot is identified by supplier plus lot code plus our own id, never by the printed code alone, and a lot is separate from each delivery of it. The agents disagreed on QC carry-over: RCV-034 lets new vials of an already-checked lot inherit its QC, while EDGE-034 and the EDGE notes want QC tied to what was actually sampled. We need to pick one and say so.

### double_entry

Every physical action needs a stable identity (a delivery reference, a robot run plus step number) so a second copy is recognised and not counted again. A duplicate is undone by a correction that stays visible, not by a delete.

### barcode_is_not_container

A container has its own id, and barcodes are names it holds for a period of time. A container can have several barcodes, and a barcode can point to only one live container at a time. The agents disagreed on what to do with a clash: LOC-006 would refuse the second registration, while EDGE-011 and ASK-032 assume the clash is already in the lab and say no amount may change until a person picks the right tube.

### amount_kinds

Quantity has to be stored with its unit and kind (mass, volume, count, activity), and concentration is a separate measurement, not a quantity. Claimed values (the CoA) and measured values are kept side by side. An unknown amount stays unknown, never zero and never "the tube's capacity".

### split_conservation

A split or transfer is one run with inputs and outputs, saved together, and the system checks that outputs don't add up to more than went in. The agents disagreed on what happens when they do. XFER-003 says never block, because the liquid already moved: save it and flag the negative balance. XFER-001 says refuse or flag, and EDGE-012 says the impossible children must not count as usable. EDGE-009 adds that two people drawing on the same last 50 µL at once can't both be accepted as normal. We lean towards saving everything and flagging, with flagged amounts kept out of "usable".

### losses_and_dead_volume

We need an explicit "loss" entry type with a reason (dead volume, tip loss, evaporation), so the books balance without inventing a destination. Dead volume belongs to the container type and makes some liquid held but not usable. The agents used different numbers for it: LIFE-020 says 10 µL a pipette can't get out, XFER-004 implies about 2 µL, the noise model says 5 µL for a 1.5 mL tube, and XFER-011 uses 15 µL for an Echo plate where the research says about 20. EDGE-029 points out that evaporation loses water, not protein, so volume and amount of protein can't always be reduced together.

### well_level_transfers

Transfers are recorded per well, with source well, destination well and volume, and a robot run can produce hundreds of them as one batch. Wells need positions that follow a known layout, including 96 to 384 mappings. Serial dilutions chain from well to well, so a source can be another destination in the same run.

### plate_wells

A plate is one container whose wells are smaller containers, each with its own contents, status and QC. A plate map is imported data that can be wrong and corrected as a whole. An empty well is empty, not "zero of something".

### robot_run_partial

We need to keep the plan and what really happened as separate records, and only what really happened moves material. A run can end as aborted or uncertain, and a missing completion file must never refund liquid that was already used (EDGE-019).

### made_material

Making something creates a new lot with several parent lots, including buffers and mixes, not just the main material. Expression is the clearest case: one plate, 96 new protein lots, each linked to its DNA well and to the mix lot.

### mixed_contents

This is the cluster that adds a fourth idea to material, lot and container: the contents of a container at a given time. A well can hold two lots, a tube can be refilled with something else, and an expression plate keeps its barcode while its contents turn from DNA into protein. Contents have to be a history with every source kept, and QC has to attach to the contents that were sampled, not to the barcode.

### wrong_container

The fix for a wrong scan or a rotated plate is a correction that replaces the wrong entries and remaps lineage, and a rotation should be fixable as one action, not 96. Anything already made from the wrong source has to be re-checked through lineage.

### places_and_moves

Places nest (tube in box in rack in freezer), so moving a box moves everything in it with one record. Slots have a grid that depends on the box type, one slot holds one thing, and nothing can end up inside itself (EDGE-021).

### location_confidence

A location answer is "last seen here, at this time, by this kind of scan", not a plain fact. We need a "location uncertain" state that is different from lost and from disposed, for things like a freezer emptied in a hurry (LOC-011).

### physical_count

A count is its own event with its own findings, and a found item can be one we thought was elsewhere, never registered, or disposed. The agents disagreed on what a count should change: ASK-021 says nothing changes until a person decides, while LOC-040 moves items not found to "location uncertain" straight away. A middle path is that a count may change confidence in a location but not quantities.

### late_facts

Every fact needs two times, when it happened at the bench and when it was recorded, and history has to be replayable in bench order. A late fact can make an earlier balance negative (ASK-019) or change an earlier exposure (EDGE-038), so the affected period has to be rechecked. Times are stored in UTC with the original offset, or clock changes break intervals (EDGE-018).

### corrections_and_history

Nothing is overwritten or deleted. A correction is a new entry that points to the one it replaces, a correction can itself be corrected (EDGE-007), and a cancelled run is reversed by new entries. The person behind an entry is a stable actor record, separate from the login account, so deleting an account doesn't break history (EDGE-020).

### expiry_clocks

Expiry is calculated, not stored as one date. A container can have several clocks at once (supplier date, made plus 7 days, thawed plus 7 days, moved to the fridge), each started by a different event, and the earliest wins. Lifetime rules need versions with a start date. The agents disagreed on rule changes: LIFE-030 applies a shorter rule to existing stock from today, while EDGE-026 leaves open whether new rules apply only to new batches. LIFE-007 also assumes a made buffer can't outlive its components, which is a lab policy we are guessing. EDGE-037 adds that expiry happens with no event written, so "usable" must be worked out at the time of the question.

### storage_exposure

Freeze-thaw counts and warm-ups come from location history: when a tube left the cold and came back, and which freezer it was in during a bad window. A freezer event has to reach every container inside it without touching each one. The agents disagreed on the freeze-thaw limit. LIFE assumed 3 for targets, while the research found vendors don't give a number and the noise model defaults to 1, with a range of 1 to 5. The design should store a limit per material and not assume any one value. ASK-024 adds that a child aliquot inherits its parent's thaws.

### usable_reasons

"Usable" is a view that lists every reason something is blocked, each with its own scope (lot, container, well) and its own way of being cleared. A purity pass mustn't clear a contamination hold (EDGE-027), and passing one assay doesn't qualify material for every use (EDGE-031). Some answers have to be "unknown lot", not a guess (ASK-038).

### disposal_with_contents

Disposal is an event that writes off whatever was left, with a reason, so the leftover counts as discarded rather than used or still in stock. The agents disagreed on whether the system may assume a disposal. ASK-035 says a used BLI plate should stop counting even without a disposal scan, because that material type is always thrown away after use. LIFE-004 has the finished run trigger the disposal. LOC-036 and LIFE-019 expect a scan. We lean towards a rule-based disposal after single-use runs, recorded as its own entry so it can be corrected (EDGE-016 shows why: the "disposed" tube can turn up alive).

### leaves_the_lab

Leaving the lab is its own event, different from disposal, with a destination. The material stays in lineage after it leaves, and a returned tube comes back as a new receipt linked to the outgoing one, held until checked (EDGE-013).

### counted_consumables

Some stock is counted in units (boxes, plates, chips), not volumes, and a few of those items have expiry dates or use counts (sensor regenerations, chip uses). The brief says consumables don't expire, and RCV-026 disagrees for BLI sensors. We'd model "has expiry" as a rule of the material type.

### new_material_types

Material types should be rows with rules (units, storage, lifetime, freeze-thaw limit, light sensitivity), so a small molecule or an enzyme sold in activity units needs no schema change. Converting between unit kinds needs a recorded measurement, and without one the system says it can't convert.

### lineage_forward

Lineage is a graph of transfers and "made from" links that can be walked forward through every input, including buffers and sensors, not just the main material. Links must never form a loop (EDGE-001). The walk has to show what's still in the freezer so it can be put on hold.

### lineage_backward

The same graph, walked from a result well back to supplier lots, certificates, QC results and buffer lots. A plate well must resolve to its customer and experiment even with a smudged label.

### planning_numbers

Usable amounts must be computable for a future date, so expiry is checked against the planned day and not today. Re-run planning needs per-well leftovers on expression plates and the DNA behind them.

### lab_reports

These need a price on each lot, a reason on every loss and correction, and the recorder on every entry. They don't add new structure if the rest is in place, which is why they rank low for us.
