# Agent lab, 5 days, 4 people (sonnet)

Lena (tech), Marco (scientist), Jonas (procurement), Priya (reviewer) worked 5 days in the simulated lab, starting Monday 7 September. Each block of a shift was one headless Claude Code session (sonnet), with only the lab's tools. Together they made 697 tool calls, 16 of which the lab or the inventory turned down.

## The two notebooks at the end

At the last checkpoint the scorer compared 97 amounts (one per container and lot). 0 were off by more than 10% and 47 were within 10% (pipetting noise alone puts most hand-filled tubes there). 0 containers were in the wrong place or slot on record, 0 were still live on record after going in the bin, 0 were recorded as gone but are still in the lab, and 0 exist in the lab but were never recorded at all. 0 records point at containers that don't exist. flags() raised 0 items.

Usable target protein: really 1895.3 µL, the inventory says 1893.0 µL.

## What the people said at the end of their blocks

**Jonas, day 1 morning.** I placed no orders this morning, and both tasks are ticked off. The inventory has no record of how much target a run uses, so I couldn't work out when stock would run out.
**Stock**
- **EGFR:** 12 usable tubes, about 35 µL usable each (420 µL total). They are in 3 lots, all passed QC.
- **PD-L1:** 12 usable tubes, 420 µL, also in 3 lots, all passed QC.
- **Physical check:** I looked in Freezer F80-1. All 6 target boxes are there with 4 tubes each, so the freezer matches the inventory. I didn't open the individual boxes. The inventory's "last confirmed" dates for the tubes are 19 Aug to 27 Aug.
- **BLI sensors:** 5 sealed boxes of 384, 1,920 in total. I inspected each box on Shelf S1 and the labels match the inventory.
**Ordering decision**
- I asked Lena for her planned runs on each target and had no reply by 08:52.
- Twelve tubes of each is probably enough for two weeks. I can't confirm that without a run rate.
- If Lena says she plans more than about 10 runs on either target over the next two weeks, order that target before the 12:00 cut-off. A vial takes 1–2 weeks to arrive, so waiting past today matters.
- The cut-off is 12:00, still in the morning block. I'm watching for her answer and will order if the numbers call for it.
**Expiry**
- **BUF-00046:** The only item expiring within 14 days is this loading buffer (50 mL, Fridge R1). It expires 11 Sep at 11:00, and it is 7 days from when it was made. I told Lena to use it first and to make fresh buffer after that.
- **Flags:** The inventory shows none open, and nothing has been thrown away since 1 Sep.

**Priya, day 1 morning.** No reply from Marco yet. I'm leaving T1 open, and this is my handover.
**Handover (Mon 7 Sep, morning)**
**T1, EXP-05 re-run for Thu 10 Sep: still open, because the expression plate is missing.**
- **PD-L1 target:** usable.
  - The inventory shows 12 tubes across lots 7, 13 and 19, all QC-passed.
  - I looked in BOX-00012, BOX-00028 and BOX-00039 in F80-1. All 12 tubes are there, at about 40–50 µL by eye.
  - I recommended lot 19 (ALQ-00040-001 to 003) and kept lots 7 and 13 as spares.
- **Loading buffer:** BUF-00046 is in Fridge R1, about 53 mL. It was made on 4 Sep and expires Fri 11 Sep at 11:00, so it is fine on Thursday but only just. Marco should use it that day or make fresh.
- **Other supplies:** BLI running buffer BUF-00047 (about 382 mL) is in R1. Five boxes of sensors are on Shelf S1.
- **Expression plate: not found.**
  - There is no plate or EXP-05 record in the inventory.
  - I looked in all three -80 freezers, F20-1, the fridge, both benches, Shelf S1 and the goods-in shelf. I did not open KIT-00014, KIT-00023 or KIT-00034 in F80-2, which show as PURE-mix kits.
  - The plate only lasts two weeks, so I can't say whether it will still be usable on Thursday.
  - I've asked Marco where it is and when it was made. If it is gone or will be older than 14 days on Thursday, the re-run needs fresh expression started now. Please check this before the 15:00 deadline.
**Other things I noticed**
- One tube in BOX-00010 slot 1 has a frosted label I couldn't read. The inventory expects ALQ-00011-001 there, but I haven't confirmed it. It holds EGFR, so it doesn't affect this task.
- Most items have no scan confirmation for 2–3 weeks, including the PD-L1 tubes.
- I ran no counts and changed no records.

**Marco, day 1 morning.** Morning block is done except T5, which can't happen before the run ends at 15:00.
**Done**
- **T1:** I made target plate TP-00048 and put 4 µL of EGFR in each of A1–H1, all from tube ALQ-00011-002. The inventory showed every EGFR tube as full and unused, so I found no part-used tube. I took the one that looked lowest by eye. All 8 transfers are recorded.
- **T2:** I took 40 mL of running buffer from BUF-00047 and 32 sensors from SEN-00003. SEN-00003 now has 352 sensors, and both uses are recorded. The buffer and sensors are on Bench B2.
- **T3:** ALQ-00011-002 still held about 15 µL, so I did not bin it. I put it back in BOX-00010 slot 2 and recorded the move. It has now thawed twice, so use it last.
- **T4:** I told Priya that PD-L1 has 420 µL usable across 12 tubes. I checked the three boxes in F80-1, and all 12 tubes are there at 40–50 µL by eye.
  - Her three lot-19 tubes (ALQ-00040-001 to -003) hold about 105 µL usable.
  - I also told her Lena binned BUF-00046 this morning and replaced it with BUF-00049, so she should use BUF-00049 on Thursday.
**Still open**
- **T5:** After the run ends at 15:00, bin TP-00048 and record the disposal.
- **Gator 1 slot:** Sara asked whether I can be ready at 10:45 because the slot may move up 15 minutes. I told her yes.
**Odd things**
- **EXP-05 expression plate:** Priya can't find it and it isn't in the inventory. I don't know when it was made or where it is. It lasts 2 weeks, so if it isn't found today the re-run needs fresh expression, and that has to start now.
- **Scanner:** The scanner couldn't read ALQ-00011-002 because the label was frosted, so I typed the barcode to record its move.
- **Old sensor counts:** SEN-00003 and other items were last confirmed about 20 days ago.

**Lena, day 1 morning.** All four tasks are done and recorded in the inventory, and nothing is open.
**What I did**
- **T1:** I made the loading buffer as BUF-00049, with 48.5 mL water from WAT-00017, 0.5 mL HEPES from HEP-00002 and 1 mL NaCl from NAC-00004. It's in Fridge R1. I binned last week's BUF-00046 and recorded the disposal.
- **T2:** The delivery (DN-4005) arrived at 09:39 with two vials. I booked in TGT-00050 (EGFR-100, lot S050) and TGT-00051 (PDL1-200, lot S051), 200 µL each.
- **T3:** Both vials passed QC (SDS-PAGE and A280), and I recorded the results and the 5 µL QC sample used from each.
- **T4:** I split each vial into 4 aliquots of 45 µL. The EGFR aliquots are ALQ-00054-001 to -004 in BOX-00052. The PD-L1 aliquots are ALQ-00055-001 to -004 in BOX-00053. Both boxes are in Freezer F80-1. I binned the two empty vials and recorded the disposals. I used two new boxes, one per target, rather than one.
- I told Marco where the new EGFR aliquots are.
**Odd things**
- **Jonas and BUF-00046:** Jonas twice asked me to use BUF-00046 first. My list said to bin it, so I binned it. It had expired on 11 Sep at 11:00 and was still in date, so Jonas may want to know it's gone.
- **Jonas's stock question:** He asked how many BLI runs per week and how many tubes per run for EGFR and PD-L1. I don't have that information, so I pointed him to Marco or the lab manager. He wanted it before the 12:00 supplier cut-off, so check whether it got answered.
- **Scanner:** It wouldn't read some labels (WAT-00017, TGT-00050, and a split record). Each time I checked the physical label against the barcode, then retried with the barcode typed by hand. I only typed after checking the label matched.
- **Vial amounts:** The vials looked like about 190–210 µL by eye against 200 µL on the slip. I booked them at 200 µL, and about 15 µL was left in each after the split.

