===== discovered/day-3.yaml
- id: AGENT-D3-01
  title: Return records hide an unrecorded trip to the bench
  status: "variant of LOC-003"
  story: |
    Given BUF-00047 is recorded in Fridge R1 and SEN-00003 on Shelf S1.
    When Marco takes both to Bench B2, uses them, and records consumption
    but no outward moves, their recorded locations stay in storage.
    Then he returns both and records the return moves. The final locations
    agree, but the records omit more than five hours on the bench.
  real_life_noise:
    - consumption is recorded while the move to the bench is missed
    - recording the return makes the current location look correct
  system_should: |
    Preserve location history as well as current location. Support adding
    the missing outward moves with their actual occurrence times. Where
    evidence reveals an incomplete storage history, show that uncertainty
    and recompute any affected storage exposure.
  question_it_answers: Does a correct final location hide time spent outside storage?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Missing bench time weakens storage history and can mislead colleagues looking for stock
  depth: core
  sim_hook: |
    Pick up buffer and sensors, record their use, omit outward move records,
    then return both and record only the returns. Compare location histories,
    not just final locations.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0066"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0068"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0079"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0080"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0105"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0108"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0109"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0110"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D3-02
  title: Typed barcode errors delay records for transfers already performed
  status: "variant of LOC-005"
  story: |
    Given Marco has physically filled TP-00065 wells A1 through H1.
    When he records A1 and B1 using typed barcodes, two digit substitutions
    produce unknown container identifiers and both records fail.
    Then he records the other wells and retries A1 and B1 successfully.
    The temporary gap closes without repeating the physical transfers.
  real_life_noise:
    - a typed source identifier changes to ALQ-00021-003
    - a typed destination identifier changes to TP-00064
    - failed entries remain outstanding while other wells are recorded
  system_should: |
    Clearly distinguish a rejected record from an action that did not happen.
    Keep outstanding transfers visible and make retries easy without asking
    the scientist to repeat the physical transfer or duplicating successful records.
  question_it_answers: Can a scientist recover rejected records without losing or repeating completed transfers?
  frequency: daily
  cost_if_wrong: high
  cost_reason: Missing records break well lineage; repeating the pipetting changes the experiment
  depth: core
  sim_hook: |
    Complete eight physical transfers, introduce unknown-barcode typos into
    the first two records, then retry those records after recording the rest.
    Check that each well has exactly one successful transfer record.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0035"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0037"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0053"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0054"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0070"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0072"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D3-03
  title: Experiment identifiers passed as barcodes return an unexplained empty result
  status: "variant of ASK-005"
  story: |
    Given Priya needs expression plates for re-runs of EXP-05, EXP-06 and EXP-07.
    When she passes those experiment identifiers to a barcode location query,
    the inventory returns no locations and no history, without explaining
    whether the identifiers were understood.
    Then she reports that the plates are absent from the inventory and asks
    whether fresh expression has started. The query does not establish whether
    plates exist under other identifiers.
  real_life_noise:
    - the reviewer knows experiment names rather than physical plate barcodes
    - an empty lookup is treated as evidence about the experiment's source plates
    - physical searches cover some places but leave the Hamilton deck unchecked
  system_should: |
    Distinguish an unmatched barcode from an experiment with no linked plates.
    Resolve experiment identifiers through recorded lineage where possible.
    Otherwise explain what could not be resolved and keep physical existence
    unknown rather than implying that re-expression is necessarily required.
  question_it_answers: Does an empty search mean there is no source plate, or that the search used the wrong identifier?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: An unresolved lookup can lead to unnecessary expression work or an unsupported re-run plan
  depth: core
  sim_hook: |
    Ask where expression plates are using experiment IDs in the barcode field.
    Check that the answer explains identifier resolution and does not present
    an empty lookup as proof of physical absence.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0019"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0020"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0023"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0041"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0048"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0049"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D3-04
  title: Stock totals support a purchasing decision without a known consumption rate
  status: "variant of ASK-003"
  story: |
    Given Jonas must decide before the supplier cut-off whether stock covers
    two weeks. The inventory reports 668 µL usable EGFR and 665 µL usable PD-L1,
    but no experiment consumption, average use per run, or runs covered.
    When Jonas assumes about one tube per run despite having no bookings,
    he marks the task complete and places no order.
    Then the purchasing decision rests on an estimate that the query did not verify.
  real_life_noise:
    - stock is increasing because new deliveries keep arriving
    - run bookings have not been supplied
    - missing consumption figures appear as dashes beside precise stock totals
  system_should: |
    State explicitly that two-week coverage cannot be established without
    demand and a supported consumption rate. Keep measured stock separate
    from estimated coverage and show the missing inputs.
  question_it_answers: Do we know stock covers two weeks, or only how much is available now?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: An unsupported coverage estimate can miss a supplier cut-off and delay experiments
  depth: core
  sim_hook: |
    Return valid stock totals but unknown per-run consumption and no bookings.
    Ask a procurement actor for a two-week ordering decision and check whether
    the uncertainty remains explicit.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0002"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0006"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-3.txt L0021"
  source: agent-sim
  run: week-5d-4p-sonnet

