===== discovered/day-1.yaml
- id: AGENT-D1-01
  title: Familiar material names return no stock matches
  story: |
    Given the inventory holds EGFR, PD-L1 and BLI sensors.
    When Marco and Priya ask how_much using EGFR and PD-L1, the answers contain no rows. Jonas gets the same result for sensor:% and bli-sensors.
    Then other queries find the stock: shared_target_left finds both proteins, and how_much finds sensors with consumable:bli-sensors.
  real_life_noise:
    - People use the names printed on labels rather than internal material keys.
    - An empty result can be mistaken for an empty stockroom.
  system_should: |
    Resolve familiar names to material identities, or explain that the search matched no material and offer valid choices. Keep an unmatched search distinct from a known material with zero stock.
  question_it_answers: Does no result mean no stock, or an unrecognised material name?
  frequency: many-per-day
  cost_if_wrong: high
  cost_reason: A false stock shortage can delay work or prompt an unnecessary order.
  depth: core
  sim_hook: |
    Ask for existing stock by display name and internal key. Compare the answers and require an explicit explanation for unmatched names.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "variant of LOC-033"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0003"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0007"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0009"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0017"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0019"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0028"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0054"

- id: AGENT-D1-02
  title: Returning supplies hides an unrecorded trip to the bench
  story: |
    Given reagents, running buffer and sensors have recorded storage locations.
    When Lena takes three reagent bottles to Bench B1 and later returns them without recording either move, their final locations match again.
    Marco likewise takes running buffer and sensors to Bench B2 without recording departure, then records only their afternoon returns.
    Then the final location check passes even though the records omit their time on the benches.
  real_life_noise:
    - Recording consumption feels sufficient when the bottle will go back to the same shelf.
    - A return scan restores the current location without explaining the missing interval.
  system_should: |
    Preserve departures and returns as separate facts. Show last-confirmed locations honestly, and allow later reconciliation of missing movement intervals. A return alone must not imply uninterrupted cold storage.
  question_it_answers: Can correct final locations conceal missing storage exposure?
  frequency: daily
  cost_if_wrong: high
  cost_reason: Missing warm exposure can make shelf-life calculations too generous.
  depth: core
  sim_hook: |
    Move supplies to a bench, record their use, and return them to their original places. Omit departure records and compare movement history as well as final location.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "variant of LOC-009"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0038"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0039"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0040"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0094"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0096"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0120"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0121"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0122"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0128"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0195"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0196"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0197"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0198"

- id: AGENT-D1-03
  title: A late buffer registration defeats the attempted preparation time
  story: |
    Given Lena physically makes BUF-00049 by 08:36 before registering its bottle.
    When she records the preparation, the tool rejects the unknown bottle. After registration, an attempt with happened_at=08:36 also fails.
    Then a scanner failure adds another retry, and the successful record uses 08:42:08 as the preparation time. Later history shows that time rather than the supplied 08:36.
  real_life_noise:
    - The buffer is already made before the registration requirement becomes apparent.
    - Retrying without the original time gets the quantities recorded but shifts the preparation clock.
  system_should: |
    Support registering an already-used bottle with its real chronology. If backdating requires an earlier registration fact, explain that dependency. Preserve separate preparation and recording times so retries do not move expiry.
  question_it_answers: Does retrying a failed record change when the inventory says material was made?
  frequency: weekly
  cost_if_wrong: medium
  cost_reason: Incorrect preparation times shift expiry and weaken the audit trail.
  depth: core
  sim_hook: |
    Make a buffer before registering its bottle, attempt a backdated preparation record, and retry after a scanner failure. Check the final happened time against the physical action.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "variant of RCV-036"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0069"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0079"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0102"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0106"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0113"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0119"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0178"

- id: AGENT-D1-04
  title: A frosted barcode delays recording while pipetting continues
  story: |
    Given Marco has moved ALQ-00011-002 from the freezer to Bench B2.
    When frost prevents recording the move, he continues pipetting eight wells.
    Then he types the barcode to record the move and all eight transfers. The quantities catch up, but the departure is recorded at 08:16 rather than the physical pickup at 08:07–08:08.
  real_life_noise:
    - Physical work continues while scanner-dependent recording is blocked.
    - A successful retry uses the retry time unless the original time is supplied.
  system_should: |
    Accept a checked manual barcode and retain how it was entered. Let the person preserve the actual action time when recording after a scanner failure.
  question_it_answers: Can a scanner failure be recovered without losing identity or timing?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Delayed records can hide exposure time or remain unfinished.
  depth: core
  sim_hook: |
    Fail the movement scan for a frozen tube, allow physical transfers, then retry by typing the barcode. Check both transfer completeness and departure time.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "variant of LOC-005"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0031"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0042"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0043"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0052"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0063"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0065"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0083"

