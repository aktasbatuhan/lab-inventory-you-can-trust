# [SHARED] Inventory Management Take-Home

Source: https://adaptyvbio.notion.site/SHARED-Inventory-Management-Take-Home-3fc5ca69e7be812bb9f9e328962042da (copied 2026-10-21, text unchanged)

## Problem

Our lab runs automated protein characterization experiments at high throughput, and the quality of the data we produce depends on the lab running smoothly. Inventory management is part of the backbone of that system: every experiment consumes materials (DNA, proteins, buffers, consumables), and the lab cannot move faster than its ability to track what it has, what it needs, and where things are.

Our production process consists of several steps, and each step has different requirements and some logic for how much of each component is used up. There are several types of materials that differ on how they are used and restocked, how fast they expire, and how much they can be reused across different projects.

The inventory is also the system everything else trusts. Experiment planning reads it to decide what can run, scientists read it to find the right tube, and we use it to trace a result back to the exact material it came from. When it is wrong, the cost is real: material we own gets reordered because it looks used up, plates already thrown away still look usable, and a bad batch of a target can't be traced to the experiments it touched. Recording the facts correctly matters more than any single feature.

The goal is to sketch out a system for tracking how much of each material we have at any given time, where it came from, which processes use it, and where it is stored in the lab.

## How the lab works

**Material is bought or made.** Bought material arrives from a supplier lot, with a certificate of analysis. Made material comes from other material: a diluted copy of a DNA plate, samples from DNA, buffers from their components, small target tubes (aliquots) from a larger one.

**It lives in containers, in places.** Tubes, plates where each well holds its own material, boxes and racks. They sit in freezers, fridges, on shelves, on the bench or inside an instrument. Things get moved around several times a day, and containers carry barcodes that people scan.

**It moves from container to container.** Lab tasks take material out of some containers and put it into others, and each task does this differently. For example, a robot may transfer liquid from one plate to another well by well, or a scientist may split one tube into many smaller ones.

**It has a life.** How long material lasts depends on how it is stored and since when. A new lot is checked by QC before use and can fail. Containers are thrown away, sometimes with material still inside, and some material leaves the lab.

**Many hands, many mistakes.** It's not impossible that people record the wrong volume, scan the wrong tube, or register a delivery twice.

## Use cases

### Questions the system should answer

These are the obvious ones and not a complete list. Part of the exercise is figuring out what else the lab will need to ask, and making sure your model can answer it.

1. How much do we have, and how much of it is usable? Some of what we hold can't be used, for example because it has expired or was thrown away.
   - Targets in binding experiments are expensive and shared across experiments. We need to know what is left from previous experiments before ordering more.
   - Steps whose data fail QC are re-run. Whoever plans those re-runs needs numbers they can trust.
2. Is it still viable? What has expired, and what expires soon?
3. Where is it? As the lab grows, finding the right tube or plate gets harder, and containers move during the day.
4. Where did it come from, and where did it go? If a batch of target turns out to be bad, we need to find everything that was made from it.
5. Who changed what, and when? And what did the record say before the change?

## What's in the lab today

This is the list we have today but new kinds of material keep appearing (small molecules, for example), and your model should handle that easily.

| Material | What it is | How we get it | Lifetime |
|---|---|---|---|
| DNA | DNA of the proteins a customer wants to test | Ordered from a supplier (5–10 days, expensive), or made in-house (2 days, cheaper) | Many years in the freezer |
| Samples | The customer's proteins | Usually expressed in-house from the DNA; sometimes bought as finished protein | Expression Plates: 2 weeks. GFP and BLI Plates: thrown away after use |
| Target proteins | The protein the samples are tested against | Usually bought finished from a supplier lot (5–10 days, expensive), each lot QC'd before use; sometimes expressed in-house | Many years in the freezer |
| Buffers | Liquids we put proteins and DNA in | Made in-house from ordered components | GFP stock: 6 months frozen. Loading buffer: 1 week. Others: 1 month |
| Consumables | Pipette tips, well plates, chips | Several suppliers | No expiry |
| Other materials | Buffer components, PBS | Suppliers | Varies, typically long |

## What we'd like to see

We want to see how you reason through a domain problem and translate it into the artifacts an engineer would actually produce. Please deliver the following.

A data model and SQL schema. Show us the entities you would create, their relationships, and the key columns. We care about:
- how you handle the differences between material types;
- how you represent storage locations, and things that move between them;
- how you track quantities and expiration;
- how consumption is recorded, including when material moves from one container into others;
- how you tell what is usable from what merely exists;

## Scope and logistics

We give you 48 hours to work on this. We would much rather see depth on a few well-chosen pieces than breadth across everything, so if you cut things, tell us what you cut and why.

Experiment planning (deciding what to run, reserving material for it, choosing what to order) is a separate system and out of scope. Your inventory only has to give it numbers it can trust.

You are welcome to use AI tools freely. We care about the output and your reasoning, not how it was produced.

We will not be available to answer questions, so please bake any assumptions you need into your submission rather than waiting on clarification. The assumptions themselves are useful signal for us.

At the end of the 48 hours, you'll present your approach to us and we'll discuss it together live. Please send your work 30mins before the meeting so that we have time to read through it beforehand.

## Workflow example

This is the "Binding" workflow, used in Binding Experiments. Grey boxes are lab tasks; colored plates are the tasks' inputs and outputs, and contain materials. See `binding-workflow.png`.

Reading of the diagram (ours, not theirs):
- DNA path: DNA Arrival (Twist plate, DNA) → DNA Reconstitution (reconstituted Twist plate) → optional DNA Dilution (diluted DNA plate) → Expression Plate Prep (expression plate) → Expression Run (expression plate with proteins).
- Target path: Antigen arrival → Antigen reconstitution, buffer exchange, QC → Target stock tube → BLI/SPR Target Plate Prep → BLI/SPR target plate.
- Expressed proteins go to BLI/SPR Sample Plate Prep (sample plates) and to Split GFP plate prep (split-GFP plate) → Split GFP measurement.
- Split GFP measurement feeds a sample concentration normalisation step back into BLI/SPR Sample Plate Prep (marked "implementation in progress").
- BLI/SPR Run takes target plate + sample plates → Data Processing → Data Review → Results delivered.
