# Schema gaps found while writing the queries and the demo lab

Written while building `seed/02_demo_lab.sql` and `queries/`. I didn't touch
`schema/`. Each item says what I saw in the demo answers, why it happens, and
the smallest fix I'd make. They're ordered by how much they'd mislead someone.

## 1. A lost robot log line leaves the source looking fuller than it is

Seen in: `queries/examples/q1_how_much_and_usable.txt` (dna:D-017),
`q6_flags.txt`.

The Hamilton did pipette 5 µL of D-017's DNA from the Twist plate (B5) into the
expression plate (B5); only the log line went missing. The expression well goes
to -5 µL when expression uses that DNA, and two flags fire on it. Good. But the
Twist plate's B5 still says 20 µL, and `usable()` calls 18 µL of it usable,
when the tube really holds 15. Per material, D-017's DNA ends up with "held 15,
usable 18": usable bigger than held. Someone planning a re-expression from the
DNA plate would trust the 18.

Why: `flags()` reports the missing step against the destination only, and
`usable()` knows nothing about missing steps, so the source keeps a clean bill.

Smallest fix: treat a planned-but-unlogged step of a finished run as a doubt on
both ends. In `usable()`, add one reason:

```sql
-- in usable(), next to the other ctes
unconfirmed as (
  select pt.from_container_id as container_id from planned_transfer pt
  where exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.kind = 'run finished')
    and not exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.run_step = pt.step)
  union
  select pt.to_container_id from planned_transfer pt
  where exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.kind = 'run finished')
    and not exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.run_step = pt.step)
),
-- and in the reasons array
case when b.container_id in (select container_id from unconfirmed) then 'robot step not confirmed' end,
```

and in `flags()` emit the `robot run incomplete` row for `from_container_id`
as well. A person then confirms the step (records the transfer with the run and
step) or says it didn't happen, and both reasons go away.

## 2. A rule that's missing looks the same as "never expires"

Seen in: the first build of the demo, before the seed fix described in
`journal/agent-runs/schema-gaps.md` item 1. With no shelf-life rules visible,
`q2_expiring` came back almost empty and LB-0922 (expired three weeks ago)
showed as fully usable.

Why: when no rule matches a lot, `expiry()` returns no row, `expires_at` is
null, and `usable()` reads null as "fine". That's right for consumables (the
brief says they don't expire) but wrong for a new buffer or a new material
kind someone forgot to give a rule. Principle 1 says this should read
"unknown, because no rule applies", not "fine".

Smallest fix: say explicitly that something doesn't expire (a rule with a null
duration, which the schema already supports) and warn when there's no rule at
all.

```sql
-- seed: consumables never expire, on purpose
insert into shelf_life_rule (material_kind_id, clock, duration, effective_from, recorded_at, recorded_by, note)
values ('consumable', 'since_origin', null, '2020-01-01', '2020-01-01', 'p:sara', 'Brief: no expiry.');

-- in usable(), in the warnings array
case when not exists (select 1 from rules_for_lots(t, k) r where r.lot_id = b.lot_id)
          and l.supplier_expiry is null
     then 'no shelf-life rule: expiry unknown' end,
```

`rules_for_lots` drops null-duration rules only later (in `expiry_clocks`), so
the `exists` above sees them.

## 3. finish_run only throws away plates that had liquid moved in that run

Seen in: building the demo. The BLI sample and target plates are prepared the
afternoon before the BLI run, then only read by the Gator. If plate prep is its
own task (its own run, or no run), the BLI run has no ledger lines on those
plates, so `finish_run` doesn't discard them and they stay "usable" in the
fridge. The demo works around it by recording plate prep as part of the BLI
run (same `run_id`). Same for the split-GFP plate and the plate reader.

Why: `finish_run` finds single-use vessels through `quantity_entry` rows of
events with that `run_id`. Reading a plate isn't a ledger line.

Smallest fix: also count single-use containers that sat in the run's
instrument while the run was going.

```sql
-- in finish_run, add to the "vessels used in this run" set
union
select ps.container_id
from run r
join event rs on rs.id = r.created_event_id
join parent_spans('infinity') ps on ps.parent_id = r.instrument_id
where r.id = p_run and ps.from_at < p_at and ps.to_at > rs.occurred_at
```

## 4. Counting the tubes in a box doesn't confirm the box

Seen in: `queries/examples/q3b_not_seen_lately.txt`. Every EGFR tube in
BOX-0011 was found in the 16 October count, but the box itself (and Rack A)
still say "last confirmed 4 September" and show up as not seen lately.

Why: `location()` only counts sightings, scanned moves and count lines of the
container itself.

Smallest fix: in `location()`, let a confirmation of a container also confirm
everything it was inside at that moment.

```sql
-- in location(), after confirmations
confirmations_up as (
  select c.container_id, c.at, c.how from confirmations c
  union all
  select ps.parent_id, c.at, c.how || ' (something inside it)'
  from confirmations c
  join parent_spans(k) ps on ps.container_id = c.container_id and ps.from_at <= c.at and c.at < ps.to_at
),
```

(walked up recursively, as `up` already does). The boxes would then show the
count date, with "something inside it" making clear what was actually seen.

## 5. A typed-in move reads as "placed", same as a scanned one

Seen in: `queries/examples/q3_where_is_it.txt`. BOX-0012 was carried to F3 and
the move was typed in later, never scanned. `location()` says status "placed",
same as a scanned move; only the "last confirmed 17 Sep" column hints that
something is off, and you need the trail to see why.

Smallest fix: one more status in `location()`, between "placed" and
"uncertain":

```sql
when conf.at is null or conf.at < (select max(from_at) from ps where ps.container_id = l.id)
  then 'placed, not confirmed'
```

i.e. the latest move into its current place came after the last time anyone
actually saw it.

## Smaller things

- Received lots need a product, so each custom Twist gene needs its own
  `product` row (one per design, catalog number = order line). Fine for 24
  designs, clumsy for 2,000 a week. Letting a received lot carry the supplier
  and order line without a catalog product would be simpler.
- `lot.unit_price` doesn't say per what. `q7_waste.sql` treats it as the price
  of the whole delivery and says so. A comment in `02_facts.sql` (or a
  `price_per` column) would remove the guess.
- The 37 °C incubator isn't one of the four storage conditions. Nothing stays
  there long enough to matter, so the demo calls it room temperature.
