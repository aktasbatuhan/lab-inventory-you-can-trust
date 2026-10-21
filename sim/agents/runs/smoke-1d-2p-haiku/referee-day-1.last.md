===== discovered/day-1.yaml
- id: AGENT-D1-01
  title: A second vial on one delivery note cannot be received
  status: "new"
  story: |
    Given delivery DN-4005 contains EGFR vial TGT-00050 and PD-L1 vial TGT-00051.
    When Lena records the first receipt, it succeeds, but the second fails with
    event_external_ref_key. Four attempts fail, including a typed-barcode retry.
    The failed operation leaves TGT-00051 registered and located but without material.
    Physical QC passes, yet recording that result fails because no material is recorded.
    Then the vial remains physically present with 194.96 µL, while inventory reports
    no contents. Lena escalates the problem, but it remains unresolved.
  real_life_noise:
    - Different products and lots share one delivery note.
    - A failed receipt leaves a container registration behind.
    - Retrying with a typed barcode does not resolve the error.
    - The late delivery arrives after both receiving and QC deadlines.
  system_should: |
    Allow distinct vials on one delivery note while making retries of each receipt
    idempotent. A failed operation must either roll back completely or leave an
    explicit, recoverable incomplete receipt. Show the unresolved contents and QC
    recording problem alongside stock answers, rather than making the vial look empty.
  question_it_answers: Which delivered vials still lack recorded contents or QC?
  frequency: weekly
  cost_if_wrong: high
  cost_reason: Physically present target disappears from stock totals and cannot be released through QC.
  depth: core
  sim_hook: |
    Receive two different products under DN-4005. Retry the second receipt after
    failure, including typed entry. Perform physical QC and try recording its pass.
    Check for recoverable receipt state, retained identity and a visible unresolved item.
  source: agent-sim
  run: smoke-1d-2p-haiku
  evidence:
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0120"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0122"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0124"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0127"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0128"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0129"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0140"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0141"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0154"

- id: AGENT-D1-02
  title: Recording a QC pass leaves its sample volume in stock
  status: "variant of XFER-028"
  story: |
    Given TGT-00050 has a recorded receipt of 200 µL.
    When qc_check removes a 5 µL sample, Lena records the pass but no consumption.
    She then physically splits four 45 µL aliquots and records that split.
    Then the parent contains 14.98 µL, while inventory says 20 µL.
    The missing sample debit remains unflagged.
  real_life_noise:
    - The QC tool removes liquid as part of running the assay.
    - The QC record accepts the outcome without accounting for the sample.
    - Splitting happens after all three tasks are overdue.
    - Lena notices about 15 µL remains and keeps the vial rather than binning it.
  system_should: |
    Make QC sample consumption explicit in the recording workflow. Link the sample
    debit to the assay so it is recorded once, with a destination or a consumption
    reason. Recording a pass alone must not imply that the sample volume remains.
  question_it_answers: How much target remains after QC sampling and aliquoting?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Repeated unrecorded QC samples overstate scarce target and usable leftovers.
  depth: core
  sim_hook: |
    Receive 200 µL, remove 5 µL through qc_check, record the pass, then split
    4 × 45 µL. Assert a nominal 15 µL parent balance when sample consumption is
    recorded, and expose the missing debit when only the QC outcome is entered.
  source: agent-sim
  run: smoke-1d-2p-haiku
  evidence:
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0122"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0138"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0139"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0145"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0148"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0152"

- id: AGENT-D1-03
  title: A recorded return hides an unrecorded trip to the bench
  status: "variant of LOC-009"
  story: |
    Given inventory places ALQ-00011-001 in BOX-00010 slot 1.
    When Marco takes it to Bench B2 without recording the outward move, Lena's
    location query still points to the freezer. She subsequently sees the slot empty.
    Marco returns the tube and records only that return.
    Then the final location agrees, but the recorded trail omits the bench interval.
    Lena later repeats the earlier missing-tube observation in a message to Marco.
  real_life_noise:
    - Two people inspect or use the same stock during overlapping work.
    - Transfers are recorded while the source tube still appears frozen.
    - Recording the return restores the final place without restoring the missing history.
    - An earlier observation is repeated after the tube has been returned.
  system_should: |
    Make outward and return moves easy to record together with their actual times.
    Keep last-confirmed location distinct from current certainty. When an empty-slot
    observation is recorded, retain its time and reconcile it against later sightings.
    Flag or qualify missing storage history rather than inventing an exposure duration.
  question_it_answers: Where was the tube during use, and is a missing-tube report still current?
  frequency: daily
  cost_if_wrong: high
  cost_reason: Correct final locations can conceal missing thaw and storage exposure history.
  depth: core
  sim_hook: |
    Move an aliquot from freezer to bench without record_move. Have another actor
    query its place and inspect its slot. Return it and record only the return.
    Check both the temporary wrong answer and the incomplete storage trail.
  source: agent-sim
  run: smoke-1d-2p-haiku
  evidence:
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0020"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0021"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0031"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0064"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0065"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0135"

