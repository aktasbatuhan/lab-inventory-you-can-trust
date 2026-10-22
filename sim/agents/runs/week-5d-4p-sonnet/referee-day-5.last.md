===== discovered/day-5.yaml
- id: AGENT-D5-01
  title: Freezer queries omit contents and then report known boxes as unexpected
  status: "variant of LOC-020"
  story: |
    Given Lena physically put BOX-00078 and BOX-00079 into Freezer F80-1 and recorded both moves.
    When she queried the freezer contents, the inventory returned no rows.
    Then her later count reported 55 expected and 55 found, but also called all 16 boxes unexpected and told her to record moves, including the two moves already recorded.
  real_life_noise:
    - The freezer contains tubes nested inside boxes.
    - The count lists both boxes and individual tubes.
    - A matching tube total appears beside warnings about every box.
  system_should: |
    Resolve freezer contents through containment. Distinguish boxes from tubes in count totals. Check existing moves before recommending more moves, and explain any difference in query scope.
  question_it_answers: Does this freezer count show a real location discrepancy?
  frequency: weekly
  cost_if_wrong: medium
  cost_reason: False warnings waste reconciliation work and can encourage unsupported move records.
  depth: core
  sim_hook: |
    Put and record two filled boxes into a freezer. Query freezer contents, then count boxes and tubes together. Check that known boxes are included and are not reported as unexpected.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0061"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0062"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0067"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0068"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0074"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0082"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0126"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D5-02
  title: Recording only the return hides hours on the bench
  status: "variant of LOC-009"
  story: |
    Given BUF-00047 was in Fridge R1 and SEN-00003 was on Shelf S1.
    When Marco took both to Bench B2, used material and recorded consumption, he recorded neither outbound move.
    Then he returned both after lunch and recorded their destinations, leaving correct final locations but no move records for their time on the bench.
  real_life_noise:
    - Consumption is recorded while movement is omitted.
    - Returning an item to its original place makes the final location look correct.
  system_should: |
    Preserve intermediate location evidence and separate happened time from recording time. Offer reconciliation when use suggests a missing movement. Do not invent an exact bench interval from consumption alone; show unresolved exposure as uncertain.
  question_it_answers: Did correct final locations conceal an unrecorded storage interval?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: Missing warm exposure can make storage history and expiry calculations too reassuring.
  depth: core
  sim_hook: |
    Pick up buffer and sensors, record their consumption without outbound moves, then return them and record only the returns. Check both final location and historical uncertainty.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0079"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0080"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0083"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0084"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0085"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0086"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0133"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0134"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0135"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0136"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D5-03
  title: A typed barcode error leaves a binned tube live until a retry
  status: "variant of LOC-005"
  story: |
    Given Marco had physically binned ALQ-00011-001 with only residual liquid left.
    When he typed its disposal record, the barcode became ALQ-00911-001 and the inventory rejected the unknown identifier.
    Then the real tube remained undisposed in the records until Marco retried successfully several minutes later.
  real_life_noise:
    - A single mistyped digit produces an unknown barcode.
    - Other work happens between rejection and retry.
  system_should: |
    Keep the failed attempt visible and make retrying against the confirmed tube easy. Never treat rejection as completed disposal or apply the event to a guessed barcode.
  question_it_answers: Was the physical disposal eventually recorded against the right tube?
  frequency: daily
  cost_if_wrong: medium
  cost_reason: An abandoned retry leaves ghost stock and an incomplete disposal history.
  depth: core
  sim_hook: |
    Bin a known tube, corrupt one digit in a typed disposal attempt, then retry with the correct barcode. Check that exactly one disposal is recorded.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0087"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0088"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0101"
  source: agent-sim
  run: week-5d-4p-sonnet

