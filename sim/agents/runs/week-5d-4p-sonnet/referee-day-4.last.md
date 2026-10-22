===== discovered/day-4.yaml
- id: AGENT-D4-01
  title: Recording the return hides an unrecorded afternoon on the bench
  status: "variant of LOC-003"
  story: |
    Given BUF-00047 is recorded in Fridge R1 and SEN-00003 on Shelf S1.
    When Marco takes both to Bench B2 around 08:22 without recording either move,
    then returns them around 13:46 and records only the returns.
    Then their final locations agree, but the inventory history misses over five
    hours on the bench, including the buffer's time outside cold storage.
  real_life_noise:
    - Consumption is recorded while the outbound moves are omitted.
    - Recording the returns makes the final location comparison look clean.
  system_should: |
    Keep location history separate from current location. Use consumption and
    return records as prompts to reconcile missing movements. Accept the actual
    movement times later, preserving when they were recorded. Show uncertainty
    in storage exposure until the missing interval is resolved.
  question_it_answers: Does a correct final location hide an unrecorded period outside storage?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Missing bench time can distort storage budgets and misdirect colleagues.
  depth: core
  sim_hook: |
    Pick up a buffer and sensor box, record their use but omit outbound moves,
    then return both and record only the returns. Compare historical locations
    and storage exposure as well as final locations.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0067"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0069"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0073"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0075"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0098"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0099"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0100"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0101"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D4-02
  title: An empty barcode lookup becomes a claim that experiment plates are unregistered
  status: "new"
  story: |
    Given Priya needs the expression plates for EXP-05 through EXP-08.
    When she passes those experiment IDs to where_is_it as barcodes,
    the inventory returns empty location and history tables.
    Then she reports that the plates are absent from the inventory.
    The lookup establishes no matching barcode records; it does not establish
    whether plates exist under other identifiers or are linked to those experiments.
  real_life_noise:
    - A person knows the experiment ID but not the physical plate barcode.
    - Empty tables give no explanation of what was searched or what remains unknown.
  system_should: |
    State explicitly which identifiers did not match. Distinguish a barcode
    lookup from an experiment-to-container search, and offer the latter when
    supported. Do not let an unmatched identifier stand as evidence that no
    associated plate was registered or physically exists.
  question_it_answers: Does no barcode match mean that this experiment has no recorded plate?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: An unsupported absence claim can trigger unnecessary expression work or delay a re-run.
  depth: core
  sim_hook: |
    Ask for an experiment's expression plate using the experiment ID in the
    barcode field. Check that the response explains the unmatched identifier
    instead of silently returning an apparently conclusive empty table.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0012"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0050"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0102"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D4-03
  title: Stock totals support a purchasing decision without a measured run rate
  status: "variant of ASK-036"
  story: |
    Given Jonas must decide whether target stock covers the next two weeks.
    When shared_target_left reports usable amounts but no experiment consumption,
    average use per run, or runs covered.
    Then Jonas closes the task without ordering, using an estimate of one tube
    per day per target. Later, Marco records eight target transfers for EXP-10,
    but those transfer calls carry no experiment identifier.
  real_life_noise:
    - Accurate container balances can coexist with incomplete experiment attribution.
    - A purchasing deadline still requires a decision when coverage is unknown.
  system_should: |
    Preserve the distinction between known stock and unknown coverage. Explain
    missing consumption attribution, provide a supported way to associate plate
    transfers with experiments, and label any assumed demand rate separately
    from measured use. Do not present an assumed rate as established coverage.
  question_it_answers: Can we justify two weeks of cover when consumption is not linked to runs?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: Unsupported demand estimates can cause either stockouts or unnecessary purchases.
  depth: core
  sim_hook: |
    Record target transfers without experiment attribution, ask for stock and
    run coverage, and require a purchasing decision. Check that unknown coverage
    stays explicit despite accurate stock balances.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0003"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0006"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0016"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0055"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0066"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0079"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D4-04
  title: Temporary frost makes recorded stock hard to identify
  status: "variant of LOC-005"
  story: |
    Given the inventory lists ALQ-00038-002 as usable in BOX-00037 slot 2.
    When Priya looks, its label is frosted and unreadable, so she asks Marco
    to use other tubes and rescan or relabel it.
    Then Marco can read the same tube's label on a later look.
    A separate box label is also unreadable during Priya's freezer inspection.
  real_life_noise:
    - Label readability changes between observers and inspection times.
    - Stock remains present even when its identity cannot be confirmed by sight.
  system_should: |
    Keep a no-read distinct from an empty slot or a missing container. Support
    recording the observation and confirming identity later without creating a
    replacement container record. Keep physical identification confidence
    separate from the recorded amount and QC status.
  question_it_answers: Can someone confidently identify the usable stock the inventory lists?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Unreadable labels cause avoidable searches and can encourage unsupported substitutions.
  depth: supported
  sim_hook: |
    Frost a tube label for one inspection and clear it for another. Check that
    both observations can be reconciled against the same container identity.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0004"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0024"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0025"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0050"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0082"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-4.txt L0088"
  source: agent-sim
  run: week-5d-4p-sonnet

===== verdicts/day-4.md
The day ended with good agreement on stock and current locations. The scorer found no material amount errors, missing containers or misplaced items, and no flags. Small volume differences were ordinary pipetting noise. All assigned tasks were marked done on time, but the clean ending hides missing movement history and unresolved planning evidence.

Marco took BUF-00047 and SEN-00003 to Bench B2 around 08:22 without recording either outbound move (day-4.txt L0067, L0069). He returned them around 13:46 and recorded the returns (L0098–L0101). Their current locations were fixed, but over five hours on the bench remained absent from inventory history. No flag was reported.

The frosted tube was an identification problem, not a demonstrated stock loss. Priya could not read BOX-00037 slot 2 and requested alternatives; Marco later read ALQ-00038-002 there (L0024, L0050, L0082). His message resolved that tube's identity for Priya, but no identification observation was recorded in inventory. The frosted box seen at L0025 remained unresolved in the handover.

The failed PD-L1 delivery was handled correctly. Lena recorded its QC sample and failure, kept it unsplit, and recorded its move to Fridge R1 (L0029, L0033, L0035, L0059, L0065). A failed QC status does not require a separate discrepancy flag. Likewise, the EGFR parent was binned with about 15 µL remaining; its disposal was recorded, so the word “empty” in the note is imprecise rather than evidence of missing stock (L0054, L0058).

### Inventory answers that misled or could mislead

The clearest problem was the plate search. Priya supplied EXP-05 through EXP-08 as barcodes and received empty tables (L0012). She then reported that the plates were absent from inventory (L0050, L0102). That answer did not distinguish unmatched experiment IDs from missing plate records. The log does not establish whether those plates physically existed.

The stock queries correctly left consumption per run and coverage unknown (L0003, L0006). Jonas nevertheless concluded that stock exceeded two weeks of demand using an estimated daily tube rate (L0016). No stockout occurred that day, but the coverage claim was an assumption, not an inventory result.

The expiry answer was useful: it gave BUF-00049's exact deadline, and Priya warned that a 17 September re-run would need fresh buffer (L0009, L0050). There is no evidence that deadline pressure caused a recording omission.

Summary: Final stock agreed, but missing bench history and weak search and consumption evidence left planning less reliable than the task completion figures suggest.