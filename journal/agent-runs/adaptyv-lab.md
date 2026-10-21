# What Adaptyv's lab actually looks like

Research agent run, 2026-10-21. Numbers feed `sim/lab-profile.yaml`; keys [A#] match the list at the bottom.

## Confirmed by a source

**What they sell.** Three assays: binding, expression and thermostability. Enzyme activity and developability also show up in job posts [A21]. Customers upload protein sequences as CSV or FASTA, not DNA, through the Foundry portal, the API or an MCP server [A1, A11, A12]. Binding takes about 21 days, and the website lays it out as days 1 to 7 for prep and DNA, 8 to 9 for expression, 10 to 15 for measurement and 16 to 21 for review [A2]. The minimum is 20 designs per target, with duplicates by default [A11]. A faster lane called Prime promises "as little as 3 days" and is in private beta [A1].

**How a design becomes data.** Each sequence is turned into DNA, which is either ordered (Twist part-sponsored the DNA for the EGFR competition [A17], and the brief's diagram says "Twist plate") or assembled in-house from fragments [A14]. The linear DNA goes straight into cell-free expression with no cloning. They use a PURE-style kit built from purified E. coli parts, plus lysate-based kits [A8, A22]. The SPR methods page gives the scale: 8 µL reactions with 4 nM DNA, run for 8 hours at 37 °C [A7]. About 95% of designs express [A14, A17]. Every protein carries a Twin-Strep tag and a small GFP piece. Adding the other half of GFP makes the well glow in proportion to how much soluble protein there is, and that is the split-GFP check in the diagram [A9].

**Binding instruments.** For BLI they use the Gator Bio "Gator Pro" [A10], and a job post says "runs come off the Gators", so there is more than one [A20]. The designed protein sits on a Strep-Tactin XT probe and the target is in the wells. One probe cycle is roughly 38 minutes: 440 s of capture and baseline, then 4 concentrations from 1000 to 30 nM, each with 220 s on and 240 s off [A6]. For SPR they use a Carterra LSA XT with a 96-channel printhead and 7 concentrations [A7].

**Other kit named in job posts.** The posts mention Hamilton liquid handlers (plural, calibrated daily and weekly), an Echo acoustic dispenser, plate readers, robot arms, incubators, nanoDSF, capillary electrophoresis and HPLC-SEC [A22, A23, A35]. They don't run the robots through vendor software. They drive them from Python with PyLabRobot and PyHamilton, and reverse-engineer instruments that have no API [A27, A28].

**Scale.** The posts give "150+ experiments per month" [A21] and "thousands of constructs a week" [A22, A23]. The procurement post talks about "tens of thousands of proteins a month" as where they are heading [A25]. Throughput grew about 5x in a year [A16]. Real batches: EGFR round 2 had 400 designs, 378 expressed and 53 bound [A17]; Claude's run had 1,320 designs on 16 targets [A14]; the current Anthropic competition plans 5,000+ [A19].

**Targets.** A public catalog lives at targets.adaptyvbio.com. Off-catalog targets mostly come from ACRO, Sino Biological and Kactus [A5]. Customers who ship their own target are asked for about 150 µg at 0.5 mg/mL or more [A5]. The API prices some targets "per broken lot", and its example is a $300 lot that serves up to 33 sequences [A13]. Leftover target "is reused, not re-charged" [A11].

**Software and inventory.** Their internal system is called LabOS. It handles scheduling, execution, data capture and sample tracking, and it has an API [A21, A22, A25, A29]. The stack is Python and TypeScript, Postgres on Supabase, and Modal for compute [A28]. Benchling isn't mentioned in any of the 34 open posts [A37]. Their GitHub has forks of a Brother P-touch label printer driver and a barcode generator [A30], which points to printing their own barcode labels. The company has about 25 people and expects about 50 within a year [A24, A25].

## Inferred, not stated

- A Hamilton STAR with a 384-channel head and an Agilent Bravo. Both come from branches in their PyLabRobot fork, not from any post [A30].
- Gator Pro capacity: 32 probes, three 96- or 384-well plates and up to 1,152 samples a batch. That is the vendor spec, not something Adaptyv has said about its own setup [A31].
- Plate formats. Nothing public says whether expression or BLI plates are 96 or 384 wells. The 8 µL reactions suggest 384. The YAML marks these as guesses.
- "ABE / ART format" on the target stock tube. I found nothing in vendor catalogs, Adaptyv's docs or general search. Probably two internal stock formats, but that is a guess, so the model should keep "format" as free text on the tube.
- Head counts per role, shift hours and all the hands-on step times (DNA reconstitution, plate prep, split-GFP incubation) are guesses.

## The surprising part

Two job posts read almost like our brief. The procurement post says "scientists have bought what they need", talks about "inventory that is planned rather than remembered", and wants to avoid "six figures of reagents quietly expiring in a freezer" [A25]. The lab technician post says this person will "lead the rollout of new inventory management" [A23]. So the inventory system is being built right now, and the people who will use it are mostly lab operations staff who receive, aliquot and put away, not scientists.

## Sources

1. https://www.adaptyvbio.com
2. https://www.adaptyvbio.com/services/binding
3. https://www.adaptyvbio.com/services/expression
4. https://www.adaptyvbio.com/services/thermostability
5. https://docs.adaptyvbio.com/docs/experiment-setup/target-proteins.md
6. https://docs.adaptyvbio.com/wiki/methods/bli-methods.md
7. https://docs.adaptyvbio.com/wiki/methods/spr-methods.md
8. https://docs.adaptyvbio.com/wiki/technologies/cell-free-protein-expression.md
9. https://docs.adaptyvbio.com/wiki/technologies/split-GFP.md
10. https://docs.adaptyvbio.com/wiki/technologies/BLI.md
11. https://docs.adaptyvbio.com/docs/faq/overview.md
12. https://docs.adaptyvbio.com/llms.txt
13. https://docs.adaptyvbio.com/api-reference/targets/get-target.md
14. https://www.adaptyvbio.com/blog/anthropic-1
15. https://docs.adaptyvbio.com/docs/experiment-types/binding.md
16. https://www.adaptyvbio.com/blog/series-a
17. https://www.biorxiv.org/content/10.1101/2025.04.17.648362v1.full
18. https://raw.githubusercontent.com/adaptyvbio/egfr_competition_2/fc91b91ddc367830b755b215dbc69669675ad6a0/README.md
19. https://proteinbase.com/competitions/anthropic-adaptyv-2026
20. https://jobs.ashbyhq.com/adaptyv/88451659-b23b-4f27-a082-2e5635d8126a (Scientist, Binding Kinetics)
21. https://jobs.ashbyhq.com/adaptyv/32b4fe9e-cd0a-4600-bea3-2fe44ff781fb (Senior Scientist, Production)
22. https://jobs.ashbyhq.com/adaptyv/8cdef07a-1803-4679-b039-c66c8e307518 (Research Associate, Molecular Biology)
23. https://jobs.ashbyhq.com/adaptyv/a6f40152-e49c-4bdd-a0cd-650776b785b9 (Lab Technician, Lab Operations)
24. https://jobs.ashbyhq.com/adaptyv/7116a0f0-0326-45a6-9356-829b1519932f (Lab Operations Associate)
25. https://jobs.ashbyhq.com/adaptyv/34944559-933b-491a-874f-a15c6a0660e8 (Supply Chain & Procurement Manager)
26. https://jobs.ashbyhq.com/adaptyv/e4372bd7-efc1-4255-aef4-3a2180f6cd35 (Head of UK Lab Operations)
27. https://jobs.ashbyhq.com/adaptyv/71e7b346-1db7-4d87-808d-9abdf615e488 (Lab Automation Engineer)
28. https://jobs.ashbyhq.com/adaptyv/8e67b2b8-0cff-4dcf-96c2-572926ffeb73 (Software Engineer, Lab Automation)
29. https://jobs.ashbyhq.com/adaptyv/cf3cc792-16d2-4370-a9e8-091380fff318 (Software Engineer, Product)
30. https://github.com/adaptyvbio and https://api.github.com/repos/adaptyvbio/pylabrobot/branches
31. https://solvescientific.com.au/gator-bio/bli/
32. https://carterra-bio.com/lsa-xt/
33. https://adaptyvbio.substack.com/p/introducing-benchbb-and-the-community
34. https://jobs.ashbyhq.com/adaptyv/64318537-2279-48f2-9213-7acce3bfd808 (Synthesis Instrumentation Engineer)
35. https://jobs.ashbyhq.com/adaptyv/d490ee05-1c8f-464f-978a-f67467ed3f4e (Lab Automation Internship)
36. https://www.adaptyvbio.com/careers
37. https://api.ashbyhq.com/posting-api/job-board/adaptyv (full text of all 34 posts; the job pages themselves render with JavaScript)
