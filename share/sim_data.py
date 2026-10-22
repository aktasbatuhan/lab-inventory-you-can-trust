"""Turn simulation runs into share/data/sim.json for the review console.

Two kinds of run:
  dice:   sim/out/<name>/ with score.json, errors.jsonl and report.md
  agents: sim/agents/runs/<id>/ with calls.jsonl, score*.json, discovered/, verdicts/, handover-day-*.md
"""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

KIND = {
    "look": "hands", "pick_up": "hands", "put": "hands", "pipette": "hands", "split": "hands", "inspect": "hands",
    "get_new": "hands", "use": "hands", "qc_check": "hands", "bin": "hands", "read_label": "hands", "wait": "hands",
    "scan": "scanner",
    "ask_inventory": "ask",
    "tell": "talk", "my_tasks": "talk", "done": "talk", "inbox": "talk",
}
ROLE = {"lena": "Lab operations", "marco": "Production scientist", "priya": "Procurement", "jonas": "Data reviewer"}


def kind(tool):
    if tool.startswith("record_") or tool in ("correct", "review_flag"):
        return "pen"
    return KIND.get(tool, "other")


def short(v, n=220):
    s = v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def yaml_to_json(path):
    r = subprocess.run(["ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.load_file(ARGV[0]))", str(path)],
                       capture_output=True, text=True)
    if r.returncode:
        return []
    data = json.loads(r.stdout)
    if isinstance(data, dict):
        data = data.get("scenarios") or data.get("discovered") or list(data.values())
    return data if isinstance(data, list) else []


def dice_run(d):
    score = json.loads((d / "score.json").read_text())
    report = (d / "report.md").read_text() if (d / "report.md").exists() else ""
    head = next((l for l in report.splitlines() if "simulated days" in l), "")
    errors = [json.loads(l) for l in (d / "errors.jsonl").read_text().splitlines() if l.strip()] if (d / "errors.jsonl").exists() else []
    verdicts = score.get("verdicts", {})
    fates, totals = {}, {}
    for e in errors:
        f = verdicts.get(e["id"], "unscored")
        e["fate"] = f
        fates.setdefault(e["type"], {}).setdefault(f, 0)
        fates[e["type"]][f] += 1
        totals[f] = totals.get(f, 0) + 1
    order = {"silently wrong": 0, "flagged": 1, "corrected": 2, "refused at entry": 3, "no lasting harm": 4}
    errors.sort(key=lambda e: (order.get(e["fate"], 9), e["at"]))
    checkpoints = []
    for c in score["checkpoints"]:
        amounts = c.get("amounts", {})
        total = sum(sum(v.values()) for v in amounts.values()) or 1
        off = sum(v.get("off", 0) for v in amounts.values())
        target_real = sum(v[0] for k, v in c.get("usable", {}).items() if k.startswith("target"))
        target_says = sum(v[1] for k, v in c.get("usable", {}).items() if k.startswith("target"))
        prot = c.get("usable", {}).get("sample_protein", [0, 0])
        loc = c.get("location", {})
        checkpoints.append({
            "label": c["label"], "t": c["t"],
            "amounts_off_pct": round(100 * off / total, 1),
            "ghosts": len(c.get("ghosts", [])), "lost": len(c.get("lost", [])),
            "wrong_place": loc.get("wrong place", 0) + loc.get("right place, wrong spot", 0),
            "flags": sum(c.get("flags", {}).values()),
            "flag_kinds": c.get("flags", {}),
            "target_really": round(target_real, 1), "target_says": round(target_says, 1),
            "protein_really": round(prot[0], 1), "protein_says": round(prot[1], 1),
            "usable_seconds": c.get("timings", {}).get("usable"),
        })
    m = re.search(r"(\d+) simulated days.*?(\d+) designs a week, (\d+) targets", head)
    seed = re.search(r"seed (\d+)", head)
    preset = "bad_week" if d.name.startswith("bad_week") else "normal"
    return {
        "kind": "dice", "name": d.name,
        "title": f"{'Bad week' if preset == 'bad_week' else 'Normal'} noise, {m.group(1) if m else '?'} days, {m.group(2) if m else '?'} designs a week",
        "preset": preset, "days": int(m.group(1)) if m else None, "designs_per_week": int(m.group(2)) if m else None,
        "targets": int(m.group(3)) if m else None, "seed": int(seed.group(1)) if seed else None,
        "recorded_calls": sum(1 for _ in (d / "recorded.sql").open()) if (d / "recorded.sql").exists() else None,
        "load_seconds": score.get("load_seconds"), "description": head,
        "checkpoints": checkpoints, "fates": fates, "totals": totals, "mistakes_total": len(errors),
        "mistakes": [{k: e.get(k) for k in ("id", "type", "at", "by", "what", "fate", "containers")} for e in errors[:300]],
    }


def agent_run(d):
    calls = [json.loads(l) for l in (d / "calls.jsonl").read_text().splitlines() if l.strip()]
    people = sorted({c["who"] for c in calls})
    days = sorted(int(m.group(1)) for p in d.glob("score-day-*.json") if (m := re.search(r"day-(\d+)", p.name)))
    score = json.loads((d / "score.json").read_text()) if (d / "score.json").exists() else {}
    per_day = {}
    for day in days:
        per_day[day] = json.loads((d / f"score-day-{day}.json").read_text())
    discovered = []
    for f in sorted((d / "discovered").glob("*.yaml")) if (d / "discovered").exists() else []:
        for s in yaml_to_json(f):
            if isinstance(s, dict):
                s["day_file"] = f.name
                discovered.append(s)
    verdicts = {f.stem: f.read_text() for f in sorted((d / "verdicts").glob("*.md"))} if (d / "verdicts").exists() else {}
    handovers = {f.stem: f.read_text() for f in sorted(d.glob("handover-day-*.md"))}
    return {
        "kind": "agents", "name": d.name,
        "title": score.get("title") or d.name,
        "finished": (d / "summary.md").exists(),
        "people": [{"id": p, "name": p.capitalize(), "role": ROLE.get(p, "")} for p in people],
        "stats": {k: v for k, v in score.items() if isinstance(v, (int, float))},
        "per_day": per_day,
        "calls": [{
            "n": c["n"], "who": c["who"], "start": c["sim_start"], "end": c["sim_end"], "minutes": c.get("minutes"),
            "tool": c["tool"], "kind": kind(c["tool"]), "refused": bool(c.get("refused")),
            "args": short(c.get("args", {}), 160), "result": short(c.get("result", ""), 260),
        } for c in calls],
        "discovered": discovered,
        "verdicts": verdicts,
        "handovers": handovers,
        "summary": (d / "summary.md").read_text() if (d / "summary.md").exists() else "",
        "timeline": (d / "timeline.md").read_text() if (d / "timeline.md").exists() else "",
    }


def sim_runs():
    runs = []
    for d in sorted((ROOT / "sim/out").glob("*")):
        if (d / "score.json").exists() and not d.name.startswith("probe") and d.name not in ("normal", "bad_week"):
            runs.append(dice_run(d))
    for d in sorted((ROOT / "sim/agents/runs").glob("*")):
        if (d / "calls.jsonl").exists():
            runs.append(agent_run(d))
    return runs


if __name__ == "__main__":
    runs = sim_runs()
    out = ROOT / "share/data/sim.json"
    out.write_text(json.dumps(runs, indent=1, ensure_ascii=False, default=str))
    print(f"{len(runs)} runs, {out.stat().st_size // 1024} KB")
