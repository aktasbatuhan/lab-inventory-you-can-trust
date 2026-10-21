#!/usr/bin/env python3
"""The referee: at the end of each simulated day, a Codex session reads the day
and writes candidate scenarios and verdicts.

    python3 sim/agents/referee.py sim/agents/runs/<run-id> --day 1     # re-run one day's referee

It runs `codex exec --skip-git-repo-check -s read-only` from the repository root
with no MCP tools: it reads the run's files and the scenario catalog, and its
final message is split into discovered/day-N.yaml and verdicts/day-N.md.
Rate limits are waited out. Standard library only.
"""
import argparse
import os
import re
import subprocess
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LIMIT = re.compile(r"rate.?limit|usage limit|429|too many requests|try again", re.I)

PROMPT = """You are the referee of a simulated protein lab. AI agents played the people in the lab for one day. Their
hands changed the real lab (notebook A, kept by a simulator) and they wrote records into the inventory database
(notebook B) with whatever they chose to say. You don't touch the lab; you judge it. Do not change any files: your
final message is the output.

Read these files (paths are relative to the repository root, which is your working directory):

- {rel}/log/day-{day}.txt: every tool call of the day, one per line, numbered L0001, L0002, ... Each line shows the
  simulated time it started and ended, who, the tool, its arguments and the answer the person got (including the clock
  and how far behind they were).
- {rel}/drift-day-{day}.json: where notebook A and notebook B disagree at the end of the day (amounts, places,
  containers only one side knows about), the flags the inventory raised, physical friction the world added on its own
  (frosted labels, scanner no-reads, short-filled vials), and each person's task list with what got done when.
- {rel}/score-day-{day}.json: the scorer's headline numbers.
- {rel}/handover-day-{day}.md: what each person said at the end of each block.
- scenarios/README.md (the scenario format and areas) and scenarios/catalog.yaml (244 scenarios we already have; search
  it, it is long).
- docs/principles.md and docs/decisions.md (how the inventory is meant to behave).

Two kinds of tools exist: hands (look, pick_up, put, pipette, use, split, get_new, bin, inspect, qc_check, make_buffer)
and pen and scanner (scan, record_*, correct, ask_inventory). A hand action with no matching record is a gap between the
notebooks. A record that doesn't match what the hands did is a gap too. Nobody was told to make mistakes.

Write your final message in exactly two parts, with these two marker lines and nothing before the first one:

===== discovered/day-{day}.yaml
A YAML list of candidate scenarios that this day actually showed: moments where the inventory and the lab drifted
apart, where someone's answer from ask_inventory misled them, where the time pressure changed what got recorded, or
where the tools made the right thing hard. Use the catalog format from scenarios/README.md (id, title, story, real_life_noise,
system_should, question_it_answers, frequency, cost_if_wrong, cost_reason, depth, sim_hook, source) plus these fields:
  id: AGENT-D{day}-01, AGENT-D{day}-02, ...
  status: "new", "variant of <catalog id>" or "already covered by <catalog id>" (check the catalog before deciding)
  evidence: list of log lines, like ["{rel}/log/day-{day}.txt L0012", "{rel}/log/day-{day}.txt L0015"]
  source: agent-sim
  run: {run_id}
Only include what really happened in the log. Fewer, solid entries beat many thin ones. If nothing happened, write [].

===== verdicts/day-{day}.md
A short markdown page. Start with one plain paragraph saying how the day went. Then, for each drift between the two
notebooks that matters (skip pure pipetting noise within a few percent), say in a sentence or two what happened, citing
log lines, and whether the inventory flagged it, someone fixed it, or it went silently wrong. Then a section on any
moment where an agent asked the inventory something and the answer misled them, or would have. End with a one-line
summary starting with "Summary:".

Writing rule: write like a thoughtful person explaining to a colleague. Plain, short sentences, no hype words, no
filler, no walls of bullets where a sentence reads better.
"""


def run_day(run_dir, day, run_id, stats=None, timeout=1500, max_wait_hours=6):
    rel = os.path.relpath(run_dir, ROOT)
    prompt = PROMPT.format(rel=rel, day=day, run_id=run_id)
    last = os.path.join(run_dir, "referee-day-%d.last.md" % day)
    waited, delay = 0, 60
    while True:
        if stats is not None:
            stats["codex_calls"] += 1
        cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "-C", ROOT, "--color", "never", "-o", last, prompt]
        t0 = time.time()
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
            out, err, code = r.stdout, r.stderr, r.returncode
        except subprocess.TimeoutExpired:
            out, err, code = "", "referee timed out after %d s" % timeout, -1
            if stats is not None:
                stats["hung"].append("referee day %d killed after %d s" % (day, timeout))
        with open(os.path.join(run_dir, "referee-day-%d.log" % day), "w") as f:
            f.write("exit %s after %.0f s\n--- stdout\n%s\n--- stderr\n%s\n" % (code, time.time() - t0, out[-20000:], err[-20000:]))
        if code != 0 and LIMIT.search(err + out) and waited < max_wait_hours * 3600:
            if stats is not None:
                stats["rate_limit_waits"] += 1
            time.sleep(delay)
            waited += delay
            delay = min(delay * 2, 900)
            continue
        break
    text = open(last).read() if os.path.exists(last) else ""
    return split_output(run_dir, day, text)


def split_output(run_dir, day, text):
    parts = re.split(r"^=====\s*(discovered/day-\d+\.yaml|verdicts/day-\d+\.md)\s*$", text, flags=re.M)
    found = {}
    for i in range(1, len(parts) - 1, 2):
        found[parts[i].split("/")[0]] = parts[i + 1].strip("\n") + "\n"
    os.makedirs(os.path.join(run_dir, "discovered"), exist_ok=True)
    os.makedirs(os.path.join(run_dir, "verdicts"), exist_ok=True)
    disc = found.get("discovered", "# the referee gave no scenarios (see referee-day-%d.log)\n[]\n" % day)
    verd = found.get("verdicts", "The referee gave no verdict for this day; see referee-day-%d.log.\n" % day)
    disc = re.sub(r"^```\w*\s*$", "", disc, flags=re.M)
    with open(os.path.join(run_dir, "discovered", "day-%d.yaml" % day), "w") as f:
        f.write(disc)
    with open(os.path.join(run_dir, "verdicts", "day-%d.md" % day), "w") as f:
        f.write(verd)
    statuses = re.findall(r"^\s*status:\s*[\"']?([^\"'\n]+)", disc, flags=re.M)
    m = re.search(r"^Summary:\s*(.+)$", verd, flags=re.M)
    return {"day": day, "new": sum(1 for s in statuses if s.strip().startswith("new")),
            "variant": sum(1 for s in statuses if s.strip().startswith("variant")),
            "covered": sum(1 for s in statuses if s.strip().startswith("already")),
            "summary": m.group(1).strip() if m else verd.strip().split("\n\n")[0][:600]}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run_dir")
    ap.add_argument("--day", type=int, default=1)
    a = ap.parse_args()
    r = run_day(os.path.abspath(a.run_dir), a.day, os.path.basename(os.path.abspath(a.run_dir)))
    print(r)


if __name__ == "__main__":
    main()
