# Research: how real labs get inventory wrong

Research agent run, 2026-10-21. Numbers feed `sim/noise-model.yaml`; keys [S#] match the list below.

## The short version

There is good data on human error, but almost all of it comes from hospital labs, not research labs. Equipment specs are solid because vendors publish them. Dead volumes for ordinary tubes, barcode no-read rates in the field, freezer failure rates and inventory accuracy in labs are thin or missing, so those numbers in the YAML are marked as assumptions and should be swept, not trusted.

## People

Hospital labs have measured this for decades. CAP Q-Probes across 147 labs found 0.92 labeling errors per 1,000 labels, with the worst labs far higher [S3]. "Wrong blood in tube" runs about 1 in 2,000 [S1, S2]. We borrowed it for "scanned the wrong tube"; our lab is calmer than a ward, so it may be high.

Typed numbers are worse. A Seattle study compared 6,930 hand-typed glucose results with the instrument values and found 3.7% differed, and about 0.5% were off by more than 20% (one was 13 typed for 132) [S4]. The classic keying figure is one wrong character per 300, versus about one per 3 million for barcodes; the barcode figure is a vendor claim, and real scanners tested 10 to 15 times worse [S5, S11].

For steps that simply don't get recorded, we used general human-reliability tables: about 0.3% for skipping a step that's in a written procedure, 1% with no reminder, and 0.3% for picking the wrong item from a set [S6]. For duplicate deliveries we found nothing in labs, so we borrowed accounts-payable duplicate invoice rates, 0.05% to 2% [S8]. That one is weak.

## Liquids and containers

ISO 8655 lets a 2 µL pipette be 4% off with 2% CV; at 10 µL it's 1.2% and 0.8% [S12]. Robots do as well: Tecan lists under 4% CV at 1 µL with a 50 µL tip [S13]; an Agilent Bravo 384 head gave 1.3% CV at 2 µL [S14].

The Echo is the one place where dead volume is a hard rule. The standard 384PP source plate works between 15 or 20 and 65 µL, with about 20 µL you can never get back; the low-dead-volume plate works between 3 and 12 µL [S16, S17]. For 1.5 mL tubes, 2D-barcoded Matrix tubes and PCR plates, no vendor publishes a dead volume [S10, S15]; our numbers are guesses.

Evaporation from an open 384-well plate with 50 µL on the bench was about 15% in 8 hours, around 0.9 µL per well per hour; a loose lid cut that to about a third [S21]. In an incubator, corner wells lose 0.45 µL/h at 30 °C and 0.66 µL/h at 37 °C, perimeter wells about half that [S22].

## Real formats

Twist ships genes dried, at room temperature, in 96 or 384-well plates or tubes. Clonal genes come in yield tiers (1 to 4 µg for the smallest prep); a clone that misses the 1 µg guarantee is still shipped and marked "NA" [S23]. They suggest resuspending to at least 10 ng/µL [S24].

BLI plates take 200 µL per well in 96-well format and 40 to 80 µL (60 typical) in 384 tilted plates [S18, S19, S20]. His-tagged targets are loaded at 5 to 25 µg/mL [S27], so one 96-well target well uses about 2 µg. Catalog targets come lyophilized, usually 100 µg for roughly 200 to 400 USD, about 2,400 USD per mg, and keep around 12 months at -20 to -80 °C [S25, S26]. Cell-free yields of 10 to 100 µg come from a third-party description of Adaptyv, not Adaptyv itself [S28].

## Freezing

Vendors say "avoid repeated freeze-thaw" without a number [S31]. Published cases disagree: an IgG study saw particles after 5 cycles [S29]; one patented enzyme should be frozen only once, while another protein was fine after 7 [S30]. The honest model is a freeze-thaw counter with a limit per material, not a fixed loss curve.

The only freezer failure number we found is "16% of freezers fail each year" in a trade article that doesn't name its study [S32]. All six Swedish university biobanks asked had had a freezer fail [S33].

## Inventory accuracy

A study of 370,000 retail records found 65% wrong [S34]. Warehouses on paper or legacy systems run 95 to 98% accurate by location [S35]; companies with cycle counting average 98% [S36]. One textbook example shows accuracy drifting about 2.5 points a month once counting stops [S37]. Nobody has measured this in research labs.

## How existing tools model it

Benchling has nested locations, boxes, plates and containers; a container holds "contents" pointing at an entity and a batch, and transfers create new containers [S38]. Volume sits as a single number on the container, so history lives in the audit log, not in the data. eLabFTW has a location tree and containers with quantity and unit, but its docs don't mention lots or expiry [S39]. Quartzy users praise ordering but say inventory drifts and some fall back to spreadsheets [S40]. SciNote reviewers rate inventory as its weak spot; LabWare is strong but heavy to configure [S41]. Titian Mosaic, built for pharma sample banks, checks there's enough sample before a request goes ahead and keeps a full audit trail [S42]. The common complaint is inventory that falls behind reality.

## Sources

Pages fetched and read: S4, S16, S17, S21, S22, S23, S29, S32, S38, S39. The others were read through search-result extracts only.

1. S1 Notify Library, Sample errors (WBIT 1:2000). https://notifylibrary.org/content/183-sample-errors
2. S2 CLN, Mislabeled specimens. https://myadlm.org/cln/articles/2014/april/psf-mislabeled-specimens
3. S3 Specimen labeling errors: a Q-Probes analysis of 147 clinical laboratories. https://mdanderson.elsevierpure.com/en/publications/specimen-labeling-errors-a-q-probes-analysis-of-147-clinical-labo
4. S4 Mays & Mathias, Measuring the rate of manual transcription error in outpatient point-of-care testing, JAMIA 2019. https://academic.oup.com/jamia/article/26/3/269/5287977
5. S5 Wasp Barcode, Why barcodes almost never fail. https://waspbarcode.com/buzz/why-barcodes-almost-never-fail
6. S6 Technique for human error-rate prediction (THERP). https://en.wikipedia.org/wiki/Technique_for_human_error-rate_prediction
7. S7 Biohub preprint on manual plate errors. https://www.biorxiv.org/content/10.1101/2021.12.17.473010v2.full.pdf
8. S8 Hyperbots, Duplicate payment rate. https://www.hyperbots.com/glossary/duplicate-payment-rate
9. S9 Racklify, Troubleshooting Data Matrix printing and verification. https://racklify.com/encyclopedia/troubleshooting-printing-and-verification-for-data-matrix-ecc-200/
10. S10 Thermo Fisher, Matrix 2D barcoded tubes. https://www.thermofisher.com/order/catalog/product/3736
11. S11 Clinical Chemistry podcast, Misidentifications caused by bar code errors. https://myadlm.org/science-and-research/clinical-chemistry/clinical-chemistry-podcasts/2010/patient-misidentifications-caused-by-errors-in-standard-bar-code-technology
12. S12 Gilson MyPIPETMAN spec sheet with ISO 8655 limits. https://new.marshallscientific.com/v/vspfiles/specs/Gilson%20MyPIPETMAN%20Select%20Pipette%20Series%20-%20Marshall%20Scientific.pdf
13. S13 Tecan, Multichannel arm 384 tips. https://lifesciences.tecan.com/multichannel-arm-384-disposable-tips
14. S14 Agilent, Bravo 384ST 10 µL tip performance. https://agilent.com/cs/library/technicaloverviews/public/te-bravo-automated-liquid-handling-384st-10-ul-tip-5990-3645en-agilent.pdf
15. S15 Hamilton, PCR FramePlate 96-well. https://www.hamiltoncompany.com/automated-liquid-handling/other-robotics/814302
16. S16 HKU, SOP Beckman Echo 650. https://cpos.hku.hk/wp-content/uploads/2026/01/SOP_Beckman_Echo650_20260129.pdf
17. S17 DeRisi lab RNA library prep on Echo, protocols.io. https://www.protocols.io/view/derisi-lab-rna-library-prep-96-well-protocol-on-ec-cpm7vk9n.pdf
18. S18 University of Delaware, SOP BLI Octet assay. https://sites.udel.edu/mslab/files/2023/09/SOP_BLI-OCtet-assay-1.pdf
19. S19 Harvard CMI, Octet RED384 getting started. https://cmi.hms.harvard.edu/resource/cmi-octetred384-bli-getting-started-guide
20. S20 Sartorius, Octet 384-well tilted bottom plate datasheet. https://www.sartorius.hr/media/vh3dyapm/octet-384-well-tilted-bottom-microplate-ds-3014-en-sartorius.pdf
21. S21 GEN, Measuring volume changes in screening plates. https://www.genengnews.com/insights/measuring-volume-changes-in-screening-plates/
22. S22 Reshape Biotech, Evaporation characterization and mitigation. https://support.reshapebiotech.com/en/articles/13860354-evaporation-characterization-and-mitigation
23. S23 Twist, How are genes delivered. https://www.twistbioscience.com/faq/gene-synthesis/how-are-genes-delivered
24. S24 Twist, DNA resuspension and storage. https://www.twistbioscience.com/content/dam/twist-aem-migration/DOC-4045%20DNA%20Resuspension%20and%20Storage%20REV1%20singles%20(1).pdf
25. S25 Labome, Sino Biological His-tag protein listing. https://www.labome.com/product/Sino-Biological/14333-H07E.html
26. S26 VWR, ACRO SARS-CoV-2 S2 protein. https://pr.vwr.com/store/product/33862015/sars-cov-2-recombinant-s2-protein-from-hek293-cells
27. S27 ForteBio TN-31, Ni-NTA kinetics. https://www.xtal.iqfr.csic.es/TBIO/laboratory/7869_ForteBio_TN_31_NiNTA_Kinetics_RevB.pdf
28. S28 Third-party Adaptyv skill reference. https://cdn.jsdelivr.net/npm/@saibolla/ada@0.1.3/skills/adaptyv/reference/experiments.md
29. S29 Horn et al., Freeze/thaw of IgG solutions, EJPB 2019. https://epub.ub.uni-muenchen.de/83655/
30. S30 US patent 12662664 (hyaluronidase) and 10415026 (factor B). https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/12662664
31. S31 Assay Genie, Recombinant proteins FAQ. https://www.assaygenie.com/antibody-genie-recombinant-proteins-faqs
32. S32 Technology Networks, Forgotten biological samples. https://www.technologynetworks.com/drug-discovery/articles/forgotten-biological-samples-threaten-research-integrity-400491
33. S33 Universitetsläraren, After the KI freezer failure. https://universitetslararen.se/2024/04/18/after-the-ki-freezer-failure-university-biobanks-are-comfortable-with-their-security/
34. S34 DeHoratius & Raman, Inventory record inaccuracy, Management Science 2008. https://ideas.repec.org/a/inm/ormnsc/v54y2008i4p627-641.html
35. S35 Aptean, How cycle counting improves accuracy. https://www.aptean.com/en-US/resources/industry-insights/blog/how-cycle-counting-improves-accuracy
36. S36 Industrial Distribution, Tompkins cycle counting report. https://www.inddist.com/economy/article/13764028/cycle-counting-achieves-higher-inventory-accuracy
37. S37 GlobalSpec, Inventory accuracy guide excerpt. https://www.globalspec.com/reference/21784/203279/chapter-5-day-5-45-control-groups-and-root-cause-analysis
38. S38 Benchling, Warehouse inventory tables. https://docs.benchling.com/docs/wh-inventory
39. S39 eLabFTW, Inventory docs. https://doc.elabftw.net/docs/usage/inventory
40. S40 Capterra, Quartzy reviews. https://www.capterra.com/p/189585/Quartzy/reviews/?page=2
41. S41 G2, LabWare LIMS vs SciNote. https://www.g2.com/compare/labware-lims-vs-scinote
42. S42 LIMSwiki, Titian Software. https://limswiki.org/index.php/Vendor:Titian_Software_Ltd.