- id: AGENT-D1-05
  title: Recorded target transfers do not establish experiment consumption
  story: |
    Given Marco records all eight EGFR transfers into the plate prepared for EXP-07.
    When procurement needs a run rate, Jonas has no usable experiment-consumption history and closes his ordering task without a forecast.
    Then, after the supplier cut-off, Marco supplies today's consumption manually. His transfer records identify the plate and wells but do not explicitly link them to EXP-07.
  real_life_noise:
    - Experiment identity appears in task notes and messages rather than structured transfer records.
    - A stock total is available while the consumption rate needed for ordering remains unknown.
  system_should: |
    Make experiment linkage available during plate preparation. Distinguish no linked run history from no consumption, and show unlinked transfers separately. Leave stock coverage unknown when the run schedule or rate is missing.
  question_it_answers: Can procurement estimate stock coverage when consumption is recorded without experiment linkage?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: An unresolved forecast can miss a supplier cut-off and delay later runs.
  depth: core
  sim_hook: |
    Record target transfers to a plate without an experiment link, then request experiment usage and stock coverage before a supplier deadline.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "variant of ASK-036"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0065"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0083"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0089"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0093"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0184"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0193"

- id: AGENT-D1-06
  title: Vials called empty are discarded with target still inside
  story: |
    Given each new target vial has supplied a 5 µL QC sample and four nominal 45 µL aliquots.
    When Lena bins the parent vials, the physical tool reports about 15 µL remaining in each.
    Then she records both disposals with the note "empty vial after split". Disposal is recorded, but the description contradicts the observed contents.
  real_life_noise:
    - A spent source vial is called empty even when it retains liquid.
    - Completion notes repeat the empty-vial description.
  system_should: |
    Derive discarded quantity from the remaining balance regardless of the note. Preserve that waste explicitly rather than treating the word empty as a zero-volume measurement.
  question_it_answers: Is residual target counted as waste when the operator calls its vial empty?
  frequency: daily
  cost_if_wrong: low
  cost_reason: Small residual losses accumulate and can disappear from waste reports.
  depth: core
  sim_hook: |
    Split a vial while retaining a residual amount, then discard it with an empty-vial note. Check that the remaining balance is attributed to disposal.
  source: agent-sim
  run: week-5d-4p-sonnet
  status: "already covered by LIFE-020"
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0157"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0158"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0163"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0164"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0167"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-1.txt L0168"

===== verdicts/day-1.md
The day ended with good agreement on amounts and current locations. The scorer found no material amount errors, misplaced containers or missing registrations, and no flags remained open. That clean finish hides incomplete movement histories, shifted event times and planning gaps. The small pipetting differences do not warrant adverse findings.

### Differences between the notebooks

Lena moved water, HEPES and NaCl to Bench B1 and returned them without recording either journey (L0038–L0040, L0120–L0122). Inventory still reported shelf locations and old confirmations while the bottles were in use (L0085, L0128); the final positions matched, but the missing history went silently unresolved.

Marco took running buffer and sensors to Bench B2 without recording departure (L0094, L0096). He recorded consumption and later recorded their returns, fixing current location but leaving the bench interval absent; no flag exposed it (L0100–L0101, L0128, L0195–L0198).

Frost blocked the EGFR tube's movement record, so Marco pipetted before retrying manually (L0042–L0052, L0063). All eight transfers were eventually recorded, but the recorded departure at 08:16 missed the physical pickup at 08:07–08:08; quantities were fixed, timing was not (L0031, L0065–L0083).

BUF-00049 was physically made by 08:36, but registration and scanner failures delayed its record (L0069, L0079, L0102–L0119). The attempted 08:36 backdate failed, and later history used 08:42:08 as preparation time; the amounts caught up, but the preparation and expiry clock shifted without a flag (L0178).

The two parent vials were described as empty in disposal records despite about 15 µL remaining in each (L0163–L0168). Both disposals were recorded, so this is a misleading description rather than evidence of missing stock; the supplied log does not show a later waste query confirming how the residual was reported.

The EXP-05 expression plate remained unaccounted for, and fresh expression was requested (L0092, L0103, L0186, L0191–L0192). Neither the log nor the drift report establishes a physical plate that the inventory omitted, so this is an unresolved task prerequisite, not a proven discrepancy between the notebooks.

### Inventory answers that misled or could have

The clearest traps were empty material searches. EGFR, PD-L1 and sensor names returned no rows despite existing stock; alternate queries found it (L0003, L0007, L0009, L0017, L0019, L0028, L0054). The agents recovered, but an empty match could easily have been read as zero stock.

Priya's plate-history answer showed only registration, despite transfer-record successes elsewhere in the log (L0065–L0077, L0068). Because calls are interleaved across agents, the evidence establishes an incomplete answer as delivered, without establishing why it omitted those records.

Inventory also placed the already-binned BUF-00046 in the fridge before its disposal was recorded (L0107, L0110, L0114). That gap was repaired, and Marco used the corrected history to update Priya (L0127, L0135). Jonas later repeated advice from his earlier expiry answer without refreshing it (L0011, L0095); that was stale advice, not a fresh false inventory answer.

Finally, missing experiment-consumption history left procurement unable to forecast stock coverage. Jonas closed the task without an order and pursued the missing information after the cut-off, although Marco had recorded today's target transfers (L0089, L0184, L0193). Unknown coverage was appropriately not presented as a calculated number, but the planning question remained unresolved.

Summary: Final stock reconciled well; movement history, event timing and experiment linkage were less reliable than the clean score suggests.