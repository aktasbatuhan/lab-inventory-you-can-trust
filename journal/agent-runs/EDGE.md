# Where the design can break

The ledger records changes, but it does not by itself stop two people spending the same liquid or make a half-finished robot run honest. Check balances and save related entries together. Separate planned transfers, confirmed work and uncertain losses. Give each physical action a stable identity so retries cannot spend it twice.

Two timestamps are useful, but late facts can break an earlier balance, location or expiry calculation. Define how corrections replace facts, how conflicting edits are resolved and what happens when time order is unknown. Recheck affected intervals and keep both the revised history and what the lab previously believed queryable.

Material, lot and container need one more distinction: the contents at a particular time. A well can contain multiple source lots, and a reused tube can hold unrelated contents. Preserve all sources through mixtures and bind QC to what was actually sampled. Check lineage and containment for cycles, including concurrent edits.

An amount needs more than a number and a unit. Concentration is not stock quantity; activity units need assay context. Keep measurements, conversion evidence and uncertainty separate. Do not turn missing amounts into zero or infer volume from container capacity.

The usable view needs independent, scoped reasons, not one status. A purity pass cannot clear contamination, a disposal correction cannot erase warm exposure, and a partial plate failure cannot decide every well. Version release and expiry rules. Recompute affected descendants after corrections, and let stock expire even when no new ledger event arrives.

Keep audit actors separate from login accounts and container identities separate from barcodes. Otherwise account deletion or a reused label can break an otherwise intact history.
