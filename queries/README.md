# Queries

One file per question the lab asks. Each starts with a short note on who asks,
why, and what a trustworthy answer looks like. None of them recalculates
anything on its own: amounts, usability, expiry, locations, lineage and flags
all come from the functions in `schema/05_derived.sql`, so a query can't
disagree with the rest of the system.

To see real answers without running anything, read `examples/`. Each file
there is the output of the query against the demo lab in
`seed/02_demo_lab.sql`, with the command that produced it at the top.

## Which question each file answers

| Question | File | What it shows |
|---|---|---|
| Brief 1: how much do we have, and how much is usable? | `q1_how_much_and_usable.sql` | Per material: held, usable, and the reasons for the gap (expired, failed QC, location uncertain, negative balance, liquid a pipette can't reach). |
| Brief 1a: what's left of a shared target before we reorder? | `q1b_shared_target_left.sql` | Every delivery of the protein with its QC state, every tube still held, what earlier experiments took, and how many runs the rest covers. |
| Brief 1b: numbers for a re-run after data fails QC | `q1c_rerun_numbers.sql` | For each material the step used: what it took last time, usable today, and usable on the re-run date, with the reason when it won't be. |
| Brief 2: what has expired, what expires soon? | `q2_expiring.sql` | Everything expired or expiring within N days, with the clock that decided it, when that clock started and the rule behind it. |
| Brief 3: where is it? | `q3_where_is_it.sql` | For each barcode: path, status, when and how someone last confirmed it, and the trail of moves with how each was recorded. |
| Where should the next count start? | `q3b_not_seen_lately.sql` | Containers nobody has confirmed for N days, and anything a count couldn't find. |
| Brief 4: a batch is bad, what did it touch? | `q4_forward_trace.sql` | From a supplier lot to every lot made from it, every container that held it, the runs, experiments and customer designs it reached, and what's still here to put on hold. |
| Brief 4, the other way: where did this well come from? | `q4b_backward_trace.sql` | From a barcode (and well) back through everything it was made from to supplier lots, with QC and certificate claims, plus the target and buffers on the other side of the same run. |
| Brief 5: who changed what, and when? | `q5_history.sql` | Every event that touched a container, in order, with both times, who, how it was recorded, and whether it still counts or was corrected (by whom, when, why). |
| Brief 5: what did the record say before the change? | `q5b_as_we_knew_it.sql` | The same moment read twice: as the record stood then and as we know it now, plus the late entries that made the difference. |
| What needs a person today? | `q6_flags.sql` | Negative balances, missing robot steps, tubes a count couldn't find, possible duplicate deliveries, and expired or failed material still on a shelf. |
| What did we throw away, and what was it worth? | `q7_waste.sql` | Containers thrown away with material in them, by rule or by hand, with amounts and value where the price is known. |
| What's in this freezer or box? | `q8_whats_in_this_place.sql` | Everything inside a place at any depth, as a tree, with contents, usability and last confirmation. Takes a barcode or a name, and says so when neither matches. |
| How fast are we using it, and how long will it last? | `q9_usage_rate.sql` | What left the stock tubes each week, the average, usable stock now, and how many weeks it covers. Added after the agent lab's procurement agent kept asking. |

## Running them

Load the demo with `./run.sh demo`, then from that psql prompt:

```
\i queries/q1b_shared_target_left.sql
```

or from the shell:

```
psql -d inventory_test -f queries/q4_forward_trace.sql -v supplier_lot=P-2209
```

Every setting has a default, listed at the top of each file. Two settings
appear everywhere:

- `t` is the moment you're asking about. It defaults to the demo's "today",
  21 October 2026 at 17:00, so the examples stay the same whenever you run
  them. In real use you'd pass `-v t=now`.
- `k` is how much of the record to believe, by when it was written down. It
  defaults to now (everything on record). Set it to an earlier moment to see
  what the system said back then; `q5b_as_we_knew_it.sql` does this for you.

## What the demo lab answers show

A few things the example outputs make visible, all traceable to a line in
`seed/02_demo_lab.sql`:

- EGFR: 355 µL held, 225 µL usable. 105 µL of the gap is liquid stuck in the
  bottom of the tubes (10 µL in each 25 µL aliquot) and 25 µL is the aliquot
  the October count couldn't find. At 30 µL a run, the rest covers 7 runs.
- PD-L1: 800 µL held, 315 µL usable, because 400 µL is the lot that failed QC
  and is still in the freezer waiting to go back.
- The re-run planned for 28 October can't use the expression plate: it's
  usable today but expires on the 23rd, and the loading buffer runs out on the
  26th. Running buffer, sensors and EGFR are fine.
- The robot log missing one step shows up twice in the flags, on the well that
  went negative. The source well looks fuller than it is; that's a schema gap,
  written up in `journal/agent-runs/schema-gaps-queries.md`.
- On 24 September the record said the EGFR stock tube held -100 µL. It held
  80 µL: Marco had typed 200 for 20 and corrected it two days later.
  Both versions are still there.
