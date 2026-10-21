# RCV agent run, 2026-10-21

I wrote 40 receiving scenarios in `scenarios/raw/RCV.yaml`: 15 core, 23 supported, 2 cut. They cover target vials arriving as powder, reconstitution and buffer exchange, QC pass, fail and retest, Twist DNA plates (dried, 96 and 384 wells, plate map files), partial and wrong deliveries, double registration, cold-chain breaks, recalls, reused lot numbers, barcodes and relabeling, in-house DNA and targets, buffer components and consumables. Only a few cover the happy path. Most cover the ways it goes wrong.

The ones that matter most for the data model:

- RCV-034 and RCV-014. A lot and a delivery are different things. QC belongs to the lot, which the supplier made. Transit damage belongs to one delivery. Without both, warm vials pass under an old QC result.
- RCV-005 and RCV-002. Keep what the supplier claims and what we measured as separate facts. Count the amount lost during buffer exchange as a loss, not as missing material.
- RCV-006 and RCV-009. A plate is one container with one lot per well. The plate map is imported data, and a well's state (dry or liquid) can change.
- RCV-016 and RCV-017. Supplier plus lot number is not a safe unique key.
- RCV-020 and RCV-021. A barcode is a name a container has, not the container itself. One container can have several barcodes over time.
- RCV-011, RCV-032 and RCV-036. Record what really happened, even when it's late or against the rules, then warn about it.

Assumptions (marked in the stories): a ±20 percent tolerance on concentration, a CoA required for buffer components, a past QC carrying over to new vials of the same lot, customers sometimes shipping their own material, and in-house DNA made by something like PCR. The probabilities in `sim_hook` are my educated guesses, not measured rates.

Sources: general lab knowledge, plus Twist's DNA resuspension guide and product pages (https://www.twistbioscience.com/resources/protocol/twist-dna-resuspension-guidelines, https://twistbioscience.com/products/genes/fragments, https://twistbioscience.com/faq/gene-synthesis/how-are-genes-delivered) and the ACROBiosystems FAQ on reconstitution and aliquots (https://www.acrobiosystems.com/support/faq).
