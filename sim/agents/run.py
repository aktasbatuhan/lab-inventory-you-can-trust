#!/usr/bin/env python3
"""Run the lab with AI agents as the people in it.

    python3 sim/agents/run.py --days 1 --people tech,scientist --model haiku      # the smoke run
    python3 sim/agents/run.py --days 5 --people tech,scientist,procurement,reviewer

Each person is a headless Claude Code session (`claude -p`) whose only tools are
the lab's (lab_mcp.py), kept for the whole run: --session-id on the first block,
--resume after. The lab itself (lab.py: the World, the inventory database and
everyone's clock) lives in this process and is served to the MCP servers over
JSON-over-HTTP on localhost. At the end of each day the scorer compares the two
notebooks and the referee (referee.py, `codex exec`) reads the day.

Writes sim/agents/runs/<run-id>/. Needs PG_BIN, PGHOST, PGPORT, PGUSER like
sim/run.sh; the database is INV_DB (default inv_agentlab) and is rebuilt.
Standard library only.
"""
import argparse
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lab as LAB      # noqa: E402
import referee         # noqa: E402

UTC, LOCAL = LAB.UTC, LAB.LOCAL
START_DAY = LAB.S.START.astimezone(LOCAL).date()      # Monday 7 September 2026

CAST = {
    "tech": {"key": "lena", "actor": "p:lena", "name": "Lena", "bench": "Bench B1", "prompt": "lab-ops-technician.md"},
    "scientist": {"key": "marco", "actor": "p:marco", "name": "Marco", "bench": "Bench B2", "prompt": "production-scientist.md"},
    "procurement": {"key": "jonas", "actor": "p:jonas", "name": "Jonas", "bench": "Bench B1", "prompt": "procurement-manager.md"},
    "reviewer": {"key": "priya", "actor": "p:priya", "name": "Priya", "bench": "Bench B2", "prompt": "data-reviewer.md"},
}
BLOCKS = [((8, 0), (13, 0), "morning"), ((13, 45), (18, 0), "afternoon")]


def at(day, h, m=0):
    return datetime(day.year, day.month, day.day, h, m, tzinfo=LOCAL).astimezone(UTC)


def workdays(n):
    d, out = START_DAY, []
    while len(out) < n:
        if d.weekday() < 5:
            out.append(d)
        d += timedelta(days=1)
    return out


