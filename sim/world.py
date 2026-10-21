"""Notebook A: what is really in the lab.

The world knows every container, what is truly in it (per lot), where it
truly is, and when it was thrown away. It knows nothing about the inventory
database or about recording mistakes. Two kinds of lab drive it:

  * the dice simulation (simulate.py), which also writes notebook B with
    mistakes rolled at researched rates;
  * the AI-agent lab (agents/), whose people act through tools.

Physics lives here too, because it is part of what really happens: a pipette
or a robot moves a little more or less than asked, an open plate loses water,
liquid at the bottom of a tube can't be drawn up (dead volume).

Times are timezone-aware datetimes. Every action happens at the world clock
unless `at=` says otherwise (the dice lab schedules a task's steps ahead of
time). Amounts are in µL for volumes, µg for masses and pieces for counts.

Standard library only.
"""
import calendar
import itertools
import random
from datetime import timedelta

ROWS = "ABCDEFGHIJKLMNOP"

# Container types, matching seed/01_reference_data.sql.
CT = {
    "well_96": {"cat": "well", "dead": 2}, "well_384": {"cat": "well", "dead": 2},
    "well_bli": {"cat": "well", "dead": 0}, "well_gfp": {"cat": "well", "dead": 0},
    "plate_96": {"cat": "plate", "grid": (8, 12), "well": "well_96"},
    "plate_384": {"cat": "plate", "grid": (16, 24), "well": "well_384"},
    "plate_bli": {"cat": "plate", "grid": (8, 12), "well": "well_bli", "single": True},
    "plate_gfp": {"cat": "plate", "grid": (16, 24), "well": "well_gfp", "single": True},
    "tube_1_5ml": {"cat": "tube", "dead": 5}, "tube_matrix": {"cat": "tube", "dead": 10},
    "bottle": {"cat": "tube", "dead": 1000},
    "box_9x9": {"cat": "holder"}, "rack": {"cat": "holder"},
    "freezer": {"cat": "place"}, "fridge": {"cat": "place"}, "bench": {"cat": "place"},
    "instrument": {"cat": "instrument"},
}
KIND_DIM = {"target": "volume", "dna": "mass", "sample_protein": "volume", "buffer": "volume",
            "reagent": "volume", "consumable": "count"}
NEEDS_QC = {"target"}

DEFAULT_PHYSICS = {
    "manual_cv_pct": 0.8,         # noise-model manual_10ul
    "robot_cv_pct": 3.0,          # noise-model default_robot_cv_pct
    "robot_bias_pct": [-5, 5],    # noise-model default_robot_bias_pct, drawn per robot per week
    "evap_ul_per_h": 0.3,         # noise-model lidded_384_bench
}


def add_months(t, m):
    y, mo = divmod(t.month - 1 + m, 12)
    y += t.year
    mo += 1
    return t.replace(year=y, month=mo, day=min(t.day, calendar.monthrange(y, mo)[1]))


# Shelf-life rules, the same as the seed's.
def since_origin(lot):
    t0 = lot.created
    if lot.material == "buffer:loading":
        return t0 + timedelta(days=7)
    if lot.material == "buffer:gfp-stock":
        return add_months(t0, 6)
    return {"target": add_months(t0, 36), "dna": add_months(t0, 60),
            "sample_protein": t0 + timedelta(days=14), "buffer": add_months(t0, 1),
            "reagent": add_months(t0, 24)}.get(lot.kind)


def budget(lot, cond, start):
    """Time allowed in a storage condition (decision D9: a budget, paused while elsewhere).
    Returns the end of the budget if it were all spent from `start` on, or None."""
    if lot.material == "buffer:gfp-stock" and cond == "fridge":
        return add_months(start, 1) - start
    if lot.kind == "target" and cond == "fridge":
        return timedelta(days=7)
    if lot.kind == "target" and cond == "room":
        return timedelta(hours=8)
    return None


