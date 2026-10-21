"""Build the data behind the review console.

Runs every scenario test in trace mode and writes share/data/*.json:
  tests.json      each test: its story, every event it recorded, every check
  scenarios.json  the scenario catalog, so tests can link to their stories
  sim.json        simulation runs, if any exist under sim/out or sim/agents/runs

Uses the same PG* environment variables and PG_BIN as run.sh, and builds its
own database (INV_DB, default inventory_trace).
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "share" / "data"
PSQL = str(Path(os.environ["PG_BIN"]) / "psql") if os.environ.get("PG_BIN") else "psql"
DB = os.environ.get("INV_DB", "inventory_trace")
SCENARIO_ID = re.compile(r"\b(?:RCV|XFER|LOC|LIFE|ASK|EDGE)-(?:BIND-)?\d+\b")
DECISION_ID = re.compile(r"\bD(?:[1-9]|1[0-9])\b")


def psql(*args, stdin=None):
    return subprocess.run([PSQL, "-X", "-d", DB, *args], input=stdin, capture_output=True, text=True)


def build_db():
    subprocess.run([PSQL, "-X", "-q", "-d", "postgres", "-c", f"drop database if exists {DB}", "-c", f"create database {DB}"],
                   check=True, capture_output=True)
    files = sorted((ROOT / "schema").glob("*.sql")) + [ROOT / "seed/01_reference_data.sql", ROOT / "tests/_helpers.sql"]
    for f in files:
        r = psql("-q", "-v", "ON_ERROR_STOP=1", "-f", str(f))
        if r.returncode:
            sys.exit(f"failed to load {f}:\n{r.stderr}")


def comment_block(lines):
    """The run of `--` lines, joined into plain text."""
    return "\n".join(l[2:].strip() for l in lines).strip()


def split_blocks(sql):
    """Each begin; ... rollback; block, with the comment just above it."""
    lines = sql.splitlines()
    blocks, pending, current = [], [], None
    for line in lines:
        s = line.strip()
        if current is None:
            if s.startswith("--"):
                pending.append(s)
            elif s == "begin;":
                current = {"story": comment_block(pending), "sql": [line]}
                pending = []
            elif s:
                pending = []
        else:
            current["sql"].append(line)
            if s == "rollback;":
                current["sql"] = "\n".join(current["sql"])
                blocks.append(current)
                current = None
    return blocks


def run_test(path):
    sql = path.read_text()
    blocks = split_blocks(sql)
    traced = ["set inv.trace = 'on';"]
    for i, b in enumerate(blocks):
        body = b["sql"].rsplit("rollback;", 1)[0]
        traced += [body, f"select 'BLOCK{i}\t' || trace_json()::text;", "rollback;"]
    r = psql("-q", "-A", "-t", stdin="\n".join(traced))
    results = {}
    for line in r.stdout.splitlines():
        m = re.match(r"BLOCK(\d+)\t(.*)", line)
        if m:
            results[int(m.group(1))] = json.loads(m.group(2))
    errors = [l for l in r.stderr.splitlines() if "ERROR" in l]
    out_blocks = []
    for i, b in enumerate(blocks):
        res = results.get(i)
        out_blocks.append({
            "story": b["story"],
            "sql": b["sql"],
            "events": res["events"] if res else [],
            "checks": res["checks"] if res else [],
            "error": None if res else (errors.pop(0) if errors else "the block stopped before it finished"),
        })
    checks = [c for b in out_blocks for c in b["checks"]]
    passed = all(b["error"] is None for b in out_blocks) and all(c["ok"] for c in checks)
    header = sql.split("begin;", 1)[0]
    return {
        "file": f"tests/{path.name}",
        "name": path.stem.split("_", 1)[1].replace("_", " "),
        "number": int(path.stem.split("_", 1)[0]),
        "summary": comment_block([l.strip() for l in header.splitlines() if l.strip().startswith("--")]),
        "scenarios": sorted(set(SCENARIO_ID.findall(sql))),
        "decisions": sorted(set(DECISION_ID.findall(sql)), key=lambda d: int(d[1:])),
        "passed": passed,
        "checks_passed": sum(c["ok"] for c in checks),
        "checks_total": len(checks),
        "blocks": out_blocks,
    }


def scenarios():
    r = subprocess.run(["ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.load_file(ARGV[0]))",
                        str(ROOT / "scenarios/catalog.yaml")], capture_output=True, text=True, check=True)
    catalog = json.loads(r.stdout)
    shortlist = set(SCENARIO_ID.findall((ROOT / "scenarios/shortlist.md").read_text().split("## What we're not doing deep")[0]))
    for s in catalog:
        s["shortlisted"] = s["id"] in shortlist
    return catalog


def sim_runs():
    runs = []
    for d in sorted((ROOT / "sim").glob("out/*")) + sorted((ROOT / "sim/agents").glob("runs/*")):
        summary = next((d / n for n in ("summary.json", "score.json") if (d / n).exists()), None)
        if summary:
            runs.append({"path": str(d.relative_to(ROOT)), **json.loads(summary.read_text())})
    return runs


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    build_db()
    tests = [run_test(p) for p in sorted((ROOT / "tests").glob("[0-9]*.sql"))]
    (OUT / "tests.json").write_text(json.dumps(tests, indent=1, default=str))
    (OUT / "scenarios.json").write_text(json.dumps(scenarios(), indent=1))
    (OUT / "sim.json").write_text(json.dumps(sim_runs(), indent=1))
    ok = sum(t["passed"] for t in tests)
    print(f"{ok}/{len(tests)} tests passed, {sum(t['checks_total'] for t in tests)} checks, "
          f"{sum(len(b['events']) for t in tests for b in t['blocks'])} events traced")


if __name__ == "__main__":
    main()
