#!/usr/bin/env python3
"""Compare what the inventory says with what really happened.

    python3 sim/score.py sim/out/normal            # build a fresh database, load, score
    python3 sim/score.py sim/out/normal --no-load  # score a database that's already loaded

Reads truth.json (World snapshots, one per checkpoint), errors.jsonl if there is
one, and loads recorded.sql after schema/*.sql and seed/01_reference_data.sql,
like run.sh does. Writes report.md and score.json next to them.

The comparison itself, compare(snapshot, db), needs only a World snapshot and a
database whose sim.cmap and sim.lmap tables map the world's ids (C12, L40) to
database ids. Any lab that drives world.py and writes those two tables can use it.

Connection: INV_DB (default inv_sim_agent), PG_BIN, and the usual PGHOST,
PGPORT, PGUSER. Standard library only.
"""
import argparse
import csv
import io
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PSQL = os.path.join(os.environ["PG_BIN"], "psql") if os.environ.get("PG_BIN") else "psql"
REAL_EVENTS = {"supplier_duplicate", "rule_default_wrong", "freezer_failure"}
NOT_ABOUT_ERRORS = {"over thaw limit"}
# A flag only counts as catching a mistake if it is the kind of flag that mistake can cause.
AMOUNT = {"negative balance", "robot step assumed", "robot run incomplete"}
PLACE = {"location uncertain", "seen after it left"}
RELEVANT = {
    "move_unscanned": PLACE, "discard_unscanned": PLACE, "count_missed": PLACE, "wrong_position": PLACE,
    "rule_default_wrong": PLACE, "freezer_failure": PLACE,
    "step_unrecorded": AMOUNT, "typo_small": AMOUNT, "typo_big": AMOUNT, "supplier_short_fill": AMOUNT,
    "wrong_scan": AMOUNT | PLACE, "late_sync": AMOUNT | PLACE,
    "robot_step_missing": AMOUNT, "robot_log_late": AMOUNT,
    "duplicate_delivery": {"possible duplicate delivery"} | AMOUNT, "supplier_duplicate": {"possible duplicate delivery"},
    "duplicate_label": {"barcode clash"},
}


def psql_file(db, path):
    subprocess.run([PSQL, "-q", "-v", "ON_ERROR_STOP=1", "-d", db, "-f", path], check=True, stdout=subprocess.DEVNULL)


def query(db, sql):
    out = subprocess.run([PSQL, "-X", "-q", "-v", "ON_ERROR_STOP=1", "--csv", "-d", db, "-c", sql],
                         check=True, capture_output=True, text=True).stdout
    return list(csv.DictReader(io.StringIO(out)))


def build(db, recorded):
    subprocess.run([PSQL, "-q", "-d", "postgres", "-c", "drop database if exists %s" % db, "-c", "create database %s" % db],
                   check=True, stdout=subprocess.DEVNULL)
    for f in sorted(os.listdir(os.path.join(ROOT, "schema"))):
        if f.endswith(".sql"):
            psql_file(db, os.path.join(ROOT, "schema", f))
    psql_file(db, os.path.join(ROOT, "seed", "01_reference_data.sql"))
    t0 = time.time()
    psql_file(db, recorded)
    return time.time() - t0


def lit(t):
    return "'%s'::timestamptz" % t


