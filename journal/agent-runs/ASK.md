# ASK agent run

Wrote 40 scenarios in `scenarios/raw/ASK.yaml` (21 core, 19 supported). They cover the brief's five questions (how much and how much usable, viability, location, lineage both ways, history) and the people asking them: scientists, the lab manager, the planning system, the re-run planner, finance, the customer-facing person and an auditor.

The new questions that matter most:

- What did we believe on a past date, as opposed to what we now know was true then (ASK-017). Late entries, back-dated entries and corrections all make these two answers differ, and blame or a missed order can only be explained with the first.
- Re-run sources per well, with expiry measured against the planned re-run date and not today (ASK-005, ASK-030). The 2-week expression plate is what makes this hard.
- How sure are we? Every number should say how many containers under it have open flags (ASK-025), every location is really "last seen, by what" (ASK-009), and some answers have to be "unknown" (ASK-038).
- Did a correction change a result we already delivered (ASK-027)? A swapped well is far worse than a wrong volume.
- Waste cost by cause, and error rates by recorder and by task type (ASK-022, ASK-023). These give the lab something to fix.

The thread running through them: an answer is only trustworthy if it can show why material isn't usable, where the trail breaks, and what changed since.

Assumptions about Adaptyv's internals, marked in the file:
- Target lots aren't mixed inside one experiment without someone deciding to.
- Aliquots are picked oldest first.
- Each target has a maximum number of freeze-thaws.
- The 2-week clock on an expression plate starts when the expression run ends.
- A purchase price is recorded for each lot.
- Runs carry experiment and customer IDs from the planning system.
- Buffer recipes are fixed for each buffer type.
- Plates put on the robot the wrong way round are caught by people later, not by the robot.
