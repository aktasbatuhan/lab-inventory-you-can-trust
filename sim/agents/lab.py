"""The shared lab for the AI-agent run: one World (notebook A), one inventory
database (notebook B), a clock per person, and the tools people use.

run.py creates one AgentLab and serves it over a small JSON-over-HTTP server on
localhost. Every person's MCP server (lab_mcp.py) forwards tool calls there, so
everyone works in the same lab. All calls go through one lock, in the order
they arrive.

Hands change the World and are honest, with the friction real hands have: a
frosted label that won't scan, a pipette a little off, a freezer that takes
minutes to search. Pen and scanner call the record API in schema/06_record.sql
with whatever the person says. Nothing here decides to make a mistake.

Times inside are UTC (like world.py and score.py). People see Zurich time.
Standard library only.
"""
import heapq
import json
import os
import re
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.dirname(HERE)
ROOT = os.path.dirname(SIM)
sys.path.insert(0, SIM)

import simulate as S          # noqa: E402  (the dice lab's opening stock and helpers)
import score as SC            # noqa: E402
from world import CT          # noqa: E402

LOCAL = ZoneInfo("Europe/Zurich")
UTC = timezone.utc
PSQL = SC.PSQL

# How long things take, in minutes (DESIGN.md "Time pressure").
COST = {
    "scan": 10 / 60, "record": 0.5, "look_freezer": (2, 6), "look_box": 0.5, "look_bench": 0.3,
    "search": (2, 10), "pick_up": 0.5, "put": 0.7, "put_cold": 1.0, "pipette": 0.8, "use": 1.0,
    "split_base": 5, "split_per_tube": 1.25, "bin": 0.5, "inspect": 0.5, "get_new": 1.5,
    "qc": 60, "make_buffer": 30, "ask": 1.5, "tell": 2, "tasks": 0.3, "done": 0.3, "missing": 5,
}
COLD = {"minus80", "minus20"}
NEW_PREFIX = {"box_9x9": "BOX", "plate_bli": "TP", "plate_96": "PL96", "plate_384": "PL384", "bottle": "BUF",
              "tube_matrix": "TUBE", "tube_1_5ml": "TUBE", "plate_gfp": "GFP"}
RECIPES = S.RECIPES
QUERIES = {   # ask_inventory name -> (file, allowed settings, numeric settings)
    "how_much": ("q1_how_much_and_usable.sql", {"material", "include_discarded"}, {"include_discarded"}),
    "shared_target_left": ("q1b_shared_target_left.sql", {"protein"}, set()),
    "rerun_numbers": ("q1c_rerun_numbers.sql", {"experiment", "step", "designs", "rerun_at"}, set()),
    "expiring": ("q2_expiring.sql", {"days"}, {"days"}),
    "where_is_it": ("q3_where_is_it.sql", {"barcodes"}, set()),
    "not_seen_lately": ("q3b_not_seen_lately.sql", {"days"}, {"days"}),
    "forward_trace": ("q4_forward_trace.sql", {"supplier_lot"}, set()),
    "backward_trace": ("q4b_backward_trace.sql", {"barcode", "well"}, set()),
    "history": ("q5_history.sql", {"barcode"}, set()),
    "as_we_knew_it": ("q5b_as_we_knew_it.sql", {"barcodes", "then"}, set()),
    "flags": ("q6_flags.sql", {"qc_wait_days"}, {"qc_wait_days"}),
    "waste": ("q7_waste.sql", {"from"}, set()),
    "whats_in": ("q8_whats_in_this_place.sql", {"place"}, set()),
}


def local(t):
    return t.astimezone(LOCAL)


def hm(t):
    return local(t).strftime("%H:%M")


def day_name(t):
    return local(t).strftime("%a %-d %b")


def lit(s):
    return "null" if s is None else "'" + str(s).replace("'", "''") + "'"


def ts(t):
    return "'" + t.astimezone(UTC).strftime("%Y-%m-%d %H:%M:%S") + "+00'"


class Refused(Exception):
    """Something the person can't do, said in their words. The call still costs time."""


class Person:
    def __init__(self, key, actor, name, bench):
        self.key, self.actor, self.name, self.bench = key, actor, name, bench
        self.clock = None
        self.block_end = None
        self.shift_end = None
        self.tasks = []           # {"id", "text", "due", "done_at", "note"}
        self.inbox = []           # (time, text)
        self.cold = {}            # container id -> when it came out of a freezer
        self.seen = {}            # place id -> when they last looked inside
        self.calls = 0


