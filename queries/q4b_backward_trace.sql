-- Where did this come from?
--
-- Who asks: the data reviewer looking at a strange binding curve, or a
-- customer asking what exactly was in their well.
-- Why: the brief's fourth question, the other way round. A result is only
-- explainable if we can name every batch that went into the well.
-- A trustworthy answer: every lot that ever entered the well, and for each
-- one the chain back to what it was made from, down to supplier lots, with
-- the QC verdict and certificate claims on each. A BLI measurement is a sample
-- well against target wells, so the second part lists the target and buffer
-- lots that the same run used on the other plate.
--
-- Settings: barcode (default the EXP-0457 BLI sample plate), well (default
-- 'B5', design D-017; leave empty for the whole plate or a tube), t, k.

\if :{?barcode}
\else
  \set barcode 'BLI-S-0457'
\endif
\if :{?well}
\else
  \set well 'B5'
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
\echo Backward trace of :barcode :well, as of :t, as recorded by :k

create temp table start_at as
  select c.id
  from container c
  where c.id in (select l.container_id from events_at(:'t', :'k') e join label l on l.event_id = e.id
                 where l.barcode = :'barcode' and l.action = 'attach')
    and :'well' = ''
  union
  select c.id
  from container c
  where c.plate_id in (select l.container_id from events_at(:'t', :'k') e join label l on l.event_id = e.id
                       where l.barcode = :'barcode' and l.action = 'attach')
    and (c.position = :'well' or :'well' = '');

\echo
\echo 1. What went into it, and what that was made from

with entered as (
  select distinct q.lot_id
  from events_at(:'t', :'k') e join quantity_entry q on q.event_id = e.id
  where q.container_id in (select id from start_at) and q.amount > 0
),
tree as (
  select en.lot_id as root, a.lot_id, a.depth
  from entered en cross join lateral lot_ancestors(en.lot_id, :'k') a
)
select tr.root as "lot in the well", tr.depth as "steps back",
       repeat('  ', tr.depth) || l.material_id as material, tr.lot_id as lot, l.origin,
       coalesce(p.supplier || ' ' || p.catalog_number || coalesce(', lot ' || l.supplier_lot_code, ''), '-') as "supplier and lot",
       e.occurred_at::date as "received or made",
       q.status as qc, q.decided_at::date as "qc on", r.assay, l.coa as "certificate says"
from tree tr
join lot l on l.id = tr.lot_id
join event e on e.id = l.created_event_id
left join product p on p.id = l.product_id
join lot_qc(:'t', :'k') q on q.lot_id = tr.lot_id
left join qc_result r on r.event_id = q.decided_by_event and r.lot_id = tr.lot_id
order by tr.root, tr.depth, tr.lot_id;

\echo
\echo 2. The other side of the measurement: targets and buffers used in the same run

with runs_in as (
  select distinct e.run_id
  from events_at(:'t', :'k') e join quantity_entry q on q.event_id = e.id
  where q.container_id in (select id from start_at) and e.run_id is not null
),
partners as (
  select distinct e.run_id, q.lot_id
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id and q.amount > 0
  join lot l on l.id = q.lot_id
  join material m on m.id = l.material_id
  where e.run_id in (select run_id from runs_in)
    and q.container_id not in (select id from start_at)
    and not m.attributes ? 'design_id'
    and q.lot_id not in (select q2.lot_id from events_at(:'t', :'k') e2 join quantity_entry q2 on q2.event_id = e2.id
                         where q2.container_id in (select id from start_at))
)
select r.experiment_ref as experiment, pa.lot_id as "lot used", a.depth as "steps back",
       repeat('  ', a.depth) || l.material_id as material, a.lot_id as lot, l.origin,
       coalesce(p.supplier || ' ' || p.catalog_number || coalesce(', lot ' || l.supplier_lot_code, ''), '-') as "supplier and lot",
       q.status as qc, q.decided_at::date as "qc on"
from partners pa
join run r on r.id = pa.run_id
cross join lateral lot_ancestors(pa.lot_id, :'k') a
join lot l on l.id = a.lot_id
left join product p on p.id = l.product_id
join lot_qc(:'t', :'k') q on q.lot_id = a.lot_id
order by pa.lot_id, a.depth, a.lot_id;

drop table start_at;
