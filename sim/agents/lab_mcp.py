#!/usr/bin/env python3
"""The lab's tools, as an MCP server over stdio, one process per person.

It holds no state. Every call is sent to the shared lab that run.py serves on
localhost (LAB_URL), tagged with who is calling (LAB_AGENT), so all the people
in a run work in the same lab and on the same clock rules. Standard library only.
"""
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_stdio import serve, tool  # noqa: E402

URL = os.environ.get("LAB_URL", "http://127.0.0.1:8765")
AGENT = os.environ.get("LAB_AGENT", "nobody")

S, N, B = "string", "number", "boolean"
WHEN = ("happened_at", (S, "Only if it happened earlier: the time it happened, like 09:40. Leave out if it is happening now."))
TYPED = ("typed", (B, "true if you type the barcode by hand because the scanner won't read it."))

TOOLS = [
    # hands: these change the real lab
    ("look", "Hands. Look inside a place, box or rack and see what is physically there. Places: Freezer F80-1, "
             "Freezer F80-2, Freezer F80-3, Freezer F20-1, Fridge R1, Bench B1, Bench B2, Shelf S1, Goods-in shelf; "
             "or a box barcode. Opening a freezer and reading labels takes a few minutes.",
     [("place", (S, "place name or box barcode"))], ["place"]),
    ("pick_up", "Hands. Take a tube, plate, bottle or box from wherever it really is and put it on your bench. "
                "Finding something in a freezer you haven't just looked into takes a while.",
     [("barcode", (S, "barcode on the label"))], ["barcode"]),
    ("put", "Hands. Put something into a place or box (optionally a slot, like 'slot 3').",
     [("barcode", (S, "what you put away")), ("place", (S, "place name or box barcode")), ("slot", (S, "slot, optional"))],
     ["barcode", "place"]),
    ("pipette", "Hands. Pipette liquid from a tube or bottle into another container or a well (PLATE:A1). Both must be "
                "out of the freezer or fridge.",
     [("source", (S, "barcode")), ("destination", (S, "barcode, or PLATE:A1 for a well")), ("microlitres", (N, "volume in µL"))],
     ["source", "destination", "microlitres"]),
    ("use", "Hands. Use something up: µL of a liquid, or pieces such as BLI sensors.",
     [("barcode", (S, "barcode")), ("amount", (N, "µL, or pieces for sensors"))], ["barcode", "amount"]),
    ("split", "Hands. Split a tube into new labelled tubes (aliquots) in a box. The label printer prints the new barcodes.",
     [("barcode", (S, "the tube to split")), ("tubes", (N, "how many new tubes")), ("microlitres_each", (N, "µL per tube")),
      ("into_box", (S, "barcode of an empty box"))], ["barcode", "tubes", "microlitres_each", "into_box"]),
    ("get_new", "Hands. Take a new empty container and stick a freshly printed label on it. Types: box_9x9, plate_bli, "
                "bottle, tube_matrix, tube_1_5ml, plate_96, plate_384.",
     [("container_type", (S, "type")), ("place", (S, "where to put it, default your bench"))], ["container_type"]),
    ("bin", "Hands. Throw a container in the bin.", [("barcode", (S, "barcode"))], ["barcode"]),
    ("inspect", "Hands. Look closely at one container: what the label says, roughly how full it is, where it is.",
     [("barcode", (S, "barcode or PLATE:A1"))], ["barcode"]),
    ("qc_check", "Hands. Run the target protein QC (SDS-PAGE and A280) on a vial. Takes a 5 µL sample and about an hour.",
     [("barcode", (S, "vial barcode"))], ["barcode"]),
    ("make_buffer", "Hands. Make a buffer by recipe into a bottle on your bench. Recipes: buffer:loading (48.5 mL water, "
                    "0.5 mL HEPES, 1 mL NaCl), buffer:bli-running (384 mL water, 4 mL HEPES, 12 mL NaCl), buffer:gfp-stock "
                    "(30 mL water). Name the component bottles you take from (they must be on your bench).",
     [("recipe", (S, "recipe name")), ("sources", (S, "comma-separated barcodes of the component bottles")),
      ("bottle", (S, "barcode of the empty bottle"))], ["recipe", "sources", "bottle"]),
    # pen and scanner: these write to the inventory, whatever you tell them
    ("scan", "Scanner. Scan a barcode to confirm you've seen it, optionally where.",
     [("barcode", (S, "barcode")), ("seen_in", (S, "place or box it is in, optional")), TYPED], ["barcode"]),
    ("record_move", "Inventory. Record that a container moved to a place or box.",
     [("barcode", (S, "what moved")), ("to_place", (S, "place name or box barcode")), ("slot", (S, "slot, optional")), WHEN, TYPED],
     ["barcode", "to_place"]),
    ("record_use", "Inventory. Record that you used some of what's in a container (µL, or pieces).",
     [("barcode", (S, "barcode")), ("amount", (N, "amount used")), ("note", (S, "what for, optional")), WHEN, TYPED],
     ["barcode", "amount"]),
    ("record_transfer", "Inventory. Record liquid pipetted from one container into another (or into a well, PLATE:A1).",
     [("source", (S, "barcode")), ("destination", (S, "barcode or PLATE:A1")), ("microlitres", (N, "µL")), WHEN, TYPED],
     ["source", "destination", "microlitres"]),
    ("record_split", "Inventory. Record a split into new tubes; the new tubes get the barcodes PREFIX001, PREFIX002, ...",
     [("barcode", (S, "the tube split")), ("tubes", (N, "how many")), ("microlitres_each", (N, "µL each")),
      ("into_box", (S, "box barcode")), ("barcode_prefix", (S, "the printed prefix, like ALQ-00051-")), WHEN, TYPED],
     ["barcode", "tubes", "microlitres_each", "into_box", "barcode_prefix"]),
    ("record_disposal", "Inventory. Record that a container was thrown away.",
     [("barcode", (S, "barcode")), ("note", (S, "optional")), WHEN, TYPED], ["barcode"]),
    ("record_new_container", "Inventory. Register a new labelled container (box, plate, bottle, tube) and where it is.",
     [("barcode", (S, "barcode")), ("container_type", (S, "box_9x9, plate_bli, bottle, tube_matrix, tube_1_5ml, ...")),
      ("place", (S, "place name or box barcode")), ("slot", (S, "optional")), WHEN, TYPED],
     ["barcode", "container_type", "place"]),
    ("record_receive", "Inventory. Book in a delivery: registers the vial if it's new and records what arrived as a new lot.",
     [("barcode", (S, "vial barcode")), ("product", (S, "catalog number from the packing slip, like EGFR-100")),
      ("amount", (N, "amount, in µL for liquids")), ("supplier_lot", (S, "supplier lot from the slip")),
      ("delivery_note", (S, "delivery note number")), ("place", (S, "where it is now")), ("slot", (S, "optional")), WHEN, TYPED],
     ["barcode", "product", "amount", "supplier_lot", "delivery_note", "place"]),
    ("record_qc", "Inventory. Record a QC result (pass or fail) for the lot in a container.",
     [("barcode", (S, "vial barcode")), ("outcome", (S, "pass or fail")), ("assay", (S, "optional")), WHEN, TYPED],
     ["barcode", "outcome"]),
    ("record_make", "Inventory. Record a buffer you made: recipe, the bottle, how much, and what went in.",
     [("recipe", (S, "recipe name, like buffer:loading")), ("bottle", (S, "barcode of the new bottle")),
      ("microlitres_made", (N, "µL made")), ("inputs", (S, "BARCODE=µL pairs, comma-separated, like WAT-00017=48500, HEP-00019=500")),
      WHEN, TYPED], ["recipe", "bottle", "microlitres_made", "inputs"]),
    ("correct", "Inventory. Mark an earlier record (by its event number) as wrong, with a reason. Then record the right version.",
     [("event_id", (N, "event number from the earlier record")), ("why", (S, "reason"))], ["event_id", "why"]),
    ("ask_inventory", "Inventory. Ask the inventory a question. question is one of: how_much (settings: material=target:%), "
                      "shared_target_left (protein=EGFR or protein=PD-L1), expiring (days=7), where_is_it (barcodes=A,B), "
                      "not_seen_lately (days=7), forward_trace (supplier_lot=...), backward_trace (barcode=..., well=A1), "
                      "history (barcode=...), flags, waste (from=2026-09-01), whats_in (place=BOX-00010). Settings look like "
                      "name=value; name=value.",
     [("question", (S, "question name")), ("settings", (S, "name=value; name=value, optional"))], ["question"]),
    ("record_count", "Inventory. Record a count of one place: list every barcode you actually found there. Anything the "
                     "inventory expected there that you don't list is marked not found.",
     [("place", (S, "place name")), ("found", (S, "comma-separated barcodes you found"))], ["place", "found"]),
    ("place_order", "Order target vials or reagents from the supplier by catalog number.",
     [("catalog_number", (S, "like EGFR-100")), ("vials", (N, "how many"))], ["catalog_number", "vials"]),
    # the day
    ("my_tasks", "Your task list for today with deadlines and what's done.", [], []),
    ("done", "Tick a task off your list.", [("task_id", (S, "like T2")), ("note", (S, "optional"))], ["task_id"]),
    ("wait", "Spend some minutes on routine work that isn't on your list while you wait for something (a delivery, a run). "
             "Up to 120 minutes.", [("minutes", (N, "how long")), ("doing", (S, "what you do meanwhile, optional"))], ["minutes"]),
    ("tell", "Say something to a colleague (Lena, Marco, the data reviewer, the lab manager).",
     [("to", (S, "who")), ("message", (S, "what you say"))], ["to", "message"]),
]


def forward(name, args):
    body = json.dumps({"agent": AGENT, "tool": name, "args": args}).encode()
    req = urllib.request.Request(URL + "/call", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read())["text"]


for name, desc, params, required in TOOLS:
    tool(name, desc, dict(params), required)(lambda _n=name, **kw: forward(_n, kw))

if __name__ == "__main__":
    serve("lab")