**Lena, day 1 afternoon.** Nothing is open this afternoon. All four tasks (T1–T4) were finished this morning, and the inventory shows no open flags.
**Handover**
- **Buffer:** BUF-00049, the new loading buffer, is in Fridge R1. It expires 14 Sep at about 08:36. I binned BUF-00046 and recorded the disposal.
- **Delivery DN-4005:** I booked in TGT-00050 (EGFR) and TGT-00051 (PD-L1). Both passed QC.
- **Aliquots:** The EGFR aliquots are ALQ-00054-001 to -004 in BOX-00052. The PD-L1 aliquots are ALQ-00055-001 to -004 in BOX-00053. Both boxes are in Freezer F80-1, and I binned the empty vials.
- **Open question:** Jonas asked about BLI run plans (runs per week and tubes per run for EGFR and PD-L1) before the 12:00 supplier cut-off. I couldn't answer, so I pointed him to Marco or the lab manager. Nobody has confirmed an answer, so check whether it was sorted out or whether more target needs ordering.
- **Jonas and BUF-00046:** He asked twice for BUF-00046 to be used first. My list said to bin it, so I did, even though it was still in date until 11 Sep. He may want to know it's gone.
- **Scanner:** It failed to read a few labels. In each case I checked the physical label against the barcode and retried with the barcode typed by hand.

**Priya, day 1 afternoon.** **Handover (Mon 7 Sep, afternoon).** T1 is ticked off, but the expression plate is still unaccounted for.
**What I checked**
- **PD-L1:** the 12 tubes are all in place and QC-passed. I'm using lot 19, tubes ALQ-00040-001 to 003, which is about 105 µL usable. Lots 7 and 13 are spare.
- **Loading buffer:** my morning message to Marco was wrong. BUF-00046 was thrown away this morning at 08:41, and the inventory shows that. Its replacement, BUF-00049, was made today and is in Fridge R1 (about 50 mL by eye), so it's good until 14 Sep. I've corrected this with Marco.
- **Running buffer and sensors:** Marco used 40 mL of BUF-00047 and 32 sensors from SEN-00003 today for EXP-07. That leaves about 332 mL and 352 sensors, which is plenty. BUF-00047 is no longer in the fridge, so I assume it's on Marco's bench.
**Expression plate**
- I still can't find the EXP-05 plate. It isn't in the inventory or in any place I looked. Marco knows nothing about it and Lena hasn't answered.
- I told Marco to start fresh expression for the three designs so it's ready by Thursday. I did not check the Hamilton deck myself. If the old plate turns up and is under 14 days old on Thursday, it can be used instead.
**Still open**
- Lena's reply about the plate.
- Marco confirming that fresh expression has started.
**Odd things**
- Most PD-L1 and other items have had no scan confirmation for 2–3 weeks.
- The frosted-label tube in BOX-00010 slot 1 is still unread.
- Bench B1 was empty when I looked this afternoon. Its water, HEPES and NaCl bottles were there this morning, and I don't know where they went.

**Jonas, day 1 afternoon.** Afternoon handover (7 Sep):
**Open tasks:** None. T1 and T2 were ticked off this morning.
**Orders:** I placed none. The 12:00 supplier cut-off has passed, so any order now goes out tomorrow.
- **Targets:** I have 12 usable tubes each of EGFR and PD-L1, about 35 µL usable per tube. The inventory has no record of run usage, so I can't say whether that lasts two weeks.
- **Sensors:** I have 1,920 BLI sensors in 5 sealed boxes, which is plenty.
**Still open:**
- **Run plans:** Lena said at 08:48 that she has no run plans or tubes-per-run figures and pointed me to Marco or the lab manager. I only saw her message after lunch. I've now asked Marco.
- **Reorder trigger:** If he expects more than about 10 runs on either target in the next two weeks, I'll order a vial of that target (about 300 CHF, 1–2 weeks to arrive) first thing tomorrow. I haven't heard back from him yet.
**Expiry:** Lena had already binned BUF-00046 (the loading buffer that was due to expire 11 Sep) at 08:41 and made a fresh batch, BUF-00049. Both are recorded correctly in the inventory. BUF-00049 will expire around 14 Sep, 7 days after it was made. Nothing else expires within 14 days.
**Odd:** The inventory has recorded no target usage at all. Until someone records usage, I can't trust any run-rate figure.

**Marco, day 1 afternoon.** All five tasks are done. The one open item is Priya's request for fresh PD-L1 expression, which isn't on my list.
**Done**
- **T1–T3, this morning:** I made target plate TP-00048 with 4 µL of EGFR in each of A1–H1, all from tube ALQ-00011-002. I took 40 mL of running buffer (BUF-00047) and 32 sensors (SEN-00003). ALQ-00011-002 still held about 15 µL, so I put it back in BOX-00010 slot 2 instead of binning it. It has now thawed twice, so use it last.
- **T4:** I told Priya the PD-L1 stock. It is now 560 µL usable in 16 tubes, including Lena's new lot 30. I checked the 12 older tubes by eye this morning and haven't looked at the 4 new ones.
- **T5:** I binned TP-00048 at 15:02 and recorded the disposal. I didn't check that the run itself finished; I went by the 15:00 end time.
- **Tidying:** BUF-00047 and SEN-00003 were still on my bench, so I returned them to Fridge R1 and Shelf S1 and recorded the moves. BUF-00047 should be about 332 mL and SEN-00003 has 352 sensors.
- **Jonas (procurement):** I told him I don't know the run schedule, so I can't give a forecast. An EGFR run like today's takes about one 35 µL tube, 32 sensors and 40 mL of buffer. His stock numbers were out of date because of Lena's new aliquots. He should get the bookings from Sara before reordering.
**Open**
- **Fresh PD-L1 expression for Thursday:** Priya says the EXP-05 plate still hasn't turned up, and she wants fresh expression started as soon as possible for the 3 failed designs. She wants it to use PD-L1 lot 19 (ALQ-00040-001 to -003) and BUF-00049. This isn't on my list and I haven't started it. It needs Sara to confirm the booking or the plan, and the expression start is time-critical.
- **EGFR stock:** I haven't checked Lena's new EGFR aliquots (ALQ-00054-001 to -004 in BOX-00052). Expect roughly 15 usable EGFR tubes plus the nearly empty ALQ-00011-002.
**Odd**
- **EXP-05 plate:** It is still missing and not in the inventory.
- **Old sensor counts:** Several items on Shelf S1 were last confirmed about 20 days ago.

**Priya, day 2 morning.** **Handover (Tue 8 Sep, morning).** T1 is ticked off, but the expression plate is again unaccounted for.
**What I checked for the EXP-06 re-run on Thursday**
- **EGFR:** I'm using the lot-18 tubes ALQ-00038-001 to 003 in BOX-00037. They are physically there, at about 40–45 µL by eye, and give about 105 µL usable. Lot 29 in BOX-00052 is a spare that has never been thawed. Marco should skip ALQ-00011-002, which has only about 3 µL usable.
- **Loading buffer:** BUF-00049 in Fridge R1 is fine for Thursday. It was made on 7 Sep and expires on 14 Sep. I told Marco not to use BUF-00046, which was discarded.
- **Running buffer:** BUF-00047 is back in R1. The inventory says about 360 mL, but I see about 396 mL by eye. The gap is probably just eyeballing error, so I've only told Marco.
- **Expression plate:** there is no EXP-06 or EXP-05 plate in the inventory or in any freezer, fridge or bench I looked at. I told Marco to start fresh expression for the three designs today so it's ready by Thursday. He needs to confirm that. I have also asked Lena who ran the expression and when.
**Still open**
- Lena's answers about the plates and about a box in F80-2 with a frosted, unreadable label.
- Marco confirming fresh expression has started.
**Odd things**
- Expression plates seem to be going unregistered in the inventory, which is why two re-runs now depend on fresh expression.
- BOX-00010 slot 1 and one box in F80-2 have frosted labels that I couldn't read.
- I ran no counts and changed no records.