- id: AGENT-D5-04
  title: A visibly short delivery produces fewer aliquots than the slip implies
  status: "variant of RCV-029"
  story: |
    Given the delivery slip described TGT-00076 as containing 200 µL.
    When Lena saw substantially less liquid, she registered 145 µL from a visual estimate rather than copying the slip.
    Then she took the QC sample, made three 45 µL aliquots, recorded those actions and told Sara about the short delivery.
  real_life_noise:
    - The first visual estimate was 135 µL and the pickup estimate was 145 µL.
    - The packing slip still said 200 µL.
    - Visual estimates are less precise than their entered numeric values suggest.
  system_should: |
    Preserve the declared amount separately from the observed estimate and its method. Carry the estimated receipt through consumption and splitting, and retain the supplier discrepancy without advertising the missing volume as stock.
  question_it_answers: Was available stock based on the observed delivery or the packing slip?
  frequency: monthly
  cost_if_wrong: medium
  cost_reason: Copying the slip would promise an aliquot the delivery could not supply.
  depth: supported
  sim_hook: |
    Deliver a short-filled vial with a 200 µL slip. Let the receiver inspect it, register an estimate, sample it for QC and split three aliquots. Check quantity provenance and the supplier discrepancy.
  evidence:
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0011"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0019"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0024"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0032"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0035"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0037"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0051"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0060"
    - "sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt L0129"
  source: agent-sim
  run: week-5d-4p-sonnet

===== verdicts/day-5.md
The day ended with close agreement on amounts and locations. The scorer found no major amount errors, missing containers or wrong final locations; remaining numeric differences were small. That clean finish hides two unrecorded trips to the bench, a disposal repaired after rejection, and misleading freezer responses. All assigned tasks were marked done on time, and the log does not show deadline pressure causing omissions.

All line references below are to `sim/agents/runs/week-5d-4p-sonnet/log/day-5.txt`.

Marco took BUF-00047 and SEN-00003 to Bench B2 without recording their outbound moves (L0079–L0080). Consumption was recorded and the afternoon returns restored agreement on final locations, but the intervening bench history remained absent; no response shown flagged that gap (L0083–L0086, L0133–L0136).

ALQ-00011-001 was physically binned before a typing error caused its disposal record to fail (L0087–L0088). The rejection was explicit, and Marco fixed the temporary ghost by retrying with the correct barcode at 08:32–08:33 (L0101).

Lena caught the short PD-L1 delivery instead of copying the slip’s 200 µL. She registered an estimated 145 µL, recorded QC consumption and three aliquots, and told Sara; this avoided a large stock overstatement, although the receipt was still an estimate (L0019, L0024, L0032, L0037, L0051, L0060, L0129).

Two frosted labels interrupted the freezer count. A slot-based inspection failed, but inspections using the expected tube barcodes returned locations and supplier lots; Lena included both tubes in the count and requested relabelling (L0105, L0107, L0115–L0116, L0121, L0126, L0129). No wrong identity is demonstrated.

## Inventory answers that misled or could mislead

The freezer contents query returned zero rows despite Lena seeing 16 boxes there, including two whose moves she had just recorded (L0067–L0068, L0074, L0082). The count then said “55 expected, 55 found” while calling all 16 boxes unexpected and recommending moves, including those already recorded (L0126). These were misleading responses rather than demonstrated physical location errors; Lena’s handover left the box warning for Sara to investigate.

Priya queried experiment names as barcodes and received empty location and history tables (L0010). She subsequently described the expression plates as absent from inventory (L0026). The response established no matching barcodes, not the absence of every plate linked to those experiments; that distinction should have been explicit.

Marco twice said BUF-00047’s inventory balance was about 163 mL, but no query shown returned that figure (L0118, L0139). Priya’s earlier visual estimate was 265 mL before the day’s 40 mL draw (L0009, L0083). The final comparison was about 202 mL physically versus 200 mL recorded, so the claimed large discrepancy was not supported by the closing evidence, and the promised count was not performed.

The target queries correctly excluded the failed-QC vial and separated dead volume from usable stock (L0003–L0004). The flags query also explicitly reported the failed vial, despite the closing score and drift files listing zero flags; those closing numbers do not mean nobody saw a warning during the day (L0007).

Summary: Final stock was close, but missing movement history and misleading query responses remained unresolved after the disposal error was repaired.

