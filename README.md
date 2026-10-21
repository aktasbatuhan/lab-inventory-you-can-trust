# Lab inventory you can trust

A design for tracking material in a high-throughput protein lab: how much there is, how much of it can actually be used, where it is, where it came from, and who changed what. It started as a take-home exercise for Adaptyv Bio and is kept public so the reasoning can be followed step by step.

The brief is in [`case/brief.md`](case/brief.md). The short version: every experiment uses up DNA, proteins, buffers and plastics; everything else in the lab trusts the inventory; and when the inventory is wrong, people reorder things they already have, use plates that were thrown away, or can't trace a bad batch to the results it touched.

## The idea in one paragraph

We never store "how much is left" as a number that gets overwritten. Every change is written down as a new entry, and the current amount is worked out from those entries. Mistakes are fixed by adding a correcting entry, so the history is never lost and we can always answer "what did the record say before?". On top of that, we keep three things apart that are easy to blur: what a material is, which batch it came from, and which barcoded tube or plate it's sitting in.

## How to read this repo

| Folder | What's in it |
|---|---|
| [`case/`](case/) | The original brief and workflow diagram, unchanged |
| [`scenarios/`](scenarios/) | Stories about what happens in the lab and what the inventory should say afterwards. Written before the schema, used as tests after |
| [`docs/`](docs/) | The written deliverables: assumptions, data model, decisions, what we cut |
| [`schema/`](schema/) | The SQL schema, in the order it runs |
| [`queries/`](queries/) | One query per question the lab asks |
| [`seed/`](seed/), [`sim/`](sim/), [`tests/`](tests/) | Example data, a small simulated lab that makes realistic mistakes, and the tests that check the system copes |
| [`journal/`](journal/) | How the work actually went, day by day, including the raw output of every AI agent we used |
| [`share/`](share/) | Polished versions for reading without the repo |

The commit history is part of the story. Each milestone is its own commit, so you can watch the design take shape.

## Deliverables

Filled in as they're finished.

| Deliverable | Where |
|---|---|
| Principles the design follows | [`docs/principles.md`](docs/principles.md) |
| Data model, explained | [`docs/data-model.md`](docs/data-model.md) |
| SQL schema | [`schema/`](schema/), run in order |
| Decisions and why | [`docs/decisions.md`](docs/decisions.md) |
| Queries for the lab's questions, with real answers | [`queries/`](queries/) and [`queries/examples/`](queries/examples/) |
| Scenario catalog (244 stories, 29 themes) | [`scenarios/`](scenarios/) |
| Scenario tests (20, all passing) | [`tests/`](tests/), run with `./run.sh` |
| Demo lab walking the Binding workflow | [`seed/02_demo_lab.sql`](seed/02_demo_lab.sql), open with `./run.sh demo` |
| Simulation | [`sim/`](sim/) (in progress) |
| What we cut and why | [`scenarios/shortlist.md`](scenarios/shortlist.md) for now |
| Assumptions | not yet |

## How this was made

Batuhan Aktas did this with heavy use of AI tools (Claude Code, with Codex as a second opinion), which the brief allows. The `journal/` folder shows where agents did the work and where the decisions were made.