# ---------------------------------------------------------------------- one checkpoint
def compare(snap, db, k=None):
    """Score the database against one World snapshot. t is the snapshot's time;
    k (what the record knew) defaults to the same moment: 'what did the system say then?'"""
    T, K = lit(snap["t"]), lit(k or snap["t"])
    timings = {}

    def timed(name, sql):
        t0 = time.time()
        rows = query(db, sql)
        timings[name] = round(time.time() - t0, 2)
        return rows

    cid_sql = "coalesce(cm.sim_id, pm.sim_id || '/' || c.position, 'db:' || c.id)"
    joins = ("join container c on c.id = x.container_id left join sim.cmap cm on cm.db_id = c.id "
             "left join sim.cmap pm on pm.db_id = c.plate_id")
    bal = timed("balances", "select %s as cid, coalesce(lm.sim_id, 'db:' || x.lot_id) as lot, m.kind_id as kind, x.dimension, x.amount "
                "from balances(%s, %s) x %s left join sim.lmap lm on lm.db_id = x.lot_id join lot l on l.id = x.lot_id "
                "join material m on m.id = l.material_id" % (cid_sql, T, K, joins))
    cons = timed("containers", "with ps as (select container_id, parent_id, slot from parent_spans(%s) where from_at <= %s and %s < to_at) "
                 "select cm.sim_id as cid, c.plate_id is null as top, (x.container_id is null) as live, pm.sim_id as parent, ps.slot "
                 "from container c join events_at(%s, %s) e on e.id = c.created_event_id join sim.cmap cm on cm.db_id = c.id "
                 "left join exits(%s, %s) x on x.container_id = c.id left join ps on ps.container_id = c.id "
                 "left join sim.cmap pm on pm.db_id = ps.parent_id" % (K, T, T, T, K, T, K))
    use = timed("usable", "select %s as cid, coalesce(lm.sim_id, 'db:' || x.lot_id) as lot, x.material_id, x.usable, "
                "array_to_string(x.reasons, '; ') as reasons from usable(%s, %s) x %s left join sim.lmap lm on lm.db_id = x.lot_id"
                % (cid_sql, T, K, joins))
    flg = timed("flags", "select x.flag, case when x.container_id is null then null else %s end as cid, "
                "coalesce(lm.sim_id, 'db:' || x.lot_id) as lot, x.detail from flags(%s, %s) x "
                "left join container c on c.id = x.container_id left join sim.cmap cm on cm.db_id = c.id "
                "left join sim.cmap pm on pm.db_id = c.plate_id left join sim.lmap lm on lm.db_id = x.lot_id"
                % (cid_sql, T, K))

    truth = snap["containers"]
    lots = snap["lots"]

    def t_live(cid):
        if "/" in cid:
            return cid.split("/")[0] in truth and truth[cid.split("/")[0]].get("exists", False)
        return cid in truth and truth[cid].get("exists", False)

    sys_live = {r["cid"]: r["live"] == "t" for r in cons if r["top"] == "t"}
    sys_parent = {r["cid"]: (r["parent"], r["slot"] or None) for r in cons if r["top"] == "t"}

    def s_live(cid):
        return sys_live.get(cid.split("/")[0], False)

    # Amounts, per container and lot, where both sides think the container exists.
    pairs = {}
    for cid, rec in truth.items():
        if not t_live(cid) or not s_live(cid):
            continue
        for lot, (amount, _, dim) in rec.get("contents", {}).items():
            pairs[(cid, lot, dim)] = [amount, 0.0, lots[lot]["kind"]]
    for r in bal:
        if r["cid"].startswith("db:") or not t_live(r["cid"]) or not s_live(r["cid"]):
            continue
        key = (r["cid"], r["lot"], r["dimension"])
        pairs.setdefault(key, [0.0, 0.0, r["kind"]])[1] = float(r["amount"])
    amounts = {}
    pair_class = {}
    for key, (tv, sv, kind) in pairs.items():
        d = abs(sv - tv)
        if abs(tv) < 1e-6 and abs(sv) < 1e-6:
            continue
        cls = "exact" if d <= max(0.005 * abs(tv), 0.01) else "within 10%" if d <= 0.1 * abs(tv) else "off"
        pair_class[key] = (cls, tv, sv)
        amounts.setdefault(kind, {"exact": 0, "within 10%": 0, "off": 0})[cls] += 1

    # Existence: things the system thinks exist that were thrown away, and the other way round.
    ghosts, lost = [], []
    for cid, rec in truth.items():
        if "/" in cid or rec.get("type") in ("freezer", "fridge", "bench", "instrument"):
            continue
        sl = sys_live.get(cid)
        if sl is None:
            continue
        if sl and not rec["exists"]:
            ghosts.append(cid)
        if rec["exists"] and not sl:
            lost.append(cid)

    # Location: where both agree it exists.
    def sys_top(cid):
        seen = 0
        node = cid
        while sys_parent.get(node, (None, None))[0] and seen < 20:
            node = sys_parent[node][0]
            seen += 1
        return node
    loc = {"right spot": 0, "right place, wrong spot": 0, "wrong place": 0, "not placed": 0}
    loc_wrong = set()
    for cid, rec in truth.items():
        if "/" in cid or not rec.get("exists") or rec.get("parent") is None or not sys_live.get(cid):
            continue
        sp, ss = sys_parent.get(cid, (None, None))
        if sp is None:
            loc["not placed"] += 1
            loc_wrong.add(cid)
        elif sp == rec["parent"] and (ss or None) == (rec.get("pos") or None):
            loc["right spot"] += 1
        elif sys_top(cid) == rec["place"]:
            loc["right place, wrong spot"] += 1
            loc_wrong.add(cid)
        else:
            loc["wrong place"] += 1
            loc_wrong.add(cid)

    # Usable, per material for targets and per kind for everything.
    def kind_of_material(m):
        return m.split(":")[0].replace("sample", "sample_protein").replace("consumable", "consumable")
    t_use, s_use = {}, {}
    for cid, rec in truth.items():
        if not t_live(cid):
            continue
        for lot, (_, u, dim) in rec.get("contents", {}).items():
            key = lots[lot]["material"] if lots[lot]["kind"] == "target" else lots[lot]["kind"]
            t_use[key] = t_use.get(key, 0.0) + u
    for r in use:
        m = r["material_id"]
        key = m if m.startswith("target:") else kind_of_material(m)
        s_use[key] = s_use.get(key, 0.0) + float(r["usable"])
    usable_rows = {k: (round(t_use.get(k, 0.0), 1), round(s_use.get(k, 0.0), 1)) for k in sorted(set(t_use) | set(s_use))}

    flag_counts = {}
    for f in flg:
        flag_counts[f["flag"]] = flag_counts.get(f["flag"], 0) + 1

    return {"label": snap["label"], "t": snap["t"], "amounts": amounts, "ghosts": ghosts, "lost": lost, "location": loc,
            "usable": usable_rows, "flags": flag_counts, "timings": timings,
            "_pair_class": pair_class, "_flags": flg, "_loc_wrong": loc_wrong, "_sys_live": sys_live, "_truth": truth}


