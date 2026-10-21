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
