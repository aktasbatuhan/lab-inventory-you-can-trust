# A lab run by AI agents

The dice simulation in `sim/` tests the inventory against mistakes we already thought of: it rolls for each one at a researched rate. This one is for finding the mistakes we didn't think of. A few AI agents play the people in the lab for a simulated week, under the same time pressure real people have, and a referee watches for the moments where the inventory and reality drift apart without anyone noticing.

## Running on subscriptions, not API credits

Every agent is a headless command-line session:

- **People in the lab** run on Claude Code: `claude -p`, using Batuhan's Claude subscription. Each person keeps one session for the whole week (`--session-id` on day one, `--resume` after that), so they remember yesterday and form habits, good and bad.
- **The referee** runs on Codex: `codex exec`, using his ChatGPT subscription. A different model judging the lab means the referee doesn't share the players' blind spots.

Agents get no shell, no file access and no raw SQL. Each session starts with `--strict-mcp-config` and `--allowedTools` limited to the lab's own tools (below), in an empty working directory. Codex runs with a read-only sandbox and sees only the files it's handed. It needs no tools: headless Codex won't call MCP tools without someone approving each call, which is fine because the referee only reads.

A small run is roughly 4 people × 2 shifts × 5 days = 40 sessions of 20 to 40 tool calls each. That fits comfortably within subscription limits over an afternoon. The orchestrator waits and retries when a limit is hit, rather than failing.

## The key idea: doing and writing down are separate

Each agent has two kinds of tools, and that split is what makes mistakes appear on their own instead of being injected:

**Hands (the real lab, notebook A).** `look(place)`, `pick_up(barcode)`, `put(barcode, place, slot)`, `pipette(from, to, µL)`, `split(tube, n, µL)`, `bin(barcode)`, `read_label(barcode)`. These change the true state of the world kept by the dice simulation's world model. They're honest: liquid really moves, tubes really go where they're put. The physical world adds its own friction from `sim/noise-model.yaml`: a frosted barcode that won't scan, a pipette that's a few percent off, a tube that's not in the slot the agent remembers.

**Pen and scanner (the inventory, notebook B).** `scan(barcode)`, `record_move`, `record_use`, `record_split`, `record_disposal`, `correct(event, why)`, and `ask_inventory(question)`. These call the real record API in `schema/06_record.sql` with whatever the agent says, true or not. `ask_inventory` runs the files in `queries/`, so agents see the same answers a person would.

Nobody tells an agent to make a mistake. A person who's 40 minutes behind may decide to skip recording a move, or type the volume they meant to take rather than the one they took. The gap between A and B is whatever the agents actually did.

## Time pressure

Every tool call costs simulated time. A scan takes 10 seconds, typing a record 30, a split of 20 tubes 25 minutes, finding a tube in a crowded freezer 2 to 10 minutes. Each person starts a shift with a task list and deadlines that come from Adaptyv's real Binding schedule (`sim/lab-profile.yaml`), and the orchestrator adds the things that happen in real labs: a delivery arrives mid-task, a robot run fails and needs a hand, someone asks where the PD-L1 aliquots are.

At every turn the agent sees the clock, what's left on its list, and how far behind it is. Shifts end at 18:00, and Friday afternoons are tighter. No one is told to cut corners. They're just short of time, which is how it happens in real life.

## Cast

Roles come from Adaptyv's job posts (`journal/agent-runs/adaptyv-lab.md`).

| Who | Their week |
|---|---|
| Lab operations technician | Receives deliveries, puts things away, splits target stock into aliquots, makes buffers, runs the Friday freezer count |
| Production scientist | Reconstitutes DNA, preps expression and BLI plates, runs the robot, thaws targets |
| Procurement manager | Checks what's left before reordering targets; has a budget and hates expired stock |
| Data reviewer | Plans re-runs after BLI data fails QC, needs to know what's still usable for them |
| Referee (Codex) | Sees both notebooks; doesn't touch the lab |

## The referee

At the end of each simulated day the referee gets three things: the day's tool calls from every agent, the scored difference between the two notebooks (from the dice simulation's scorer), and the current scenario catalog. It writes:

- `discovered/day-N.yaml`: new scenarios in the catalog format, each tied to the moment in the transcripts where it happened. It checks whether each one is already in `scenarios/catalog.yaml` first, and marks it `new`, `variant of <id>` or `already covered`.
- `verdicts/day-N.md`: for each drift between A and B, whether the inventory flagged it, whether someone fixed it, or whether it went silently wrong.

The referee also notes when an agent asked the inventory something and got an answer that misled it. Those are the most valuable findings, because they're about what the system says, not just what it stores.

## What comes out

```
sim/agents/runs/<run-id>/
  transcripts/<person>-day-N.jsonl   every turn, tool call and result
  timeline.md                        what happened in the lab, in order, in plain words
  discovered/day-N.yaml              candidate scenarios from the referee
  verdicts/day-N.md                  caught, fixed or silently wrong, day by day
  summary.md                         the week in a page
```

New scenarios that hold up get merged into `scenarios/catalog.yaml` with `source: agent-sim` and the run id, and the interesting ones become tests.

## Build order

1. Wait for the dice simulation's world model and scorer, and reuse them for notebook A.
2. `lab_mcp.py`: an MCP server over stdio exposing hands, pen and scanner. It's one process per run, shared by all agents, so they're working in the same lab.
3. `run.py`: the orchestrator. Simulated clock, task lists, interruptions, one `claude -p` call per person per turn block, retries on limits.
4. `referee.py`: the end-of-day `codex exec` call and the merge into `discovered/`.
5. A one-day smoke run with two people before the full week.

## Choices made

- **Python**, to share the world model with the dice simulation and match Adaptyv's lab code.
- **Time pressure on**, because realistic mistakes come from being busy, not from being told to fail.
- **Small first.** One simulated week with four people. Longer runs are a flag on `run.py`, not a redesign.
- **Claude for the people, Codex for the referee**, both on subscriptions.

## Checked so far

- 2026-10-21: a headless `claude -p` session (Haiku, `--strict-mcp-config`, built-in tools off) found a tool on our dependency-free MCP server (`mcp_stdio.py`), called it and answered from the result in 2 turns.
- 2026-10-21: headless `codex exec` refuses MCP tool calls without approval, so the referee works from files only.
