#!/usr/bin/env python3
"""The dice lab: rolls through a few weeks of Adaptyv-style binding work and
writes two notebooks.

Notebook A (what really happened) is kept by world.py. Notebook B (what people,
robots and imports wrote down) is a list of calls to the record API in
schema/06_record.sql, with mistakes mixed in at the rates in presets.py. The
inventory database only ever sees notebook B; score.py compares its answers
with notebook A.

    python3 sim/simulate.py --preset normal                  # 1 week, small
    python3 sim/simulate.py --preset bad_week --days 28 --designs-per-week 768 --targets 4

Writes sim/out/<preset>/recorded.sql, truth.json and errors.jsonl.
Standard library only.
"""
import argparse
import heapq
import itertools
import json
import os
import random
from datetime import datetime, timedelta, timezone

from presets import PRESETS
from world import CT, ROWS, World

HERE = os.path.dirname(os.path.abspath(__file__))
UTC = timezone.utc
START = datetime(2026, 9, 7, tzinfo=UTC)      # a Monday; mistakes start here
SETUP = START - timedelta(days=21)            # opening stock, recorded without mistakes


def H(h):
    return timedelta(hours=h)


def D(d):
    return timedelta(days=d)


def ts(t):
    return "'" + t.strftime("%Y-%m-%d %H:%M:%S") + "+00'"


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def q(s):
    return "null" if s is None else "'" + str(s).replace("'", "''") + "'"


def n(x):
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


# The first three target products are in the seed; the preamble adds the rest.
TARGETS = [
    ("target:egfr", "vendorA:EGFR-100", "EGFR extracellular domain", None),
    ("target:pdl1", "vendorA:PDL1-200", "PD-L1", None),
    ("target:her2", "vendorA:HER2-100", "HER2 extracellular domain", "HER2"),
    ("target:il6r", "vendorB:IL6R-50", "IL-6 receptor alpha", "IL6R"),
    ("target:tnfa", "vendorB:TNFA-20", "TNF alpha", "TNFA"),
    ("target:cd47", "vendorA:CD47-100", "CD47", "CD47"),
]
SCIENTISTS = ["p:marco", "p:ana", "p:yuki", "p:ben"]
OPS = ["p:lena", "p:tom"]
REAGENTS = {   # product, material, container type, amount per delivery
    "water": ("vendorC:WATER", "reagent:water", "bottle", 500000.0),
    "hepes": ("vendorC:HEPES", "reagent:hepes", "bottle", 100000.0),
    "nacl": ("vendorC:NACL", "reagent:nacl", "bottle", 100000.0),
    "sensors": ("vendorE:SENSORS", "consumable:bli-sensors", "box_9x9", 384.0),   # a case of four trays
}
RECIPES = {
    "buffer:loading": [("water", 48500.0), ("hepes", 500.0), ("nacl", 1000.0)],
    "buffer:bli-running": [("water", 384000.0), ("hepes", 4000.0), ("nacl", 12000.0)],
    "buffer:gfp-stock": [("water", 30000.0)],
}
DNA_WELL_UL = 50.0     # water added per Twist well; 1-4 µg in 50 µL is 20-80 ng/µL (Twist: at least 10)


class Exp:
    def __init__(self, eid, target, designs, sci):
        self.id, self.target, self.designs, self.sci = eid, target, designs, sci
        self.dna_plates, self.ep, self.made = [], None, None
        self.wellmap = {}   # expression well position -> (dna plate id, dna well position, design)


