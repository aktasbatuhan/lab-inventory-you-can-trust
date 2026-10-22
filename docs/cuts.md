# What we cut, and why

The brief asked for depth on a few well-chosen pieces over breadth, and to say what was cut. We went deep on four things: the ledger of facts with two times on each, keeping material, lot, container and contents apart, transfers as runs, and "usable" worked out with its reasons. Everything below was left out or left shallow on purpose.

## Left out entirely

| What | Why |
|---|---|
| Reservations, planning and ordering | The brief puts experiment planning out of scope. The inventory gives it numbers it can trust, including usable amounts on a future date. |
| A user interface | Not asked for. The record functions are the API a scanner app or LabOS screen would call, and the review console shows what the data looks like. |
| Logins and permissions | Every fact names who recorded it and who did it, through an actor table kept apart from login accounts, so deleting an account never breaks history. Who may record what is a job for the application layer. |
| Tracking single pipette tips | Consumables are counted by the box. |
| Freezer temperature alarms | A "location uncertain" state exists and storage history is kept, but tying in alarm data depends on monitors we don't know about. |

## Built, but not deep

| What | Where it stands | Why we stopped there |
|---|---|---|
| Speed at scale | Every answer is worked out from the facts each time. A month of data at 768 designs a week answers "what's usable" in 1.5 s. | The next step is cached summaries per container and lot, checked against the from-scratch versions in tests. The design doesn't change. |
| Converting µg to µL on request | Dissolving powder records the mass, the volume and the concentration. | Answers come back in the dimension last recorded. Converting needs a measured concentration, and guessing would break principle 1. |
| Two people drawing on the last 50 µL at once | Both are recorded, the balance goes negative, and it's flagged. | No row locking: recording what happened matters more than stopping it. |
| Evaporation | Losses can be recorded by hand with a reason. | The simulation shows this is the biggest blind spot: expressed protein is overstated by 22 to 36% over a month. The fix follows principle 3: an evaporation rule per plate type and condition, applied automatically when a plate goes back to cold storage. |
| A count that finds something in the wrong place | A count can say "not found", which marks the item uncertain at once. | It can't yet say "found, but over here"; today the counter records a move as well. |
| Splitting into a box that already has tubes | Works, but slots are numbered from 1. | A small change to accept the first free slot; not worth the time in 48 hours. |
| Recall through a made buffer | Lineage walks through every "made from" link, so a recalled component reaches every buffer made from it. | Same mechanism as a bad target lot, so one test covers both. |
| Material sold in activity units | A material kind can count in activity units. | Converting activity to mass needs assay context we don't have; the system says it can't convert rather than guessing. |
| BLI sensors used a few times | Consumables are counted; a use count is a small rule on the material kind. | Not a deep enough change to the model to test separately. |

## Scenarios we chose not to test deeply

The full list, with a reason for each, is at the end of `scenarios/shortlist.md`. The catalog in `scenarios/catalog.yaml` marks every scenario as core, supported or cut.
