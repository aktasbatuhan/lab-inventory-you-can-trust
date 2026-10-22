-- Where is it?
--
-- Who asks: a scientist with a barcode on a worklist, standing in front of a
-- freezer.
-- Why: the brief's third question. Containers move several times a day, and
-- "where the system thinks it is" isn't the same as "where someone last saw it".
-- A trustworthy answer: the full path (freezer, rack, box, slot), whether
-- that's confirmed, uncertain (missed in a count) or only typed in, when and
-- how someone last actually confirmed it, and the trail of moves with how
-- each was recorded. A barcode that was on a container now thrown away still
-- answers, with "discarded".
--
-- Settings: barcodes (comma separated, default three that tell different
-- stories), t, k.

\if :{?barcodes}
\else
  \set barcodes 'EGFR-L4471-009,BOX-0012,BLI-S-0457'
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
\echo Barcodes :barcodes, as of :t, as recorded by :k

with wanted as (
  select distinct l.barcode, l.container_id
  from events_at(:'t', :'k') e join label l on l.event_id = e.id
  where l.action = 'attach' and l.barcode = any(string_to_array(:'barcodes', ','))
)
select w.barcode, container_label(w.container_id) as container,
       loc.status, loc.path as "where",
       loc.last_confirmed_at as "last confirmed", loc.last_confirmed_how as how,
       date_trunc('hour', :'t'::timestamptz - loc.last_confirmed_at) as "since then",
       exists (select 1 from live_labels(:'t', :'k') ll where ll.barcode = w.barcode and ll.container_id = w.container_id) as "label still live"
from wanted w
join location(:'t', :'k') loc on loc.container_id = w.container_id
order by w.barcode;

\echo
\echo Anything asked for that is not a barcode we know, and what it might mean instead

-- An empty answer must never read as "it isn't registered". Found by the agent
-- lab: a reviewer looked up experiment names as barcodes, got nothing back, and
-- concluded the plates were missing.
with asked as (
  select trim(x) as q from unnest(string_to_array(:'barcodes', ',')) x
),
unknown as (
  select a.q from asked a
  where not exists (select 1 from label l where l.barcode = a.q and l.action = 'attach')
)
select u.q as "you asked for",
       'no container has ever had this barcode' as "what we know",
       coalesce(
         (select 'it is an experiment: ' || count(distinct coalesce(c.plate_id, c.id)) || ' containers used in its runs, for example '
                 || string_agg(distinct container_label(coalesce(c.plate_id, c.id)), ', ')
          from run r join event e on e.run_id = r.id join quantity_entry q on q.event_id = e.id
          join container c on c.id = q.container_id
          where r.experiment_ref = u.q),
         (select 'it is the name of ' || string_agg(container_label(c.id), ', ') from container c where lower(c.name) = lower(u.q)),
         (select 'did you mean ' || string_agg(l.barcode, ', ') from (select distinct barcode from label where barcode ilike '%' || u.q || '%' limit 5) l),
         'nothing similar either; check the label') as "it may be"
from unknown u;

\echo
\echo The trail: every place each one has been, and how the move was recorded

with wanted as (
  select distinct l.barcode, l.container_id
  from events_at(:'t', :'k') e join label l on l.event_id = e.id
  where l.action = 'attach' and l.barcode = any(string_to_array(:'barcodes', ','))
)
select w.barcode, ps.from_at as "from", nullif(ps.to_at, 'infinity') as "until",
       container_label(ps.parent_id) || coalesce(' @' || ps.slot, '') as "in",
       case ps.source when 'scan' then 'scanned' when 'robot_log' then 'robot log' when 'manual' then 'typed in, not scanned' else ps.source end as "recorded how"
from wanted w
join parent_spans(:'k') ps on ps.container_id = w.container_id
where ps.from_at <= :'t'
order by w.barcode, ps.from_at;
