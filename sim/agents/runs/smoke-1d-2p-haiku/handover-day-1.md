## Lena, day 1 morning

(no handover note: the session ran out of turns at 08:39)

## Marco, day 1 morning

Morning block handover, Marco, Monday 7 Sep. All four tasks are ticked off.

**Done**
- **T1, EGFR target plate:** TP-00048 (BLI plate, Bench B2) has 4 µL of EGFR in each of A1–H1, 32 µL total from ALQ-00011-001 (lot S000). The tube had about 40–45 µL by eye, so I used it as the part-used tube. Eight transfers are recorded.
- **T2, run buffer and sensors:** 40 mL of bli-running buffer is in the new bottle BUF-00049 on Bench B2, taken from BUF-00047 (Fridge R1, now back in the fridge). 32 sensors came from SEN-00003 (Shelf S1, now back on the shelf with 352 left).
- **T3, aliquot return:** ALQ-00011-001 (about 13 µL left) is back in BOX-00010 slot 1 in F80-1. It isn't empty, so I didn't bin it.
- **T4, PD-L1 for Priya:** the inventory shows 420 µL usable across 12 tubes in three lots (S010, S011, S012), all in F80-1. I messaged her with the caveats below.

**Still open / for the 11:00 run**
- The Gator 1 run itself isn't on my list. Plate TP-00048, buffer BUF-00049 and the sensors are on the bench or shelf ready for it.

**Things to know**
- **Double entry, corrected:** I accidentally recorded the 40 mL buffer move twice (a transfer and a make). I marked the make entry (event 172) as wrong, correction event 173. The inventory now shows BUF-00049 at 40 mL and BUF-00047 at the stock level. Worth a glance if anyone checks buffer volumes.
- **New plate and bottle needed registering:** TP-00048 and BUF-00049 were not in the inventory when I first used them. I registered both on Bench B2 before recording anything against them.
- **Volumes don't match the records:** the EGFR and PD-L1 tubes all show 45 µL held in the inventory, but by eye they are 40–50 µL. The records were last confirmed 19–27 Aug. The inventory also has no per-run consumption, so "runs covered" is blank. The 420 µL figure is a best estimate and should be re-checked before anyone plans a run around it.
- **Frosted labels:** two PD-L1 tubes have unreadable labels in the box. I identified them by inspection as ALQ-00013-004 (BOX-00012 slot 4) and ALQ-00029-002 (BOX-00028 slot 2). Someone should relabel them.
- **Sensor box display:** the shelf view showed the sensor boxes as "0 things inside", but inspecting them showed 384 sensors each. Probably a display quirk, but worth knowing.

## Marco, day 1 afternoon

Afternoon block handover, Marco, Monday 7 Sep.

**Task list:** all four original tasks (T1–T4) were ticked off this morning. Nothing new is on the list except Sara's request.

**Sara's request (open):** at 13:45 she asked whether I could be ready for Gator 1 at 10:45, in case the slot moved up 15 minutes. That time had already passed when her message reached me, so I didn't know whether the 11:00 run went ahead. I messaged her at 13:47 asking for the new slot time, or whether the run has already happened. She hasn't replied yet.

**Ready for the run (if it's still pending):**
- BLI plate TP-00048 on Bench B2, 4 µL EGFR in each of A1–H1.
- Running buffer BUF-00049 (40 mL) on Bench B2.
- 32 sensors taken from SEN-00003, which is back on Shelf S1 (352 left).

**Things to watch:**
- **Plate has been out since about 08:20.** TP-00048 has been on the bench for about five and a half hours. Target is fine for a working day, but if the run is delayed much further, someone should decide whether to make a fresh plate.
- **Records checked:** the inventory matches the bench for TP-00048, BUF-00049 and SEN-00003.
- **Morning issues still stand:** the duplicate buffer entry I corrected (event 172), the EGFR and PD-L1 volumes being estimates rather than checked values, and the two frosted PD-L1 labels (ALQ-00013-004, ALQ-00029-002) are all still relevant for whoever picks up the work.

## Lena, day 1 afternoon

Handover, Monday 7 Sep, afternoon block (it's 16:35; the shift ends at 18:00). None of my three tasks is fully closed. The main blocker is one vial the inventory won't accept.

**Done**
- **Delivery DN-4005 (arrived 13:45, late):**
  - TGT-00050 (EGFR-100, lot S050) is booked in and passed QC (SDS-PAGE and A280, clean band). The pass is recorded.
  - TGT-00050 was split into 4 × 45 µL aliquots, ALQ-00053-001 to -004, in the new box BOX-00052 (registered on Bench B1, now in F80-1). The split is recorded.
  - About 15 µL is left in TGT-00050. It is not empty, so I did not bin it. It is in BOX-INBOX in F80-1.
- **Sara's question:** loading buffer BUF-00046 is in Fridge R1, on record, about 53 mL left. Its 7-day life ends 11 Sep 11:00, which is after Thursday's run. Sara has the answer.
- **Marco's question:** I told him where the EGFR aliquots are: BOX-00010 slots 2–4, BOX-00026 and BOX-00037 (lots 6, 12, 18). Nothing looked part-used by eye.

**Open**
- **TGT-00051 (PD-L1-200, lot S051, 200 µL slip):**
  - It passed QC on the bench, but I could not record that QC, because the inventory has no receipt for it.
  - Every attempt to book the receipt (four in total, including after a typed-barcode retry) failed with "duplicate key value violates unique constraint event_external_ref_key". The barcode is already registered (event 179, "put into Goods-in shelf"), but with no lot or product.
  - I did not try to force it through another route. It is physically in BOX-INBOX in F80-1, and I logged the move.
  - It still needs booking, QC recording and splitting into 45 µL aliquots. Sara knows about the duplicate-key error. Someone with inventory access should look at it.
- **T1 and T2** are overdue because the delivery arrived late and the PD-L1 booking is blocked. T3 is partly done, for the EGFR vial only.

**Odd things noticed**
- BOX-00010 slot 1 should hold ALQ-00011-001 according to the inventory, but the box only has slots 2–4. I did not find the tube, so the inventory location may be wrong. Someone should check the box and the trail for that tube.
- The packing slip says 200 µL for each vial. By eye, TGT-00050 read about 180–210 µL and TGT-00051 about 210–220 µL. I recorded the slip amount.
- BOX-INBOX is in F80-1 and was empty when I started. It now holds TGT-00050 (with its 15 µL remainder) and TGT-00051. Both should be filed properly once the inventory is fixed.

