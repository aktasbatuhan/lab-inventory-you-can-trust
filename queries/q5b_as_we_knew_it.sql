-- What did the record say then, and what do we know now about then?
--
-- Who asks: someone explaining a decision after the fact. "Why did we think
-- the EGFR stock was empty on the 24th?" or "why did the system show 800 µL
-- of PD-L1 on the 17th?".
-- Why: the second half of the brief's fifth question ("what did the record
-- say before the change?"). Every fact has two times, so the same moment can
-- be read two ways: as the record stood back then, and with every correction
-- written since.
-- A trustworthy answer: for each tube, held, usable and the reasons, side by
-- side for "as we knew it then" and "as we know it now", followed by the
-- entries written after that moment that changed the picture: who wrote
-- them, when, and why.
--
-- Settings: barcodes (comma separated, default 'TGT-0101'), then (the moment,
-- default 24 Sep 2026 noon, the day after Marco's typo), k (now).
-- Try also: -v barcodes=TGT-0103 -v then='2026-09-17 12:00' (the duplicate delivery).

\if :{?barcodes}
\else
  \set barcodes 'TGT-0101'
\endif
\if :{?then}
\else
  \set then '2026-09-24 12:00'
\endif
\if :{?k}
\else
  \set k now
\endif
set timezone = 'Europe/Zurich';
\pset null '-'
\echo Barcodes :barcodes on :then, as recorded at that moment versus as recorded by :k

create temp table wanted as
  select distinct l.barcode, l.container_id
  from label l join event e on e.id = l.event_id
  where l.action = 'attach' and l.barcode = any(string_to_array(:'barcodes', ',')) and e.recorded_at <= :'k';

with was as (select * from usable(:'then', :'then') where container_id in (select container_id from wanted)),
     now_ as (select * from usable(:'then', :'k') where container_id in (select container_id from wanted))
select w.barcode, coalesce(a.lot_id, b.lot_id) as lot, coalesce(a.material_id, b.material_id) as material,
       round(a.held, 1) as "held, then", round(b.held, 1) as "held, now",
       round(a.usable, 1) as "usable, then", round(b.usable, 1) as "usable, now",
       nullif(array_to_string(a.reasons, ', '), '') as "reasons, then",
       nullif(array_to_string(b.reasons, ', '), '') as "reasons, now"
from was a
full join now_ b on b.container_id = a.container_id and b.lot_id = a.lot_id and b.dimension = a.dimension
join wanted w on w.container_id = coalesce(a.container_id, b.container_id)
order by w.barcode, lot;

\echo
\echo What changed the picture: entries written after that moment about things that had already happened

select e.id as event, e.kind, e.occurred_at as happened, e.recorded_at as written, a.name as who,
       case when e.voids_event_id is not null then 'voids event ' || e.voids_event_id end as voids,
       e.note
from event e
join actor a on a.id = e.recorded_by
where e.recorded_at > :'then' and e.recorded_at <= :'k' and e.occurred_at <= :'then'
  and (exists (select 1 from quantity_entry q where q.event_id = e.id and q.container_id in (select container_id from wanted))
       or exists (select 1 from quantity_entry q where q.event_id = e.voids_event_id and q.container_id in (select container_id from wanted)))
order by e.recorded_at;

drop table wanted;
