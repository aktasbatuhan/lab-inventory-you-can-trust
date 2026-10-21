-- Who changed what, and when?
--
-- Who asks: the lab manager when a number looks wrong, or anyone asked "why
-- does the system say 80 µL?".
-- Why: the brief's fifth question. Facts are never edited (principle 2), so
-- the history of a tube is simply every fact that mentions it.
-- A trustworthy answer: every event that touched the container, in the order
-- it happened, with both times (when it happened at the bench, when it was
-- written down), who did it, how it got in (scan, typed, robot log, import,
-- a rule), and whether it still counts. A wrong entry stays in the list,
-- marked as voided, with who corrected it, when and why; the correction is
-- in the list too, carrying the right numbers.
-- QC results on the lots the container held are included, since they change
-- what the tube is good for.
--
-- Settings: barcode (default 'TGT-0101', the EGFR stock tube), k (what was
-- on record by then; default now).

\if :{?barcode}
\else
  \set barcode 'TGT-0101'
\endif
\if :{?k}
\else
  \set k now
\endif
set timezone = 'Europe/Zurich';
\pset null '-'
\echo History of :barcode, everything on record by :k

with c as (
  select distinct l.container_id as id
  from label l join event e on e.id = l.event_id
  where l.barcode = :'barcode' and l.action = 'attach' and e.recorded_at <= :'k'
),
lots_held as (
  select distinct q.lot_id from quantity_entry q where q.container_id in (select id from c)
),
lines as (
  select q.event_id, q.id as ord,
         (case when q.amount > 0 then '+' else '' end) || q.amount ||
         case q.dimension when 'volume' then ' µL ' when 'mass' then ' µg ' else ' ' end ||
         l.material_id || ' (lot ' || q.lot_id || ', ' || q.reason || ')' as what
  from quantity_entry q join lot l on l.id = q.lot_id
  where q.container_id in (select id from c)
  union all
  select p.event_id, 0, 'put into ' || container_label(p.parent_id) || coalesce(' @' || p.position, '')
  from placement p where p.container_id in (select id from c)
  union all
  select p.event_id, 0, container_label(p.container_id) || ' put in here' || coalesce(' @' || p.position, '')
  from placement p where p.parent_id in (select id from c)
  union all
  select s.event_id, 0, 'scanned' || coalesce(' as ' || s.scanned_code, '') from sighting s where s.container_id in (select id from c)
  union all
  select lb.event_id, 0, 'label ' || lb.barcode || ' ' || lb.action || 'ed' from label lb where lb.container_id in (select id from c)
  union all
  select x.event_id, 0, case x.kind when 'discard' then 'thrown away' else 'shipped to ' || coalesce(x.destination, '?') end
  from container_exit x where x.container_id in (select id from c)
  union all
  select cl.event_id, 0, case when cl.found then 'found in a count' || coalesce(', looked like ' || cl.observed_amount, '') else 'NOT found in a count' end
  from count_line cl where cl.container_id in (select id from c)
  union all
  select h.event_id, 0, 'put on hold: ' || h.reason from hold_placed h where h.container_id in (select id from c)
  union all
  select m.event_id, 0, m.property || ' measured: ' || m.value || ' ' || m.unit from measurement m where m.container_id in (select id from c)
  union all
  select r.event_id, 0, 'QC ' || r.outcome || ' for lot ' || r.lot_id || ' (' || r.assay || ')'
  from qc_result r where r.lot_id in (select lot_id from lots_held)
),
voided as (select event_id from voided_events(:'k'))
select e.id as event, e.occurred_at as happened, e.recorded_at as written,
       e.kind, string_agg(li.what, '; ' order by li.ord) as what,
       coalesce(pa.name, ra.name) || case when e.performed_by is not null and e.performed_by <> e.recorded_by
                                          then ' (written by ' || ra.name || ')' else '' end as who,
       e.source,
       case
         when e.id in (select event_id from voided) then
           'VOIDED by event ' || v.id || ' on ' || to_char(v.recorded_at, 'YYYY-MM-DD HH24:MI') || ' by ' || va.name || ': ' || v.note
         when e.voids_event_id is not null then 'correction of event ' || e.voids_event_id || ': ' || e.note
         when e.occurred_at > :'k'::timestamptz then 'not happened yet'
         else 'counts'
       end as status,
       case when e.voids_event_id is null and e.note is not null then e.note end as note
from event e
join lines li on li.event_id = e.id
left join actor ra on ra.id = e.recorded_by
left join actor pa on pa.id = e.performed_by
left join event v on v.voids_event_id = e.id and v.recorded_at <= :'k'
left join actor va on va.id = v.recorded_by
where e.recorded_at <= :'k'
group by e.id, pa.name, ra.name, v.id, v.recorded_at, va.name, v.note
order by e.occurred_at, e.recorded_at, e.id;
