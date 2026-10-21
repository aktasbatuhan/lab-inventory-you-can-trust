# LIFE agent run, 2026-10-21

Wrote 40 scenarios in `scenarios/raw/LIFE.yaml` (23 core, 17 supported). They cover the brief's lifetimes (loading buffer 1 week, GFP stock 6 months frozen, expression plates 2 weeks, GFP and BLI plates thrown away after use, DNA and targets for years), thawing and refreezing, freeze-thaw limits, bench and freezer accidents, re-QC and extending expiry, disposal on purpose and by mistake, shipping out, count-limited consumables like tip boxes, BLI sensors and SPR chips, and a first small molecule in DMSO.

The ones that matter most for the data model:

- LIFE-002 and LIFE-010. Expiry is not one field. A container can have several clocks at once (the lot's date, the supplier's date, "thawed plus 7 days", "made plus 1 week"), and the earliest one wins. Moving somewhere warmer can only bring the date closer.
- LIFE-008 and LIFE-012. Freeze-thaw counts and freezer failures have to come from the location history: when a tube left the freezer, when it came back, and where it was during a time window.
- LIFE-011, 015, 018 and 019. "On hold", "failed", "lost" and "disposed" are different states. Each one needs its own event and a person who set it.
- LIFE-014 and LIFE-030. Extending an expiry, or changing a lifetime rule, adds a new record that takes over from a date. Past questions keep getting the answer that was true back then.
- LIFE-028. A new material type has to be added as rows and settings, with its own units and conditions like "keep dark".

Assumptions (also marked in the file): 3 freeze-thaw cycles for targets, 7 days for thawed target at 4 °C, 1 month for GFP buffer once in the fridge, 5 regenerations for a BLI sensor tray, 10 µL that a pipette can't get out, the lab being in Lausanne, a possible second site, and an SPR chip life of 7 days.

Sources: these come from general lab knowledge, not from pages I checked during this run. That covers supplier datasheets that warn against repeated freeze-thaw, Sartorius Octet notes on regenerating sensors with low-pH glycine, and the common rules for DMSO stocks (it freezes at about 18.5 °C and takes up water from the air). Check them before quoting any number in the final docs.
