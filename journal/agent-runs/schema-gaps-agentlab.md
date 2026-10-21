# Schema gaps found by the agent lab

Things the AI-agent lab (`sim/agents/`) ran into in the schema. We didn't change the schema; these are notes for whoever does.

## 1. One delivery note can only book in one vial

Found in the smoke run `sim/agents/runs/smoke-1d-2p-haiku`, log lines L0124 to L0129.

`event.external_ref` is unique (`schema/02_facts.sql`, line 19), and `receive()` puts the delivery note there. That stops the same delivery being booked twice, which is what it's for. But a real packing slip often lists several vials, and booking each vial is a separate `receive()`, so the second vial on the same slip is refused with `duplicate key value violates unique constraint "event_external_ref_key"`. Lena tried four times, gave up, and the PD-L1 vial spent the day in the freezer with nothing on record, so its QC result couldn't be recorded either.

The dice simulation never hit this because it gives every vial its own note number.

Two ways out: make the reference unique per delivery line rather than per note (for example the note number plus a line number, or a unique key on note and container), or let one `receive()` call book several containers in one event. The first is the smaller change.

## 2. A QC sample isn't taken out of the tube unless someone records it separately

Found in the same run, L0138 to L0148. `qc()` records the outcome only. The 5 µL the assay used has to be recorded as a separate `consume()`, and nobody did, so the vial shows 5 µL more than it has. This is more a workflow gap than a schema one, but a `qc()` that optionally takes the sample amount and container would make the honest record the easy one.

## Not a schema gap

In the smoke run a refused booking left the vial registered with no lot, because the agent tool registered the container and booked it in as two separate statements. That was our tool, not the schema; `record_receive` now does both in one statement, so a refusal leaves nothing behind.
