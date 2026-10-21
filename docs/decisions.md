# Decisions

The scenario agents disagreed with each other in a few places. Each disagreement was a real design choice, so we made it on purpose and wrote down why. Scenario ids point into `scenarios/catalog.yaml`; the full disagreement is described in `scenarios/clusters.md`.

## D1. Taking more than the system thinks is there: record it and flag it

When someone draws 30 µL from a tube the system says holds 25 µL, we save the 30 µL and flag the tube. The liquid is already in the pipette; refusing to record it only makes the records wrong in a new way. The tube's balance goes negative on purpose, which makes the problem visible, and everything in a flagged tube is left out of "usable" until a person resolves it, usually with a corrected volume or a recount.

This also covers splits where the children add up to more than the parent had, and two people drawing on the same last 50 µL at once.
Scenarios: XFER-003, XFER-001, EDGE-012, EDGE-009. Principle 4.

## D2. QC belongs to one delivery of one batch, not to the batch number

If the supplier's lot L-4471 passed QC in March and another box of L-4471 arrives in June, the June box is on hold until it's checked. The box could have warmed up on the way, or the supplier could have reused the lot number. In our system each delivery of a supplier lot is its own batch, linked to the others by the supplier's lot code. Tubes we split from a batch that already passed QC inherit that pass, because they are the same liquid.
Scenarios: RCV-034, EDGE-034, RCV-016.

## D3. Barcode clashes are refused, and if one slips through, both tubes freeze

Registering a barcode that already belongs to a live container is refused. If a clash still turns up in the lab (two pre-printed labels from the same roll, a label stuck on the wrong tube), neither tube can have liquid recorded against it until a person says which is which. A barcode is a label a container wears for a while; it is not the container.
Scenarios: LOC-006, EDGE-011, ASK-032.

## D4. A physical count changes confidence at once, but never amounts by itself

When someone counts a freezer and a tube isn't there, the tube immediately becomes "location uncertain". Amounts only change when a person approves the count's findings, and the approval is a fact of its own with the counted values in it.
Scenarios: ASK-021, LOC-040.

## D5. Changed shelf-life rules apply to existing stock from the day they change

Rules have versions with a start date. If the lab decides loading buffer only lasts 5 days instead of 7, buffer made last week follows the new rule from today on. Questions about the past are still answered with the rule that applied then.
Scenarios: LIFE-030, EDGE-026.

## D6. The expected action is recorded by default; doing something else must be reported

Single-use plates (GFP and BLI) are recorded as thrown away when their run finishes, without anyone scanning the bin. The same idea applies wherever a protocol says what normally happens. The default is a fact marked as coming from a rule, so if the plate later turns up on a bench, that's a visible mismatch and someone has to explain it. We'd rather make the common case free and the exception loud than ask people to record the obvious.
Scenarios: ASK-035, LIFE-004, LOC-036, EDGE-016. Principle 3.

## D7. Freeze-thaw limits are set per protein and source, and they warn rather than block

Sources disagree on how many freeze-thaw cycles a protein survives (1 to 5), and the answer depends on the protein and on who made it and in what formulation. So limits are rules that can be set at three levels, and the most specific one wins:
1. this protein from this supplier product (say, a target from one vendor's catalog number)
2. this protein from any source
3. this kind of material (all target proteins)

If no limit is set at any level, the system still counts the cycles and shows the number, but doesn't judge it. Going over a limit flags the container; it doesn't block it, because the scientist may know the protein is fine.
Scenarios: LIFE-008, ASK-024. Research: `journal/agent-runs/research.md`.

## D8. The simulation starts from researched error rates

The scenario agents guessed that people forget to record a step 3 to 40% of the time. Published human-reliability figures say 0.3 to 1% per step. The simulation starts from the researched numbers in `sim/noise-model.yaml` and uses the agents' higher numbers as a "bad week" setting, so we can show how the system behaves in both.

## D9. Storage rules are time budgets: used time never comes back, and going cold again pauses the clock

"GFP stock lasts a month in the fridge" means a month of fridge time in total, not a month from the first time it went in. Nine days in the fridge, back to the freezer, then out again leaves one month minus nine days. While the tube is back in the freezer its fridge clock is paused and the other clocks decide.

We considered the simpler rule "the clock starts the first time it enters the fridge and never stops". It breaks targets: the 8-hour room-temperature allowance would start the moment someone thaws a tube for 20 minutes to take an aliquot, and the tube would expire that evening even though it's back at -80. A total-time budget is closer to how people in the lab think about it ("this tube has been out for most of a day already") and handles both cases with one rule.
Scenarios: LIFE-002, LIFE-008. Found by test `11_expiry_clocks.sql`; the discussion is in `journal/agent-runs/schema-gaps.md`.

## D10. A robot run that finished normally did its plan; an aborted one did not

When a liquid handler finishes a run, its log should have a line for every step on the worklist. Sometimes one is missing anyway: the robot PC was offline, an upload failed. Treating the step as not done leaves the source well looking fuller than it is, and that's the number a scientist planning a re-expression would trust.

So we apply principle 3. If the run finished normally, a step without a log line is recorded as done, marked as coming from a rule, and flagged "robot step assumed". If the real log line turns up later, it replaces the assumption on its own. If the run was aborted (a tip jam, an emergency stop), nothing is assumed: the missing steps are flagged at both ends, the source wells that may still be full and the destination wells that may be empty, until a person says what happened.
Scenarios: XFER-007, XFER-008, EDGE-022. Found by the demo lab, see `journal/agent-runs/schema-gaps-queries.md` item 1.

## D11. Some flags ask for judgement, and a person can close them

"Possible duplicate delivery" can't tell two real orders of the same supplier lot from one delivery registered twice; only someone with the delivery notes can. The same goes for "seen after it left", "robot step assumed" and "over thaw limit". For these, a person records a review ("two separate orders, DN-601 and DN-644"), and the flag closes from then on. The review is a fact like any other, so asking about the moment before it still shows the flag open. Flags backed by numbers, like a negative balance or a barcode clash, can't be closed this way: they go away when the facts behind them are fixed.
Found by the dice simulation, `journal/agent-runs/schema-gaps-sim.md` item 4.
