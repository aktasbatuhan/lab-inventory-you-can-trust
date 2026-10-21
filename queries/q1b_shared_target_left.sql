-- What's left of a shared target before we order more?
--
-- Who asks: whoever is about to order another lot of an expensive target
-- (EGFR here, about 300 CHF a lot).
-- Why: targets are shared across experiments and customers. The brief's worry
-- is reordering material we already own because it looks used up, or not
-- reordering because a failed or missing tube still looks usable.
-- A trustworthy answer: every lot of the protein with its QC state, the tubes
-- that are usable right now with where they are and how often they've been
-- thawed, the tubes that exist but can't be used and why, and how much earlier
-- experiments took, so "how many more runs does this cover" is a sum and not
-- a guess.
--
-- Settings: protein (default 'EGFR', matched on the material's protein
-- attribute, so every supplier and lot counts), t, k.

\if :{?protein}
\else
  \set protein 'EGFR'
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
\echo Target protein :protein, as of :t, as recorded by :k
\echo
\echo 1. Each delivery (lot) of this protein

with lots as (
  select l.id, l.supplier_lot_code, p.supplier, p.catalog_number, e.occurred_at as received_at
  from lot l
  join material m on m.id = l.material_id
  join event e on e.id = l.created_event_id
  left join product p on p.id = l.product_id
  where m.kind_id = 'target' and m.attributes->>'protein' = :'protein'
    and e.id in (select id from events_at(:'t', :'k'))
),
u as (
  select * from usable(:'t', :'k')
  where lot_id in (select id from lots) and not reasons && array['discarded', 'shipped']
)
select lots.id as lot, lots.supplier, lots.catalog_number as product, lots.supplier_lot_code as "supplier lot",
       lots.received_at::date as received, q.status as qc, q.decided_at::date as "qc on",
       coalesce(round(sum(u.held), 1), 0) as "held µL", coalesce(round(sum(u.usable), 1), 0) as "usable µL",
       count(u.container_id) filter (where u.usable > 0) as "usable tubes"
from lots
join lot_qc(:'t', :'k') q on q.lot_id = lots.id
left join u on u.lot_id = lots.id
group by lots.id, lots.supplier, lots.catalog_number, lots.supplier_lot_code, lots.received_at, q.status, q.decided_at
order by lots.received_at;

\echo
\echo 2. Every tube we still hold, usable ones first

with lots as (
  select l.id from lot l join material m on m.id = l.material_id
  where m.kind_id = 'target' and m.attributes->>'protein' = :'protein'
),
bc as (
  select l.container_id, string_agg(distinct l.barcode, ', ') as barcode
  from events_at(:'t', :'k') e join label l on l.event_id = e.id where l.action = 'attach' group by 1
)
select bc.barcode, u.lot_id as lot, round(u.held, 1) as "held µL", round(u.usable, 1) as "usable µL", u.thaws,
       coalesce(nullif(array_to_string(u.reasons, ', '), ''), 'usable') as status,
       nullif(array_to_string(u.warnings, ', '), '') as warnings,
       loc.path as "where", loc.last_confirmed_at::date as "last confirmed"
from usable(:'t', :'k') u
join location(:'t', :'k') loc on loc.container_id = u.container_id
left join bc on bc.container_id = u.container_id
where u.lot_id in (select id from lots) and not u.reasons && array['discarded', 'shipped'] and u.held > 0
order by u.usable > 0 desc, loc.path, bc.barcode;

\echo
\echo 3. What earlier experiments took of this protein

with lots as (
  select l.id from lot l join material m on m.id = l.material_id
  where m.kind_id = 'target' and m.attributes->>'protein' = :'protein'
),
taken as (
  select r.experiment_ref, r.protocol, min(e.occurred_at) as at, sum(-q.amount) as taken
  from events_at(:'t', :'k') e
  join run r on r.id = e.run_id
  join quantity_entry q on q.event_id = e.id
  where q.lot_id in (select id from lots) and q.amount < 0
  group by r.experiment_ref, r.protocol
)
select experiment_ref as experiment, protocol, at::date as "on", round(taken, 1) as "took µL" from taken
union all
select 'average per run', null, null, round(avg(taken), 1) from taken
order by 3 nulls last;

\echo
\echo 4. Bottom line

with lots as (
  select l.id from lot l join material m on m.id = l.material_id
  where m.kind_id = 'target' and m.attributes->>'protein' = :'protein'
),
left_over as (
  select sum(usable) as usable from usable(:'t', :'k')
  where lot_id in (select id from lots) and not reasons && array['discarded', 'shipped']
),
per_run as (
  select avg(taken) as avg_taken from (
    select e.run_id, sum(-q.amount) as taken
    from events_at(:'t', :'k') e join quantity_entry q on q.event_id = e.id
    where e.run_id is not null and q.lot_id in (select id from lots) and q.amount < 0
    group by e.run_id) x
)
select round(left_over.usable, 1) as "usable µL now",
       round(per_run.avg_taken, 1) as "µL per run so far",
       floor(left_over.usable / nullif(per_run.avg_taken, 0)) as "runs it covers, at that rate"
from left_over, per_run;