# ---------------------------------------------------------------------- the schedule
def plan_day(lab, day, k, who, size):
    """Tasks, messages and deliveries for one workday. Deadlines follow the Binding schedule
    in lab-profile.yaml: target plate prep about 30 minutes before a BLI slot, buffers on Monday,
    deliveries in the morning, the count on Friday. `size` is "small" for the smoke run."""
    wd = day.weekday()
    target, other = (("EGFR", "PD-L1") if k % 2 == 0 else ("PD-L1", "EGFR"))
    tasks = {w: [] for w in who}

    def task(w, text, h=None, m=0):
        if w in tasks:
            tasks[w].append({"id": "T%d" % (len(tasks[w]) + 1), "text": text, "due": at(day, h, m) if h is not None else None,
                             "done_at": None, "note": ""})

    if wd == 0 and size != "small":
        task("tech", "Make this week's loading buffer (recipe buffer:loading) in a new bottle from the water, HEPES and NaCl "
                     "on Shelf S1, and put it in Fridge R1. Last week's bottle (BUF-00046) goes in the bin.", 10, 0)
    task("tech", "A target delivery is due around 09:00 on the Goods-in shelf. Book every vial in as soon as it arrives.", 10, 30)
    task("tech", "QC each new target vial (qc_check) and record the result.", 13, 0)
    task("tech", "Split every vial that passed QC into 45 µL aliquots in a new box in Freezer F80-1, then bin the empty vial.", 16, 0)
    if wd == 4 and size != "small":
        task("tech", "Friday count: count Freezer F80-1 and record it.", 17, 0)
    task("scientist", "BLI run for experiment EXP-%02d (%s) is booked on Gator 1 at 11:00. Prepare the target plate: a new BLI "
                      "plate with 4 µL of %s target in each of wells A1 to H1, from the %s aliquots in Freezer F80-1. Use "
                      "part-used aliquots first." % (7 + k, target, target, target), 10, 45)
    task("scientist", "For the same run, take 40 mL of BLI running buffer from Fridge R1 and 32 sensors from a sensor box on Shelf S1.", 11, 0)
    task("scientist", "Put the %s aliquots you used back in their box in the -80, or bin any that are empty." % target, 11, 30)
    task("scientist", "Priya (data reviewer) is planning a %s re-run for Thursday and needs to know how much %s target is "
                      "usable. Find out and tell her." % (other, other), 14, 0)
    if size != "small":
        task("scientist", "The run ends at 15:00. The target plate is single use: bin it.", 16, 0)
    task("procurement", "Check stock of EGFR and PD-L1 target and of BLI sensors; order what will run out within two weeks. "
                        "The supplier cut-off is 12:00.", 12, 0)
    task("procurement", "Check what expires in the next 14 days and tell Lena what to use first.", 16, 0)
    task("reviewer", "Run EXP-%02d failed QC on three designs. Plan a re-run for Thursday: check the expression plate, %s target "
                     "and loading buffer are still usable then, and tell Marco what to prepare." % (5 + k, other), 15, 0)

    if "tech" in who:
        lab.at(at(day, 9, 0) + timedelta(minutes=lab.rng.randint(-10, 25)), lab.deliver,
               [("vendorA:EGFR-100", 200.0), ("vendorA:PDL1-200", 200.0)], "")
    msgs = []
    if "scientist" in who:
        msgs.append((at(day, 10, 20), "marco", "Sara (lab manager) asks: the Gator 1 slot might move up by 15 minutes, can you be ready at 10:45?"))
        msgs.append((at(day, 14, 30), "marco", "Priya asks again about the usable %s; she wants to send the plan today." % other))
    if "tech" in who:
        msgs.append((at(day, 11, 15), "lena", "Marco asks where the %s aliquots are; he can't find a part-used one." % target))
        msgs.append((at(day, 15, 10), "lena", "Sara asks: is the new loading buffer in the fridge and on record? The Thursday run depends on it."))
    for when, key, text in msgs:
        lab.at(when, lab.message, key, text)
    return tasks


# ---------------------------------------------------------------------- the lab server
def serve(lab):
    class H(BaseHTTPRequestHandler):
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            try:
                text = lab.call(body["agent"], body["tool"], body.get("args") or {})
            except Exception as e:  # keep the server up; the agent sees the error
                text = "error in the lab server: %s" % e
            out = json.dumps({"text": text}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(out)))
            self.end_headers()
            self.wfile.write(out)

        def log_message(self, *a):
            pass

    srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, "http://127.0.0.1:%d" % srv.server_address[1]


# ---------------------------------------------------------------------- one person's block
LIMIT = re.compile(r"rate.?limit|usage limit|limit reached|429|overloaded|too many requests|hit your limit", re.I)


def session_exists(sid):
    root = os.path.expanduser("~/.claude/projects")
    for d, _, files in os.walk(root):
        if sid + ".jsonl" in files:
            return True
    return False