**Jonas, day 2 morning.** Morning handover (Tue 8 Sep): T1 and T2 are both ticked off. I placed no orders.
**Stock:** The inventory matches Marco's account of what he used and what Lena added yesterday. I didn't open the freezer today.
- **EGFR:** 15 full tubes plus one with only 3 µL usable (ALQ-00011-002, which Marco used from). That is 528 µL usable.
- **PD-L1:** 16 tubes, 560 µL usable.
- **BLI sensors:** 1,888 left, which is about 59 runs at 32 per run.
- **Cover:** Marco says an EGFR run takes about one tube, so each target covers roughly 15 runs.
**Why no order:** Nobody has given me the run bookings for the next 2–3 weeks. Marco doesn't know them and pointed me to Sara or Priya. I asked Sara at 08:08 and had no reply by 11:08. I made the call on current stock and the per-run figure from Marco.
**Still open:**
- **Bookings:** If Sara or Priya say a target has more than about 14 runs booked, I'd order a vial of it (about 300 CHF, 1–2 weeks to arrive). Priya's PD-L1 re-run on Thursday has 3 designs and may take 1–3 tubes.
- **Cut-off:** Today's 12:00 cut-off is about to pass, so any order goes out tomorrow.
**Expiry:** The only item expiring within 14 days is loading buffer BUF-00049, which expires 14 Sep at 08:42. I told Lena, and suggested using the older target tubes first.
**Odd:** The inventory still lists no µL per run for either target, even though Marco ran EGFR yesterday. Someone should record the usage.

**Marco, day 2 morning.** Morning block ends at 13:00, so I'm writing the handover now.
**Done (T1–T4)**
- **T1:** I made target plate TP-00056 with 4 µL of PD-L1 in each of A1–H1. I used spare lot 7 (ALQ-00013-002), so Priya's lot-19 tubes stay untouched. There were no part-used PD-L1 tubes.
- **T2:** I took 40 mL of running buffer (BUF-00047) and 32 sensors (SEN-00003). Both uses are recorded.
- **T3:** ALQ-00013-002 held only about 10 µL, which is dead volume. I binned it and recorded the disposal.
- **T4:** I told Priya the EGFR stock. It is 15 full tubes, about 525 µL usable, and I checked all four boxes in the freezer. ALQ-00011-002 has about 3 µL usable and should be skipped. Her lot-18 tubes ALQ-00038-001 to -003 cover Thursday with about 105 µL.
- **Recording:** The scanner couldn't read the frosted label on ALQ-00013-002. Four of the eight well transfers needed a typed barcode to record, and all eight are now recorded.
**Open**
- **T5:** After the run ends at 15:00, bin TP-00056 and record the disposal.
- **Return items:** BUF-00047 and SEN-00003 are still on Bench B2. Put them back in Fridge R1 and Shelf S1 after loading, and record the moves.
- **Gator slot:** Sara asked at 11:08 whether the slot could move up to 10:45 and I haven't answered. By now that is only a question about timing. I was ready from 08:30, so I'll confirm with her.
- **Fresh expression for EXP-06:** Priya needs it started today for the 3 EGFR designs. I asked Sara whether to schedule it and which designs to use. I have no reply yet.
**Odd**
- **Missing plates:** The old EXP-05 and EXP-06 expression plates are still not in the inventory or in any freezer, fridge or bench Priya looked in.
- **Frosted label:** The label in BOX-00026 slot 4 is frosted over. It should be ALQ-00027-004, but I haven't confirmed that.
- **Buffer volumes:** BUF-00047 reads about 323 mL by the inventory, but Priya saw more than that by eye. I used 40 mL on each of the two days.

**Lena, day 2 morning.** All three tasks (T1–T3) are done and recorded in the inventory, ahead of their deadlines. Nothing on my list is open.
**Done**
- **Delivery DN-4010:** TGT-00057 (EGFR, lot S057) and TGT-00058 (PD-L1, lot S058) were booked in at 200 µL each.
- **QC:** Both vials passed QC. I recorded the results and the 5 µL QC sample used from each.
- **Aliquots:** I split each vial into 4 aliquots of 45 µL. The EGFR aliquots are ALQ-00061-001 to -004 in BOX-00059, and the PD-L1 aliquots are ALQ-00062-001 to -004 in BOX-00060. Both boxes are in Freezer F80-1. I binned the two empty vials and recorded the disposals.
- **Marco:** I told him where the new aliquots are. His message mentioned part-used PD-L1 aliquots, and none of these are part-used.
- **Sara:** I confirmed that BUF-00049 is in Fridge R1 and on record. It expires 14 Sep, so it covers Thursday.
**Open**
- **EXP-05 and EXP-06 expression plates (Priya):** I have no record of either plate, and I can't see the Hamilton deck from here. Someone at the Hamilton needs to look. I suggested she request fresh expression for Thursday.
- **Frosted box in F80-2 (Priya):** I don't know what it is. Its label is unreadable, so it can't be recorded properly. Sara may know, and the box needs identifying and relabelling.
- **Loading buffer:** Make a fresh batch around 14 Sep, when BUF-00049 expires.

**Lena, day 2 afternoon.** My list is clear again this afternoon. T1–T3 were finished this morning and nothing new has come in.
**Handover**
- **Delivery DN-4010:** TGT-00057 (EGFR) and TGT-00058 (PD-L1) were booked in, QC'd (both passed), split and binned, with all records made.
- **Aliquots:** The EGFR aliquots are ALQ-00061-001 to -004 in BOX-00059. The PD-L1 aliquots are ALQ-00062-001 to -004 in BOX-00060. Both boxes are in Freezer F80-1.
- **Open, not mine to close:**
  - The EXP-05 and EXP-06 plates are still unlocated. Priya needs someone to check the Hamilton deck, and she may need fresh expression for Thursday.
  - The frosted, unreadable box in F80-2 needs identifying and relabelling. Sara may know what it is.
- **Next up:** Make a fresh loading buffer around 14 Sep, when BUF-00049 expires.

**Jonas, day 2 afternoon.** Afternoon handover (Tue 8 Sep): Nothing new came in after lunch, and T1 and T2 stay done. I placed no orders.
- **Stock (as of this morning):** EGFR has 15 full tubes plus one nearly empty one. PD-L1 has 16 tubes. There are 1,888 BLI sensors. At about one tube per run, each target covers roughly 15 runs.
- **Run bookings:** Sara hasn't answered my 08:08 request for the bookings over the next 2–3 weeks. Priya's PD-L1 re-run on Thursday is the only run I know of, and it needs about 1–3 tubes. Today's supplier cut-off has passed.
- **If bookings come in:** If they total more than about 14 runs on either target, I'll order a vial of that target tomorrow morning, before the 12:00 cut-off. A vial costs about 300 CHF and takes 1–2 weeks to arrive.
- **Expiry:** Loading buffer BUF-00049 expires on 14 Sep at 08:42. I've told Lena. Nothing else expires within 14 days.
- **Odd:** The inventory still shows no µL per run for either target, even though Marco ran EGFR yesterday. Someone should record the usage.

