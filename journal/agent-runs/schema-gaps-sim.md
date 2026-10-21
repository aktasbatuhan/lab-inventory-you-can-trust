# Schema gaps found by the simulation

Written while building `sim/` (the dice lab and its scorer). Nothing in `schema/`
was changed; each item says what the simulation needed, why the schema got in
the way, how the simulation works around it, and the smallest fix we can see.
Numbers come from a 4-week run at 768 designs a week (about 23,000 recorded
calls, 16,000 containers counting wells).

## 1. usable() and flags() are slow, though every piece they're built from is fast

At the end of the 4-week run, `usable(t, k)` takes about 90 s and `flags(t, k)`
another 75 s (flags calls usable again for the thaw warnings). The functions it
reads from are each well under half a second on the same data: `balances` 30 ms,
`location` 370 ms, `expiry` 280 ms, `lot_thaws` 55 ms, `condition_stretches`
185 ms, `barcode_clashes` 400 ms.

Why: inside `usable`, the reasons are worked out with correlated subqueries
against CTEs that have no index (`select kind from ex where ex.container_id = ...`,
`select status from loc where ...`, `exists (select 1 from hl ...)`), one lookup
per balance row, so the cost is rows × rows. The new "no shelf-life rule"
warning also calls `rules_for_lots(t, k)` inside the row expression, which
can run once per row.

Smallest fix: left join `ex`, `loc`, `clash` and an aggregated `hl` once, and
compute "lots with a rule" once in a CTE, then build the arrays from the joined
columns. Same answers, one pass. In `flags`, take the thaw warnings from a
`lot_thaws`/`thaw_limits` join instead of calling `usable` a second time.

Workaround in the sim: the default run is small (one week) and scores in
seconds. `score.py --last-only` scores only the final checkpoint on big runs.

## 2. One delivery of several tubes of the same lot can't be received as one lot

A PURE kit is six tubes of one supplier lot. `receive()` creates a new lot on
every call, so receiving six tubes makes six lots, and `flags()` then reports
each pair as a "possible duplicate delivery" (same product, lot and amount,
within 3 days).

Workaround in the sim: receive the whole kit into the first tube and `split()`
it into the other five. The books balance, but the record now says liquid was
pipetted between tubes when it wasn't.

Smallest fix: let `receive()` take `p_lot` (attach a line for an existing lot to
the same receive event), or an array of containers and amounts.

## 3. Custom DNA needs one product row per design

`receive()` finds the material through the product, and a product is one
material under one catalog number. Every Twist gene is a different material, so
the sim inserts a product `twist:<design>` for each design next to its material.
That works but means two reference rows per design before the plate can be
booked in.

Smallest fix: let `receive()` take an optional `p_material` that overrides the
product's material, for made-to-order products ("Twist clonal gene" as one
product, the design as the material).

## 4. "Possible duplicate delivery" can't be dismissed and never ages out

The check compares every pair of lots ever received. Two bottles of water from
the same supplier lot that arrive two days apart are flagged forever, and the
only way to clear the flag is to void one of the receipts, which would be a lie.
The sim's opening stock hit this at once (ten flags before the week started), so
opening deliveries are now spaced four days apart. During a run, orders placed
on Monday and Thursday can still trigger it.

Smallest fix: a "flag reviewed" fact (who, when, which flag and which lots) that
`flags()` subtracts. It keeps principle 2, since nothing is deleted, and gives
people a way to say "checked, not a duplicate".

## 5. Correcting a received amount or one input of a make() creates a new lot

`void()` followed by `receive(..., p_event => fix)` or `make(..., p_event => fix)`
inserts a new lot row. Everything recorded after it (the split into aliquots,
the transfers out of the expression wells) still points at the old lot, whose
creating event is now voided, so the old lot's later entries go negative.

Workaround in the sim: a mistyped received amount is fixed the way decision D4
intends, with `count_place` plus `approve_count` on the tube. A mistyped input to
`make()` is never corrected in the sim.

Smallest fix: let `receive()` and `make()` take `p_lot` so a correction can
re-attach the right lines to the existing lot.

## 6. split() always numbers slots from 1

`split(..., p_into => box)` puts the new tubes in "slot 1" to "slot n" whatever
is already in the box. A second split into the same box claims slots that are
taken, and nothing complains.

Workaround in the sim: one new box per lot.

Smallest fix: a `p_first_slot` argument, or a list of slots.

## 7. "Seen after it left" only listens to sightings

If a tube was recorded as thrown away (say the wrong tube was scanned at the
bin) and is later moved with a scan or pipetted from, nothing is flagged: only
rows in `sighting` count. The container keeps "discarded" as a usable reason, so
its contents silently drop out of the usable numbers.

Workaround in the sim: people scan a tube when they take it out of a box
(`scan()`), which is realistic and makes the flag fire.

Smallest fix: include scanned placements and manual quantity entries after the
exit in the "seen after it left" branch of `flags()`.

## 8. Nothing records evaporation, so expression wells are overstated

Not a bug, but the biggest systematic gap the scorer finds. An expression well
holds 8 µL. Each time the plate sits on a deck it loses about 0.3 µL an hour
(lidded, noise model), twice that at the edges and four times at the corners.
Robot bias (up to ±5% per robot per week in the noise model) adds to it, because
the 8 µL going in and the 3 µL coming out are pipetted by different robots.
After the split-GFP and BLI draws the record says 5 µL where the lab has about
4 on average. Over the 4-week runs the system overstates usable expressed
protein by 22% (normal) and 36% (bad week), and the re-run planner would trust
the bigger number.

Smallest fix, following principle 3: an evaporation rule per container type and
storage condition, applied as a rule-sourced `lose()` when a plate comes back to
cold storage, so it shows and can be corrected like any other default.

## 9. A count can say "not here" but not "it's here, not where you think"

`count_place` lines with `found = true` confirm a location, but don't change it.
When the counter finds a box the record puts in another freezer, the location
stays wrong until someone records a move.

Workaround in the sim: the counter scans the stray item and records a move to
where it really is, then counts.

Smallest fix: a count line can carry the parent and slot it was found in, and
`location()` treats a found line as a placement.