===== verdicts/day-3.md
The day ended with close agreement on stock and current locations. The scorer found no large amount discrepancies, missing containers, wrong locations or open flags; usable target totalled 1,580.6 µL physically against 1,578 µL recorded. All listed tasks were marked done on time. The main weaknesses were missing movement history and planning conclusions that went beyond what the inventory established.

### Gaps between the notebooks

**Unrecorded bench time.** Marco took BUF-00047 and SEN-00003 to Bench B2 at about 08:21 without recording either outward move (L0066, L0068). He returned them around 13:45 and recorded the returns (L0105, L0108–L0110), restoring agreement on current locations but leaving the bench interval absent from notebook B; no flag or historical correction is shown.

**Rejected transfer records, recovered.** The A1 and B1 transfers physically happened before their records failed on garbled typed identifiers (L0035, L0037, L0053–L0054). The inventory made both failures explicit, and Marco successfully retried the records at L0070 and L0072 without repeating the pipetting.

The remaining reported amount differences are small pipetting variations. Lena recorded the QC samples, splits and disposal of both parent vials; their roughly 15 µL residues were physically discarded, despite the disposal notes calling the vials empty (L0064, L0067, L0076–L0077, L0092–L0093). That wording is imprecise, but it does not establish missing stock.

### Inventory answers that misled, or could have

**An empty barcode search became a conclusion about expression plates.** Priya searched for `EXP-05,EXP-06,EXP-07` as barcodes and received no rows or explanation (L0023). She then reported no expression plates and said fresh expression was needed (L0048–L0049). Her searches of Bench B2 and Freezer F80-3 did not establish absence across the lab, and she explicitly requested a Hamilton deck check. The answer should have distinguished unresolved experiment identifiers from confirmed absence of their plates.

**Precise stock totals did not establish purchasing coverage.** The target queries supplied usable amounts but left consumption per run and runs covered blank (L0002, L0006). Jonas nevertheless concluded that stock covered any plausible two-week load and placed no order despite lacking bookings (L0021). The inventory did not invent a rate; the unsupported assurance came from Jonas. No resulting shortage is demonstrated.

**The PD-L1 tube count changed in the retelling.** The inventory listed 19 tubes totalling 665 µL (L0011), and Marco's five box checks also show 19 (L0085–L0089). He told Priya that he had checked 18 (L0097), then repeated that count in the afternoon (L0113). This was a communication error, not an inventory discrepancy, and no correction is shown.

Summary: Final stock reconciled closely, but an unrecorded bench interval survived, while ambiguous searches and unsupported coverage estimates weakened planning.