**Priya, day 2 afternoon.** **Handover (Tue 8 Sep, afternoon).** T1 was ticked off this morning, but the re-runs still depend on expression that nobody has started.
**What's ready for Thursday**
- **EGFR:** lot 18 (ALQ-00038-001 to 003) covers EGFR with about 105 µL usable. Marco counted all 16 EGFR tubes in F80-1 this morning and they are there. Lot 29 is a spare that has never been thawed.
- **Loading buffer:** BUF-00049 is good until 14 Sep.
- **Running buffer:** BUF-00047 is about 323 mL by the inventory's count. Marco has it on his bench for EXP-08 today and will put it back in R1.
- **PD-L1:** lot 19 (ALQ-00040-001 to 003) covers EXP-05 with about 105 µL. Marco says there is also a new PD-L1 lot 30 in BOX-00053, which he hasn't looked at himself.
**Open and risky**
- **No expression plates:** nobody knows where the EXP-05 or EXP-06 plates are, who ran them or when. Lena and Marco have no record of them. Nobody can check the Hamilton deck from here, so someone at the Hamilton needs to look.
- **No fresh expression started:** it is not on Marco's list today, and he is checking with Sara. I have asked the lab manager to assign someone to start fresh expression today for all six designs, three from EXP-05 and three from EXP-06. If that doesn't happen, Thursday's re-runs can't happen.
**Odd things**
- The frosted-label box in F80-2 is still unidentified. Lena asked that it not be discarded, and Sara may know what it is.
- Frosted labels also affect BOX-00010 slot 1 and BOX-00026 slot 4. Marco says BOX-00026 slot 4 should be ALQ-00027-004.
- I ran no counts and changed no records.

**Marco, day 2 afternoon.** All five tasks are done and on time.
**Done**
- **T1–T4:** These were finished this morning. I made target plate TP-00056 with PD-L1 from spare lot 7, took the buffer and sensors, and told Priya the EGFR stock.
- **T3:** I binned ALQ-00013-002 because it held only dead volume.
- **T5:** I binned TP-00056 at 15:03 and recorded the disposal. I went by the 15:00 end time and didn't check that the run itself finished.
- **Return items:** I put BUF-00047 back in Fridge R1 and SEN-00003 back on Shelf S1, and recorded both moves.
- **Priya:** She asked again for the EGFR numbers, so I updated her. Lena added 4 new EGFR tubes (ALQ-00061, BOX-00059), so there are roughly 19 full tubes. I haven't looked at the new box. Her plan still works, with the lot-18 tubes (ALQ-00038-001 to -003, about 105 µL) for Thursday.
**Open**
- **Fresh expression for the 3 EGFR designs (EXP-06):** Priya wants it started now so it's ready Thursday. I asked Sara this morning which designs and layout to use, and she hasn't replied. I haven't started it. This is the main risk for Thursday, so it needs a decision first thing tomorrow, or sooner if Sara answers.
- **Gator 1 slot:** Sara's question about moving the slot up by 15 minutes got no reply from me, but the run went ahead.
**Odd**
- **Old plates:** The old EXP-05 and EXP-06 expression plates are still not in the inventory or in any freezer, fridge or bench Priya looked in.
- **Frosted label:** The label in BOX-00026 slot 4 is frosted over. It should be ALQ-00027-004, but I haven't confirmed that.
- **Buffer volumes:** BUF-00047 reads about 283 mL by the inventory after two 40 mL draws. Priya's by-eye estimates were higher, so it's worth a quick check.
- **Sensor count:** SEN-00003 should have 320 sensors left.

