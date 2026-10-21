# Adaptyv Bio inventory take-home

Case brief: `case/brief.md`. Workflow diagram: `case/binding-workflow.png`.

## Writing rule (every deliverable, doc, scenario, comment, slide)
Write like a thoughtful person explaining to a colleague, not like an AI.
- Plain, natural sentences. Short words over jargon. If a lab or database term is needed, explain it once in everyday words.
- No filler openers ("Great question", "In today's fast-paced lab"), no hype words (robust, seamless, leverage, comprehensive, delve, crucial).
- No walls of bullets where a sentence reads better. No bold on every other phrase.
- Say what we decided and why. Admit trade-offs plainly.
- Read it out loud in your head. If it sounds like a brochure or a chatbot, rewrite it.

## Design rules
No eyebrow/kicker lines above headings. No dot-separated titles or labels. No colored side-stripe cards.

## Folder layout
- `case/` the original brief, untouched
- `docs/` the written deliverables (assumptions, data model, decisions, cuts)
- `scenarios/` scenario catalog; `scenarios/raw/` per-area drafts from agents
- `schema/` SQL schema files, numbered in run order
- `queries/` one SQL file per question the lab asks
- `seed/` example data; `sim/` the lab simulation; `tests/` scenario tests
- `journal/` how we worked: dated notes, decisions as they happened, raw agent outputs in `journal/agent-runs/`
- `share/` polished, shareable versions of the above (built at the end)
