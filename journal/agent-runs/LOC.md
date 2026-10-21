# LOC agent run, 2026-10-21

Wrote 40 scenarios in `scenarios/raw/LOC.yaml` (LOC-001 to LOC-040): 24 core, 15 supported, 1 cut (moves between Adaptyv sites, since we don't know a second site exists).

They cover single tube and whole box moves, plate round trips through bench, robot deck, plate hotel and instruments, rack scanners reading 96 tubes at once, frost no-reads, typed barcodes, duplicate and reused barcodes, hand-written labels, unscanned moves, found items, stock-takes, freezer failure and warm excursions, new freezers and room changes, shipping out, late offline scans, and disposal freeing a slot.

The ones that shape the data model most:

- LOC-002 (box moves): places have to nest. A tube is in a box, the box is on a shelf, the shelf is in a freezer. One scan moves 64 tubes.
- LOC-014 and LOC-009 ("last seen" vs "is"): every place answer needs a last-confirmed time and how it was confirmed. The system's place is a claim, not a fact.
- LOC-011 (freezer breakdown): we need a "location uncertain" state that is neither missing nor disposed, and a way to clear it box by box.
- LOC-007 and LOC-006 (barcode reuse and duplicates): the barcode is not the container. A container can have several barcodes over its life, and a barcode can point to only one live container at a time.
- LOC-025 and LOC-003 (late scans): moves need a "happened at" time separate from "recorded at", or late uploads move tubes back to old places.
- LOC-004 (rotated rack): a batch scan can be wrong all at once, so it must be stored as one event that can be corrected as one.

Assumptions about Adaptyv: they use 2D-barcoded tubes and a flatbed rack scanner, handheld scanners that can sync late, a plate hotel by the liquid handler, a freezer temperature monitor, and possibly a second site. None of this is in the brief.

Sources: the case brief and workflow diagram; vendor material on frozen rack scanning (Micronic DR710 and RD235 CRYO anti-frost readers, https://fhi.nl/en/news/traceer-bevroren-monsters-met-de-nieuwe-micronic-rack-reader-dr710/; Ziath anti-fog coating via https://www.manufacturing.net/home/press-release/13153753/frozen-sample-barcode-scanner); a 2019 mailing-list report of frozen racks failing to scan (https://mailman.yale.edu/pipermail/nhcoll-l/2019-February/011439.html); Octet BLI plate loading (https://sites.udel.edu/mslab/files/2023/09/SOP_BLI-OCtet-assay-1.pdf). The probabilities in the sim hooks are our guesses, not measured.
