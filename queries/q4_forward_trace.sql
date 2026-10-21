-- A batch turned out bad: what did it touch?
--
-- Who asks: the lab manager, the day a supplier recalls a lot or our own QC
-- finds a problem after the lot was already in use.
-- Why: the brief's fourth question. "If a batch of target turns out to be
-- bad, we need to find everything that was made from it."
-- A trustworthy answer, in four parts:
--   1. every lot involved: each delivery under that supplier lot code (each
--      delivery is its own batch, decision D2) and anything made from them,
--      at any depth;
--   2. every container that ever held any of it, and whether it's still here;
--   3. every run and experiment that used it, and the customer designs that
--      were measured in those runs, so we know whose results to question;
--   4. what's still in our freezers, with a ready-to-run hold for each lot, so
--      nobody uses it while we find out.
--
-- Settings: supplier_lot (default 'L4471', the EGFR lot), t, k.

\if :{?supplier_lot}
\else
  \set supplier_lot 'L4471'
\endif
\if :{?t}
\else
  \set t '2026-10-21 17:00'
\endif
\if :{?k}
\else
  \set k now
\endif
set timezone = 'Europe/Zurich';
\pset null '-'
\echo Forward trace of supplier lot :supplier_lot, as of :t, as recorded by :k
\echo
\echo 1. The lots: every delivery of that supplier lot, and everything made from them

create temp table traced as
  select distinct d.lot_id, min(d.depth) over (partition by d.lot_id) as depth
  from lot l
  join events_at(:'t', :'k') e on e.id = l.created_event_id
  cross join lateral lot_descendants(l.id, :'k') d
  where l.supplier_lot_code = :'supplier_lot';

select t.lot_id as lot, t.depth as "steps from the delivery", l.material_id as material, l.origin,
       e.occurred_at as "received or made", q.status as qc
from traced t
join lot l on l.id = t.lot_id
join event e on e.id = l.created_event_id
join lot_qc(:'t', :'k') q on q.lot_id = t.lot_id
order by t.depth, t.lot_id;

\echo
\echo 2. Every container that ever held any of it

with touched as (
  select coalesce(c.plate_id, c.id) as vessel_id, q.lot_id, min(e.occurred_at) as first_in, count(distinct c.id) as wells
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id and q.amount > 0
  join container c on c.id = q.container_id
  where q.lot_id in (select lot_id from traced)
  group by 1, 2
),
bc as (
  select l.container_id, string_agg(distinct l.barcode, ', ') as barcode
  from events_at(:'t', :'k') e join label l on l.event_id = e.id where l.action = 'attach' group by 1
)
select bc.barcode, container_label(t.vessel_id) as container, t.lot_id as lot, t.first_in as "first got it",
       case when t.wells > 1 then t.wells || ' wells' end as wells,
       loc.status, loc.path as "where now"
from touched t
left join bc on bc.container_id = t.vessel_id
left join location(:'t', :'k') loc on loc.container_id = t.vessel_id
order by t.first_in, container;

\echo
\echo 3. Runs and experiments that used it, and the customer designs measured in them

with runs_hit as (
  select distinct e.run_id
  from events_at(:'t', :'k') e join quantity_entry q on q.event_id = e.id
  where e.run_id is not null and q.lot_id in (select lot_id from traced)
),
designs as (
  select e.run_id, count(distinct m.attributes->>'design_id') as n,
         string_agg(distinct m.attributes->>'customer', ', ') as customers,
         string_agg(distinct m.attributes->>'campaign', ', ') as campaigns
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id
  join lot l on l.id = q.lot_id
  join material m on m.id = l.material_id
  where e.run_id in (select run_id from runs_hit) and m.attributes ? 'design_id'
  group by 1
)
select r.id as run, r.experiment_ref as experiment, r.protocol, container_label(r.instrument_id) as instrument,
       e.occurred_at as started, coalesce(d.n, 0) as "designs measured", d.customers, d.campaigns
from runs_hit h
join run r on r.id = h.run_id
join event e on e.id = r.created_event_id
left join designs d on d.run_id = r.id
order by e.occurred_at;

\echo
\echo 4. Still here: put these on hold

with bc as (
  select container_id, string_agg(barcode, ', ') as barcode from live_labels(:'t', :'k') group by 1
)
select bc.barcode, container_label(u.container_id) as container, u.lot_id as lot, round(u.held, 1) as held,
       coalesce(nullif(array_to_string(u.reasons, ', '), ''), 'usable') as "status now", loc.path as "where"
from usable(:'t', :'k') u
left join bc on bc.container_id = u.container_id
left join location(:'t', :'k') loc on loc.container_id = u.container_id
where u.lot_id in (select lot_id from traced) and u.held > 0 and not u.reasons && array['discarded', 'shipped']
order by loc.path;

select format('select hold(%L, now(), %L, p_lot => %s);',
              'Supplier lot ' || :'supplier_lot' || ' under investigation', 'p:sara', t.lot_id) as "to hold every lot at once"
from traced t
where exists (select 1 from usable(:'t', :'k') u
              where u.lot_id = t.lot_id and u.held > 0 and not u.reasons && array['discarded', 'shipped'])
order by t.lot_id;

drop table traced;