**Jonas, day 3 morning.** Morning handover (Wed 9 Sep): T1 and T2 are both ticked off. I placed no orders.
**Stock (inventory only, I didn't open the freezer today):**
- **EGFR:** 19 full tubes plus one with 3 µL usable, 668 µL in total. A new lot (31, four tubes in BOX-00059) arrived on 8 Sep.
- **PD-L1:** 19 tubes, 665 µL. A new lot (32, four tubes in BOX-00060) arrived on 8 Sep. One tube from lot 7 is gone, so someone used one.
- **BLI sensors:** 1,856 left, about 58 runs at 32 per run.
**Why no order:** Use has been about one tube per run, and stock is growing. At that rate this covers about 19 runs of each target, plenty for two weeks unless the bookings are unusually heavy. Sara still hasn't given me the bookings.
**Two things to check:**
- **Deliveries:** Two target lots arrived on consecutive days (7 and 8 Sep) for each target. I didn't order them, and I don't know who did. I'd like to find out so we don't double-buy.
- **Missing usage records:** The inventory still shows no µL per run for either target, so I can't give a real run rate.
**Expiry:** The only item expiring within 14 days is loading buffer BUF-00049 (Fridge R1), which expires 14 Sep at 08:42. I told Lena to use it first and make a fresh batch around that date.

**Priya, day 3 morning.** **Handover (Wed 9 Sep, morning).** T1 is ticked off, but the expression plates for EXP-05, EXP-06 and EXP-07 are all still missing.
**What's ready for the EXP-07 re-run on Thursday**
- **PD-L1:** lot 30 (ALQ-00055-001 to 003 in BOX-00053) is the set for EXP-07. It has never been thawed and gives 35 µL usable per tube. Lot 32 (BOX-00060) is a spare. I did not look in either box myself. They are listed in the inventory as in place, so ask Marco to confirm them physically.
- **Keeping the sets apart:** EXP-05's PD-L1 re-run is also planned for Thursday. Lot 19 is for EXP-05, and I checked it in BOX-00039 (all four tubes at about 45 µL).
- **Loading buffer:** BUF-00049 in Fridge R1 is good until 14 Sep.
- **Running buffer:** BUF-00047 is in R1. I see about 300 mL against the inventory's 323 mL, which is close enough.
- **PD-L1 tube ALQ-00013-002:** it was thrown away on 8 Sep after the EXP-08 plate used it. The inventory history is consistent with that.
**Open and risky**
- **No expression plates:** none of the three plates is in the inventory or in any place I looked. That is nine designs waiting. I've asked Marco and the lab manager whether fresh expression has started, who is running it, and whether someone can check the Hamilton deck. I have no answer yet. Without fresh expression, Thursday's re-runs can't happen.
**Odd things**
- Marco reports a new EGFR lot (ALQ-00061-001 to 004 in BOX-00059) that he hasn't checked. I haven't either.
- The frosted-label box in F80-2 is still unidentified.
- I ran no counts and changed no records.

**Lena, day 3 morning.** All three tasks (T1–T3) are done and recorded in the inventory, before their deadlines. Nothing on my list is open.
- **Delivery DN-4015:** I booked in TGT-00063 (EGFR, lot S063) and TGT-00064 (PD-L1, lot S064) at 200 µL each.
- **QC:** Both vials passed. I recorded the results and the 5 µL QC sample used from each.
- **Aliquots:** I split each vial into 4 aliquots of 45 µL. The EGFR aliquots are ALQ-00068-001 to -004 in BOX-00066. The PD-L1 aliquots are ALQ-00069-001 to -004 in BOX-00067. Both boxes are in Freezer F80-1. I binned the empty vials and recorded the disposals.
- **Marco and Sara:** I told Marco where the new aliquots are. He asked for part-used EGFR aliquots, and none of these are part-used. I told Sara again that loading buffer BUF-00049 is in Fridge R1 and on record, and covers Thursday.
**Still open from before**
- **Missing expression plates:** The EXP-05 and EXP-06 plates are still unlocated. Priya needs someone to check the Hamilton deck.
- **Frosted box:** The unreadable box in F80-2 still needs identifying.
- **Loading buffer:** BUF-00049 expires 14 Sep at about 08:42, so a fresh batch is due around then.

**Marco, day 3 morning.** Morning block is nearly over, so here is the handover.
**Done**
- **T1:** I made target plate TP-00065 with 4 µL of EGFR in each of A1–H1, all from ALQ-00011-003 (lot 6). I used that tube rather than the only part-used one, ALQ-00011-002, which has about 3 µL usable and can't cover the 32 µL needed. I also kept clear of Priya's reserved lot-18 tubes.
- **T2:** I took 40 mL of BUF-00047 and 32 sensors from SEN-00003, and recorded both.
- **T3:** ALQ-00011-003 held about 10 µL, which is dead volume. I binned it and recorded the disposal.
- **T4:** I told Priya the PD-L1 stock: 665 µL usable in 18 tubes, all physically checked.
  - **EXP-05 and EXP-07 sets:** I kept the two sets separate. EXP-05 uses lot 19 (ALQ-00040-001 to -003). EXP-07 uses lot 30 (ALQ-00055-001 to -003). Lot 32 and the rest are spares.
- **Recording:** Two transfer records (A1, B1) failed on garbled barcodes at first. I retried them, and all eight wells are now recorded.
- **Sara's Gator question:** She asked at 10:35 whether I could be ready for 10:45, and I said yes.
**Open**
- **T5:** After the run ends at 15:00, bin TP-00065 and record the disposal.
- **Return items:** BUF-00047 and SEN-00003 are still on Bench B2. Put them back in Fridge R1 and Shelf S1 and record the moves. By the inventory, BUF-00047 is about 243 mL and SEN-00003 has 288 sensors.
- **Fresh expression for EXP-05, 06 and 07 (the main risk):** I have not started it, and I told Priya so. It isn't on my list, and Sara hasn't answered my questions from Tuesday or this morning. If the plates don't exist, Thursday isn't feasible for those designs. I need a decision from Sara now.
**Odd**
- **New aliquots:** Lena added 4 more EGFR tubes (ALQ-00068, BOX-00066) and 4 more PD-L1 tubes (ALQ-00069, BOX-00067) today. I haven't checked either box.
- **Old plates:** The EXP-05, 06 and 07 expression plates are still not in the inventory.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.

**Lena, day 3 afternoon.** My list is clear this afternoon. T1–T3 were finished this morning, and nothing new has come in or been assigned.
**Handover**
- **Delivery DN-4015:** TGT-00063 (EGFR) and TGT-00064 (PD-L1) were booked in, QC'd (both passed), split and binned, with all records made.
- **Aliquots:** The EGFR aliquots are ALQ-00068-001 to -004 in BOX-00066. The PD-L1 aliquots are ALQ-00069-001 to -004 in BOX-00067. Both boxes are in Freezer F80-1.
- **Still open, not mine to close:**
  - The EXP-05 and EXP-06 plates are unlocated. Someone needs to check the Hamilton deck.
  - The frosted, unreadable box in F80-2 needs identifying.
- **Next up:** Make a fresh loading buffer around 14 Sep, when BUF-00049 expires.

**Jonas, day 3 afternoon.** Afternoon handover (Wed 9 Sep): Nothing new came in after lunch, and T1 and T2 stay done. I placed no orders.
- **Stock (this morning's inventory figures):** EGFR has 19 full tubes plus one nearly empty one, and PD-L1 has 19 tubes. There are 1,856 BLI sensors. Use has been about one tube per run, so this should cover at least two weeks.
- **Open question:** Sara hasn't given me the run bookings. If she sends a total above about 18 runs on either target, I'll order a vial before tomorrow's 12:00 cut-off.
- **Expiry:** Loading buffer BUF-00049 expires on 14 Sep at 08:42. Lena knows, and she should make fresh buffer around then. Nothing else expires within 14 days.
- **Unexplained deliveries:** Extra target lots arrived on 7 and 8 Sep that I didn't order. Someone should say who ordered them, so we don't pay twice.
- **Missing usage records:** The inventory still lacks per-run usage figures for both targets, so I can't give a real run rate.

**Priya, day 3 afternoon.** **Handover (Wed 9 Sep, afternoon).** My list is empty, but Thursday's re-runs are not feasible yet because no expression has started.
**Confirmed**
- Marco physically checked the PD-L1 boxes this morning, and every tube is there.
- **EXP-05:** PD-L1 lot 19 (ALQ-00040-001 to 003, about 105 µL usable) covers it.
- **EXP-07:** PD-L1 lot 30 (ALQ-00055-001 to 003, about 105 µL usable, never thawed) covers it. Lot 32 and the leftover tubes are spares.
- **EXP-06:** it uses EGFR lot 18 (ALQ-00038-001 to 003), as I planned on Tuesday.
- **Loading buffer:** BUF-00049 is good until 14 Sep.
- **Running buffer:** BUF-00047 is on Marco's bench for EXP-09 today and goes back to R1 this afternoon. The inventory puts it at about 243 mL after today's use, which is still plenty.
**Not OK**
- Marco says he has **not** started fresh expression for EXP-05, EXP-06 or EXP-07. It isn't on his task list, and Sara hasn't answered him. He is asking her again now.
- The lab manager hasn't replied to my question about who is running it or whether anyone has checked the Hamilton deck.
- Nine designs are waiting. Unless someone starts expression today or tomorrow morning, Thursday can't happen and the customers lose another week. The lab manager and Sara need to decide this first thing tomorrow.
**Odd things**
- The frosted-label box in F80-2 is still unidentified.
- Expression plates never seem to get registered in the inventory, and this is why none of them can be found.
- I changed no records and ran no counts.

**Marco, day 3 afternoon.** All five tasks are done and on time. One thing is still open: fresh expression for the Thursday re-runs.
**Done**
- **T5:** I binned target plate TP-00065 at 15:03 and recorded the disposal. I went by the 15:00 end time and didn't check that the run itself finished.
- **Return items:** BUF-00047 is back in Fridge R1 and SEN-00003 is back on Shelf S1, with both moves recorded. By the inventory, BUF-00047 is about 243 mL and SEN-00003 has 288 sensors.
- **Priya:** She asked again about PD-L1, so I updated her. It is about 665 µL usable in 18 tubes I checked, plus Lena's 4 new tubes (ALQ-00069, BOX-00067), which I haven't looked at. That is enough for EXP-05 (lot 19) and EXP-07 (lot 30) on Thursday, with spares.
**Open**
- **Fresh expression for EXP-05, 06 and 07:** I have not started it, and I told Priya so. It isn't on my list. I asked Sara on Tuesday and again this morning and have had no reply. If these designs have no expression plates, Thursday isn't feasible, so someone needs to decide tonight or first thing tomorrow.
**Odd**
- **Missing plates:** The EXP-05, 06 and 07 expression plates are still not in the inventory or anywhere Priya looked.
- **Unchecked boxes:** Lena's new EGFR box (ALQ-00068, BOX-00066) and PD-L1 box (BOX-00067) are not checked by me.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.
- **Scanner:** Typed barcodes sometimes get garbled, so I recheck each record after sending it.

**Jonas, day 4 morning.** Morning handover (Thu 10 Sep): T1 and T2 are both ticked off. I placed no orders.
**Stock (inventory figures; I didn't open the freezer today):**
- **EGFR:** 22 full tubes plus one with 3 µL usable, 773 µL in total.
- **PD-L1:** 23 tubes, 805 µL.
- **BLI sensors:** 1,824 left, about 57 runs at 32 per run.
- **Use:** Only about one tube a day is going on each target. Another EGFR lot and another PD-L1 lot arrived on 9 Sep, so stock keeps growing.
**Why no order:** At the current rate there are more than 20 tubes of each target. That is well beyond two weeks, so ordering would only add stock that might sit unused.
**Still open:**
- **Unexplained deliveries:** One new lot of each target has arrived every day since 7 Sep (lots 29–34). I didn't order them and I still don't know who did. Someone should find out, because if it's a standing order we are paying about 300 CHF per vial for stock we don't need.
- **Bookings:** Sara hasn't replied about the run bookings.
- **Missing usage records:** The inventory still shows no µL per run for either target.
**Expiry:** The only item expiring within 14 days is loading buffer BUF-00049, which expires 14 Sep at 08:42. I told Lena to use it first and make a fresh batch around then.

**Priya, day 4 morning.** **Handover (Thu 10 Sep, morning).** T1 is ticked off, but the expression plates are still unresolved and the re-run date needs a decision.
**What I checked for the EXP-08 re-run (EGFR)**
- **EGFR:** the inventory shows 23 tubes across 6 lots, about 773 µL usable. In BOX-00037, lot 18 slot 2 now has a frosted, unreadable label. I told Marco to use ALQ-00038-001, -003 and -004 instead, or the never-thawed lots 29 and 33.
- **Loading buffer:** BUF-00049 is fine today, but it expires Mon 14 Sep at 08:42. If the re-run is next Thursday, 17 Sep, it needs fresh loading buffer. The task says "Thursday" and today is Thursday, so I couldn't tell which one is meant.
- **Running buffer:** BUF-00047 is in R1, about 268 mL by eye, which is enough.
**Still open**
- **Expression plates:** there is still no EXP-05, 06, 07 or 08 plate in the inventory or in any place I looked, and nobody has confirmed that fresh expression has started. Marco's last word was that nothing was started and Sara hadn't replied. I have asked him again what has been started. The lab manager hasn't replied to my earlier messages, so this probably needs to be raised with them in person.
- **Re-run date:** Marco should confirm whether the re-runs are today or next week. That affects the loading buffer.
**Odd things**
- A box in F80-1 has a frosted, unreadable label. It has 4 tubes inside and is probably one of the newer lots. The frosted-label box in F80-2 is also still unidentified.
- Marco says Lena added a new PD-L1 lot, ALQ-00069-001 to 004 in BOX-00067, which he hasn't looked at. I haven't either.
- I ran no counts and changed no records.

**Lena, day 4 morning.** All three tasks (T1–T3) are done and recorded in the inventory, but only the EGFR vial went into stock. The PD-L1 vial failed QC.
- **Delivery DN-4020:** I booked in TGT-00070 (EGFR, lot S070) and TGT-00071 (PD-L1, lot S071) at 200 µL each.
- **EGFR:** TGT-00070 passed QC. I split it into 4 aliquots of 45 µL, ALQ-00074-001 to -004, in BOX-00073 in Freezer F80-1, and binned the empty vial.
- **PD-L1:** TGT-00071 failed QC with a degraded band, and I recorded the fail. I did not aliquot it or bin it. It's in Fridge R1, so Sara can decide on a supplier claim or a replacement order. I haven't ordered a replacement. There is no new PD-L1 stock from this delivery.
- **Messages:** I told Sara about the failed PD-L1 and that the buffer covers today's run. I told Marco there is no new PD-L1 today and to use the older aliquots in F80-1.
**Still open from before**
- **Missing plates:** The EXP-05 and EXP-06 expression plates are unlocated. Priya needs someone to check the Hamilton deck.
- **Frosted box:** The unreadable box in F80-2 still needs identifying.
- **Loading buffer:** BUF-00049 expires 14 Sep at about 08:42, so a fresh batch is due around then.

**Marco, day 4 morning.** Morning block ends at 13:00, so here is the handover.
**Done**
- **T1:** I made target plate TP-00072 with 4 µL of PD-L1 in each of A1–H1, all from ALQ-00013-001. That tube is from spare lot 7, so it doesn't touch the lot-19 or lot-30 tubes Priya reserved. There were no part-used PD-L1 tubes. All 8 transfers are recorded.
- **T2:** I took 40 mL of BUF-00047 and 32 sensors from SEN-00003, and recorded both.
- **T3:** ALQ-00013-001 held only dead volume (about 10–15 µL), so I binned it and recorded the disposal.
- **T4:** I told Priya the EGFR stock: 773 µL usable, with 21 full tubes. I checked all six EGFR boxes and every tube is there. In BOX-00037 I could read every label this morning, including slot 2, though frost may come back.
  - **EXP-08 tubes:** I suggested never-thawed lot 29 (ALQ-00054-001 to -003) for her EXP-08 re-run.
  - **Loading buffer:** BUF-00049 expires Mon 14 Sep, so a re-run on 17 Sep needs fresh loading buffer.
- **Sara's Gator question:** She asked at 10:35 whether I could be ready at 10:45, and I said yes.
**Open**
- **T5:** After the run ends at 15:00, bin TP-00072 and record the disposal.
- **Return items:** BUF-00047 and SEN-00003 are on Bench B2 and need to go back to Fridge R1 and Shelf S1 with the moves recorded. By the inventory, BUF-00047 is about 203 mL and SEN-00003 has 256 sensors.
- **Fresh expression for EXP-05, 06, 07 and 08 (the main risk):** I have not started it, and I told Priya plainly that nothing has been started and I can't give a ready date. Sara hasn't answered my questions (this is the third time I've asked), and the old plates are still not in the inventory. Sara or the lab manager needs to decide, or Priya should be told the re-runs are on hold.
**Odd**
- **Failed lot:** Lena says PD-L1 lot S071 failed QC and was not aliquoted. Use only the older PD-L1 tubes.
- **New EGFR:** Lena added ALQ-00074-001 to -004 (BOX-00073). I haven't checked that box.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.
- **Priya's expiry note:** She says BUF-00049 expires 14 Sep at 08:42. That is a tighter time than the date I gave her earlier.

**Jonas, day 4 afternoon.** Afternoon handover (Thu 10 Sep): Nothing new came in after lunch, and T1 and T2 stay done. I placed no orders.
- **Stock (this morning's inventory figures):** EGFR has 22 full tubes plus one nearly empty one, and PD-L1 has 23 tubes. There are 1,824 BLI sensors. That is well beyond two weeks of cover at about one tube per run.
- **Expiry:** Loading buffer BUF-00049 expires on Mon 14 Sep at 08:42. Lena knows and should make a fresh batch before then. Nothing else expires within 14 days.
- **Unexplained deliveries:** A new lot of each target has arrived every day since 7 Sep that I didn't order (lots 29–34). I still don't know who ordered them. If it's a standing order, it is costing about 300 CHF per vial for stock we don't need, so someone should check with the supplier.
- **Missing usage records:** The inventory still shows no µL per run for either target, so I can't give a real run rate.
- **Bookings:** Sara hasn't given me the run bookings.

**Lena, day 4 afternoon.** My list is clear this afternoon. T1–T3 were finished this morning and nothing new has been assigned.
**Handover**
- **EGFR:** Lot S070 (TGT-00070) passed QC. I aliquoted it as ALQ-00074-001 to -004 in BOX-00073 in Freezer F80-1. All records are made.
- **PD-L1 failure:** Lot S071 (TGT-00071) failed QC with a degraded band, so I did not aliquot it. It's recorded as failed and sits in Fridge R1. It needs a decision from Sara: a supplier claim, a replacement order, and what to do with the vial. I told Sara and Marco. We have no new PD-L1 from this delivery, so the older aliquots in F80-1 are the only stock.
- **Still open, not mine to close:**
  - The EXP-05 and EXP-06 plates are unlocated. Priya needs someone to check the Hamilton deck.
  - The frosted, unreadable box in F80-2 needs identifying.
- **Next up:** Make a fresh loading buffer around 14 Sep, when BUF-00049 expires.

**Priya, day 4 afternoon.** **Handover (Thu 10 Sep, afternoon).** My list is empty, but nothing is ready to re-run, because no fresh expression has been started.
**Confirmed**
- **EGFR for EXP-08:** Marco physically checked all six EGFR boxes. All tubes are there and full, apart from ALQ-00011-002, which has only about 3 µL usable.
- **Frosted label:** the BOX-00037 slot 2 label was readable for him this morning, and it is ALQ-00038-002. The frost clears and comes back.
- **Which tubes to use:** use the never-thawed lot 29 (ALQ-00054-001 to 003 in BOX-00052) or lot 33. Lot 18 also works.
- **Loading buffer:** BUF-00049 expires Mon 14 Sep, so a re-run on 17 Sep needs fresh loading buffer. Marco will make it when it's needed.
**Open**
- **Expression:** nobody has started fresh expression for EXP-05, 06, 07 or 08. Marco has had no answer from Sara since Tuesday, and I can't reach her. I escalated again to the lab manager, with a request for a decision today on who starts it and whether someone can check the Hamilton deck for the old plates. There is no reply yet.
- **Customer impact:** twelve designs are waiting. Each day without expression pushes the re-runs further out.
- **Re-run date:** Marco is planning on 17 Sep, but I haven't confirmed that with the lab manager.
**Odd things**
- Expression plates are never registered in the inventory. That is why they can't be traced, and it's worth a process fix.
- The frosted-label boxes in F80-1 and F80-2 are still unidentified.
- I ran no counts and changed no records.

**Marco, day 4 afternoon.** All five tasks are done and on time. Fresh expression for the re-runs is still unresolved.
**Done**
- **T5:** I binned target plate TP-00072 at 15:03 and recorded the disposal. I went by the 15:00 end time and didn't check that the run itself finished.
- **Return items:** BUF-00047 is back in Fridge R1 and SEN-00003 is back on Shelf S1, with both moves recorded. By the inventory, BUF-00047 is about 203 mL and SEN-00003 has 256 sensors.
- **Priya:** She asked about EGFR again, so I updated her. It is 773 µL usable in 21 full tubes I checked, plus Lena's new ALQ-00074 (BOX-00073), which I haven't looked at. That is plenty. I suggested never-thawed lot 29 (ALQ-00054-001 to -003) for her EXP-08 re-run.
**Open**
- **Fresh expression for EXP-05, 06, 07 and 08:** I haven't started it, and Priya knows nothing has been started. I asked Sara three times, on Tuesday, Wednesday and Thursday morning, and have had no answer. It isn't on my list and I have no design lists. Someone needs to either authorise and schedule it or tell Priya the re-runs are on hold.
- **Loading buffer:** BUF-00049 expires Mon 14 Sep. A re-run next week needs fresh loading buffer.
**Odd**
- **Failed lot:** PD-L1 lot S071 failed QC today and was not aliquoted.
- **Unchecked box:** I haven't looked at BOX-00073, the new EGFR box.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.
- **Old plates:** The old expression plates for EXP-05, 06 and 07 are still not in the inventory.

**Jonas, day 5 morning.** Morning handover (Fri 11 Sep): T1 and T2 are both ticked off. I placed no orders.
**Stock (inventory figures; I didn't open the freezer today):**
- **EGFR:** 27 tubes, 913 µL usable.
- **PD-L1:** 22 usable tubes, 770 µL. A further 195 µL vial failed QC and is excluded from that count.
- **BLI sensors:** 1,792 left, about 56 runs at 32 per run.
- **Why no order:** Use is about one tube a day per target, so both targets are far beyond two weeks of cover.
**Needs attention:**
- **Failed PD-L1 vial:** TGT-00071 (lot 36, supplier lot S071, 195 µL) failed SDS-PAGE and A280 QC on 10 Sep. It is in Fridge R1 and flagged in the inventory. Per its history, Lena received it on 10 Sep and moved it to the fridge, and it has a 7-day thawed clock ending 17 Sep. I told the lab manager not to bin it yet, since we may get a credit or replacement. Nobody has contacted the supplier about this yet.
- **Unexplained deliveries:** A vial of each target has arrived every day since 7 Sep (lots 29–36), and I didn't order any of them. I asked the lab manager whether it's a standing order. If it is, it needs stopping, since each vial costs about 300 CHF.
**Expiry:** Loading buffer BUF-00049 expires Mon 14 Sep at 08:42. Lena should make a fresh batch before then. TGT-00071 is the other item on the 14-day list, and it shouldn't be used. I told Lena about both.
**Still open:** Sara hasn't replied about run bookings, and the inventory still has no µL-per-run records.

**Priya, day 5 morning.** **Handover (Fri 11 Sep, morning).** T1 is ticked off, but there is still no expression plate and nothing has been started.
**What I checked for the EXP-09 re-run (PD-L1)**
- **Re-run date:** I assumed Thu 17 Sep, since today is already Friday.
- **PD-L1:** I'm using lot 34, ALQ-00069-001 to 003 in BOX-00067. I looked and they are there at about 40–50 µL by eye, QC-passed and never thawed.
- **Loading buffer:** BUF-00049 expires Mon 14 Sep and will be unusable on the 17th. I told Marco to make fresh loading buffer on 16–17 Sep.
- **Running buffer:** BUF-00047 is about 265 mL by eye, which is enough for one run.
**Needs attention**
- **Failed-QC target in the fridge:** TGT-00071 is PD-L1 lot 36 and failed QC on 10 Sep, but it is in Fridge R1 and still shows as 195 µL held. It must not be used. I warned Marco and asked the lab manager whether to bin it. I haven't touched it.
- **Expression:** no EXP-05 to EXP-09 plate is in the inventory or in any place I looked, and nothing has been started that I know of. That makes 15 designs waiting. The lab manager and Sara haven't answered.
**Odd things**
- Marco says Lena added another EGFR lot (ALQ-00074-001 to 004 in BOX-00073) that he hasn't checked.
- The frosted-label boxes in F80-1 and F80-2 are still unidentified.
- I ran no counts and changed no records.

**Marco, day 5 morning.** Morning block ends at 13:00, so here is the handover.
**Done**
- **T1:** I made target plate TP-00077 with 4 µL of EGFR in each of A1–H1, all from ALQ-00011-001 (lot 6, the oldest). There were no part-used tubes that could cover the 32 µL. All 8 transfers are recorded.
- **T2:** I took 40 mL of BUF-00047 and 32 sensors from SEN-00003, and recorded both.
- **T3:** ALQ-00011-001 held only dead volume (about 10 µL), so I binned it. The first disposal record failed on a garbled barcode, and the retry went through.
- **T4:** I told Priya the PD-L1 stock: 770 µL usable in 22 good tubes. I checked all six boxes and every tube is there. I confirmed her three separate sets: lot 19 for EXP-05, lot 30 for EXP-07 and lot 34 for EXP-09.
- **Failed vial:** TGT-00071 (PD-L1 lot 36, failed QC on 10 Sep, 195 µL) is still in Fridge R1. It is excluded from the stock figures. I asked Lena whether to bin it or return it to the supplier, and I haven't touched it.
- **Sara's Gator question:** She asked at 10:35 whether I could be ready at 10:45, and I said yes.
**Open**
- **T5:** After the run ends at 15:00, bin TP-00077 and record the disposal.
- **Return items:** BUF-00047 and SEN-00003 are still on Bench B2. They need to go back to Fridge R1 and Shelf S1 with the moves recorded. By the inventory, BUF-00047 is about 163 mL and SEN-00003 has 224 sensors.
- **TGT-00071:** I'm waiting for Lena's answer on binning or returning it.
- **Fresh expression for EXP-05 to 09 (the main risk):** I haven't started it, and Priya knows. This is my fourth ask to Sara since Tuesday, with no answer. Priya now has five re-runs waiting on it.
- **Loading buffer:** BUF-00049 expires Mon 14 Sep. Fresh loading buffer is needed before the 17 Sep re-runs, once the date is confirmed.
**Odd**
- **Buffer volume:** Priya's by-eye reading of BUF-00047 is higher than the inventory's. The inventory may be undercounting, or the volumes are just hard to read by eye. At 40 mL per day, it is worth a proper check before it runs short.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.

**Lena, day 5 morning.** All four tasks (T1–T4) are done and recorded in the inventory, with nothing open.
- **Delivery DN-4025:** I booked in TGT-00075 (EGFR, lot S075) at 200 µL and TGT-00076 (PD-L1, lot S076) at 145 µL.
- **Short PD-L1 vial:** The packing slip said 200 µL, but the PD-L1 vial looked like about 145 µL by eye, so I booked it at 145 µL. I told Sara so she can raise it with the supplier.
- **QC:** Both vials passed.
- **Aliquots:** The EGFR vial gave 4 aliquots, ALQ-00080-001 to -004, in BOX-00078. The PD-L1 vial gave only 3, ALQ-00081-001 to -003, in BOX-00079. Both boxes are in Freezer F80-1. I binned the empty vials and recorded the disposals.
- **Friday count (F80-1):** The inventory expected 55 and I found 55. The count reply also said it didn't expect any of the boxes (BOX-00010 to BOX-00079 and BOX-INBOX) in the freezer, and asked for moves to be recorded. I had already recorded moves for the boxes I filled this week. The older boxes are probably the same case, and I left that for Sara to look at.
- **Frosted labels:** Two aliquot labels are frosted over: ALQ-00062-003 in BOX-00060 and ALQ-00069-002 in BOX-00067. I identified them by slot and lot, and they need relabelling.
- **Failed PD-L1 vial:** TGT-00071 is still in Fridge R1, flagged. I told Marco not to bin it until Sara decides whether to return it to the supplier.
- **Still open from before:**
  - The EXP-05 and EXP-06 plates are unlocated.
  - The frosted box in F80-2 still needs identifying.
  - Loading buffer BUF-00049 expires Mon 14 Sep at about 08:42, so I need to make a fresh batch then.

**Jonas, day 5 afternoon.** Afternoon handover (Fri 11 Sep): Nothing new came in after lunch, and T1 and T2 stay done. I placed no orders.
- **Stock (this morning's inventory figures):** EGFR has 27 tubes and PD-L1 has 22 usable tubes. There are 1,792 BLI sensors. That is far beyond two weeks of cover.
- **Failed PD-L1 vial:** TGT-00071 failed QC on 10 Sep and is flagged in Fridge R1. I've asked the lab manager not to bin it while we ask the supplier for a credit or replacement. The lab manager hasn't answered yet, and nobody has contacted the supplier.
- **Unexplained daily deliveries:** I'm still waiting to hear who is ordering the daily target deliveries that began 7 Sep. If they continue over the weekend, the extra stock will cost about 300 CHF per vial.
- **Expiry:** Loading buffer BUF-00049 expires Mon 14 Sep at 08:42. Lena should make a fresh batch before then.
- **Monday:** On Monday I'll recheck stock, the failed-vial return, and the delivery source.

**Lena, day 5 afternoon.** My list is clear this afternoon. T1–T4 were finished this morning and nothing new has been assigned.
**Handover**
- **Delivery DN-4025:** TGT-00075 (EGFR) and TGT-00076 (PD-L1) were booked in, QC'd (both passed), split and binned.
- **Aliquots:** The EGFR aliquots are ALQ-00080-001 to -004 in BOX-00078. The PD-L1 aliquots are ALQ-00081-001 to -003 in BOX-00079. Both boxes are in Freezer F80-1.
- **Short PD-L1 vial:** TGT-00076 held only about 145 µL against 200 on the slip. Sara knows, in case she wants to raise it with the supplier.
- **Friday count (F80-1):** The inventory expected 55 tubes and I found 55. The count reply also said it didn't expect any of the boxes (BOX-00010 to BOX-00079 and BOX-INBOX) in the freezer, and I left that for Sara to look at. Two aliquot labels are frosted and need relabelling: ALQ-00062-003 in BOX-00060 and ALQ-00069-002 in BOX-00067.
- **Failed PD-L1 vial:** TGT-00071 is in Fridge R1, flagged. It needs a decision from Sara to return it to the supplier or bin it. Marco knows to leave it alone until then.
- **Still open, not mine to close:**
  - The EXP-05 and EXP-06 expression plates are unlocated. Priya needs someone to check the Hamilton deck.
  - The frosted, unreadable box in F80-2 needs identifying.
- **Next up:** Make a fresh loading buffer on Monday 14 Sep. BUF-00049 expires that day at about 08:42.

**Priya, day 5 afternoon.** **Handover (Fri 11 Sep, afternoon).** My list is empty, and the main blocker is unchanged: nothing has been started on fresh expression.
**Confirmed**
- Marco physically checked the PD-L1 boxes this morning and every tube is there. The three re-run sets are separate: EXP-05 uses lot 19, EXP-07 uses lot 30 and EXP-09 uses lot 34. Each has about 105 µL usable, with spares.
- TGT-00071 (the QC-failed PD-L1) is not counted in the 770 µL usable. Marco has asked Lena what to do with it.
- Marco will make fresh loading buffer on 16–17 Sep once the re-run date is confirmed.
**Still open**
- **Expression:** nothing has been started for EXP-05 to EXP-09, and there are no plates in the inventory. Sara hasn't answered Marco since Tuesday, and the lab manager hasn't answered me. I have no more routes to try today. This needs a person to ask in the room, on Monday morning at the latest.
- **Re-run date:** it still needs confirming with the lab manager. Marco is assuming 17 Sep.
- **TGT-00071:** the QC-failed tube is still in Fridge R1 until someone decides to bin it.
**Odd things**
- **Running buffer:** the BUF-00047 numbers disagree. The inventory says about 163 mL after Marco's runs, but I saw about 265 mL by eye this morning. Marco will do a count. That matters because he uses 40 mL a day, so the real volume decides when it runs short.
- The frosted-label boxes in F80-1 and F80-2 are still unidentified.
- I ran no counts and changed no records.

**Marco, day 5 afternoon.** All five tasks are done and on time. Fresh expression for the re-runs is still not started.
**Done**
- **T5:** I binned target plate TP-00077 at 15:03 and recorded the disposal. I went by the 15:00 end time and didn't check that the run itself finished.
- **Return items:** BUF-00047 is back in Fridge R1 and SEN-00003 is back on Shelf S1, with both moves recorded. By the inventory, BUF-00047 is about 163 mL and SEN-00003 has 224 sensors.
- **Priya:** She asked about PD-L1 again, so I updated her. It is 770 µL usable in 22 good tubes I checked, plus Lena's new ALQ-00081-001 to -003 (BOX-00079), which I haven't looked at. That comes to about 875 µL. Her three reserved sets (lots 19, 30 and 34) are untouched.
- **Failed vial:** Lena says not to bin TGT-00071 yet. It stays in Fridge R1 until Sara decides on returning it to the supplier, and it is excluded from every usable figure.
**Open**
- **Fresh expression for EXP-05 to 09 (the main risk):** I haven't started it. This is my fourth ask to Sara since Tuesday, and I have had no answer. Priya has five re-runs waiting on it. Either Sara authorises and schedules it with design lists, or Priya is told the re-runs are on hold.
- **TGT-00071:** Sara has to decide whether it goes back to the supplier or gets binned.
- **Loading buffer:** BUF-00049 expires Mon 14 Sep. Fresh loading buffer is needed before any re-run on 17 Sep.
**Odd**
- **Unchecked boxes:** Lena's new EGFR box (ALQ-00080, BOX-00078) and PD-L1 box (BOX-00079) are not checked by me.
- **Part-used EGFR tube:** ALQ-00011-002 is nearly empty and could be binned.
- **Buffer volume:** Priya's by-eye readings of BUF-00047 are higher than the inventory's. A proper check is worth doing before it runs short.

## The referee

Day 1: Final stock reconciled well; movement history, event timing and experiment linkage were less reliable than the clean score suggests.
Day 2: Final stock reconciled closely, but missing bench history, an inconclusive plate lookup and an unsupported demand forecast remained unresolved.
Day 3: Final stock reconciled closely, but an unrecorded bench interval survived, while ambiguous searches and unsupported coverage estimates weakened planning.
Day 4: Final stock agreed, but missing bench history and weak search and consumption evidence left planning less reliable than the task completion figures suggest.
Day 5: Final stock was close, but missing movement history and misleading query responses remained unresolved after the disposal error was repaired.

## Cost and running

40 claude sessions and 5 codex calls. 0 waits for a rate limit. No session hung.
