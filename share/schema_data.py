"""Export the schema for the review console's Schema tab: share/data/schema.json.

Reads the tables, columns, keys and foreign keys from a database built from
schema/ (INV_DB, default inventory_trace, as built by share/build_data.py), and
the comment above each table and function from the SQL files themselves.
"""
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PSQL = str(Path(os.environ["PG_BIN"]) / "psql") if os.environ.get("PG_BIN") else "psql"
DB = os.environ.get("INV_DB", "inventory_trace")

GROUPS = {
    "reference": ["actor", "material_kind", "material", "product", "container_type", "shelf_life_rule", "thaw_limit_rule"],
    "things": ["event", "lot", "lot_parent", "container", "run", "planned_transfer"],
    "lines": ["quantity_entry", "placement", "sighting", "label", "qc_result", "hold_placed", "hold_released",
              "container_exit", "count_line", "measurement", "flag_review"],
}

COLUMNS_SQL = """
select json_agg(json_build_object('table', c.table_name, 'column', c.column_name, 'type', c.data_type,
  'nullable', c.is_nullable = 'YES', 'position', c.ordinal_position) order by c.table_name, c.ordinal_position)
from information_schema.columns c
join information_schema.tables t on t.table_name = c.table_name and t.table_schema = c.table_schema
where c.table_schema = 'public' and t.table_type = 'BASE TABLE'
"""
KEYS_SQL = """
select json_agg(json_build_object('table', rel.relname, 'kind', con.contype,
  'columns', (select json_agg(a.attname) from unnest(con.conkey) k join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k),
  'references', case when con.contype = 'f' then (select relname from pg_class where oid = con.confrelid) end))
from pg_constraint con join pg_class rel on rel.oid = con.conrelid join pg_namespace n on n.oid = rel.relnamespace
where n.nspname = 'public' and con.contype in ('p', 'f', 'u')
"""


def q(sql):
    r = subprocess.run([PSQL, "-X", "-A", "-t", "-d", DB, "-c", sql], capture_output=True, text=True, check=True)
    return json.loads(r.stdout.strip() or "[]")


def comments(kind):
    """The run of -- lines right above each `create table x` / `create function x(`."""
    out = {}
    for f in sorted((ROOT / "schema").glob("*.sql")):
        lines = f.read_text().splitlines()
        for i, line in enumerate(lines):
            m = re.match(rf"create {kind} (\w+)", line)
            if not m:
                continue
            j, buf = i - 1, []
            while j >= 0 and lines[j].startswith("--"):
                buf.insert(0, lines[j][2:].strip())
                j -= 1
            text = " ".join(x for x in buf if x)
            out[m.group(1)] = {"comment": text, "file": f"schema/{f.name}"}
    return out


def function_signatures():
    sigs = {}
    for f in sorted((ROOT / "schema").glob("*.sql")):
        for m in re.finditer(r"create function (\w+)\((.*?)\)\s*\n?\s*returns ([^\n$]*?)(?: language|\n)", f.read_text(), re.S):
            args = re.sub(r"\s+", " ", m.group(2)).strip()
            args = re.sub(r" default [^,]+", "", args)
            sigs[m.group(1)] = {"args": [a.strip().split(" ")[0] for a in args.split(",") if a.strip()],
                                "returns": re.sub(r"\s+", " ", m.group(3)).strip(), "file": f"schema/{f.name}"}
    return sigs


def sections(path, pattern):
    """Split a markdown doc into its `## ` sections: id, title, body paragraphs, scenario ids."""
    text = (ROOT / path).read_text()
    out = []
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", text, re.S | re.M):
        head, body = m.group(1).strip(), m.group(2).strip()
        h = re.match(pattern, head)
        if not h:
            continue
        scen = re.findall(r"\b(?:RCV|XFER|LOC|LIFE|ASK|EDGE)-\d+\b", body)
        body = re.sub(r"^Scenarios:.*$", "", body, flags=re.M)
        body = re.sub(r"^(Found by|Research:).*$", "", body, flags=re.M).strip()
        out.append({"id": h.group(1), "title": h.group(2).strip(), "body": body,
                    "scenarios": sorted(set(scen)), "principles": sorted(set(re.findall(r"Principle (\d)", m.group(2))))})
    return out


def main():
    (ROOT / "share/data/principles.json").write_text(json.dumps({
        "principles": sections("docs/principles.md", r"(\d+)\. (.+)"),
        "decisions": sections("docs/decisions.md", r"(D\d+)\. (.+)"),
    }, indent=1, ensure_ascii=False))
    cols, keys = q(COLUMNS_SQL), q(KEYS_SQL)
    tcomm, fcomm, sigs = comments("table"), comments("function"), function_signatures()
    tables = {}
    for c in cols:
        t = tables.setdefault(c["table"], {"name": c["table"], "columns": [], "references": []})
        t["columns"].append({"name": c["column"], "type": c["type"], "nullable": c["nullable"]})
    for k in keys:
        t = tables.get(k["table"])
        if not t:
            continue
        for col in t["columns"]:
            if col["name"] in (k["columns"] or []):
                if k["kind"] == "p":
                    col["pk"] = True
                elif k["kind"] == "f":
                    col["fk"] = k["references"]
        if k["kind"] == "f" and k["references"] not in t["references"] and k["references"] != t["name"]:
            t["references"].append(k["references"])
    for name, t in tables.items():
        t.update(tcomm.get(name, {}))
        t["group"] = next((g for g, names in GROUPS.items() if name in names), "other")
    files = {"schema/04_time.sql": "time", "schema/05_derived.sql": "answers", "schema/06_record.sql": "record"}
    functions = [{"name": n, **sigs.get(n, {}), **fcomm.get(n, {}), "group": files.get(sigs.get(n, {}).get("file"), "other")}
                 for n in sigs if sigs[n]["file"] in files]
    out = ROOT / "share/data/schema.json"
    out.write_text(json.dumps({"tables": sorted(tables.values(), key=lambda t: t["name"]), "functions": functions}, indent=1))
    print(len(tables), "tables,", len(functions), "functions ->", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