# ---------------------------------------------------------------------- the injected mistakes
def classify(errors, final, refused):
    flag_by_c, flag_by_l = {}, {}
    for f in final["_flags"]:
        if f["flag"] in NOT_ABOUT_ERRORS:
            continue
        if f["cid"]:
            flag_by_c.setdefault(f["cid"], []).append(f)
        if f["lot"]:
            flag_by_l.setdefault(f["lot"], []).append(f)
    end = final["t"]
    truth = final["_truth"]
    out = []
    for e in errors:
        hits = []
        for c in e["containers"]:
            hits += flag_by_c.get(c, [])
        for l in e["lots"]:
            hits += flag_by_l.get(l, [])
        rel = RELEVANT.get(e["type"])
        hits = [h for h in hits if rel is None or h["flag"] in rel]
        if e.get("corrected_at") and e["corrected_at"] <= end:
            verdict = "corrected"
        elif e["id"] in refused:
            verdict = "refused at entry"
        elif hits:
            verdict = "flagged"
        elif e["type"] in ("late_sync", "robot_log_late"):
            # Only the timing was wrong. By the end it either arrived or it didn't.
            verdict = "no lasting harm" if e.get("recorded_at", "") <= end else "silently wrong"
        else:
            wrong = False
            for c in e["containers"]:
                top = c.split("/")[0]
                rec = truth.get(top)
                sl = final["_sys_live"].get(top)
                if rec is not None and sl is not None and rec.get("exists", False) != sl:
                    wrong = True
                if c in final["_loc_wrong"]:
                    wrong = True
            # Amounts drift for physical reasons too (evaporation, pipetting), so only the
            # lots the mistake was about count here.
            # A typo smaller than 10% would hide in "within 10%", so for typos the test is
            # whether at least half of the typing difference is still there.
            slip = abs(e["typed"] - e["meant"]) / 2 if "typed" in e else None
            for (cid, lot, dim), (cls, tv, sv) in final["_pair_class"].items():
                if lot in e["lots"] and (cid in e["containers"] or cid.split("/")[0] in e["containers"]):
                    if cls == "off" or (slip and abs(sv - tv) >= slip):
                        wrong = True
            verdict = "silently wrong" if wrong else "no lasting harm"
        out.append((e, verdict, hits[:1]))
    return out


# ---------------------------------------------------------------------- the report
def pct(a, b):
    return "%d%%" % round(100.0 * a / b) if b else "n/a"


