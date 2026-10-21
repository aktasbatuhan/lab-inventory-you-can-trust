# Scenarios

Each scenario is a small story about something that happens in the lab, and what the inventory should say afterwards. We wrote them before the schema so the schema has something to be tested against. At the end, the ones marked `core` become runnable tests in `tests/`, and the simulation in `sim/` produces them at volume with realistic mistakes mixed in.

Drafts per area live in `raw/`. The merged, de-duplicated list is `catalog.yaml`.

## Format

```yaml
- id: SPLIT-004            # AREA-number, areas listed below
  title: Scientist splits a target tube into 20 small tubes
  story: |                 # Given / When / Then, in plain words
    Given a 500 µL tube of Target X (lot L1, QC passed) in freezer F2.
    When a scientist splits it into 20 tubes of 24 µL and scans each new barcode.
    Then there are 20 tubes of lot L1, 480 µL in total, and the parent tube shows 20 µL left (dead volume) or is marked empty.
  real_life_noise:         # the messy versions of this that actually happen
    - forgets to scan two of the new tubes
    - records 25 µL each, so the total is 500 µL and the parent "loss" goes missing
  system_should: |         # what a good inventory does, including with the noise
    Keep the lot the same on every child. Check that children plus leftover don't add up to more than the parent had. Flag the mismatch instead of silently accepting it.
  question_it_answers: How much usable Target X do we have?
  frequency: weekly        # how often in a real lab: many-per-day | daily | weekly | monthly | rare
  cost_if_wrong: high      # low | medium | high, plus why in a few words
  cost_reason: Target is expensive; a missing tube means a needless reorder
  depth: core              # core (we model and test it) | supported (model handles it, not tested deeply) | cut (out of scope, say why)
  sim_hook: |              # how a simulated lab agent could produce this
    Actor scientist, action split_tube, error forget_scan with p≈0.03 per child tube
  source: brief            # brief | workflow | research | inferred
```

## Areas

- `RCV` receiving, supplier lots, certificates, QC, duplicate deliveries
- `XFER` splitting, pipetting, robots, plate-to-plate transfers, dilutions, the Binding workflow end to end
- `LOC` storage places, scanning, moving things around, lost and found
- `LIFE` expiry, storage-dependent shelf life, freeze-thaw, disposal (including with material left inside), material leaving the lab
- `ASK` the questions people ask: how much, usable or not, lineage, audit history, re-runs, shared targets
- `EDGE` adversarial cases that try to break the model