class Lab:
    def __init__(self, preset, days, designs_per_week, n_targets, seed):
        self.preset, self.p = preset, PRESETS[preset]()
        self.rng = random.Random(seed)
        self.seed, self.days, self.end = seed, days, START + D(days)
        self.designs_per_week = designs_per_week
        self.targets = TARGETS[:n_targets]
        self.w = World({k: self.p[k] for k in ("manual_cv_pct", "robot_cv_pct", "robot_bias_pct", "evap_ul_per_h")},
                       start=SETUP, seed=seed + 1)
        self.C = self.w.c
        self.heap, self._h = [], itertools.count()
        self.lines, self._seq = [], itertools.count()
        self.errors = []
        self._e, self._x, self._r, self._b, self._bc = (itertools.count(1) for _ in range(5))
        self.belief, self.bexit, self.live_bc = {}, set(), {}
        self.snapshots = []
        self.P = {}
        self.pools = {"water": [], "hepes": [], "nacl": [], "sensors": [], "pure": []}
        self.buf = {m: None for m in RECIPES}
        self.aliquots = {m: [] for m, _, _, _ in self.targets}
        self.pending = {}
        self.exps = []
        self.rack_slot = itertools.count(1)
        self.count_week = 0

    # ------------------------------------------------------------------ plumbing
    @property
    def now(self):
        return self.w.now

    def at(self, t, fn, *args):
        heapq.heappush(self.heap, (t, next(self._h), fn, args))

    def on(self):
        return self.now >= START

    def chance(self, key):
        return self.on() and self.rng.random() < self.p[key]

    def emit(self, sql, rec, tag=None):
        self.lines.append((rec, next(self._seq), sql + ("  -- " + tag if tag else "")))

    def err(self, kind, what, by, containers=(), lots=(), run=None, t=None, **extra):
        e = {"id": "E%05d" % next(self._e), "type": kind, "at": iso(t or self.now), "by": by, "what": what,
             "containers": list(containers), "lots": list(lots), "run": run, "corrected_at": None}
        e.update(extra)
        self.errors.append(e)
        return e

    def fixed(self, e, t):
        if t <= self.end:
            e["corrected_at"] = iso(t)
            return True
        return False

    def bc(self, prefix):
        return "%s-%05d" % (prefix, next(self._bc))

    def ref(self, cid):
        c = self.C[cid]
        if c.plate:
            return "well(sim.c('%s'),'%s')" % (c.plate, c.pos)
        return "sim.c('%s')" % cid

    def label(self, cid):
        c = self.C[cid]
        return c.barcode or c.name or cid

    def workday(self, t, hour, minute=0, plus=1):
        d = (t + D(plus)).replace(hour=hour, minute=minute, second=0, microsecond=0)
        while d.weekday() >= 5:
            d += D(1)
        return d

    def main_lot(self, cid):
        best = max(self.C[cid].contents.items(), key=lambda kv: kv[1], default=None)
        return best[0] if best and best[1] > 0 else None

    def acc(self, cid):
        lot = self.main_lot(cid)
        return self.w.accessible(cid, lot) if lot else 0.0

    def dim(self, lot):
        return self.w.lots[lot].dim

    # ------------------------------------------------------------------ notebook B: the pen and the scanner
    def rec_time(self, t, by, containers=(), lots=(), what="entry"):
        if self.chance("late_manual"):
            lo, hi = self.p["late_manual_hours"]
            rec = t + H(self.rng.uniform(lo, hi))
            self.err("late_sync", "%s written down %.1f h after it happened" % (what, (rec - t).total_seconds() / 3600),
                     by, containers, lots, t=t, recorded_at=iso(rec), source="person")
            return rec
        return t

    def typed(self, value, by, what, containers=(), lots=()):
        if not self.on():
            return value, None
        r = self.rng.random()
        if r < self.p["typo_big"]:
            v, kind = (value * 10 if self.rng.random() < 0.5 else value / 10), "typo_big"
        elif r < self.p["typo_any"]:
            v, kind = value * (1 + self.rng.choice((-1, 1)) * self.rng.uniform(0.02, 0.2)), "typo_small"
        else:
            return value, None
        v = round(v, 1) if value >= 10 else round(v, 3)
        if v <= 0 or v == value:
            return value, None
        e = self.err(kind, "%s: typed %s instead of %s" % (what, n(v), n(value)), by, containers, lots,
                     typed=v, meant=value, source="person")
        return v, e

    def noticed(self, e, key):
        return e is not None and self.rng.random() < self.p["notice"].get(key, 0)

    def r_register(self, cid, t, by, into=None, pos=None, source="scan"):
        c = self.C[cid]
        if c.barcode and self.live_bc and self.chance("label_duplicate"):
            dup = self.rng.choice(sorted(self.live_bc))
            e = self.err("duplicate_label", "label for a new %s printed as %s, which is already on a live container" % (c.type, dup),
                         by, [cid, self.live_bc[dup]], source="person", expect="refused")
            self.emit("select sim.try(%s, $s$ select register_container(%s, %s, %s, %s, p_into => %s, p_position => %s) $s$);"
                      % (q(e["id"]), q(c.type), ts(t), q(by), q(dup), self.ref(into) if into else "null", q(pos)), t, e["id"])
        self.emit("select sim.setc(%s, register_container(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s));"
                  % (q(cid), q(c.type), ts(t), q(by), q(c.barcode), q(c.name), q(c.cond),
                     self.ref(into) if into else "null", q(pos), q(source), ts(t)), t)
        if c.barcode:
            self.live_bc[c.barcode] = cid
        if into:
            self.belief[cid] = into

    def register(self, ctype, t, by, barcode=None, into=None, pos=None, source="scan", name=None, cond=None):
        cid = self.w.register(ctype, barcode, into, pos, name=name, condition=cond, at=t)
        self.r_register(cid, t, by, into, pos, source)
        return cid

    def r_move(self, cid, dest, pos, t, by, source="scan"):
        if source == "scan":
            if self.chance("move_unscanned"):
                self.err("move_unscanned", "%s moved to %s without a scan" % (self.label(cid), self.label(dest)), by, [cid], source="person")
                return
            if pos and pos.startswith("slot ") and self.chance("wrong_position"):
                k = int(pos.split()[1])
                wrong = "slot %d" % (k + 1 if k < 81 else k - 1)
                self.err("wrong_position", "%s put in %s but recorded as %s" % (self.label(cid), pos, wrong), by, [cid], source="person")
                pos = wrong
        rec = self.rec_time(t, by, [cid], what="move of " + self.label(cid)) if source == "scan" else t
        self.emit("select move(%s, %s, %s, %s, %s, %s, p_recorded => %s);"
                  % (self.ref(cid), self.ref(dest), q(pos), ts(t), q(by), q(source), ts(rec)), rec)
        self.belief[cid] = dest

    def move(self, cid, dest, pos, t, by, source="scan", record_as=None):
        self.w.move(cid, dest, pos, at=t)
        self.r_move(record_as or cid, dest, pos, t, by, source)

    def r_scan(self, cid, t, by, seen_in=None):
        self.emit("select scan(%s, %s, %s, %s, %s, p_recorded => %s);"
                  % (self.ref(cid), ts(t), q(by), q(self.C[cid].barcode), self.ref(seen_in) if seen_in else "null", ts(t)), t)

    def r_consume(self, cid, lot, amount, t, by, note=None, run=None):
        """A person writes down that they used some of a lot."""
        e = None
        d = self.dim(lot)
        if self.chance("step_unrecorded"):
            e = self.err("step_unrecorded", "took %s from %s and didn't record it" % (n(amount), self.label(cid)),
                         by, [cid], [lot], source="person")
            if self.noticed(e, "step_unrecorded"):
                later = t + H(self.rng.uniform(12, 72))
                if self.fixed(e, later):
                    self.emit("select consume(%s, sim.l(%s), %s, %s, %s, %s, p_note => %s, p_recorded => %s);"
                              % (self.ref(cid), q(lot), n(amount), q(d), ts(t), q(by), q("remembered later"), ts(later)), later, e["id"])
            return
        amount, e = self.typed(amount, by, "amount taken from " + self.label(cid), [cid], [lot])
        rec = self.rec_time(t, by, [cid], [lot], "use of " + self.label(cid))
        call = ("consume(%s, sim.l(%s), %s, %s, %s, %s, 'manual', %s, null, %s, p_recorded => %s)"
                % (self.ref(cid), q(lot), n(amount), q(d), ts(t), q(by), ("sim.r(%s)" % q(run)) if run else "null", q(note), ts(rec)))
        if e is not None and self.noticed(e, e["type"]):
            x = "X%d" % next(self._x)
            self.emit("select sim.sete(%s, %s);" % (q(x), call), rec, e["id"])
            later = rec + H(self.rng.uniform(4, 72))
            if self.fixed(e, later):
                self.emit("select consume(%s, sim.l(%s), %s, %s, %s, %s, p_event => void(sim.e(%s), %s, %s, %s));"
                          % (self.ref(cid), q(lot), n(e["meant"]), q(d), ts(t), q(by), q(x), q(by),
                             q("typed %s, meant %s" % (n(e["typed"]), n(e["meant"]))), ts(later)), later, e["id"])
        else:
            self.emit("select %s;" % call, rec, e["id"] if e else None)

    def r_discard(self, cid, t, by, neighbours=(), note=None):
        if self.chance("discard_unscanned"):
            self.err("discard_unscanned", "%s thrown away without a scan" % self.label(cid), by, [cid], source="person")
            return
        target, e = cid, None
        if neighbours and self.chance("wrong_scan"):
            target = self.rng.choice(list(neighbours))
            e = self.err("wrong_scan", "scanned %s instead of %s when throwing it away" % (self.label(target), self.label(cid)),
                         by, [cid, target], source="person")
        rec = self.rec_time(t, by, [target], what="disposal of " + self.label(target))
        call = "discard(%s, %s, %s, 'scan', %s, p_recorded => %s)" % (self.ref(target), ts(t), q(by), q(note), ts(rec))
        if e and self.noticed(e, "wrong_scan"):
            x = "X%d" % next(self._x)
            self.emit("select sim.sete(%s, %s);" % (q(x), call), rec, e["id"])
            later = rec + H(self.rng.uniform(24, 240))
            if self.fixed(e, later):
                self.emit("select discard(%s, %s, %s, 'scan', p_event => void(sim.e(%s), %s, %s, %s));"
                          % (self.ref(cid), ts(t), q(by), q(x), q(by), q("scanned the wrong tube at the bin"), ts(later)), later, e["id"])
                self.bexit.add(cid)
                return
        else:
            self.emit("select %s;" % call, rec, e["id"] if e else None)
        self.bexit.add(target)

    def discard(self, cid, t, by, neighbours=(), note=None):
        self.w.discard(cid, at=t)
        self.live_bc.pop(self.C[cid].barcode, None)
        self.r_discard(cid, t, by, neighbours, note)

    def robot_run(self, protocol, instrument, robot, by, t, steps, consumes=(), exp=None, finish_by=None, finish_at=None, extra=None):
        """A robot run: the worklist is imported as planned transfers, the robot really does
        each step (world), and its log arrives as one transfer per step. A log line can go
        missing, and a whole log can be uploaded late."""
        rid = "R%d" % next(self._r)
        self.emit("select sim.setr(%s, start_run(%s, %s, %s, p_instrument => %s, p_experiment => %s, p_recorded => %s));"
                  % (q(rid), q(protocol), ts(t), q(by), self.ref(instrument), q(exp), ts(t)), t)
        rows = ["(sim.r(%s), %d, %s, %s, sim.l(%s), %s, %s)" % (q(rid), i, self.ref(s), self.ref(d), q(l), q(self.dim(l)), n(a))
                for i, (s, d, l, a) in enumerate(steps, 1)]
        for k in range(0, len(rows), 400):
            self.emit("insert into planned_transfer values %s;" % ", ".join(rows[k:k + 400]), t)
        late = t
        if self.chance("robot_log_late"):
            lo, hi = self.p["robot_log_late_hours"]
            late = t + H(self.rng.uniform(lo, hi))
            self.err("robot_log_late", "log of the %s run uploaded %.0f h late" % (protocol, (late - t).total_seconds() / 3600),
                     robot, [steps[0][1]] if steps else [], run=rid, recorded_at=iso(late), source="robot")
        for i, (src, dst, lot, amt) in enumerate(steps, 1):
            at = t + timedelta(seconds=6 * i)
            self.w.transfer(src, dst, lot, amt, device=robot, at=at)
            if self.chance("robot_step_missing"):
                self.err("robot_step_missing", "%s step %d (%s to %s) done but missing from the log" % (protocol, i, src, dst),
                         robot, [src, dst], [lot], run=rid, source="robot")
                continue
            rec = max(at, late)
            self.emit("select transfer(%s, %s, sim.l(%s), %s, %s, %s, %s, 'robot_log', sim.r(%s), %d, p_recorded => %s);"
                      % (self.ref(src), self.ref(dst), q(lot), n(amt), q(self.dim(lot)), ts(at), q(robot), q(rid), i, ts(rec)), rec)
        end = t + timedelta(seconds=6 * (len(steps) + 1))
        for j, (cid, lot, amt) in enumerate(consumes, 1000):
            self.w.take(cid, lot, amt, device=robot)
            self.emit("select consume(%s, sim.l(%s), %s, %s, %s, %s, 'robot_log', sim.r(%s), %d, p_recorded => %s);"
                      % (self.ref(cid), q(lot), n(amt), q(self.dim(lot)), ts(end), q(robot), q(rid), j, ts(max(end, late))), max(end, late))
        if extra:
            extra(rid, end)
        fin = finish_at or end
        frec = fin if finish_by else max(fin, late)
        self.emit("select finish_run(sim.r(%s), %s, %s, p_recorded => %s);" % (q(rid), ts(fin), q(finish_by or robot), ts(frec)), frec)
        return rid

    # ------------------------------------------------------------------ setup: the opening stock
    def setup(self):
        t = SETUP
        places = [("Freezer F80-1", "freezer", "minus80"), ("Freezer F80-2", "freezer", "minus80"),
                  ("Freezer F80-3", "freezer", "minus80"), ("Freezer F20-1", "freezer", "minus20"),
                  ("Fridge R1", "fridge", "fridge"), ("Bench B1", "bench", "room"), ("Bench B2", "bench", "room"),
                  ("Shelf S1", "bench", "room"), ("Hamilton 1", "instrument", "room"), ("Hamilton 2", "instrument", "room"),
                  ("Incubator 1", "instrument", "room"), ("Plate reader 1", "instrument", "room"),
                  ("Gator 1", "instrument", "room"), ("Gator 2", "instrument", "room")]
        for name, ctype, cond in places:
            self.P[name] = self.register(ctype, t, "p:sara", name=name, cond=cond, source="manual")
        self.P["rack"] = self.register("rack", t, "p:sara", "RACK-D1", into=self.P["Freezer F20-1"])
        self.P["inbox"] = self.register("box_9x9", t, "p:sara", "BOX-INBOX", into=self.P["Freezer F80-1"])
        t = SETUP + H(10)
        # Opening stock arrives at least 4 days apart per product, so the duplicate-delivery
        # check (same product, lot and amount within 3 days) only fires on what happens in the run.
        for i in range(5):
            self.at(t + D(i * 4), self.deliver_reagent, "water")
            self.at(t + D(i * 4) + H(1), self.deliver_reagent, "sensors")
        for i in range(2):
            self.at(t + D(i * 5), self.deliver_reagent, "hepes")
            self.at(t + D(i * 5) + H(1), self.deliver_reagent, "nacl")
        for i in range(4):
            self.at(t + D(i * 3) + H(2), self.deliver_reagent, "pure")
        for k, (mat, prod, _, _) in enumerate(self.targets):
            for i in range(3):
                self.at(t + D(1 + i * 4) + H(k * 0.5), self.target_delivery, mat, prod, "S%02d%d" % (k, i), 200.0, 200.0, False)
        self.at(START - D(10) + H(9), self.make_buffer, "buffer:gfp-stock")
        self.at(START - D(3) + H(9), self.make_buffer, "buffer:loading")
        self.at(START - D(3) + H(9.5), self.make_buffer, "buffer:bli-running")

    # ------------------------------------------------------------------ the supplier and receiving
    def deliver_reagent(self, what):
        t = self.now
        by = self.rng.choice(OPS)
        self.pending[what] = 0
        if what == "pure":
            return self.deliver_pure(t, by)
        prod, mat, ctype, amount = REAGENTS[what]
        cid = self.register(ctype, t, by, self.bc(what.upper()[:3]), into=self.P["Shelf S1"])
        kind = "consumable" if what == "sensors" else "reagent"
        lot = self.w.receive(cid, mat, kind, amount, prod, "LOT-%s-%d" % (what.upper(), (t - SETUP).days // 30), at=t)
        self.r_receive(lot, cid, amount, t, by, "DN-%d" % next(self._b))
        self.pools[what].append(cid)

    def deliver_pure(self, t, by):
        # A kit is six tubes of one lot. receive() makes one lot per call, so the kit is
        # received into the first tube and split into the other five (see the gaps note).
        box = self.register("box_9x9", t, by, self.bc("KIT"), into=self.P["Freezer F80-2"])
        first = self.register("tube_1_5ml", t, by, self.bc("PURE"), into=box, pos="slot 0")
        self.C[first].home = (box, "slot 0")
        lot = self.w.receive(first, "reagent:pure-mix", "reagent", 7500.0, "vendorD:PURE", "PM-%d" % next(self._b), at=t)
        self.r_receive(lot, first, 7500.0, t, by, "DN-%d" % next(self._b))
        prefix = self.bc("PURE") + "-"
        kids = self.w.split(first, lot, 5, 1250.0, "tube_1_5ml", place=box, barcode_prefix=prefix, at=t)
        for k in kids:
            self.live_bc[self.C[k].barcode] = k
            self.belief[k] = box
        self.emit("select sim.setcs(array[%s], split(%s, sim.l(%s), 5, 1250, 'tube_1_5ml', %s, %s, %s, p_into => %s, p_recorded => %s));"
                  % (", ".join(q(k) for k in kids), self.ref(first), q(lot), ts(t), q(by), q(prefix), self.ref(box), ts(t)), t)
        self.pools["pure"] += [first] + kids

    def r_receive(self, lot, cid, stated, t, by, ref, source="manual", price=None):
        L = self.w.lots[lot]
        amount, e = (self.typed(stated, by, "amount received into " + self.label(cid), [cid], [lot])
                     if source == "manual" else (stated, None))
        args = "%s, %s, %s, %s, %s, %s, p_supplier_lot => %s, p_ref => %s, p_price => %s, p_source => %s, p_recorded => %s" % (
            q(L.product), self.ref(cid), n(amount), q(L.dim), ts(t), q(by), q(L.code), q(ref), n(price) if price else "null",
            q(source), ts(t))
        self.emit("select sim.setl(%s, receive(%s));" % (q(lot), args), t, e["id"] if e else None)
        if e and self.noticed(e, e["type"]):
            self.at(t + H(self.rng.uniform(4, 30)), self.recount, cid, lot, e, by)
        if self.chance("dup_delivery"):
            if source == "import" or self.rng.random() < 0.5:
                e2 = self.err("duplicate_delivery", "delivery %s booked in a second time with the same delivery note (a retry)" % ref,
                              by, [cid], [lot], source="person", expect="refused")
                self.emit("select sim.try(%s, $s$ select receive(%s) $s$);" % (q(e2["id"]), args), t + H(0.1), e2["id"])
            else:
                dup = "LB%d" % next(self._b)
                later = t + H(self.rng.uniform(0.5, 6))
                e2 = self.err("duplicate_delivery", "delivery %s booked in again by a second person without the delivery note" % ref,
                              by, [cid], [lot, dup], source="person")
                self.emit("select sim.setl(%s, receive(%s, %s, %s, %s, %s, %s, p_supplier_lot => %s, p_recorded => %s));"
                          % (q(dup), q(L.product), self.ref(cid), n(stated), q(L.dim), ts(later), q(by), q(L.code), ts(later)), later, e2["id"])
                if self.noticed(e2, "duplicate_delivery"):
                    fix = later + H(self.rng.uniform(2, 30))
                    if self.fixed(e2, fix):
                        self.emit("select void((select created_event_id from lot where id = sim.l(%s)), %s, %s, %s);"
                                  % (q(dup), q("p:sara"), q("same delivery booked twice"), ts(fix)), fix, e2["id"])

    def recount(self, cid, lot, e, by):
        # Someone noticed a typed amount looked wrong and recounted the tube (D4: count, then approve).
        t = self.now
        if self.C[cid].exited or not self.fixed(e, t):
            return
        amt = self.C[cid].contents.get(lot, 0.0)
        self.emit("select approve_count(count_place(jsonb_build_array(jsonb_build_object('container', %s, 'found', true, 'amount', %s, 'dimension', %s)), %s, %s, 'recount', p_recorded => %s), %s, %s, %s, p_recorded => %s);"
                  % (self.ref(cid), n(amt), q(self.dim(lot)), ts(t), q(by), ts(t), ts(t), q(by), q("typed amount looked wrong"), ts(t)), t, e["id"])

    def target_delivery(self, mat, prod, code, stated, actual, ordered=True):
        t = self.now
        by = self.rng.choice(OPS)
        if ordered:
            self.pending[mat] = max(0, self.pending.get(mat, 0) - 1)
        cid = self.register("tube_1_5ml", t, by, self.bc("TGT"), into=self.P["inbox"])
        lot = self.w.receive(cid, mat, "target", actual, prod, code, at=t)
        if actual != stated:
            self.err("supplier_short_fill", "vial %s holds %s µL, the packing slip says %s" % (self.label(cid), n(actual), n(stated)),
                     "supplier", [cid], [lot], source="supplier")
        self.r_receive(lot, cid, stated, t, by, "DN-%d" % next(self._b), price=300)
        self.at(self.workday(t, 9), self.qc_target, cid, lot)

    def order_target(self, mat, prod):
        lead = self.rng.randint(5, 10)
        if self.chance("supplier_late"):
            lead += self.rng.randint(2, 4)
        arrive = self.workday(self.now, 10, plus=lead)
        code = "S%d" % next(self._b)
        actual = 150.0 if self.chance("supplier_short_fill") else 200.0
        self.pending[mat] = self.pending.get(mat, 0) + 1
        self.at(arrive, self.target_delivery, mat, prod, code, 200.0, actual)
        if self.chance("supplier_duplicate"):
            # The supplier really ships the same vial twice. Both are real; the record is right.
            self.pending[mat] += 1
            self.at(arrive + D(1), self.target_delivery, mat, prod, code, 200.0, actual)
            self.err("supplier_duplicate", "supplier shipped lot %s of %s twice; both vials are real" % (code, mat),
                     "supplier", [], [], source="supplier", real=True)

    def qc_target(self, cid, lot):
        t = self.now
        by = "p:lena"
        if self.C[cid].exited:
            return
        self.w.take(cid, lot, 5.0)
        self.r_consume(cid, lot, 5.0, t, by, note="QC sample")
        outcome = "fail" if (self.on() and self.rng.random() < self.p["target_qc_fail"]) else "pass"
        self.w.set_qc(lot, outcome)
        rec = self.rec_time(t, by, [cid], [lot], "QC result")
        self.emit("select qc(sim.l(%s), %s, 'SDS-PAGE and A280', %s, %s, p_recorded => %s);" % (q(lot), q(outcome), ts(t), q(by), ts(rec)), rec)
        if outcome == "pass":
            self.at(t + H(1), self.aliquot, cid, lot)
        else:
            self.at(self.workday(t, 10), self.discard_task, cid, "p:lena")
            self.order_target(self.w.lots[lot].material, self.w.lots[lot].product)

    def discard_task(self, cid, by):
        if not self.C[cid].exited:
            self.discard(cid, self.now, by)

    def aliquot(self, cid, lot):
        t = self.now
        by = "p:lena"
        if self.C[cid].exited:
            return
        self.move(cid, self.P["Bench B1"], None, t, by)
        box = self.register("box_9x9", t, by, self.bc("BOX"), into=self.P["Freezer F80-1"])
        count = min(4, int(self.w.accessible(cid, lot) // 45))
        prefix = self.bc("ALQ") + "-"
        kids = self.w.split(cid, lot, count, 45.0, "tube_matrix", place=box, barcode_prefix=prefix, at=t) if count else []
        for k in kids:
            self.live_bc[self.C[k].barcode] = k
            self.belief[k] = box
        if count:
            each, e = self.typed(45.0, by, "volume per aliquot in the split of " + self.label(cid), [cid] + kids, [lot])
            self.emit("select sim.setcs(array[%s], split(%s, sim.l(%s), %d, %s, 'tube_matrix', %s, %s, %s, p_into => %s, p_recorded => %s));"
                      % (", ".join(q(k) for k in kids), self.ref(cid), q(lot), count, n(each), ts(t), q(by), q(prefix), self.ref(box), ts(t)),
                      t, e["id"] if e else None)
            if e and self.noticed(e, e["type"]):
                later = t + H(self.rng.uniform(4, 72))
                if self.fixed(e, later):
                    x = "X%d" % next(self._x)
                    self.emit("select sim.sete(%s, void((select q.event_id from quantity_entry q join event v on v.id = q.event_id where v.kind = 'split' and q.container_id = %s limit 1), %s, %s, %s));"
                              % (q(x), self.ref(kids[0]), q(by), q("typed %s per aliquot, meant 45" % n(each)), ts(later)), later, e["id"])
                    for k in kids:
                        self.emit("select transfer(%s, %s, sim.l(%s), 45, 'volume', %s, %s, p_event => sim.e(%s));"
                                  % (self.ref(cid), self.ref(k), q(lot), ts(t), q(by), q(x)), later, e["id"])
        self.aliquots[self.w.lots[lot].material] += kids
        self.discard(cid, t + H(0.2), by)

    # ------------------------------------------------------------------ buffers
    def pick(self, pool, need):
        live = [(self.acc(c), c) for c in self.pools[pool] if not self.C[c].exited and self.main_lot(c)]
        live = [x for x in live if x[0] > 0]
        if not live:
            return None
        enough = [x for x in live if x[0] >= need]
        return min(enough)[1] if enough else max(live)[1]

    def make_buffer(self, mat):
        t = self.now
        by = self.rng.choice(OPS)
        old = self.buf.get(mat)
        if old is not None and not self.C[old].exited:
            self.discard(old, t, by)
        out = self.register("bottle", t, by, self.bc("BUF"), into=self.P["Fridge R1"])
        inputs, rec_inputs = [], []
        for what, amt in RECIPES[mat]:
            src = self.pick(what, amt)
            if src is None:
                continue
            slot = self.main_lot(src)
            inputs.append((src, slot, amt, "hand:0.3"))
            if self.chance("step_unrecorded"):
                self.err("step_unrecorded", "%s from %s left out of the record for %s" % (what, self.label(src), self.label(out)),
                         by, [src], [slot], source="person")
                continue
            val, _ = self.typed(amt, by, "%s volume in %s" % (what, self.label(out)), [src], [slot])
            rec_inputs.append("jsonb_build_object('container', %s, 'lot', sim.l(%s), 'amount', %s, 'dimension', 'volume')"
                              % (self.ref(src), q(slot), n(val)))
        lot = self.w.make(mat, "buffer", inputs, out, at=t)
        made_rec, _ = self.typed(sum(a for _, a in RECIPES[mat]), by, "volume made in " + self.label(out), [out], [lot])
        self.emit("select sim.setl(%s, make(%s, jsonb_build_array(%s), %s, %s, 'volume', %s, %s, p_recorded => %s));"
                  % (q(lot), q(mat), ", ".join(rec_inputs), self.ref(out), n(made_rec), ts(t), q(by), ts(t)), t)
        self.buf[mat] = out

    def ensure_buffer(self, mat, need):
        """A scientist who finds the bottle nearly empty asks lab operations for a fresh one."""
        b = self.buf.get(mat)
        if b is None or self.C[b].exited or self.acc(b) < need:
            self.make_buffer(mat)
        return self.buf.get(mat)

    # ------------------------------------------------------------------ the binding workflow
    def dna_arrival(self, exp):
        t = self.now
        by = self.rng.choice(OPS)
        nplates = (len(exp.designs) + 95) // 96
        for qd in range(nplates):
            slot = "slot %d" % next(self.rack_slot)
            pl = self.register("plate_96", t, by, "TW-%02d%d" % (exp.id, qd + 1), into=self.P["rack"], pos=slot)
            self.C[pl].home = (self.P["rack"], slot)
            for i, design in enumerate(exp.designs[qd * 96:(qd + 1) * 96]):
                pos = "%s%d" % (ROWS[i // 12], i % 12 + 1)
                w = "%s/%s" % (pl, pos)
                amount = round(self.rng.uniform(0.1, 0.9) if self.rng.random() < self.p["dna_low_yield"] else self.rng.uniform(1, 4), 3)
                lot = self.w.receive(w, "dna:" + design, "dna", amount, "twist:" + design, "TW%02d" % exp.id, at=t)
                ref = "twist:ORD-%02d:%d:%s" % (exp.id, qd + 1, pos)
                if qd == 0 and i == 0:
                    # A plate-map import can be retried by mistake; only the first line of the
                    # retry matters, because the import stops at the first refusal.
                    self.r_receive(lot, w, amount, t, by, ref, source="import")
                else:
                    self.emit("select sim.setl(%s, receive(%s, %s, %s, 'mass', %s, %s, p_supplier_lot => %s, p_ref => %s, p_source => 'import', p_recorded => %s));"
                              % (q(lot), q("twist:" + design), self.ref(w), n(amount), ts(t), q(by), q("TW%02d" % exp.id), q(ref), ts(t)), t)
            exp.dna_plates.append(pl)
        self.at(self.workday(t, 9), self.reconstitute, exp)

    def reconstitute(self, exp):
        """Dried DNA dissolved in water, well by well (multichannel by hand)."""
        t = self.now
        for pl in exp.dna_plates:
            self.move(pl, self.P["Bench B1"], None, t, exp.sci)
            vol, e = self.typed(DNA_WELL_UL, exp.sci, "water per well for " + self.label(pl), [pl], [])
            for w in sorted(self.C[pl].wells.values(), key=lambda w: (w.pos[0], int(w.pos[1:]))):
                lot = self.main_lot(w.id)
                if lot is None:
                    continue
                src = self.pick("water", DNA_WELL_UL)
                slot = self.main_lot(src)
                mass = self.C[w.id].contents[lot]
                self.w.reconstitute(w.id, lot, DNA_WELL_UL, src, slot)
                self.emit("select reconstitute(%s, sim.l(%s), %s, %s, %s, sim.l(%s), %s, %s, p_recorded => %s);"
                          % (self.ref(w.id), q(lot), n(mass), n(vol), self.ref(src), q(slot), ts(t + H(0.3)), q(exp.sci), ts(t + H(0.3))),
                          t + H(0.3), e["id"] if e else None)
        self.at(t + H(1), self.expression_prep, exp, 0)

    def expression_prep(self, exp, tries):
        t = self.now
        sci = exp.sci
        mix = sorted((c for c in self.pools["pure"] if not self.C[c].exited and self.acc(c) >= 1230), key=self.acc)
        need = 1 if len(exp.designs) <= 192 else 2
        if len(mix) < need:
            self.order_reagent("pure")
            if tries < 8:
                self.at(self.workday(t, 10), self.expression_prep, exp, tries + 1)
            return
        mix = mix[:need]
        ham = self.P["Hamilton 1"]
        ep = self.register("plate_384", t, sci, "EXP-%02d" % exp.id, into=ham)
        exp.ep = ep
        for pl in exp.dna_plates:
            self.move(pl, ham, None, t + H(0.05), sci)
        for m in mix:
            self.r_scan(m, t + H(0.05), sci, seen_in=self.C[m].home[0])
            self.move(m, ham, None, t + H(0.06), sci)
        steps, order = [], []
        for qd, pl in enumerate(exp.dna_plates):
            for i, design in enumerate(exp.designs[qd * 96:(qd + 1) * 96]):
                r, k = divmod(i, 12)
                pos96 = "%s%d" % (ROWS[r], k + 1)
                pos384 = "%s%d" % (ROWS[2 * r + qd // 2], 2 * k + qd % 2 + 1)
                src = "%s/%s" % (pl, pos96)
                steps.append((src, "%s/%s" % (ep, pos384), self.main_lot(src), 2.0))
                order.append(pos384)
                exp.wellmap[pos384] = (pl, pos96, design)
        for i, pos384 in enumerate(order):
            m = mix[0] if i < 192 else mix[1]
            steps.append((m, "%s/%s" % (ep, pos384), self.main_lot(m), 6.0))
        self.robot_run("expression plate prep", ham, "robot:hamilton-1", sci, t + H(0.1), steps, exp="EXP-%02d" % exp.id)
        back = t + H(1.5)
        for pl in exp.dna_plates:
            self.move(pl, self.C[pl].home[0], self.C[pl].home[1], back, sci)
        for m in mix:
            box, slot = self.C[m].home
            if self.acc(m) < 50:
                self.discard(m, back, sci, neighbours=[x for x in self.pools["pure"] if not self.C[x].exited and self.C[x].parent == box and x != m])
            else:
                self.move(m, box, slot, back, sci)
        self.move(ep, self.P["Incubator 1"], None, back + H(0.1), sci)
        self.at(back + H(8), self.expression_done, exp)

    def expression_done(self, exp):
        """LabOS writes one make per well when the expression run ends: DNA plus mix become protein."""
        t = self.now
        exp.made = t
        for pos, (pl, pos96, design) in exp.wellmap.items():
            w = "%s/%s" % (exp.ep, pos)
            parts = []
            for l in list(self.C[w].contents):
                L = self.w.lots[l]
                amount = 2 if L.kind == "dna" else 6
                parts.append("jsonb_build_object('container', %s, 'lot', sim.l(%s), 'amount', %s, 'dimension', 'volume')" % (self.ref(w), q(l), amount))
            inputs = [(w, l, self.C[w].contents[l], "exact") for l in list(self.C[w].contents)]
            vol = sum(a for a in self.C[w].contents.values() if a > 0)
            lot = self.w.make("sample:" + design, "sample_protein", inputs, w, amount=vol, at=t)
            if not parts:
                dl = self.main_lot("%s/%s" % (pl, pos96))
                if dl:
                    parts.append("jsonb_build_object('container', %s, 'lot', sim.l(%s), 'amount', 2, 'dimension', 'volume')" % (self.ref(w), q(dl)))
            self.emit("select sim.setl(%s, make(%s, jsonb_build_array(%s), %s, 8, 'volume', %s, 'system:labos', 'import', p_recorded => %s));"
                      % (q(lot), q("sample:" + design), ", ".join(parts), self.ref(w), ts(t), ts(t)), t)
        nxt = self.workday(t, 8, 30)
        self.at(nxt, self.move_task, exp.ep, self.P["Fridge R1"], exp.sci)
        self.at(nxt + H(0.5), self.gfp_prep, exp)

    def move_task(self, cid, dest, by):
        if not self.C[cid].exited:
            self.move(cid, dest, None, self.now, by)

    def single_use_done(self, plate, t, by):
        """The run is over; the plate goes in the bin, as the rule (D6) assumes. Sometimes it doesn't."""
        if self.on() and self.rng.random() < self.p["rule_exception"]:
            self.w.move(plate, self.P["Bench B2"], None, at=t)
            self.err("rule_default_wrong", "%s kept on the bench for a re-read; the rule recorded it as thrown away" % self.label(plate),
                     by, [plate], source="rule", real=True)
            self.at(self.workday(t, 10), self.reread, plate, by)
        else:
            self.w.discard(plate, at=t)
            self.live_bc.pop(self.C[plate].barcode, None)

    def reread(self, plate, by):
        t = self.now
        self.r_scan(plate, t, by, seen_in=self.P["Bench B2"])
        self.discard(plate, t + H(0.5), by)

    def gfp_prep(self, exp):
        t = self.now
        sci, ep = exp.sci, exp.ep
        ham = self.P["Hamilton 1"]
        self.move(ep, ham, None, t, sci)
        gp = self.register("plate_gfp", t, sci, self.bc("GFP"), into=ham)
        steps = []
        for pos in exp.wellmap:
            src = "%s/%s" % (ep, pos)
            lot = self.main_lot(src)
            if lot:
                steps.append((src, "%s/%s" % (gp, pos), lot, 1.0))
        gfp = self.ensure_buffer("buffer:gfp-stock", 10.0 * len(steps))
        cons = [(gfp, self.main_lot(gfp), 10.0 * len(steps))] if gfp and not self.C[gfp].exited and self.main_lot(gfp) else []
        reader = self.P["Plate reader 1"]

        def to_reader(rid, at):
            self.w.move(gp, reader, None, at=at)
            self.emit("select move(%s, %s, null, %s, 'robot:hamilton-1', 'robot_log', p_recorded => %s);" % (self.ref(gp), self.ref(reader), ts(at), ts(at)), at)
            self.belief[gp] = reader

        fin = t + H(2.5)
        self.robot_run("split-GFP plate prep and read", reader, "robot:hamilton-1", sci, t + H(0.1), steps, cons,
                       exp="EXP-%02d" % exp.id, finish_by="instrument:reader-1", finish_at=fin, extra=to_reader)
        self.w.evaporate(ep, 0.5)      # on the deck, lidded, while the robot works
        self.move(ep, self.P["Fridge R1"], None, t + H(1), sci)
        self.single_use_done(gp, fin + H(0.2), sci)
        nplates = len(exp.dna_plates)
        when = [t.replace(hour=13, minute=0), t.replace(hour=13, minute=6)]
        nxt = self.workday(t, 9)
        when += [nxt, nxt + H(0.1)]
        for qd in range(nplates):
            self.at(when[qd], self.bli_run, exp, qd, "Gator %d" % (qd % 2 + 1), 0, False)

    def target_stock(self, mat):
        out = []
        for a in self.aliquots[mat]:
            c = self.C[a]
            if c.exited or c.parent is None or self.C[c.parent].type != "box_9x9":
                continue
            lot = self.main_lot(a)
            if lot is None or self.w.lots[lot].qc != "pass":
                continue
            acc = self.w.accessible(a, lot)
            if acc >= 1.0:
                out.append((acc, a, lot))
        return out

    def bli_run(self, exp, qd, gator, tries, rerun):
        t = self.now
        sci, ep = exp.sci, exp.ep
        if self.C[ep].exited or t - exp.made > D(13):
            return
        if sum(x[0] for x in self.target_stock(exp.target)) < 32:
            self.check_targets()
            if tries < 6:
                self.at(self.workday(t, 13), self.bli_run, exp, qd, gator, tries + 1, rerun)
            return
        ham = self.P["Hamilton 2"]
        self.move(ep, ham, None, t, sci)
        sp = self.register("plate_bli", t, sci, self.bc("BLI"), into=ham)
        tp = self.register("plate_bli", t, sci, self.bc("TP"), into=self.P["Bench B1"])
        steps = []
        for i, design in enumerate(exp.designs[qd * 96:(qd + 1) * 96]):
            r, k = divmod(i, 12)
            src = "%s/%s%d" % (ep, ROWS[2 * r + qd // 2], 2 * k + qd % 2 + 1)
            lot = self.main_lot(src)
            if lot:
                steps.append((src, "%s/%s%d" % (sp, ROWS[r], k + 1), lot, 2.0))
        lb = self.ensure_buffer("buffer:loading", 38.0 * len(steps))
        cons = [(lb, self.main_lot(lb), 38.0 * len(steps))] if lb and not self.C[lb].exited and self.main_lot(lb) else []
        gat = self.P[gator]

        def target_plate(rid, at):
            self.target_plate_prep(exp, tp, rid, at + H(0.1), sci)

        fin = t + H(4)
        self.robot_run("BLI binding" + (" (re-run)" if rerun else ""), gat, "robot:hamilton-2", sci, t + H(0.05), steps, cons,
                       exp="EXP-%02d" % exp.id, finish_by="instrument:" + gator.lower().replace(" ", "-"), finish_at=fin, extra=target_plate)
        self.w.evaporate(ep, 0.25)     # one quadrant drawn; the plate is out for about 15 minutes
        self.move(ep, self.P["Fridge R1"], None, t + H(1.2), sci)
        self.move(sp, gat, None, t + H(1.3), sci)
        self.move(tp, gat, None, t + H(1.3), sci)
        self.single_use_done(sp, fin + H(0.2), sci)
        self.single_use_done(tp, fin + H(0.2), sci)
        if not rerun and self.rng.random() < 0.10:
            # The data reviewer asks for a re-run (lab profile: unclear calls are re-run).
            self.at(self.workday(t, 13, plus=self.rng.randint(2, 4)), self.bli_run, exp, qd, gator, 0, True)

    def target_plate_prep(self, exp, tp, rid, t, sci):
        """Target thawed from -80 aliquots and pipetted by hand into 8 wells, 4 µL each."""
        stock = sorted(self.target_stock(exp.target))
        wells = ["%s/%s1" % (tp, ROWS[r]) for r in range(8)]
        def neigh(a):
            return [x for x in self.aliquots[exp.target] if not self.C[x].exited and self.C[x].parent == self.C[a].parent and x != a]
        i = 0
        for acc, a, lot in stock:
            if i >= len(wells):
                break
            if acc < 4 and stock[-1][0] >= 4 and a != stock[-1][1]:
                continue
            rec_as, rec_lot, e = a, lot, None
            nb = neigh(a)
            if nb and self.chance("wrong_scan"):
                rec_as = self.rng.choice(nb)
                rec_lot = self.main_lot(rec_as) or lot
                e = self.err("wrong_scan", "picked %s but scanned its neighbour %s" % (self.label(a), self.label(rec_as)),
                             sci, [a, rec_as], [lot, rec_lot], run=rid, source="person")
            box, slot = self.C[a].home
            self.r_scan(rec_as, t, sci, seen_in=box)
            self.move(a, self.P["Bench B1"], None, t + H(0.01), sci, record_as=rec_as)
            vol, te = self.typed(4.0, sci, "volume per well from " + self.label(rec_as), [rec_as], [rec_lot])
            later = t + H(self.rng.uniform(24, 240))
            fix = e is not None and self.noticed(e, "wrong_scan") and self.fixed(e, later)
            while i < len(wells) and self.w.accessible(a, lot) >= 1.0:
                at = t + H(0.02 * (i + 1))
                self.w.transfer(a, wells[i], lot, 4.0, at=at)
                if self.chance("step_unrecorded"):
                    self.err("step_unrecorded", "transfer from %s into %s not recorded" % (self.label(a), wells[i]),
                             sci, [a], [lot], run=rid, source="person")
                    i += 1
                    continue
                call = ("transfer(%s, %s, sim.l(%s), %s, 'volume', %s, %s, 'manual', sim.r(%s), p_recorded => %s)"
                        % (self.ref(rec_as), self.ref(wells[i]), q(rec_lot), n(vol), ts(at), q(sci), q(rid), ts(at)))
                if fix:
                    x = "X%d" % next(self._x)
                    self.emit("select sim.sete(%s, %s);" % (q(x), call), at, e["id"])
                    self.emit("select transfer(%s, %s, sim.l(%s), %s, 'volume', %s, %s, p_event => void(sim.e(%s), %s, %s, %s));"
                              % (self.ref(a), self.ref(wells[i]), q(lot), n(vol), ts(at), q(sci), q(x), q(sci),
                                 q("scanned the neighbouring tube"), ts(later)), later, e["id"])
                else:
                    self.emit("select %s;" % call, at, (e or te or {}).get("id"))
                i += 1
            back = t + H(0.3)
            if self.w.accessible(a, lot) < 4.0:
                self.discard(a, back, sci, neighbours=neigh(a))
            else:
                self.move(a, box, slot, back, sci, record_as=rec_as)
            t = back + H(0.02)
        rb = self.ensure_buffer("buffer:bli-running", 40000.0)
        if rb and not self.C[rb].exited and self.main_lot(rb):
            lot = self.main_lot(rb)
            self.w.take(rb, lot, 40000.0, device="hand:2")
            self.r_consume(rb, lot, 40000.0, t, sci, note="BLI running buffer", run=rid)
        s = self.pick("sensors", 32)
        if s:
            lot = self.main_lot(s)
            self.w.take(s, lot, 32.0, device="exact")
            self.r_consume(s, lot, 32.0, t, sci, note="BLI sensors", run=rid)

    # ------------------------------------------------------------------ lab operations
    def order_reagent(self, what):
        if self.pending.get(what, 0) > 0:
            return
        self.pending[what] = 1
        lead = self.rng.randint(2, 3) if what in ("water", "hepes", "nacl") else self.rng.randint(5, 7)
        if self.chance("supplier_late"):
            lead += self.rng.randint(2, 4)
        self.at(self.workday(self.now, 10, plus=lead), self.deliver_reagent, what)

    def check_targets(self):
        for mat, prod, _, _ in self.targets:
            have = sum(x[0] for x in self.target_stock(mat))
            if have + 160 * self.pending.get(mat, 0) < 300:
                self.order_target(mat, prod)

    def ops_orders(self):
        def stock(pool):
            return sum(self.acc(c) for c in self.pools[pool] if not self.C[c].exited)
        for what, low in (("water", 1200000), ("hepes", 30000), ("nacl", 40000), ("pure", 8000), ("sensors", 300)):
            if stock(what) < low:
                self.order_reagent(what)
        self.check_targets()

    def ops_monday(self):
        t = self.now
        by = self.rng.choice(OPS)
        for exp in self.exps:
            ep = exp.ep
            if ep and not self.C[ep].exited and t - exp.made >= D(14):     # expression plates last two weeks
                nb = [e.ep for e in self.exps if e.ep and not self.C[e.ep].exited and e.ep != ep and self.C[e.ep].parent == self.C[ep].parent]
                self.discard(ep, t, by, neighbours=nb)
        for pool, cids in self.pools.items():
            for c in cids:
                if not self.C[c].exited and self.acc(c) < (1.0 if pool == "sensors" else 50.0):
                    self.discard(c, t + H(0.1), by)
        self.at(t + H(0.5), self.make_buffer, "buffer:loading")
        rb = self.buf["buffer:bli-running"]
        if rb is None or self.C[rb].exited or self.acc(rb) < 170000 or t - self.C[rb].created > D(20):
            self.at(t + H(0.7), self.make_buffer, "buffer:bli-running")
        gs = self.buf["buffer:gfp-stock"]
        if gs is None or self.C[gs].exited or self.acc(gs) < 12000:
            self.at(t + H(0.9), self.make_buffer, "buffer:gfp-stock")
        self.ops_orders()

    def ops_thursday(self):
        rb = self.buf["buffer:bli-running"]
        if rb is None or self.C[rb].exited or self.acc(rb) < 90000:
            self.make_buffer("buffer:bli-running")
        self.ops_orders()

    def count_place(self):
        """Friday cycle count of one place. Location only (decision D4)."""
        t = self.now
        by = "p:tom"
        order = ["Freezer F80-1", "Fridge R1", "Freezer F80-2", "Freezer F20-1", "Freezer F80-3"]
        X = self.P[order[self.count_week % len(order)]]
        self.count_week += 1
        items = [c for c in self.C.values()
                 if c.plate is None and c.exited is None and c.cat in ("tube", "plate", "holder") and c.parent and self.w.top(c).id == X]
        items.sort(key=lambda c: 0 if c.cat == "holder" else 1)
        for c in items:
            if c.id in self.bexit or self.belief.get(c.id) != c.parent:
                # Found where the record doesn't expect it: scan it and record where it really is.
                self.r_scan(c.id, t - H(0.1), by, seen_in=c.parent)
                self.emit("select move(%s, sim.c(%s), %s, %s, %s, 'scan', p_recorded => %s);"
                          % (self.ref(c.id), q(c.parent), q(c.pos), ts(t - H(0.1)), q(by), ts(t - H(0.1))), t - H(0.1))
                self.belief[c.id] = c.parent
        found = []
        for c in items:
            if c.cat == "holder":
                continue
            if self.chance("count_missed"):
                self.err("count_missed", "%s is in %s but the count marked it not found" % (self.label(c.id), self.label(X)), by, [c.id], source="count")
                continue
            found.append(c.id)
        arr = "array[%s]::text[]" % ", ".join(q(x) for x in found)
        self.emit(("select count_place(coalesce((select jsonb_agg(jsonb_build_object('container', l.container_id, 'found', m.sim_id = any(%s))) "
                   "from location(%s, %s) l join sim.cmap m on m.db_id = l.container_id join container c on c.id = l.container_id "
                   "join container_type ct on ct.id = c.type_id where l.top_place_id = %s "
                   "and l.status not in ('discarded', 'shipped', 'fixed place', 'not placed') "
                   "and ct.category in ('tube', 'plate')), '[]'::jsonb), %s, %s, %s, p_recorded => %s);")
                  % (arr, ts(t), ts(t), self.ref(X), ts(t), q(by), q("weekly count of " + self.label(X)), ts(t)), t)

    def freezer_failure(self, name):
        t = self.now
        by = "p:sara"
        F, to = self.P[name], self.P["Freezer F80-3"]
        boxes = [c.id for c in self.C.values() if c.plate is None and c.exited is None and c.cat == "holder" and c.parent == F]
        self.err("freezer_failure", "%s failed at night; %d boxes moved to %s in a hurry" % (name, len(boxes), self.label(to)), by,
                 [], source="world", real=True)
        for b in boxes:
            self.w.move(b, to, None, at=t)
            if self.rng.random() < self.p["rescue_move_unscanned"]:
                inside = [c.id for c in self.C.values() if c.parent == b and c.exited is None]
                self.err("move_unscanned", "box %s moved to %s during the freezer rescue without a scan" % (self.label(b), self.label(to)),
                         by, [b] + inside, source="person")
                continue
            self.emit("select move(%s, %s, null, %s, %s, 'scan', p_recorded => %s);" % (self.ref(b), self.ref(to), ts(t), q(by), ts(t)), t)
            self.belief[b] = to

    def snapshot(self, label):
        self.snapshots.append(self.w.snapshot(label))

    # ------------------------------------------------------------------ schedule and output
    def plan(self):
        self.setup()
        weeks = self.days / 7
        size = min(384, max(8, self.designs_per_week))
        n_exp = max(1, round(self.designs_per_week * weeks / size))
        window = max(1.0, self.days - 5)
        did = itertools.count(1)
        for i in range(n_exp):
            target = self.rng.choice(self.targets)[0]
            exp = Exp(i + 1, target, ["D%05d" % next(did) for _ in range(size)], self.rng.choice(SCIENTISTS))
            self.exps.append(exp)
            arrive = self.workday(START + D(i * window / n_exp) + D(self.rng.uniform(0, 0.5)), 10, plus=0)
            if self.rng.random() < self.p["supplier_late"]:
                arrive = self.workday(arrive, 10, plus=self.rng.randint(1, 2))
            self.at(arrive, self.dna_arrival, exp)
        for d in range(self.days):
            day = START + D(d)
            if day.weekday() == 0:
                self.at(day + H(8), self.ops_monday)
            if day.weekday() == 3:
                self.at(day + H(8.25), self.ops_thursday)
            if day.weekday() == 4:
                self.at(day + H(15), self.count_place)
        for name in ("Freezer F80-1", "Freezer F80-2"):
            if self.rng.random() < self.p["freezer_failure_per_year"] * self.days / 365:
                self.at(START + D(self.rng.randint(1, max(1, self.days - 2))) + H(2), self.freezer_failure, name)
        step = 2 if self.days <= 14 else 7
        k = step
        while k < self.days:
            self.at(START + D(k) - H(1), self.snapshot, "day %d" % k)
            k += step
        self.at(self.end - H(1), self.snapshot, "end")

    def run(self):
        self.plan()
        while self.heap:
            t, _, fn, args = heapq.heappop(self.heap)
            if t > self.end:
                break
            self.w.set_clock(t)
            fn(*args)

    def preamble(self):
        out = ["-- Notebook B, written by sim/simulate.py. Load after schema/*.sql and seed/01_reference_data.sql.",
               "-- preset=%s seed=%d days=%d designs_per_week=%d targets=%d" % (self.preset, self.seed, self.days, self.designs_per_week, len(self.targets)),
               "-- The sim schema only maps the simulation's names (C12, L40) to database ids; the inventory never reads it.",
               "begin;",
               "create schema sim;"]
        for t in ("cmap", "lmap", "rmap", "emap"):
            out.append("create table sim.%s (sim_id text primary key, db_id bigint not null unique);" % t)
            out.append("create function sim.set%s(s text, i bigint) returns bigint language sql as $$ insert into sim.%s values (s, i) returning db_id $$;" % (t[0], t))
            out.append("create function sim.%s(s text) returns bigint language sql stable strict as $$ select db_id from sim.%s where sim_id = s $$;" % (t[0], t))
        out += ["create table sim.refused (error_id text, message text);",
                "create function sim.setcs(s text[], i bigint[]) returns void language sql as $$ insert into sim.cmap select * from unnest(s, i) $$;",
                "create function sim.try(p_err text, p_stmt text) returns void language plpgsql as $$\n"
                "begin execute p_stmt; exception when others then insert into sim.refused values (p_err, sqlerrm); end $$;",
                "insert into actor values ('p:tom', 'person', 'Tom (lab operations)'), ('p:ana', 'person', 'Ana (production scientist)'),"
                " ('p:yuki', 'person', 'Yuki (production scientist)'), ('p:ben', 'person', 'Ben (production scientist)'),"
                " ('robot:hamilton-2', 'robot', 'Hamilton liquid handler 2'), ('instrument:gator-2', 'instrument', 'Gator BLI 2'),"
                " ('instrument:reader-1', 'instrument', 'Plate reader'), ('system:labos', 'system', 'LabOS imports')"
                " on conflict do nothing;"]
        for mat, prod, name, prot in self.targets:
            if prot:
                out.append("insert into material values (%s, 'target', %s, %s) on conflict do nothing;" % (q(mat), q(name), q(json.dumps({"protein": prot, "tag": "His"}))))
            vendor, cat = prod.split(":")
            out.append("insert into product values (%s, %s, %s, %s) on conflict do nothing;" % (q(prod), q(mat), q("Vendor " + vendor[-1]), q(cat)))
        designs = [d for e in self.exps for d in e.designs]
        for k in range(0, len(designs), 500):
            chunk = designs[k:k + 500]
            out.append("insert into material values %s;" % ", ".join(
                "('dna:%s', 'dna', 'DNA for design %s', '{\"design_id\": \"%s\"}'), ('sample:%s', 'sample_protein', 'Protein of design %s', '{\"design_id\": \"%s\"}')"
                % (d, d, d, d, d, d) for d in chunk))
            out.append("insert into product values %s;" % ", ".join("('twist:%s', 'dna:%s', 'Twist', 'GENE-%s')" % (d, d, d) for d in chunk))
        return out

    def write(self, outdir):
        os.makedirs(outdir, exist_ok=True)
        lines = sorted(self.lines, key=lambda x: (x[0], x[1]))
        with open(os.path.join(outdir, "recorded.sql"), "w") as f:
            f.write("\n".join(self.preamble()) + "\n")
            for _, _, sql in lines:
                f.write(sql + "\n")
            f.write("commit;\n")
        with open(os.path.join(outdir, "truth.json"), "w") as f:
            json.dump({"preset": self.preset, "seed": self.seed, "start": iso(START), "end": iso(self.end), "days": self.days,
                       "designs_per_week": self.designs_per_week, "targets": [t[0] for t in self.targets],
                       "experiments": len(self.exps), "checkpoints": self.snapshots}, f)
        with open(os.path.join(outdir, "errors.jsonl"), "w") as f:
            for e in self.errors:
                f.write(json.dumps(e) + "\n")
        return len(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", choices=sorted(PRESETS), default="normal")
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--designs-per-week", type=int, default=48)
    ap.add_argument("--targets", type=int, default=2)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    lab = Lab(a.preset, a.days, a.designs_per_week, a.targets, a.seed)
    lab.run()
    outdir = a.out or os.path.join(HERE, "out", a.preset)
    count = lab.write(outdir)
    by_type = {}
    for e in lab.errors:
        by_type[e["type"]] = by_type.get(e["type"], 0) + 1
    print("%s: %d experiments, %d recorded calls, %d injected events -> %s" % (a.preset, len(lab.exps), count, len(lab.errors), outdir))
    for k in sorted(by_type):
        print("  %-22s %d" % (k, by_type[k]))


if __name__ == "__main__":
    main()
