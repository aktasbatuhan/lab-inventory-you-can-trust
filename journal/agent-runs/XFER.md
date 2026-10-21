# XFER agent run, 2026-10-21

Output: `scenarios/raw/XFER.yaml`, 46 scenarios. That's 32 general ones (XFER-001 to 032) and 14 that walk the Binding diagram one task box at a time (XFER-BIND-01 to 14).

The general ones cover splitting tubes, pipetting by hand, robots working from worklists, the Echo moving nanolitres, cherry-picking, pooling, reconstitution, dilution, mixing buffers, normalising, expression, evaporation, dead volume, plate formats, duplicate imports and cancelled runs.

## The ones that matter most for the data model

- XFER-020 and 021, expression. One plate keeps its barcode, but what's inside becomes 96 new protein lots. So the contents of a well have to be a history, and not a column on the container.
- XFER-008 and 009, a robot run that fails partway, or a log that doesn't match the plan. We should record what actually happened, one well at a time, and keep the plan alongside it.
- XFER-003 and 026, taking more than the system says is there, and losses along the way. Outputs can be less than inputs. If they come out bigger, we flag it. We never quietly clamp a number.
- XFER-005 and 006, the wrong source plate or a rotated plate. To fix these we add correction entries. We don't edit the old ones. A rotation should be fixable in one step.
- XFER-014, reconstitution. The amount changes kind, from a mass to a volume plus a concentration, and the lot stays the same.
- XFER-011, nL vs µL. Every amount needs its unit stored with it.

## Assumptions

- Twist ships dried DNA in plates. Adaptyv uses cell-free expression, and split-GFP means a small GFP11 tag on the sample.
- An Octet BLI well holds about 200 µL in a 96-well plate and 40 to 80 µL in a 384-well plate.
- Dead volume for an Echo source well is about 15 µL.
- The diagram says "ABE / ART format" for the target stock. We don't know what that means.
- All error rates are guesses meant for the simulation.

## Sources

The case brief and diagram, plus what's generally known about these instruments. We didn't do a web search in this run, so the instrument numbers above need checking before anyone relies on them.
