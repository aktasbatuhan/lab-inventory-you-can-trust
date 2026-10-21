-- What hasn't anyone actually seen lately?
--
-- Who asks: lab operations planning the next freezer count.
-- Why: a location is only as good as the last time someone confirmed it. A
-- box carried to another freezer and typed in later, or a tube missed in a
-- count, still has a path in the system; this list is where to look first.
-- A trustworthy answer: every container we still hold whose location hasn't
-- been confirmed (scanned, moved with a scan or by a robot, found in a count)
-- for N days, plus anything a count couldn't find, with what's inside so the
-- expensive ones can go first.
--
-- Settings: days (default 14), t, k.

\if :{?days}
\else
  \set days 14
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
\echo Not confirmed for :days days before :t, or missing in a count, as recorded by :k

with held as (
  select coalesce(c.plate_id, c.id) as vessel_id,
         string_agg(distinct u.material_id, ', ') as holds,
         round(sum(u.held), 1) as amount
  from usable(:'t', :'k') u join container c on c.id = u.container_id
  where u.held > 0
  group by 1
),
inside as (
  select ps.parent_id, count(*) as n
  from parent_spans(:'k') ps join container c on c.id = ps.container_id
  where ps.from_at <= :'t' and :'t' < ps.to_at and c.plate_id is null
  group by 1
),
bc as (
  select container_id, string_agg(barcode, ', ') as barcode from live_labels(:'t', :'k') group by 1
)
select loc.status, bc.barcode, container_label(loc.container_id) as container, loc.path as "where",
       loc.last_confirmed_at as "last confirmed", loc.last_confirmed_how as how,
       date_part('day', :'t'::timestamptz - loc.last_confirmed_at) as "days ago",
       coalesce(held.holds, case when inside.n > 0 then inside.n || ' containers inside' end) as holds,
       held.amount
from location(:'t', :'k') loc
join container c on c.id = loc.container_id and c.plate_id is null
left join held on held.vessel_id = loc.container_id
left join inside on inside.parent_id = loc.container_id
left join bc on bc.container_id = loc.container_id
where loc.status in ('placed', 'uncertain', 'not placed')
  and (held.vessel_id is not null or inside.n > 0)
  and (loc.status = 'uncertain'
       or loc.last_confirmed_at is null
       or loc.last_confirmed_at < :'t'::timestamptz - make_interval(days => :days))
order by loc.status desc, loc.last_confirmed_at nulls first, loc.path;