def run_block(person, prompt, a, url, run_dir, state, label, stats):
    cfg = os.path.join(run_dir, "mcp-%s.json" % person["key"])
    with open(cfg, "w") as f:
        json.dump({"mcpServers": {"lab": {"command": sys.executable, "args": [os.path.join(HERE, "lab_mcp.py")],
                                          "env": {"LAB_URL": url, "LAB_AGENT": person["key"]}}}}, f)
    system = open(os.path.join(HERE, "personas", "_lab.md")).read() + "\n" + open(os.path.join(HERE, "personas", person["prompt"])).read()
    waited, delay = 0, 60
    out_path = os.path.join(run_dir, "transcripts", "%s-%s.json" % (person["key"], label))
    while True:
        resume = state.get("started") and session_exists(state["sid"])
        cmd = ["claude", "-p", prompt, "--system-prompt", system, "--mcp-config", cfg, "--strict-mcp-config",
               "--allowedTools", "mcp__lab__*", "--tools", "", "--setting-sources", "", "--output-format", "json",
               "--max-turns", str(a.max_turns), "--model", a.model]
        cmd += ["--resume", state["sid"]] if resume else ["--session-id", state["sid"]]
        cwd = tempfile.mkdtemp(prefix="agentlab-")
        t0 = time.time()
        stats["claude_calls"] += 1
        proc = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            out, err = proc.communicate(timeout=a.block_timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            out, err = proc.communicate()
            stats["hung"].append("%s %s killed after %d s" % (person["key"], label, a.block_timeout))
            state["started"] = True
            res = {"is_error": True, "result": "session hung and was killed", "killed": True}
            break
        try:
            res = json.loads(out.strip().splitlines()[-1]) if out.strip() else {"is_error": True, "result": err[-2000:]}
        except (json.JSONDecodeError, IndexError):
            res = {"is_error": True, "result": (out + err)[-2000:]}
        res["wall_seconds"] = round(time.time() - t0, 1)
        res["exit_code"] = proc.returncode
        text = str(res.get("result", "")) + " " + err[-1000:]
        if res.get("session_id") or session_exists(state["sid"]):
            state["started"] = True
        if (res.get("is_error") or proc.returncode) and LIMIT.search(text) and waited < a.max_wait_hours * 3600:
            stats["rate_limit_waits"] += 1
            print("  %s: rate limited, waiting %d s" % (person["key"], delay), flush=True)
            time.sleep(delay)
            waited += delay
            delay = min(delay * 2, 900)
            continue
        break
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(res, f, indent=1)
    return res


# ---------------------------------------------------------------------- writing it up
def day_log(run_dir, day_no, day):
    """The day's tool calls as numbered lines the referee can point at."""
    recs = [json.loads(x) for x in open(os.path.join(run_dir, "calls.jsonl"))]
    recs = [r for r in recs if r["sim_start"][:10] == day.isoformat()]
    lines = []
    for i, r in enumerate(recs, 1):
        args = ", ".join("%s=%s" % (k, json.dumps(v, ensure_ascii=False)) for k, v in (r["args"] or {}).items())
        res = r["result"].replace("\n", " / ")
        lines.append("L%04d %s-%s %-6s %s(%s) -> %s" % (i, r["sim_start"][11:16], r["sim_end"][11:16], r["who"], r["tool"], args, res))
    os.makedirs(os.path.join(run_dir, "log"), exist_ok=True)
    path = os.path.join(run_dir, "log", "day-%d.txt" % day_no)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.makedirs(os.path.join(run_dir, "transcripts"), exist_ok=True)
    for who in {r["who"] for r in recs}:
        with open(os.path.join(run_dir, "transcripts", "%s-day-%d.jsonl" % (who, day_no)), "w") as f:
            for r in recs:
                if r["who"] == who:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
    return recs


def sentence(r, names):
    who = names.get(r["who"], r["who"])
    first = r["result"].split("\n")[0].strip()
    if r["refused"]:
        return "%s tried %s but couldn't: %s" % (who, r["tool"].replace("_", " "), first.replace("Couldn't do that: ", ""))
    if first.startswith("You "):
        return who + " " + first[4:]
    if first.startswith("Recorded"):
        return "%s recorded it. %s" % (who, first.replace("Recorded: ", "").replace("Recorded ", ""))
    if r["tool"] == "ask_inventory":
        return "%s asked the inventory (%s %s)." % (who, r["args"].get("question"), r["args"].get("settings", ""))
    if r["tool"] == "look":
        return "%s looked in %s." % (who, r["args"].get("place"))
    if r["tool"] == "tell":
        return "%s told %s: \"%s\"" % (who, r["args"].get("to"), r["args"].get("message"))
    if r["tool"] == "my_tasks":
        return "%s checked the task list." % who
    return "%s: %s" % (who, first[0].lower() + first[1:] if first else r["tool"])


def write_timeline(run_dir, days_recs, names, lab):
    L = ["# What happened in the lab", "",
         "Every tool call in order of simulated time, in plain words. The full calls with arguments and answers are in "
         "`calls.jsonl` and `log/day-N.txt`.", ""]
    for day_no, (day, recs) in enumerate(days_recs, 1):
        L += ["## Day %d, %s" % (day_no, day.strftime("%A %-d %B")), ""]
        events = [(r["sim_start"], sentence(r, names)) for r in recs]
        for d in lab.deliveries:
            if d["at"][:10] == day.isoformat():
                events.append((d["at"], "A delivery landed on the Goods-in shelf: %s." % "; ".join(d["slip"])))
        for f in lab.friction:
            if f["at"][:10] == day.isoformat():
                events.append((f["at"], "The lab itself: %s." % f["what"]))
        for t, s in sorted(events, key=lambda x: x[0]):
            L.append("- %s %s" % (t[11:16], s))
        L.append("")
    with open(os.path.join(run_dir, "timeline.md"), "w") as f:
        f.write("\n".join(L))


def write_summary(run_dir, a, run_id, days, people, stats, scores, refs, handovers, lab):
    last = scores[-1]["headline"] if scores else {}
    calls = sum(1 for _ in open(os.path.join(run_dir, "calls.jsonl")))
    refused = sum(1 for x in open(os.path.join(run_dir, "calls.jsonl")) if json.loads(x)["refused"])
    disc = {"new": 0, "variant": 0, "covered": 0}
    for r in refs:
        for k in disc:
            disc[k] += r.get(k, 0)
    title = "Agent lab, %d day%s, %d %s (%s)" % (len(days), "" if len(days) == 1 else "s", len(people),
                                                  "person" if len(people) == 1 else "people", a.model)
    score = {"title": title, "kind": "agent-lab", "run_id": run_id, "model": a.model, "days": len(days),
             "people": len(people), "tool_calls": calls, "refused_calls": refused,
             "claude_calls": stats["claude_calls"], "codex_calls": stats["codex_calls"],
             "rate_limit_waits": stats["rate_limit_waits"], "hung_sessions": len(stats["hung"]),
             "friction_events": len(lab.friction), "discovered_new": disc["new"], "discovered_variant": disc["variant"],
             "discovered_already_covered": disc["covered"]}
    score.update(last)
    score["checkpoints"] = [s["checkpoint"] for s in scores]
    with open(os.path.join(run_dir, "score.json"), "w") as f:
        json.dump(score, f, indent=1)

    names = ", ".join("%s (%s)" % (CAST[p]["name"], p) for p in people)
    L = ["# %s" % title, "",
         "%s worked %s in the simulated lab, starting %s. Each block of a shift was one headless Claude Code session "
         "(%s), with only the lab's tools. Together they made %d tool calls, %d of which the lab or the inventory turned down."
         % (names, "one day" if len(days) == 1 else "%d days" % len(days), days[0].strftime("%A %-d %B"), a.model, calls, refused), ""]
    if last:
        L += ["## The two notebooks at the end", "",
              "At the last checkpoint the scorer compared %d amounts (one per container and lot). %d were off by more than 10%% "
              "and %d were within 10%% (pipetting noise alone puts most hand-filled tubes there). %d containers were in the wrong "
              "place or slot on record, %d were still live on record after going in the bin, %d were recorded as gone but are "
              "still in the lab, and %d exist in the lab but were never recorded at all. %d records point at containers that "
              "don't exist. flags() raised %d items."
              % (last["amounts_compared"], last["amounts_off"], last["amounts_within_10pct"], last["wrong_place_or_spot"],
                 last["ghosts"], last["lost"], last["never_recorded"], last["only_in_inventory"], last["flags"]), "",
              "Usable target protein: really %.1f µL, the inventory says %.1f µL." % (last["target_usable_really_ul"], last["target_usable_inventory_ul"]), ""]
    L += ["## What the people said at the end of their blocks", ""]
    for h in handovers:
        L += ["**%s, %s.** %s" % (h["name"], h["label"], (h["text"] or "(no note)").strip().replace("\n\n", "\n")), ""]
    if refs:
        L += ["## The referee", ""]
        for r in refs:
            L.append("Day %d: %s" % (r["day"], r["summary"]))
        L.append("")
    L += ["## Cost and running", "",
          "%d claude sessions and %d codex calls. %d waits for a rate limit. %s"
          % (stats["claude_calls"], stats["codex_calls"], stats["rate_limit_waits"],
             ("Sessions killed for hanging: " + "; ".join(stats["hung"]) + ".") if stats["hung"] else "No session hung."), ""]
    with open(os.path.join(run_dir, "summary.md"), "w") as f:
        f.write("\n".join(L))
    return score


# ---------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--days", type=int, default=1, help="workdays to simulate")
    ap.add_argument("--people", default="tech,scientist", help="comma-separated: " + ",".join(CAST))
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--max-turns", type=int, default=60)
    ap.add_argument("--block-timeout", type=int, default=1800, help="seconds before a hung session is killed")
    ap.add_argument("--max-wait-hours", type=float, default=6, help="how long to keep waiting out rate limits")
    ap.add_argument("--size", default="normal", choices=["small", "normal"])
    ap.add_argument("--preset", default="normal", help="noise preset for the physical world (normal or bad_week)")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--run-id", default=None)
    ap.add_argument("--no-referee", action="store_true")
    ap.add_argument("--db", default=os.environ.get("INV_DB", "inv_agentlab"))
    a = ap.parse_args()
    people = [p.strip() for p in a.people.split(",") if p.strip()]
    run_id = a.run_id or time.strftime("%Y%m%d-%H%M") + "-%dd-%dp-%s" % (a.days, len(people), a.model)
    run_dir = os.path.join(HERE, "runs", run_id)
    os.makedirs(os.path.join(run_dir, "transcripts"), exist_ok=True)
    print("run %s -> %s" % (run_id, run_dir), flush=True)

    lab = LAB.AgentLab(run_dir, a.db, a.seed, a.preset)
    lab.sql("insert into actor values ('p:jonas', 'person', 'Jonas (procurement)'), ('p:priya', 'person', 'Priya (data review)') on conflict do nothing")
    srv, url = serve(lab)
    states = {}
    for p in people:
        c = CAST[p]
        lab.add_person(c["key"], c["actor"], c["name"], c["bench"])
        states[p] = {"sid": str(uuid.uuid4()), "started": False}
    with open(os.path.join(run_dir, "sessions.json"), "w") as f:
        json.dump({p: s["sid"] for p, s in states.items()}, f, indent=1)

    stats = {"claude_calls": 0, "codex_calls": 0, "rate_limit_waits": 0, "hung": []}
    days = workdays(a.days)
    scores, refs, handovers, days_recs = [], [], [], []
    names = {CAST[p]["key"]: CAST[p]["name"] for p in people}
    for k, day in enumerate(days):
        day_no = k + 1
        tasks = plan_day(lab, day, k, people, a.size)
        for p in people:
            person = lab.people[CAST[p]["key"]]
            person.tasks = tasks[p]
            person.shift_end = at(day, 18)
        for (h0, m0), (h1, m1), bname in BLOCKS:
            label = "day-%d-%s" % (day_no, bname)
            threads, results = [], {}
            for p in people:
                person = lab.people[CAST[p]["key"]]
                start = at(day, h0, m0)
                with lab.lock:
                    person.clock = max(person.clock or start, start)
                    person.block_end = at(day, h1, m1)
                if person.clock >= person.block_end:
                    continue
                listing = "\n".join("- %s (due %s): %s" % (t["id"], LAB.hm(t["due"]) if t["due"] else "today", t["text"]) for t in person.tasks)
                if bname == "morning":
                    prompt = ("Good morning. It's %s, %s, and you're at your bench. Your list for today:\n%s\n\n"
                              "The morning block ends at %s. Start now." % (day.strftime("%A %-d %B"), LAB.hm(person.clock), listing, LAB.hm(person.block_end)))
                else:
                    prompt = ("You're back from lunch; it's %s. The afternoon block ends at %s, the end of your shift. "
                              "Check your list (my_tasks) and carry on." % (LAB.hm(person.clock), LAB.hm(person.block_end)))
                th = threading.Thread(target=lambda p=p, prompt=prompt: results.__setitem__(
                    p, run_block(CAST[p], prompt, a, url, run_dir, states[p], label, stats)))
                threads.append(th)
                th.start()
                print("  %s: %s started (%s)" % (label, CAST[p]["name"], LAB.hm(person.clock)), flush=True)
            for th in threads:
                th.join()
            for p, res in results.items():
                person = lab.people[CAST[p]["key"]]
                handovers.append({"name": CAST[p]["name"], "label": label.replace("-", " "), "text": res.get("result") if not res.get("is_error") else
                                  "(no handover note: the session ran out of turns at %s)" % LAB.hm(person.clock) if res.get("subtype") == "error_max_turns" else
                                  "(session ended with an error: %s)" % str(res.get("result"))[:300]})
                print("  %s: %s finished at sim %s, %d turns, %s s, %s" % (label, CAST[p]["name"], LAB.hm(person.clock),
                      res.get("num_turns", 0), res.get("wall_seconds"), res.get("subtype", "error" if res.get("is_error") else "ok")), flush=True)
        with open(os.path.join(run_dir, "handover-day-%d.md" % day_no), "w") as f:
            for h in handovers:
                if h["label"].startswith("day %d" % day_no):
                    f.write("## %s, %s\n\n%s\n\n" % (h["name"], h["label"], h["text"]))
        recs = day_log(run_dir, day_no, day)
        days_recs.append((day, recs))
        sc = lab.score("day %d" % day_no, at(day, 18, 30))
        scores.append(sc)
        with open(os.path.join(run_dir, "score-day-%d.json" % day_no), "w") as f:
            json.dump({"headline": sc["headline"], "checkpoint": sc["checkpoint"]}, f, indent=1, default=str)
        with open(os.path.join(run_dir, "drift-day-%d.json" % day_no), "w") as f:
            json.dump({"drift": sc["drift"], "flags": sc["flags"], "friction": sc["friction"],
                       "tasks": {p: [dict(t, due=LAB.hm(t["due"]) if t["due"] else None, done_at=LAB.hm(t["done_at"]) if t["done_at"] else None)
                                     for t in lab.people[CAST[p]["key"]].tasks] for p in people}}, f, indent=1, default=str)
        print("  day %d scored: %s" % (day_no, json.dumps(sc["headline"])), flush=True)
        write_timeline(run_dir, days_recs, names, lab)
        if not a.no_referee:
            r = referee.run_day(run_dir, day_no, run_id, stats)
            refs.append(r)
            print("  day %d referee: %s" % (day_no, r["summary"][:200]), flush=True)
    write_summary(run_dir, a, run_id, days, people, stats, scores, refs, handovers, lab)
    srv.shutdown()
    print("done: %s" % run_dir)


if __name__ == "__main__":
    main()
