"""Error rates for the two noise presets.

`normal` takes every rate it can from sim/noise-model.yaml (decision D8). Where
the noise model has no number for something the simulation needs, the value
here is our own assumption and says so.

`bad_week` uses the higher numbers the scenario agents guessed (the sim_hook
lines in scenarios/catalog.yaml, see the noise_ref note in
scenarios/clusters.md). They are the top of a sweep, not a forecast.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def _noise():
    with open(os.path.join(HERE, "params", "noise-model.json")) as f:
        return json.load(f)


def _rate(noise, section, name, field="rate"):
    for item in noise[section]:
        if item["name"] == name:
            return item[field]
    raise KeyError(name)


def normal():
    n = _noise()
    step = _rate(n, "human_errors", "step_not_recorded")
    return {
        # People
        "move_unscanned": _rate(n, "human_errors", "step_not_recorded", "range")[1],  # "moves are the most likely to be skipped"
        "step_unrecorded": step,
        "wrong_scan": _rate(n, "human_errors", "wrong_container_scanned"),
        "wrong_position": _rate(n, "human_errors", "wrong_position_selected"),
        "typo_any": _rate(n, "human_errors", "manual_value_mistyped"),
        "typo_big": _rate(n, "human_errors", "manual_value_badly_wrong"),
        "dup_delivery": _rate(n, "human_errors", "duplicate_delivery_registration"),
        "discard_unscanned": _rate(n, "human_errors", "discard_with_material_unrecorded"),
        "label_duplicate": _rate(n, "human_errors", "label_error"),
        "count_missed": _rate(n, "scanning", "barcode_no_read_2d_rack"),   # a count line wrongly marked "not found"
        # Late writing. Assumption: 5% of hand entries are typed up later the same day.
        "late_manual": 0.05,
        "late_manual_hours": [1, 8],
        # Robots. Assumption: a log line goes missing rarely; a whole log is
        # uploaded late about once in 100 runs (catalog EDGE robot_log_import_fail 0.01).
        "robot_step_missing": 0.0005,
        "robot_log_late": 0.01,
        "robot_log_late_hours": [4, 48],
        "robot_cv_pct": n["liquid_handling"]["default_robot_cv_pct"],
        "robot_bias_pct": n["liquid_handling"]["default_robot_bias_pct"],
        "manual_cv_pct": 0.8,      # manual_10ul in the noise model
        # Supplier. Assumptions; no source found.
        "supplier_duplicate": 0.005,
        "supplier_short_fill": 0.01,
        "supplier_late": 0.10,
        # Rules and the world.
        "rule_exception": 0.01,    # a single-use plate kept for a re-read after the rule says "thrown away"
        "freezer_failure_per_year": _rate(n, "freezer", "freezer_failure"),
        "rescue_move_unscanned": 0.05,   # step_not_recorded with a x5 stress factor
        "evap_ul_per_h": _rate(n["evaporation"], "conditions", "lidded_384_bench"),
        "target_qc_fail": n["materials"]["target_protein"]["qc_fail_rate"],
        "dna_low_yield": n["materials"]["twist_dna"]["low_yield_rate"],
        # How often people notice their own mistake later and record a fix.
        # Assumptions, the same in both presets: big slips look odd, small ones don't.
        "notice": {
            "typo_small": 0.05,
            "typo_big": 0.5,
            "wrong_scan": 0.3,
            "duplicate_delivery": 0.6,     # catalog RCV-011: detected_within_1_day 0.6
            "step_unrecorded": 0.2,
        },
    }


def bad_week():
    p = normal()
    p.update({
        "move_unscanned": 0.15,      # LOC: no_scan_return 0.05, late_return_scan 0.15, skip_intermediate_scan 0.4
        "step_unrecorded": 0.10,     # RCV: forget_buffer_lot 0.10; LIFE: unrecorded_draw 0.05
        "wrong_scan": 0.005,         # XFER: wrong_source_scan 0.005 per run
        "wrong_position": 0.02,      # LOC: slot_order_swap 0.02, swap_slots 0.01
        "typo_any": 0.05,            # top of the noise model's range
        "typo_big": 0.01,            # XFER: decimal_slip 0.005; noise model top 0.01
        "dup_delivery": 0.03,        # RCV-011: duplicate_receipt 0.03
        "discard_unscanned": 0.15,   # RCV: dispose_without_record 0.15
        "label_duplicate": 0.005,
        "count_missed": 0.03,        # LOC: missed_item 0.03 per item
        "late_manual": 0.15,         # RCV: delay_import 0.15, 1 to 7 days
        "late_manual_hours": [1, 72],
        "robot_step_missing": 0.002, # XFER: skip_well 0.002 per well
        "robot_log_late": 0.05,      # XFER: import_plan_instead_of_log 0.05
        "supplier_duplicate": 0.02,
        "supplier_short_fill": 0.05,
        "supplier_late": 0.3,
        "rule_exception": 0.05,
        "freezer_failure_per_year": 0.75,  # LOC/LIFE agents: 0.5 and 1 per freezer per year
        "rescue_move_unscanned": 0.95,     # LOC: no_scan_during_rehouse 0.95 per box
    })
    return p


PRESETS = {"normal": normal, "bad_week": bad_week}