- id: AGENT-D1-04
  title: One buffer transfer is also recorded as making new buffer
  status: "variant of EDGE-023"
  story: |
    Given Marco physically transfers 40 mL from BUF-00047 to BUF-00049 once.
    When he records both a transfer and a make using that same source and amount,
    inventory counts two source debits and two destination credits under different lots.
    Then Marco checks both histories and corrects the make event.
    The duplicate is repaired through a retained correction, rather than deletion.
  real_life_noise:
    - Two different recording tools can describe the same physical action.
    - Both entries are individually plausible and leave the source balance positive.
    - Recognising the duplicate requires reading both container histories.
  system_should: |
    Distinguish dispensing existing buffer from making a new batch. Surface a
    possible duplicate when a make closely repeats a transfer with the same source,
    destination and amount, while allowing genuine repeated work. Preserve corrections
    and recompute all affected balances and lineage from them.
  question_it_answers: Was buffer made, or was existing buffer simply dispensed once?
  frequency: weekly
  cost_if_wrong: medium
  cost_reason: Double posting overstates working buffer, understates stock and invents a preparation lot.
  depth: core
  sim_hook: |
    Physically transfer 40000 µL once. Enter record_transfer followed by record_make
    with the same bottle and input. Inspect both histories, correct the make event,
    and verify that only one transfer contributes to balances.
  source: agent-sim
  run: smoke-1d-2p-haiku
  evidence:
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0084"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0087"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0089"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0093"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0094"
    - "sim/agents/runs/smoke-1d-2p-haiku/log/day-1.txt L0097"

===== verdicts/day-1.md
Marco completed his preparation tasks and repaired a double entry. Lena received the delivery late, completed physical QC on both vials, and aliquoted the EGFR, but the inventory blocked the PD-L1 receipt. The final comparison found two substantial amount discrepancies, no final location discrepancies and no flags. That clean location result hides several unrecorded trips to the bench.

### Material differences and repairs

**EGFR QC consumption went silently unrecorded.** QC removed 5 µL from TGT-00050, but the recorded pass did not debit it; after four 45 µL aliquots, the parent held 14.98 µL against 20 µL recorded (L0138–L0139, L0145–L0148). Lena recognised the roughly 15 µL remainder and kept it, but did not reconcile the balance; no flag was raised.

**PD-L1 existed without recorded contents or QC.** TGT-00051's receipt failed four times with `event_external_ref_key`, leaving only a registration; physical QC consumed 5 µL and passed, but recording that pass was refused (L0124, L0127–L0129, L0140–L0141, L0154). The final comparison found 194.96 µL physically present against zero recorded: Lena escalated it to Sara at L0143, but it remained unresolved without an inventory flag.

**The buffer duplicate was fixed.** One physical 40 mL transfer became both a transfer and a make, temporarily doubling the destination credit and source debit (L0084, L0087, L0089). The histories exposed both postings, and Marco corrected event 172 at L0097; this was a human repair, with no automatic duplicate warning shown.

**Temporary locations were missing from the record.** Marco never recorded taking the EGFR aliquot, stock buffer or sensor box to the bench, although he recorded their returns (L0021, L0064–L0065, L0076, L0085, L0104–L0108). Lena likewise took both new targets from the freezer for QC without recording those outward moves, then returned them; EGFR's return was recorded, while PD-L1's earlier freezer location simply remained on record (L0136–L0137, L0151–L0153). Final places matched, but the missing exposure intervals were neither repaired nor flagged.

**New-container prerequisites briefly blocked truthful records.** Marco's plate transfers failed until he registered TP-00048, and Lena's completed split could not be recorded until she registered BOX-00052 (L0041–L0049, L0052–L0060, L0145–L0148). Both gaps were repaired; the tool rejections were visible, but they added work after liquid had already moved.

### Inventory answers that misled, or could have

Lena's location query at L0020 still placed ALQ-00011-001 in the freezer, although Marco had taken it to the bench at L0021; the simulated times establish that order. She found the slot empty at L0031. The answer supplied its old confirmation date, but could not reveal the unrecorded move. Her later message at L0135 repeated that earlier absence after Marco had already returned the tube, so it is not evidence of a final missing tube.

The location answer for TGT-00051 showed it as placed after the failed receipt (L0126). That was correct about location, but could have looked like successful booking if read alone; its history showed only registration, and Lena checked that distinction at L0127.

Marco's morning PD-L1 answer—420 µL usable—was not disproved by a delivery that arrived later (L0109, L0120). He passed on its age and missing run-consumption history at L0116. By day end, however, the scorer found 613 µL physically usable against the same 420 µL recorded; a fresh answer based solely on recorded stock would omit the blocked delivery. No such later stock query appears in the log.

Summary: Two amount gaps remained unflagged, one double entry was corrected, and matching final locations concealed incomplete storage histories.