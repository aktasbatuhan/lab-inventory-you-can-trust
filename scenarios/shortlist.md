# Shortlist: 25 scenarios to go deep on

These are the scenarios that become runnable tests and that the schema has to satisfy first. We picked them by asking four things of each one: how much it costs when the inventory gets it wrong, how often it happens, how hard it pushes on the core design (an append-only ledger of entries, two timestamps on every fact, material and lot and container and contents kept apart, transfers as runs, and "usable" as a view with reasons), and whether it covers one of the brief's five questions or the parts Batuhan flagged: barcode scanning, splitting one tube into many, and throwing away containers with material still inside.

None of the 25 is a duplicate. Where a shortlisted test also covers another scenario, we say so, so the cut list below isn't longer than it needs to be.

## Receiving and identity

| Id | Title | Why it's in |
|---|---|---|
| RCV-003 | QC passes and the lot becomes usable, QC fails and it is blocked but kept | Every target lot goes through this, and it's where "exists" and "usable" first split apart; it also covers the hold from RCV-001. |
| RCV-011 | Same delivery registered twice | Named in the brief, and it tests that one physical event can only be counted once and that the fix is a visible correction (same mechanism as EDGE-023 and XFER-029). |
| EDGE-011 | Two physical tubes carry the same barcode | The clearest proof that the barcode is a name and not the container; no volume may move until a person picks the tube. |
| LOC-007 | Barcode from a thrown-away plate is used again | Joins barcodes and disposal: a reused label must not bring a disposed plate back to life. |

## Splitting and transfers

| Id | Title | Why it's in |
|---|---|---|
| XFER-001 | Scientist splits a target stock tube into single-use aliquots | Batuhan's key case and a weekly one on expensive material; children keep the lot, QC and thaw count of the parent. |
| EDGE-012 | A split creates more liquid than the parent held | The conservation check on a split, and the place where we decide between blocking and flagging. |
| XFER-003 | Pipetting more than the source holds | Shows the ledger never clamps or hides a negative balance, and that the bench is never blocked after the fact. |
| XFER-007 | Liquid handler copies a plate well by well from a worklist | The brief's own example of a robot transfer; a daily run that writes 96 well-level entries as one batch. |
| EDGE-022 | A robot stops halfway through a plate transfer | Separates the plan from what really happened, and only confirmed transfers move material (also covers XFER-008). |
| XFER-020 | Expression turns DNA into protein, so 96 new lots are born | The one step that makes new lots inside an existing plate, which is why contents need their own history (covers XFER-021). |
| EDGE-004 | One well contains two lots of the same target | Tests that contents keep every source, so a later QC failure on one lot reaches the run that used the mix. |

## Places

| Id | Title | Why it's in |
|---|---|---|
| LOC-002 | A whole box moves, and everything in it moves with it | Forces nested places; one scan moves 64 tubes, which is how freezers are actually used. |
| LOC-014 | Last seen is not the same as where it is | Makes every location answer say when it was last confirmed and how, which is the honest answer to "where is it?". |
| EDGE-010 | An offline scanner brings back an old location | Tests the two timestamps on moves: a late sync adds history but can't move a tube back to where it was hours ago (covers LOC-025). |

## Lifetime and disposal

| Id | Title | Why it's in |
|---|---|---|
| LIFE-002 | GFP stock buffer lasts 6 months frozen but only a month once kept in the fridge | Straight from the brief's lifetimes; a move changes the clock, so expiry has to be worked out from history (covers LOC-031). |
| LIFE-031 | What expires in the next 14 days, by the right clock | The brief's question 2, with every clock type in one query and the rule that set each date (covers ASK-007, LIFE-003, LIFE-010). |
| LIFE-017 | Plate thrown away with protein still in the wells, on purpose | Batuhan's disposal case: the leftover has to be written off as discarded, not used and not still in stock. |
| LIFE-004 | GFP and BLI plates are thrown away right after the run | Happens many times a day, and the brief says these plates are single use; tests disposal by rule even when nobody scans the bin (covers ASK-035). |

## The questions people ask

| Id | Title | Why it's in |
|---|---|---|
| ASK-001 | How much Target X do we hold, and how much of it can we actually use? | The brief's question 1, answered as held and usable with every reason for the gap (covers ASK-002 and the scoped holds in EDGE-027). |
| ASK-003 | What's left of a shared target from earlier experiments before we order more? | The brief's own example of a needless reorder of expensive target; it needs usable totals across lots, places and experiments. |
| ASK-005 | Numbers for a re-run after BLI data fails QC | The brief says re-run planners need numbers they can trust; this one checks expiry against the re-run date, well by well. |
| ASK-012 | Bad target lot, find every plate, run and experiment it touched | The brief's question 4, walking forward through splits, plates and runs to customers. |
| ASK-014 | Trace a result back to the exact material | Question 4 the other way, from a result well back to supplier lots, QC and buffer lots. |
| ASK-016 | Who changed this tube's volume, and what did it say before? | The brief's question 5 almost word for word; every entry shows who, what, and both times. |
| ASK-017 | What did we believe last Tuesday? | The test that only works with two timestamps: what the record said then versus what we now know was true then. |

## What we're not doing deep, and why

These are notable scenarios that the model should still handle in principle, but that we won't turn into tests or let drive the schema. This list feeds the "what we cut and why" document.

| Id | Title | Why not deep |
|---|---|---|
| RCV-015 | Supplier recalls a lot | Uses the same forward walk as ASK-012; the only new part is walking through a made buffer, which the lineage design covers anyway (same for EDGE-033). |
| EDGE-023 | An import retry looks like another physical transfer | Same mechanism as RCV-011, a stable identity per physical action; one test of it is enough. |
| EDGE-009 | Two people withdraw from the last 50 microlitres | A real concurrency problem, but a single-user prototype can't show it honestly; we describe the database-level fix instead. |
| EDGE-027 | A QC pass and contamination hold arrive together | We design holds with their own scope and test that through ASK-001; racing two people on one lot is a concurrency test we're not building. |
| LIFE-008 | Target aliquot is thawed, used, and refrozen | Freeze-thaw counts come from location history we already store; the limit per material is unknown (sources say 1 to 5), so a deep test would mostly test a guess. |
| LOC-011 | Freezer breaks down and everything is moved in a hurry | Rare, and needs a "location uncertain" state plus freezer monitor data we don't know Adaptyv has; we keep the state and skip the test (same for LIFE-012). |
| RCV-008 | Plate map applied rotated 180 degrees | Rare and costly, but the fix is a batch correction we already need for wrong scans; a separate test adds little. |
| EDGE-017 | A new enzyme is sold in activity units | Material types as rows covers the brief's ask; converting units needs assay context we don't have, so we only show that the system refuses to guess (same for LIFE-028). |
| XFER-023 | Evaporation from an open plate | Real and measured, but tracking it continuously is more than the lab needs; a volume correction with a reason handles it. |
| ASK-022 | How much did we lose in the last quarter, and on what? | A report on top of the ledger, not a new piece of structure; finance and error-rate reports (ASK-023, ASK-036, ASK-037) go with it. |
| LOC-018 | Material moved to another Adaptyv site | Adaptyv's London lab opens in Q4 2026, so this will be real soon. Places already nest, so a site is just one more level at the top and moving between sites is a move plus a shipment. We support it in the model but don't test it deeply (same for LIFE-023). |
| LIFE-026 | BLI sensor tray regenerated a few times, then retired | Use counts on consumables are a small rule on the material type; tips and chips are counted by the box, not tracked one by one. |