class AgentLab:
    def __init__(self, run_dir, db, seed=7, preset="normal"):
        self.run_dir, self.db = run_dir, db
        self.lock = threading.Lock()
        self.seq = 0
        os.makedirs(run_dir, exist_ok=True)
        self.log_path = os.path.join(run_dir, "calls.jsonl")
        self.log = open(self.log_path, "a")
        # Opening stock: the dice lab's setup, recorded without mistakes (they only start at START).
        self.dice = S.Lab(preset, 1, 48, 2, seed)
        self.p = self.dice.p
        self.rng = self.dice.rng
        self.w = self.dice.w
        self.P = self.dice.P
        self.dice.setup()
        self.P["Goods-in"] = self.dice.register("bench", S.SETUP, "p:sara", name="Goods-in shelf", cond="room", source="manual")
        while self.dice.heap:
            t, _, fn, args = heapq.heappop(self.dice.heap)
            if t >= S.START:
                continue
            self.w.set_clock(t)
            fn(*args)
        self.opening_ids = set(self.w.c)
        self.people = {}
        self.events = []          # (utc time, n, fn, args): deliveries and other things that happen to the world
        self._ev = 0
        self.friction = []        # what the physical world did on its own, for the referee
        self.touched = set()      # containers someone's hands have been on
        self.orders, self.deliveries = [], []
        self._build_db()

    # ------------------------------------------------------------------ database
    def _build_db(self):
        path = os.path.join(self.run_dir, "opening.sql")
        lines = sorted(self.dice.lines, key=lambda x: (x[0], x[1]))
        with open(path, "w") as f:
            f.write("\n".join(self.dice.preamble()) + "\n")
            for _, _, sql in lines:
                f.write(sql + "\n")
            f.write("commit;\n")
        SC.build(self.db, path)

    def sql(self, q):
        r = subprocess.run([PSQL, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-d", self.db, "-c", q],
                           capture_output=True, text=True)
        if r.returncode != 0:
            msg = r.stderr.strip().splitlines()
            msg = [m for m in msg if m.startswith("ERROR")] or msg
            raise Refused("the inventory refused it: " + (msg[0].replace("ERROR:", "").strip() if msg else "unknown error"))
        return r.stdout.strip()

    def one(self, q):
        out = self.sql(q)
        return out.splitlines()[0] if out else None

    # ------------------------------------------------------------------ people and time
    def add_person(self, key, actor, name, bench):
        self.people[key] = Person(key, actor, name, self.P[bench])
        return self.people[key]

    def at(self, t, fn, *args):
        self._ev += 1
        heapq.heappush(self.events, (t, self._ev, fn, args))

    def _world_until(self, t):
        while self.events and self.events[0][0] <= t:
            when, _, fn, args = heapq.heappop(self.events)
            self.w.set_clock(when)
            fn(*args)

    def spend(self, person, minutes):
        if isinstance(minutes, tuple):
            minutes = self.rng.uniform(*minutes)
        person.clock += timedelta(minutes=minutes)
        return minutes

    def status(self, person):
        now = person.clock
        open_ = [t for t in person.tasks if not t["done_at"]]
        late = [t for t in open_ if t["due"] and t["due"] < now]
        if late:
            worst = max(late, key=lambda t: now - t["due"])
            mins = int((now - worst["due"]).total_seconds() // 60)
            behind = "BEHIND: %d task(s) overdue, worst is %s (due %s, %d min ago)" % (len(late), worst["id"], hm(worst["due"]), mins)
        else:
            nxt = min((t for t in open_ if t["due"]), key=lambda t: t["due"], default=None)
            behind = "on time" + (", next due: %s at %s" % (nxt["id"], hm(nxt["due"])) if nxt else "")
        end = person.block_end
        return "[%s %s | %d of %d tasks open | %s | this block ends %s]" % (
            day_name(now), hm(now), len(open_), len(person.tasks), behind, hm(end) if end else "-")

    # ------------------------------------------------------------------ one tool call
    def call(self, who, tool, args):
        with self.lock:
            person = self.people[who]
            t0 = person.clock
            err = False
            if person.block_end and person.clock >= person.block_end + timedelta(minutes=20):
                text = ("It is %s and this block of your shift ended at %s. Stop working now and write your "
                        "handover note as your final answer." % (hm(person.clock), hm(person.block_end)))
                self._log(person, tool, args, text, t0, True)
                return text
            fn = getattr(self, "t_" + tool, None)
            args = dict(args or {})
            if isinstance(args.get("typed"), str):
                args["typed"] = args["typed"].strip().lower() in ("true", "yes", "1")
            try:
                if fn is None:
                    raise Refused("no such tool: " + tool)
                self.w.set_clock(max(self.w.now, person.clock))
                self._world_until(person.clock)
                text = fn(person, **args)
            except Refused as e:
                text, err = "Couldn't do that: %s" % e, True
            except TypeError as e:
                text, err = "Couldn't do that: wrong arguments (%s)" % e, True
            self.w.set_clock(max(self.w.now, person.clock))
            self._world_until(person.clock)
            person.calls += 1
            news = [m for m in person.inbox if m[0] <= person.clock]
            person.inbox = [m for m in person.inbox if m[0] > person.clock]
            for when, msg in news:
                text += "\n\nNEW at %s: %s" % (hm(when), msg)
            if person.block_end and person.clock >= person.block_end:
                text += ("\n\nIt's %s, past the end of this block (%s). Finish what's in your hands, "
                         "then stop and write your handover note." % (hm(person.clock), hm(person.block_end)))
            text += "\n" + self.status(person)
            self._log(person, tool, args, text, t0, err)
            return text

    def _log(self, person, tool, args, text, t0, err):
        self.seq += 1
        rec = {"n": self.seq, "who": person.key, "actor": person.actor, "sim_start": local(t0).isoformat(timespec="minutes"),
               "sim_end": local(person.clock).isoformat(timespec="seconds"), "minutes": round((person.clock - t0).total_seconds() / 60, 2),
               "tool": tool, "args": args, "result": text, "refused": err, "wall": time.strftime("%H:%M:%S")}
        self.log.write(json.dumps(rec) + "\n")
        self.log.flush()

    # ------------------------------------------------------------------ looking things up, physically
    def wfind(self, ref):
        """The live container a person means: a barcode, a place name, or BARCODE:A1 for a well."""
        ref = (ref or "").strip()
        m = re.match(r"^(.+):([A-P]\d{1,2})$", ref)
        if m:
            pl = self.wfind(m.group(1))
            if pl is None or not self.w.c[pl].wells or m.group(2) not in self.w.c[pl].wells:
                return None
            return self.w.c[pl].wells[m.group(2)].id
        cid = self.w.find(ref)
        if cid:
            return cid
        for c in self.w.c.values():
            if c.name and c.name.lower() == ref.lower() and c.exited is None:
                return c.id
        return None

    def need(self, ref):
        cid = self.wfind(ref)
        if cid is None:
            raise Refused("you can't find anything labelled %r" % ref)
        self.touched.add(self.w.vessel(self.w.c[cid]).id)
        return cid

    def label(self, cid):
        c = self.w.c[cid]
        if c.plate:
            return "%s:%s" % (self.label(c.plate), c.pos)
        return c.barcode or c.name or cid

    def where(self, cid):
        c = self.w.vessel(self.w.c[cid])
        parts = []
        node = c
        while node.parent:
            p = self.w.c[node.parent]
            parts.append(self.label(p.id) + (" %s" % node.pos if node.pos else ""))
            node = p
        return " in ".join(parts) if parts else "nowhere (not placed)"

    def cond(self, cid):
        return self.w.top(self.w.c[cid]).cond

    def main_lot(self, cid):
        return self.dice.main_lot(cid)

    def what(self, cid):
        lot = self.main_lot(cid)
        if not lot:
            return "empty"
        L = self.w.lots[lot]
        name = L.material.split(":", 1)[1]
        amount = self.w.c[cid].contents[lot]
        if L.dim == "count":
            return "%s, %d pieces" % (name, round(amount))
        if L.dim == "mass":
            return "%s, dry" % name
        approx = amount * (1 + self.rng.uniform(-0.1, 0.1))
        if approx >= 10000:
            return "%s, about %.0f mL by eye" % (name, approx / 1000)
        return "%s, about %d µL by eye" % (name, 5 * round(approx / 5))

    def on_bench(self, person, cid):
        c = self.cond(cid)
        if c in COLD or c == "fridge":
            raise Refused("%s is still in the %s (%s). Take it out first (pick_up)." % (self.label(cid), "freezer" if c in COLD else "fridge", self.where(cid)))

    # ------------------------------------------------------------------ hands
    def t_look(self, person, place):
        pid = self.need(place)
        p = self.w.c[pid]
        items = self.w.look(pid)
        if p.cat == "place" and p.cond in COLD | {"fridge"}:
            self.spend(person, COST["look_freezer"])
        elif p.cat == "holder":
            self.spend(person, COST["look_box"])
        else:
            self.spend(person, COST["look_bench"])
        person.seen[pid] = person.clock
        if not items:
            return "%s is empty." % self.label(pid)
        lines = []
        frosty = p.cond in COLD or self.cond(pid) in COLD
        for it in sorted(items, key=lambda x: (x["slot"] or "", x["barcode"] or "")):
            c = self.w.c[it["id"]]
            name = c.barcode or c.name
            if frosty and c.barcode and self.rng.random() < 0.03:
                name = "(label frosted over, can't read it)"
                self.friction.append({"at": local(person.clock).isoformat(), "who": person.key, "what": "frosted label on %s" % c.barcode})
            inside = ""
            if c.cat == "holder":
                n = len(self.w.look(c.id))
                inside = ", " + self.what(c.id) if n == 0 and self.main_lot(c.id) else ", %d things inside" % n
            elif c.cat in ("tube", "plate") and not c.wells:
                inside = ", " + self.what(c.id)
            elif c.wells:
                filled = sum(1 for w in c.wells.values() if self.w.contents(w.id))
                inside = ", %d wells with something in them" % filled
            lines.append("- %s (%s)%s%s" % (name, c.type, " at %s" % it["slot"] if it["slot"] else "", inside))
        return "In %s you see:\n%s" % (self.label(pid), "\n".join(lines))

    def t_pick_up(self, person, barcode):
        cid = self.wfind(barcode)
        if cid is None:
            self.spend(person, COST["missing"])
            raise Refused("you look for %r for a few minutes and can't find it" % barcode)
        c = self.w.vessel(self.w.c[cid])
        cid = c.id
        self.touched.add(cid)
        was = self.where(cid)
        cold = self.cond(cid) in COLD
        if cold and person.seen.get(c.parent, datetime.min.replace(tzinfo=UTC)) < person.clock - timedelta(minutes=30):
            took = self.spend(person, COST["search"])
            how = "It took %.0f minutes to find it in the freezer." % took
        else:
            self.spend(person, COST["pick_up"])
            how = ""
        if cold:
            person.cold[cid] = person.clock
            for k in self.w.c.values():
                if k.parent == cid:
                    person.cold[k.id] = person.clock
        self.w.move(cid, person.bench, None, at=person.clock)
        return "You take %s (%s) out of %s and put it on %s. %s" % (self.label(cid), self.what(cid) if c.cat != "holder" else "a box", was, self.label(person.bench), how)

    def t_put(self, person, barcode, place, slot=""):
        cid = self.w.vessel(self.w.c[self.need(barcode)]).id
        pid = self.need(place)
        if pid == cid:
            raise Refused("you can't put something inside itself")
        if slot:
            taken = [x for x in self.w.look(pid) if x["slot"] == slot and x["id"] != cid]
            if taken:
                raise Refused("%s is already taken in %s by %s" % (slot, self.label(pid), self.label(taken[0]["id"])))
        self.spend(person, COST["put_cold"] if self.w.c[pid].cond in COLD or self.cond(pid) in COLD else COST["put"])
        self.w.move(cid, pid, slot or None, at=person.clock)
        return "%s is now in %s%s." % (self.label(cid), self.label(pid), " at " + slot if slot else "")

    def t_pipette(self, person, source, destination, microlitres):
        src, dst = self.need(source), self.need(destination)
        self.on_bench(person, src)
        self.on_bench(person, dst)
        lot = self.main_lot(src)
        if lot is None:
            self.spend(person, COST["pipette"])
            raise Refused("%s is empty" % self.label(src))
        ul = float(microlitres)
        self.spend(person, COST["pipette"])
        got = self.w.transfer(src, dst, lot, ul, device="hand", at=person.clock)
        if got < ul * 0.9:
            return ("You set the pipette to %g µL but %s ran dry: you only drew about %d µL into %s."
                    % (ul, self.label(src), round(got), self.label(dst)))
        return "Pipetted %g µL from %s into %s." % (ul, self.label(src), self.label(dst))

    def t_use(self, person, barcode, amount):
        cid = self.need(barcode)
        self.on_bench(person, cid)
        lot = self.main_lot(cid)
        if lot is None:
            raise Refused("%s is empty" % self.label(cid))
        L = self.w.lots[lot]
        amt = float(amount)
        self.spend(person, COST["use"])
        got = self.w.take(cid, lot, amt, device="exact" if L.dim == "count" else "hand:2")
        unit = "pieces" if L.dim == "count" else "µL"
        if got < amt * 0.9:
            return "You wanted %g %s from %s but only got about %d." % (amt, unit, self.label(cid), round(got))
        return "Took %g %s of %s from %s." % (amt, unit, L.material.split(":", 1)[1], self.label(cid))

    def t_split(self, person, barcode, tubes, microlitres_each, into_box):
        src = self.need(barcode)
        self.on_bench(person, src)
        box = self.need(into_box)
        n, each = int(tubes), float(microlitres_each)
        if not 1 <= n <= 81:
            raise Refused("a box holds 1 to 81 tubes")
        lot = self.main_lot(src)
        if lot is None:
            raise Refused("%s is empty" % self.label(src))
        used = {x["slot"] for x in self.w.look(box)}
        clash = [s for s in ("slot %d" % (i + 1) for i in range(n)) if s in used]
        if clash:
            raise Refused("slots %s in %s are already taken; use an empty box" % (", ".join(clash[:3]), self.label(box)))
        self.spend(person, COST["split_base"] + COST["split_per_tube"] * n)
        prefix = self.dice.bc("ALQ") + "-"
        kids = self.w.split(src, lot, n, each, "tube_matrix", place=box, barcode_prefix=prefix, at=person.clock)
        short = [self.label(k) for k in kids if sum(self.w.contents(k).values()) < each * 0.9]
        msg = ("Printed labels %s001 to %s%03d and filled %d tubes with %g µL each into %s, slots 1 to %d."
               % (prefix, prefix, n, n, each, self.label(box), n))
        if short:
            msg += " The source ran out: %s got less than %g µL." % (", ".join(short), each)
        msg += " Left in %s: %s." % (self.label(src), self.what(src))
        return msg

    def t_get_new(self, person, container_type, place=""):
        if container_type not in NEW_PREFIX:
            raise Refused("container_type must be one of " + ", ".join(sorted(NEW_PREFIX)))
        pid = self.need(place) if place else person.bench
        self.spend(person, COST["get_new"])
        bc = self.dice.bc(NEW_PREFIX[container_type])
        self.w.register(container_type, bc, pid, None, at=person.clock)
        return "Took a new %s, printed and stuck on label %s, and put it %s %s." % (
            container_type, bc, "on" if self.w.c[pid].type == "bench" else "in", self.label(pid))

    def t_bin(self, person, barcode):
        cid = self.w.vessel(self.w.c[self.need(barcode)]).id
        self.spend(person, COST["bin"])
        left = self.what(cid) if self.w.c[cid].cat != "holder" else "a box"
        self.w.discard(cid, at=person.clock)
        return "Threw %s in the bin (%s)." % (self.label(cid), left)

    def t_inspect(self, person, barcode):
        cid = self.need(barcode)
        self.spend(person, COST["inspect"])
        c = self.w.c[cid]
        lot = self.main_lot(cid)
        extra = ""
        if lot:
            L = self.w.lots[lot]
            if L.code:
                extra = " Supplier lot on the label: %s." % L.code
        return "%s is a %s with %s. It is %s.%s" % (self.label(cid), c.type, self.what(cid), self.where(cid), extra)

    def t_qc_check(self, person, barcode):
        cid = self.need(barcode)
        self.on_bench(person, cid)
        lot = self.main_lot(cid)
        if lot is None:
            raise Refused("%s is empty" % self.label(cid))
        L = self.w.lots[lot]
        if L.kind != "target":
            raise Refused("only target proteins get this QC")
        self.spend(person, COST["qc"])
        self.w.take(cid, lot, 5.0)
        if L.qc is None:
            L.qc = "fail" if self.rng.random() < self.p["target_qc_fail"] else "pass"
        return ("Took a 5 µL sample from %s and ran SDS-PAGE and A280 (an hour). Result: %s."
                % (self.label(cid), "PASS, clean band at the right size" if L.qc == "pass" else "FAIL, the band is degraded"))

    def t_make_buffer(self, person, recipe, sources, bottle):
        if recipe not in RECIPES:
            raise Refused("recipe must be one of " + ", ".join(RECIPES))
        out = self.need(bottle)
        self.on_bench(person, out)
        srcs = [self.need(s.strip()) for s in sources.split(",") if s.strip()]
        inputs, missing = [], []
        for comp, amt in RECIPES[recipe]:
            hit = None
            for s in srcs:
                lot = self.main_lot(s)
                if lot and self.w.lots[lot].material == "reagent:" + comp:
                    hit = (s, lot)
                    break
            if hit is None:
                missing.append(comp)
                continue
            self.on_bench(person, hit[0])
            inputs.append((hit[0], hit[1], amt, "hand:0.3"))
        if missing:
            raise Refused("the recipe needs %s and none of the bottles you named has it" % ", ".join(missing))
        self.spend(person, COST["make_buffer"])
        self.w.make(recipe, "buffer", inputs, out, at=person.clock)
        parts = ", ".join("%g mL %s from %s" % (a / 1000, self.w.lots[l].material.split(":")[1], self.label(s)) for s, l, a, _ in inputs)
        return "Made %s in %s: %s. It holds %s." % (recipe.split(":")[1], self.label(out), parts, self.what(out))

    # ------------------------------------------------------------------ pen and scanner
    def scanned(self, person, ref, typed):
        """What the scanner (or the person typing) actually puts into the form."""
        ref = (ref or "").strip()
        m = re.match(r"^(.+):([A-P]\d{1,2})$", ref)
        base, well = (m.group(1), m.group(2)) if m else (ref, None)
        cid = self.wfind(base)
        if typed:
            self.spend(person, 0.3)
            out = []
            for ch in base:
                if ch.isdigit() and self.rng.random() < 0.0033:
                    nxt = str((int(ch) + self.rng.choice((-1, 1))) % 10)
                    self.friction.append({"at": local(person.clock).isoformat(), "who": person.key,
                                          "what": "typed %s by hand and hit %s instead of %s" % (base, nxt, ch)})
                    ch = nxt
                out.append(ch)
            base = "".join(out)
        elif cid is not None and self.w.c[cid].barcode:
            self.spend(person, COST["scan"])
            came_out = person.cold.get(cid)
            frosty = came_out is not None and person.clock - came_out < timedelta(minutes=15)
            p = 0.08 if frosty else 0.02
            if self.rng.random() < p:
                self.friction.append({"at": local(person.clock).isoformat(), "who": person.key,
                                      "what": "scanner couldn't read %s%s" % (base, " (frosted)" if frosty else "")})
                raise Refused("the scanner beeps: no read on %s%s. Try again, or pass typed=true to type the code by hand."
                              % (base, ", the label is frosted from the freezer" if frosty else ""))
        return base + (":" + well if well else "")

    def dbref(self, person, ref, t, typed=False, scan=True):
        code = self.scanned(person, ref, typed) if scan else ref.strip()
        m = re.match(r"^(.+):([A-P]\d{1,2})$", code)
        if m:
            plate = self.dbref(person, m.group(1), t, scan=False)
            wid = self.one("select well(%s, %s)" % (plate, lit(m.group(2))))
            if not wid:
                raise Refused("%s has no well %s" % (m.group(1), m.group(2)))
            return int(wid)
        cid = self.one("select container_id from live_labels(%s, 'infinity') where barcode = %s order by container_id limit 1" % (ts(t), lit(code)))
        if cid is None:
            cid = self.one("select id from container where lower(name) = lower(%s) limit 1" % lit(code))
        if cid is None:
            raise Refused("the inventory doesn't know %r" % code)
        return int(cid)

    def dblot(self, cid, t):
        row = self.one("select lot_id || '|' || dimension from balances(%s, 'infinity') where container_id = %d and amount > 0 "
                       "order by amount desc limit 1" % (ts(t), cid))
        if row is None:
            row = self.one("select lot_id || '|' || dimension from quantity_entry where container_id = %d order by event_id desc limit 1" % cid)
        if row is None:
            raise Refused("the inventory has no material on record in that container")
        lot, dim = row.split("|")
        return int(lot), dim

    def when(self, person, happened_at):
        """When the thing happened: now, or earlier today if the person says so (HH:MM, Zurich time)."""
        if not happened_at:
            return person.clock
        m = re.match(r"^\s*(\d{1,2}):(\d{2})\s*$", str(happened_at))
        if not m:
            raise Refused("happened_at should look like 09:40")
        lt = local(person.clock).replace(hour=int(m.group(1)), minute=int(m.group(2)), second=0, microsecond=0)
        t = lt.astimezone(UTC)
        if t > person.clock:
            raise Refused("%s hasn't happened yet; it's %s" % (happened_at, hm(person.clock)))
        return t

    def map_container(self, dbid, barcode):
        cid = self.w.find(barcode) if barcode else None
        if cid:
            self.sql("insert into sim.cmap values (%s, %d) on conflict do nothing" % (lit(cid), dbid))

    def map_lot(self, dblot, world_container_barcode):
        cid = self.w.find(world_container_barcode) if world_container_barcode else None
        lot = self.main_lot(cid) if cid else None
        if lot:
            self.sql("insert into sim.lmap values (%s, %d) on conflict do nothing" % (lit(lot), dblot))

    def ev_of(self, sql_returning_event):
        return int(self.one(sql_returning_event))

    def t_scan(self, person, barcode, seen_in="", typed=False):
        t = person.clock
        code = self.scanned(person, barcode, typed)
        cid = self.dbref(person, code, t, scan=False)
        where = self.dbref(person, seen_in, t, scan=False) if seen_in else None
        ev = self.ev_of("select scan(%d, %s, %s, %s, %s, p_recorded => %s)" % (cid, ts(t), lit(person.actor), lit(code),
                                                                                where if where else "null", ts(person.clock)))
        return "Scanned %s%s (event %d)." % (code, " in " + seen_in if seen_in else "", ev)

    def t_record_move(self, person, barcode, to_place, slot="", happened_at="", typed=False):
        t = self.when(person, happened_at)
        cid = self.dbref(person, barcode, t, typed)
        into = self.dbref(person, to_place, t, scan=False)
        self.spend(person, COST["record"])
        ev = self.ev_of("select move(%d, %d, %s, %s, %s, 'scan', p_recorded => %s)" % (cid, into, lit(slot or None), ts(t), lit(person.actor), ts(person.clock)))
        return "Recorded: %s moved to %s%s at %s (event %d)." % (barcode, to_place, " " + slot if slot else "", hm(t), ev)

    def t_record_use(self, person, barcode, amount, note="", happened_at="", typed=False):
        t = self.when(person, happened_at)
        cid = self.dbref(person, barcode, t, typed)
        lot, dim = self.dblot(cid, t)
        self.spend(person, COST["record"])
        ev = self.ev_of("select consume(%d, %d, %s, %s, %s, %s, 'manual', null, null, %s, p_recorded => %s)"
                        % (cid, lot, float(amount), lit(dim), ts(t), lit(person.actor), lit(note or None), ts(person.clock)))
        return "Recorded: used %g %s from %s (event %d)." % (float(amount), "pieces" if dim == "count" else "µL" if dim == "volume" else "µg", barcode, ev)

    def t_record_transfer(self, person, source, destination, microlitres, happened_at="", typed=False):
        t = self.when(person, happened_at)
        src = self.dbref(person, source, t, typed)
        dst = self.dbref(person, destination, t, typed)
        lot, dim = self.dblot(src, t)
        self.spend(person, COST["record"])
        ev = self.ev_of("select transfer(%d, %d, %d, %s, %s, %s, %s, p_recorded => %s)"
                        % (src, dst, lot, float(microlitres), lit(dim), ts(t), lit(person.actor), ts(person.clock)))
        return "Recorded: %g µL from %s to %s (event %d)." % (float(microlitres), source, destination, ev)

    def t_record_split(self, person, barcode, tubes, microlitres_each, into_box, barcode_prefix, happened_at="", typed=False):
        t = self.when(person, happened_at)
        src = self.dbref(person, barcode, t, typed)
        box = self.dbref(person, into_box, t, scan=False)
        lot, _ = self.dblot(src, t)
        n = int(tubes)
        self.spend(person, COST["record"] * 2)
        ids = self.one("select array_to_string(split(%d, %d, %d, %s, 'tube_matrix', %s, %s, %s, p_into => %d, p_recorded => %s), ',')"
                       % (src, lot, n, float(microlitres_each), ts(t), lit(person.actor), lit(barcode_prefix), box, ts(person.clock)))
        for i, dbid in enumerate(ids.split(","), 1):
            self.map_container(int(dbid), "%s%03d" % (barcode_prefix, i))
        ev = self.one("select max(event_id) from quantity_entry where container_id = %s" % ids.split(",")[0])
        return "Recorded: %s split into %d tubes of %g µL, labels %s001 to %s%03d, in %s (event %s)." % (
            barcode, n, float(microlitres_each), barcode_prefix, barcode_prefix, n, into_box, ev)

    def t_record_disposal(self, person, barcode, note="", happened_at="", typed=False):
        t = self.when(person, happened_at)
        cid = self.dbref(person, barcode, t, typed)
        self.spend(person, COST["record"])
        ev = self.ev_of("select discard(%d, %s, %s, 'scan', %s, p_recorded => %s)" % (cid, ts(t), lit(person.actor), lit(note or None), ts(person.clock)))
        return "Recorded: %s thrown away (event %d)." % (barcode, ev)

    def t_record_new_container(self, person, barcode, container_type, place, slot="", happened_at="", typed=False):
        t = self.when(person, happened_at)
        code = self.scanned(person, barcode, typed)
        into = self.dbref(person, place, t, scan=False)
        if container_type not in CT or CT[container_type]["cat"] not in ("tube", "plate", "holder"):
            raise Refused("container_type must be a tube, plate, bottle or box type, like tube_1_5ml, tube_matrix, bottle, box_9x9, plate_bli")
        self.spend(person, COST["record"])
        dbid = int(self.one("select register_container(%s, %s, %s, %s, null, null, %d, %s, 'scan', %s)"
                            % (lit(container_type), ts(t), lit(person.actor), lit(code), into, lit(slot or None), ts(person.clock))))
        self.map_container(dbid, code)
        return "Recorded: new %s %s in %s%s." % (container_type, code, place, " " + slot if slot else "")

    def product(self, product):
        row = self.one("select p.id || '|' || mk.base_dimension from product p join material m on m.id = p.material_id "
                       "join material_kind mk on mk.id = m.kind_id where lower(p.id) = lower(%s) or lower(p.catalog_number) = lower(%s) limit 1"
                       % (lit(product), lit(product)))
        if row is None:
            known = self.sql("select string_agg(catalog_number, ', ' order by catalog_number) from product")
            raise Refused("unknown product %r; catalog numbers on file: %s" % (product, known))
        return row.split("|")

    def t_record_receive(self, person, barcode, product, amount, supplier_lot, delivery_note, place, slot="", happened_at="", typed=False):
        t = self.when(person, happened_at)
        pid, dim = self.product(product)
        code = self.scanned(person, barcode, typed)
        cid = self.one("select container_id from live_labels(%s, 'infinity') where barcode = %s limit 1" % (ts(t), lit(code)))
        into = self.dbref(person, place, t, scan=False)
        self.spend(person, COST["record"] * 2)
        rcv = ("receive(%s, %%s, %s, %s, %s, %s, p_supplier_lot => %s, p_ref => %s, p_source => 'manual', p_recorded => %s)"
               % (lit(pid), float(amount), lit(dim), ts(t), lit(person.actor), lit(supplier_lot or None),
                  lit(delivery_note or None), ts(person.clock)))
        if cid is None:
            # Registering the vial and booking it in are one form: both happen or neither does.
            wc = self.w.find(code)
            ctype = self.w.c[wc].type if wc else "tube_1_5ml"
            row = self.one(("with c as (select register_container(%s, %s, %s, %s, null, null, %d, %s, 'scan', %s) as id) "
                            % (lit(ctype), ts(t), lit(person.actor), lit(code), into, lit(slot or None), ts(person.clock)))
                           + "select c.id || '|' || " + rcv % "c.id" + " from c")
            cid, lot = (int(x) for x in row.split("|"))
            self.map_container(cid, code)
        else:
            lot = int(self.one("select " + rcv % cid))
        self.map_lot(lot, code)
        ev = self.one("select created_event_id from lot where id = %d" % lot)
        return "Recorded: received %g %s of %s into %s, supplier lot %s (lot %d, event %s). New lots wait for QC before they count as usable." % (
            float(amount), "µL" if dim == "volume" else dim, pid, code, supplier_lot, lot, ev)

    def t_record_qc(self, person, barcode, outcome, assay="SDS-PAGE and A280", happened_at="", typed=False):
        if outcome not in ("pass", "fail"):
            raise Refused("outcome is pass or fail")
        t = self.when(person, happened_at)
        cid = self.dbref(person, barcode, t, typed)
        lot, _ = self.dblot(cid, t)
        self.spend(person, COST["record"])
        ev = self.ev_of("select qc(%d, %s, %s, %s, %s, p_recorded => %s)" % (lot, lit(outcome), lit(assay), ts(t), lit(person.actor), ts(person.clock)))
        return "Recorded: QC %s for the lot in %s (event %d)." % (outcome, barcode, ev)

    def t_record_make(self, person, recipe, bottle, microlitres_made, inputs, happened_at="", typed=False):
        if recipe not in RECIPES:
            raise Refused("recipe must be one of " + ", ".join(RECIPES))
        t = self.when(person, happened_at)
        out = self.dbref(person, bottle, t, typed)
        parts = []
        for item in inputs.split(","):
            if not item.strip():
                continue
            if "=" not in item:
                raise Refused("inputs look like WAT-00017=48500, HEP-00019=500")
            bc, amt = item.split("=", 1)
            src = self.dbref(person, bc.strip(), t, typed)
            lot, dim = self.dblot(src, t)
            parts.append("jsonb_build_object('container', %d, 'lot', %d, 'amount', %s, 'dimension', %s)" % (src, lot, float(amt), lit(dim)))
        self.spend(person, COST["record"] * 2)
        lot = int(self.one("select make(%s, jsonb_build_array(%s), %d, %s, 'volume', %s, %s, p_recorded => %s)"
                           % (lit(recipe), ", ".join(parts), out, float(microlitres_made), ts(t), lit(person.actor), ts(person.clock))))
        self.map_lot(lot, bottle.strip())
        ev = self.one("select created_event_id from lot where id = %d" % lot)
        return "Recorded: made %g µL of %s in %s from %d inputs (lot %d, event %s)." % (float(microlitres_made), recipe, bottle, len(parts), lot, ev)

    def t_correct(self, person, event_id, why):
        self.spend(person, COST["record"])
        ev = self.ev_of("select void(%d, %s, %s, p_recorded => %s)" % (int(event_id), lit(person.actor), lit(why), ts(person.clock)))
        return "Recorded: event %s is now marked as wrong (correction event %d). Record the right version if there is one." % (event_id, ev)

    def t_ask_inventory(self, person, question, settings=""):
        if question not in QUERIES:
            raise Refused("question must be one of: " + ", ".join(QUERIES))
        fname, allowed, numeric = QUERIES[question]
        vals = {}
        if isinstance(settings, dict):
            items = settings.items()
        else:
            items = [kv.split("=", 1) for kv in re.split(r"[;\n]", settings or "") if "=" in kv]
        for k, v in items:
            k, v = k.strip(), str(v).strip().strip("'\"")
            if k not in allowed:
                raise Refused("%s takes only: %s" % (question, ", ".join(sorted(allowed)) or "no settings"))
            if k in numeric and not re.match(r"^(\d+|true|false)$", v):
                raise Refused("%s must be a number" % k)
            vals[k] = v
        self.spend(person, COST["ask"])
        cmd = [PSQL, "-X", "-v", "ON_ERROR_STOP=1", "-d", self.db, "-v", "t=" + local(person.clock).strftime("%Y-%m-%d %H:%M%z"),
               "-v", "k=infinity"]
        for k, v in vals.items():
            cmd += ["-v", "%s=%s" % (k, v)]
        cmd += ["-f", os.path.join(ROOT, "queries", fname)]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        out = (r.stdout + ("\n" + r.stderr if r.returncode else "")).strip()
        out = "\n".join(x for x in out.splitlines() if x not in ("SET", 'Null display is "-".'))
        if len(out) > 6000:
            out = out[:6000] + "\n... (cut, %d more characters)" % (len(out) - 6000)
        return out or "(no answer)"

    def t_record_count(self, person, place, found):
        """A count of one place (decision D4): every container the inventory thinks is in it is
        marked found or not found. Locations get surer at once; amounts don't change."""
        t = person.clock
        pid = self.dbref(person, place, t, scan=False)
        seen = {x.strip() for x in found.split(",") if x.strip()}
        rows = self.sql("select l.container_id || '|' || coalesce((select string_agg(ll.barcode, ',') from live_labels(%s, 'infinity') ll "
                        "where ll.container_id = l.container_id), '') from location(%s, 'infinity') l join container c on c.id = l.container_id "
                        "join container_type ct on ct.id = c.type_id where l.top_place_id = %d and ct.category in ('tube', 'plate') "
                        "and l.status not in ('discarded', 'shipped', 'fixed place', 'not placed')" % (ts(t), ts(t), pid)).splitlines()
        lines, missing = [], []
        for r in rows:
            cid, bcs = r.split("|")
            ok = bool(set(bcs.split(",")) & seen)
            if not ok:
                missing.append(bcs or "db:" + cid)
            lines.append("jsonb_build_object('container', %s, 'found', %s)" % (cid, "true" if ok else "false"))
        self.spend(person, COST["record"] + 0.1 * len(lines))
        ev = self.ev_of("select count_place(jsonb_build_array(%s), %s, %s, %s, p_recorded => %s)"
                        % (", ".join(lines), ts(t), lit(person.actor), lit("count of " + place), ts(person.clock)))
        extra = [b for b in seen if not any(b in r.split("|")[1].split(",") for r in rows)]
        msg = "Recorded the count of %s: %d expected, %d found (event %d)." % (place, len(lines), len(lines) - len(missing), ev)
        if missing:
            msg += " Marked not found: %s." % ", ".join(missing[:20])
        if extra:
            msg += " You listed %s, which the inventory didn't expect there; record a move for those." % ", ".join(extra[:20])
        return msg

    def t_place_order(self, person, catalog_number, vials):
        pid, _ = self.product(catalog_number)
        n = int(vials)
        if not 1 <= n <= 10:
            raise Refused("order 1 to 10 at a time")
        self.spend(person, 5)
        lead = self.rng.randint(5, 10) if pid.split(":")[1].split("-")[0] in ("EGFR", "PDL1") else self.rng.randint(2, 3)
        arrive = local(person.clock + timedelta(days=lead)).replace(hour=9, minute=15).astimezone(UTC)
        self.orders.append({"product": pid, "vials": n, "ordered": person.clock, "arrive": arrive, "by": person.key})
        self.at(arrive, self.deliver, [(pid, 200.0) for _ in range(n)], "PO from %s" % person.name)
        return "Ordered %d x %s. The supplier confirms delivery on %s." % (n, pid, day_name(arrive))

    # ------------------------------------------------------------------ things that happen to the lab
    def deliver(self, items, why=""):
        """Vials land on the Goods-in shelf with a packing slip. Sometimes a vial holds less than the slip says."""
        t = self.w.now
        dn = "DN-%d" % (4000 + self._ev)
        slip = []
        for product, stated in items:
            mat = self.one("select material_id from product where id = %s" % lit(product))
            cat = product.split(":")[1]
            actual = 150.0 if self.rng.random() < self.p["supplier_short_fill"] else stated
            bc = self.dice.bc("TGT")
            cid = self.w.register("tube_1_5ml", bc, self.P["Goods-in"], None, at=t)
            code = "S%s" % bc.split("-")[1][-3:]
            self.w.receive(cid, mat, "target" if mat.startswith("target:") else "reagent", actual, product, code, at=t)
            if actual != stated:
                self.friction.append({"at": local(t).isoformat(), "who": "supplier", "what": "%s holds %g µL; the slip says %g" % (bc, actual, stated)})
            slip.append("vial %s: catalog %s, supplier lot %s, %g µL" % (bc, cat, code, stated))
        msg = "Delivery on the Goods-in shelf (packing slip %s%s): %s." % (dn, ", " + why if why else "", "; ".join(slip))
        self.deliveries.append({"at": local(t).isoformat(), "note": dn, "slip": slip})
        for p in self.people.values():
            if p.actor == "p:lena" or len(self.people) == 1:
                p.inbox.append((t, msg))
        return msg

    def message(self, who, text):
        p = self.people.get(who)
        if p:
            p.inbox.append((self.w.now, text))

    # ------------------------------------------------------------------ the day
    def t_my_tasks(self, person):
        self.spend(person, COST["tasks"])
        lines = []
        for t in person.tasks:
            state = "done at %s" % hm(t["done_at"]) if t["done_at"] else ("due %s" % hm(t["due"]) if t["due"] else "today")
            lines.append("- %s (%s): %s" % (t["id"], state, t["text"]))
        return "Your list for today:\n" + "\n".join(lines)

    def t_done(self, person, task_id, note=""):
        for t in person.tasks:
            if t["id"].lower() == task_id.strip().lower():
                self.spend(person, COST["done"])
                t["done_at"], t["note"] = person.clock, note
                return "Ticked off %s." % t["id"]
        raise Refused("no task %r on your list" % task_id)

    def t_wait(self, person, minutes, doing=""):
        """Routine work that isn't on the list (tidying, emails, restocking tips) while waiting for something."""
        m = max(1.0, min(float(minutes), 120.0))
        self.spend(person, m)
        return "You spend %d minutes on %s." % (round(m), doing or "routine work around the lab")

    def t_tell(self, person, to, message):
        self.spend(person, COST["tell"])
        for p in self.people.values():
            if p is not person and (to.lower() in p.name.lower() or to.lower() == p.key):
                p.inbox.append((person.clock, "%s says: %s" % (person.name, message)))
                return "Told %s." % p.name
        return "Told %s." % to

    # ------------------------------------------------------------------ end of day: notebook A against notebook B
    def score(self, label, t_utc):
        """Snapshot the World, score the database against it with score.compare, and add what
        compare can't see: things that exist in only one notebook because nobody linked them."""
        with self.lock:
            self.w.set_clock(max(self.w.now, t_utc))
            snap = self.w.snapshot(label)
            res = SC.compare(snap, self.db, "infinity")
            mapped = set(self.sql("select sim_id from sim.cmap").splitlines())
            never = []
            for cid, c in self.w.c.items():
                if cid in self.opening_ids or c.plate or c.cat not in ("tube", "plate", "holder"):
                    continue
                if cid not in mapped:
                    never.append({"world": cid, "barcode": c.barcode, "type": c.type,
                                  "exists": c.exited is None, "where": self.where(cid) if c.exited is None else "binned"})
            ghosts_db = self.sql("select c.id || '|' || coalesce((select string_agg(l.barcode, ',') from label l where l.container_id = c.id), '') "
                                 "from container c join event e on e.id = c.created_event_id "
                                 "where c.plate_id is null and e.occurred_at >= %s and c.id not in (select db_id from sim.cmap)" % ts(S.START)).splitlines()
            drift = []
            for (cid, lot, dim), (cls, tv, sv) in res["_pair_class"].items():
                top = cid.split("/")[0]
                if cls == "off" or (cls != "exact" and (top in self.touched or top not in self.opening_ids)):
                    drift.append({"what": "amount", "container": self.label(cid), "material": self.w.lots[lot].material if lot in self.w.lots else lot,
                                  "really": round(tv, 2), "inventory_says": round(sv, 2), "class": cls, "unit": dim})
            for cid in res["_loc_wrong"]:
                drift.append({"what": "place", "container": self.label(cid), "really": self.where(cid)})
            for cid in res["ghosts"]:
                drift.append({"what": "ghost", "container": self.label(cid), "note": "binned in the lab, still live in the inventory"})
            for cid in res["lost"]:
                drift.append({"what": "lost", "container": self.label(cid), "note": "still in the lab, recorded as gone"})
            for n in never:
                drift.append({"what": "never recorded", "container": n["barcode"] or n["world"], "type": n["type"], "really": n["where"]})
            for row in ghosts_db:
                dbid, bcs = row.split("|")
                drift.append({"what": "only in the inventory", "container": bcs or "db:" + dbid,
                              "note": "recorded, but no such container exists in the lab"})
            flags = SC.query(self.db, "select flag, detail from flags(%s, 'infinity')" % ts(t_utc))
            offs = sum(v["off"] for v in res["amounts"].values())
            allp = sum(sum(v.values()) for v in res["amounts"].values())
            loc = res["location"]
            tgt_true = sum(v[0] for k, v in res["usable"].items() if k.startswith("target:"))
            tgt_sys = sum(v[1] for k, v in res["usable"].items() if k.startswith("target:"))
            head = {"amounts_compared": allp, "amounts_off": offs,
                    "amounts_within_10pct": sum(v["within 10%"] for v in res["amounts"].values()),
                    "wrong_place_or_spot": loc["right place, wrong spot"] + loc["wrong place"] + loc["not placed"],
                    "ghosts": len(res["ghosts"]), "lost": len(res["lost"]), "never_recorded": len(never),
                    "only_in_inventory": len(ghosts_db), "flags": len(flags),
                    "target_usable_really_ul": round(tgt_true, 1), "target_usable_inventory_ul": round(tgt_sys, 1)}
            public = {k: v for k, v in res.items() if not k.startswith("_")}
            return {"headline": head, "checkpoint": public, "drift": drift, "flags": flags, "friction": list(self.friction)}