class Ctr:
    __slots__ = ("id", "type", "cat", "barcode", "name", "cond", "parent", "pos", "hist",
                 "contents", "arrived", "wells", "plate", "exited", "created", "home")

    def __init__(self, cid, ctype, t, barcode=None, name=None, cond=None, plate=None, pos=None):
        self.id, self.type, self.cat = cid, ctype, CT[ctype]["cat"]
        self.barcode, self.name, self.cond = barcode, name, cond
        self.parent, self.pos, self.hist = None, pos, []
        self.contents, self.arrived = {}, {}
        self.wells, self.plate, self.exited, self.created, self.home = None, plate, None, t, None


class Lot:
    __slots__ = ("id", "material", "kind", "dim", "origin", "created", "product", "code", "qc", "parents")

    def __init__(self, lid, material, kind, origin, t, product=None, code=None):
        self.id, self.material, self.kind, self.dim = lid, material, kind, KIND_DIM[kind]
        self.origin, self.created, self.product, self.code = origin, t, product, code
        self.qc, self.parents = None, []


class World:
    def __init__(self, params=None, start=None, seed=0):
        self.params = dict(DEFAULT_PHYSICS, **(params or {}))
        self.rng = random.Random(seed)
        self.now = start
        self.c, self.lots = {}, {}
        self._c, self._l = itertools.count(1), itertools.count(1)
        self._bias = {}

    # ---------------------------------------------------------------- clock
    @property
    def clock(self):
        return self.now

    def advance(self, minutes):
        self.now += timedelta(minutes=minutes)
        return self.now

    def set_clock(self, t):
        if self.now is None or t >= self.now:
            self.now = t
        return self.now

    def _t(self, at):
        return at if at is not None else self.now

    # ---------------------------------------------------------------- lookups
    def get(self, cid):
        return self.c[cid]

    def find(self, barcode):
        """The live container wearing this barcode, or None."""
        for c in self.c.values():
            if c.barcode == barcode and c.exited is None:
                return c.id
        return None

    def read_label(self, cid):
        return self.c[cid].barcode

    def contents(self, cid):
        c = self.c[cid]
        return {l: a for l, a in c.contents.items() if abs(a) > 1e-9}

    def vessel(self, c):
        return self.c[c.plate] if c.plate else c

    def top(self, c):
        node = self.vessel(c)
        while node.parent:
            node = self.c[node.parent]
        return node

    def look(self, place):
        """What is physically sitting directly in a place, box or instrument."""
        return [{"id": c.id, "barcode": c.barcode, "type": c.type, "slot": c.pos}
                for c in self.c.values() if c.parent == place and c.exited is None and c.plate is None]

    # ---------------------------------------------------------------- physical actions
    def register(self, ctype, barcode=None, place=None, slot=None, name=None, condition=None, at=None):
        """A new container comes into the lab (a tube, a plate, a freezer). Returns its id.
        A plate's wells are '<id>/<position>', for example 'C12/A1'."""
        t = self._t(at)
        cid = "C%d" % next(self._c)
        c = Ctr(cid, ctype, t, barcode, name, condition)
        self.c[cid] = c
        grid = CT[ctype].get("grid")
        if grid:
            c.wells = {}
            for r in range(grid[0]):
                for k in range(grid[1]):
                    pos = "%s%d" % (ROWS[r], k + 1)
                    w = Ctr("%s/%s" % (cid, pos), CT[ctype]["well"], t, plate=cid, pos=pos)
                    c.wells[pos] = w
                    self.c[w.id] = w
        if place:
            self.move(cid, place, slot, at=t)
        return cid

    def move(self, cid, place, slot=None, at=None):
        c = self.c[cid]
        c.parent = place
        c.pos = slot
        c.hist.append((self._t(at), place, slot))

    def receive(self, cid, material, kind, amount, product=None, supplier_lot=None, at=None):
        """Material arrives from outside: a new lot appears in the container. Returns the lot id."""
        t = self._t(at)
        lot = Lot("L%d" % next(self._l), material, kind, "received", t, product, supplier_lot)
        self.lots[lot.id] = lot
        self._add(self.c[cid], lot, amount, t)
        return lot.id

    def _add(self, c, lot, amount, t):
        c.contents[lot.id] = c.contents.get(lot.id, 0.0) + amount
        c.arrived.setdefault(lot.id, t)

    def _actual(self, amount, device):
        """What a hand or a robot really moves when asked for `amount`."""
        if device == "exact":
            return amount
        if device.startswith("robot"):
            key = (device, (self.now.toordinal() // 7) if self.now else 0)
            if key not in self._bias:
                lo, hi = self.params["robot_bias_pct"]
                self._bias[key] = self.rng.uniform(lo, hi) / 100
            return max(0.0, amount * (1 + self._bias[key] + self.rng.gauss(0, self.params["robot_cv_pct"] / 100)))
        cv = self.params["manual_cv_pct"] if device == "hand" else float(device.split(":")[1])
        return max(0.0, amount * (1 + self.rng.gauss(0, cv / 100)))

    def accessible(self, cid, lot_id):
        """How much of a lot can still be drawn from a container (dead volume stays behind)."""
        c = self.c[cid]
        lot = self.lots[lot_id]
        a = c.contents.get(lot_id, 0.0)
        if a <= 0:
            return 0.0
        if lot.dim != "volume":
            return a
        dead = CT[c.type].get("dead", 0)
        total = self._volume_total(c)
        return max(0.0, a - dead * a / total) if total > dead else 0.0

    def _volume_total(self, c):
        return sum(a for l, a in c.contents.items() if self.lots[l].dim == "volume" and a > 0)

    def take(self, cid, lot_id, amount, device="hand"):
        """Draw liquid (or pieces) out and use it up. Returns what really came out."""
        got = min(self._actual(amount, device), self.accessible(cid, lot_id))
        c = self.c[cid]
        c.contents[lot_id] = c.contents.get(lot_id, 0.0) - got
        return got

    def transfer(self, src, dst, lot_id, amount, device="hand", at=None):
        """Pipette from one container into another. Returns what really moved."""
        got = self.take(src, lot_id, amount, device)
        self._add(self.c[dst], self.lots[lot_id], got, self._t(at))
        return got

    def split(self, src, lot_id, n, each, tube_type, place=None, barcode_prefix=None, at=None):
        """Fill n new tubes with `each` from src. They go to slots 1..n of `place`. Returns the new ids."""
        t = self._t(at)
        ids = []
        for i in range(n):
            bc = "%s%03d" % (barcode_prefix, i + 1) if barcode_prefix else None
            k = self.register(tube_type, bc, place, "slot %d" % (i + 1) if place else None, at=t)
            self.c[k].home = (place, "slot %d" % (i + 1)) if place else None
            self.transfer(src, k, lot_id, each, at=t)
            ids.append(k)
        return ids

    def make(self, material, kind, inputs, out_container, amount=None, at=None, keep=False):
        """Make something new. `inputs` is [(container, lot, amount, device)]. The new lot holds
        what really went in (or `amount` if given). With keep=False the inputs in the output
        container are used up (DNA and mix in a well become protein). Returns the new lot id."""
        t = self._t(at)
        lot = Lot("L%d" % next(self._l), material, kind, "made", t)
        self.lots[lot.id] = lot
        total = 0.0
        for cid, lid, amt, device in inputs:
            lot.parents.append(lid)
            total += self.take(cid, lid, amt, device)
        out = self.c[out_container]
        if not keep:
            for lid in list(out.contents):
                out.contents.pop(lid)
        self._add(out, lot, total if amount is None else amount, t)
        return lot.id

    def reconstitute(self, cid, lot_id, volume, solvent, solvent_lot, device="hand", at=None):
        """Dissolve dry material: the lot changes from µg to µL in the same container."""
        got = self.take(solvent, solvent_lot, volume, device)
        lot = self.lots[lot_id]
        mass = self.c[cid].contents.get(lot_id, 0.0)
        lot.dim = "volume"
        self.c[cid].contents[lot_id] = got
        return mass / got if got else None

    def set_qc(self, lot_id, outcome):
        """The true quality of a lot, as a QC assay finds it."""
        self.lots[lot_id].qc = outcome

    def evaporate(self, plate, hours, rate=None):
        """An open plate on a deck loses water. Edges lose twice as much, corners four times."""
        rate = self.params["evap_ul_per_h"] if rate is None else rate
        p = self.c[plate]
        rows, cols = CT[p.type]["grid"]
        for pos, w in p.wells.items():
            r, k = ROWS.index(pos[0]), int(pos[1:]) - 1
            er, ec = r in (0, rows - 1), k in (0, cols - 1)
            mult = 4 if (er and ec) else 2 if (er or ec) else 1
            for l in list(w.contents):
                if self.lots[l].dim == "volume" and w.contents[l] > 0:
                    w.contents[l] = max(0.0, w.contents[l] - rate * hours * mult)

    def discard(self, cid, at=None):
        self.c[cid].exited = self._t(at)

    # ---------------------------------------------------------------- storage and expiry
    def _cond_inside(self, pid):
        node = self.c[pid] if pid else None
        while node is not None:
            if node.cond:
                return node.cond
            node = self.c[node.parent] if node.parent else None
        return None

    def condition_history(self, cid, until=None):
        """[(from, to, condition)] for the container (a well follows its plate).
        Parents are taken where they are now; boxes rarely move between conditions."""
        v = self.vessel(self.c[cid])
        out = []
        for t, pid, _ in v.hist:
            cond = self._cond_inside(pid)
            if out and out[-1][2] == cond:
                continue
            if out:
                out[-1][1] = t
            out.append([t, None, cond])
        end = until or self.now
        return [(a, b or end, cd) for a, b, cd in out]

    def expires(self, cid, lot_id, t=None):
        t = t or self.now
        lot = self.lots[lot_id]
        c = self.c[cid]
        e = since_origin(lot)
        arrived = c.arrived.get(lot_id)
        used = {}
        hist = self.condition_history(cid, t)
        for i, (a, b, cond) in enumerate(hist):
            if a > t or (arrived and b <= arrived and i < len(hist) - 1):
                continue
            if arrived:
                a = max(a, arrived)
            allow = budget(lot, cond, a) if cond else None
            if allow is None:
                continue
            left = allow - used.get(cond, timedelta(0))
            current = i == len(hist) - 1
            if current or (b - a) >= left:
                end = a + left
                e = end if e is None else min(e, end)
            used[cond] = used.get(cond, timedelta(0)) + (b - a)
        return e

    def usable(self, cid, lot_id, t=None):
        """What the system's usable() would say if every fact were recorded right."""
        t = t or self.now
        c = self.c[cid]
        lot = self.lots[lot_id]
        a = c.contents.get(lot_id, 0.0)
        if a <= 1e-9 or self.vessel(c).exited:
            return 0.0
        if lot.kind in NEEDS_QC and lot.qc != "pass":
            return 0.0
        e = self.expires(cid, lot_id, t)
        if e is not None and e <= t:
            return 0.0
        if lot.dim != "volume":
            return a
        dead = CT[c.type].get("dead", 0)
        total = self._volume_total(c)
        if total <= dead:
            return 0.0
        return max(a - dead * a / total, 0.0)

    # ---------------------------------------------------------------- truth for the scorer
    def snapshot(self, label=None):
        """Everything the scorer needs, as plain JSON. Places and instruments are left out;
        wells only appear while their plate exists and holds something."""
        t = self.now
        out = {}
        for c in self.c.values():
            if c.cat in ("place", "instrument"):
                continue
            if c.plate:
                if self.c[c.plate].exited:
                    continue
                cont = self._contents_json(c, t)
                if cont:
                    out[c.id] = {"contents": cont}
                continue
            rec = {"type": c.type, "barcode": c.barcode, "exists": c.exited is None}
            if c.exited is None:
                rec.update(parent=c.parent, pos=c.pos, place=self.top(c).id, contents=self._contents_json(c, t))
            out[c.id] = rec
        lots = {l.id: {"material": l.material, "kind": l.kind} for l in self.lots.values()}
        return {"label": label, "t": t.strftime("%Y-%m-%dT%H:%M:%SZ"), "containers": out, "lots": lots}

    def _contents_json(self, c, t):
        return {l: [round(a, 4), round(self.usable(c.id, l, t), 4), self.lots[l].dim]
                for l, a in c.contents.items() if abs(a) > 1e-9}