def write_report(outdir, meta, load_s, checks, verdicts, refused_msgs):
    final = checks[-1]
    L = []
    L.append("# Simulation report: %s" % meta["preset"])
    L.append("")
    L.append("%d simulated days from %s, %d designs a week, %d targets (%s), %d experiment(s), seed %d. "
             "Loading the recorded calls took %.1f s." % (meta["days"], meta["start"][:10], meta["designs_per_week"], len(meta["targets"]),
                                                         ", ".join(t.split(":")[1].upper() for t in meta["targets"]), meta["experiments"],
                                                         meta["seed"], load_s))
    L.append("")
    L.append("Each checkpoint asks the system what it believed at that moment, using only what had been written down by then, "
             "and compares it with what was really in the lab. \"Exact\" means within 0.5% (rounding and nothing else); "
             "pipetting noise alone puts robot-filled wells in the \"within 10%\" group.")
    L.append("")
    L.append("## Amounts, per container and lot, at the last checkpoint (%s)" % final["t"][:16].replace("T", " "))
    L.append("")
    L.append("| Kind | Exact | Within 10% | Off by more | Share off |")
    L.append("|---|---|---|---|---|")
    tot = {"exact": 0, "within 10%": 0, "off": 0}
    for kind, c in sorted(final["amounts"].items()):
        allc = sum(c.values())
        for k in tot:
            tot[k] += c[k]
        L.append("| %s | %d | %d | %d | %s |" % (kind, c["exact"], c["within 10%"], c["off"], pct(c["off"], allc)))
    L.append("| all | %d | %d | %d | %s |" % (tot["exact"], tot["within 10%"], tot["off"], pct(tot["off"], sum(tot.values()))))
    L.append("")
    lc = final["location"]
    L.append("## Where things are")
    L.append("")
    L.append("Of %d tubes, plates, bottles and boxes that both sides agree exist, %d are recorded in the right spot, %d in the right "
             "place but the wrong box or slot, %d in the wrong place altogether and %d with no place recorded. "
             "The system still thinks %d containers exist that were really thrown away, and thinks %d were thrown away that are still in the lab."
             % (sum(lc.values()), lc["right spot"], lc["right place, wrong spot"], lc["wrong place"], lc["not placed"],
                len(final["ghosts"]), len(final["lost"])))
    L.append("")
    L.append("## Usable amounts: system against truth")
    L.append("")
    L.append("Truth-usable applies the same rules as the system (QC, expiry, dead volume) to what really happened. "
             "A gap here is what a planner would get wrong.")
    L.append("")
    L.append("| What | Unit | Really usable | System says | Difference |")
    L.append("|---|---|---|---|---|")
    units = {"dna": "µL", "consumable": "pieces"}
    for k, (tv, sv) in final["usable"].items():
        L.append("| %s | %s | %s | %s | %s |" % (k, units.get(k, "µL"), tv, sv, ("%+.1f" % (sv - tv))))
    L.append("")
    L.append("## Over time")
    L.append("")
    L.append("| Checkpoint | Amounts off | Wrong place or spot | Ghosts | Lost | Flags raised | Query time (s) |")
    L.append("|---|---|---|---|---|---|---|")
    for c in checks:
        offs = sum(v["off"] for v in c["amounts"].values())
        allp = sum(sum(v.values()) for v in c["amounts"].values())
        wrong = c["location"]["right place, wrong spot"] + c["location"]["wrong place"] + c["location"]["not placed"]
        L.append("| %s (%s) | %d of %d | %d | %d | %d | %d | %.1f |" % (c["label"], c["t"][:16].replace("T", " "), offs, allp, wrong,
                 len(c["ghosts"]), len(c["lost"]), sum(c["flags"].values()), sum(c["timings"].values())))
    L.append("")
    L.append("Flags at the last checkpoint: %s." % (", ".join("%s %d" % kv for kv in sorted(final["flags"].items())) or "none"))
    L.append("")
    mistakes = [(e, v, h) for e, v, h in verdicts if not e.get("real")]
    real = [(e, v, h) for e, v, h in verdicts if e.get("real")]
    L.append("## The injected mistakes, and what became of them")
    L.append("")
    L.append("Every mistake is in errors.jsonl with an id. \"Corrected\" means someone noticed and recorded a fix. "
             "\"Refused at entry\" means the database said no straight away, which is self-evident to whoever typed it. "
             "\"Flagged\" means flags() points at the container or lot. \"No lasting harm\" means nothing flagged it, but by the "
             "end the numbers and places it touched match the lab again, usually because a later scan or disposal overwrote it. "
             "\"Silently wrong\" means the record is still wrong and nothing says so.")
    L.append("")
    kinds = sorted({e["type"] for e, _, _ in mistakes})
    cols = ["corrected", "refused at entry", "flagged", "no lasting harm", "silently wrong"]
    L.append("| Mistake | Count | " + " | ".join(cols) + " |")
    L.append("|---|---|" + "---|" * len(cols))
    totals = {c: 0 for c in cols}
    for k in kinds:
        vs = [v for e, v, _ in mistakes if e["type"] == k]
        for c in cols:
            totals[c] += vs.count(c)
        L.append("| %s | %d | %s |" % (k, len(vs), " | ".join(str(vs.count(c)) for c in cols)))
    L.append("| all | %d | %s |" % (len(mistakes), " | ".join(str(totals[c]) for c in cols)))
    L.append("")
    if not mistakes:
        L.append("No mistakes were rolled in this run. At the researched rates a person slips about once in 200 to 300 "
                 "recorded steps, and a small week has only a few dozen steps typed by people (robot logs and imports make "
                 "up the rest), so a quiet week is the expected outcome. Run more days or more designs to see some.")
        L.append("")
    late = [e for e, _, _ in mistakes if e["type"] == "late_sync"]
    if late:
        L.append("Late entries (%d) can only hurt in between: by the end they have all arrived, so they mostly land in "
                 "\"no lasting harm\". Their cost shows in the earlier checkpoints, which ask what the system said at the time." % len(late))
        L.append("")
    if real:
        L.append("Things that really happened and were recorded correctly, but look like mistakes:")
        L.append("")
        for e, v, h in real:
            L.append("- %s (%s). %s" % (e["what"], e["id"], "Flagged: %s." % h[0]["flag"] if h else
                                         "No flag at the end; %s." % ("the record ended right" if v == "no lasting harm" else "the record is still wrong")))
        L.append("")
    known_c = {c for e, _, _ in verdicts for c in e["containers"]}
    known_c |= {c.split("/")[0] for c in known_c}
    known_l = {l for e, _, _ in verdicts for l in e["lots"]}
    unexplained = {}
    for f in final["_flags"]:
        if f["flag"] in NOT_ABOUT_ERRORS:
            continue
        if (f["cid"] and (f["cid"] in known_c or f["cid"].split("/")[0] in known_c)) or (f["lot"] and f["lot"] in known_l):
            continue
        unexplained.setdefault(f["flag"], []).append(f)
    if unexplained:
        L.append("Flags with no injected mistake behind them (false alarms, or the knock-on effect of physics such as "
                 "pipetting a little more than recorded):")
        L.append("")
        for k, fs in sorted(unexplained.items()):
            L.append("- %s: %d, for example \"%s\"." % (k, len(fs), fs[0]["detail"]))
        L.append("")
    caught = [(e, h) for e, v, h in mistakes if v == "flagged"][:4]
    missed = [e for e, v, _ in mistakes if v == "silently wrong"][:4]
    if caught:
        L.append("Caught, for example:")
        L.append("")
        for e, h in caught:
            L.append("- %s %s: %s. Flag: %s (%s)." % (e["id"], e["type"], e["what"], h[0]["flag"], h[0]["detail"]))
        L.append("")
    if missed:
        L.append("Missed, for example:")
        L.append("")
        for e in missed:
            L.append("- %s %s: %s." % (e["id"], e["type"], e["what"]))
        L.append("")
    if refused_msgs:
        L.append("Refused at entry, for example: %s" % "; ".join("%s: %s" % kv for kv in list(refused_msgs.items())[:3]))
        L.append("")
    path = os.path.join(outdir, "report.md")
    with open(path, "w") as f:
        f.write("\n".join(L))
    return path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("outdir")
    ap.add_argument("--db", default=os.environ.get("INV_DB", "inv_sim_agent"))
    ap.add_argument("--no-load", action="store_true")
    ap.add_argument("--last-only", action="store_true", help="score only the last checkpoint (faster on big runs)")
    a = ap.parse_args()
    with open(os.path.join(a.outdir, "truth.json")) as f:
        meta = json.load(f)
    errors = []
    ep = os.path.join(a.outdir, "errors.jsonl")
    if os.path.exists(ep):
        with open(ep) as f:
            errors = [json.loads(line) for line in f if line.strip()]
    load_s = 0.0 if a.no_load else build(a.db, os.path.join(a.outdir, "recorded.sql"))
    snaps = meta["checkpoints"][-1:] if a.last_only else meta["checkpoints"]
    checks = [compare(s, a.db) for s in snaps]
    refused = {r["error_id"]: r["message"] for r in query(a.db, "select * from sim.refused")} if errors else {}
    verdicts = classify(errors, checks[-1], refused)
    path = write_report(a.outdir, meta, load_s, checks, verdicts, refused)
    with open(os.path.join(a.outdir, "score.json"), "w") as f:
        json.dump({"load_seconds": round(load_s, 1),
                   "checkpoints": [{k: v for k, v in c.items() if not k.startswith("_")} for c in checks],
                   "verdicts": {e["id"]: v for e, v, _ in verdicts}}, f, indent=1)
    print("%s: loaded in %.1f s, wrote %s" % (meta["preset"], load_s, path))


if __name__ == "__main__":
    sys.exit(main())
