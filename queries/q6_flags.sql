-- What needs a person today?
--
-- Who asks: the lab manager, first thing in the morning.
-- Why: principle 4 says we record first and flag after. That only works if
-- the flags land on someone's desk. Each item here is something the system
-- can't settle on its own: a balance gone negative, a robot step missing from
-- the log, a tube a count couldn't find, a duplicate-looking delivery, plus
-- material that's still sitting in a fridge or freezer although it has
-- expired, failed QC or has been waiting for QC for a while.
-- A trustworthy answer: one line per problem with what it is, where it is,
-- the detail behind it, and nothing that has already been resolved (a flag
-- goes away when the facts behind it are corrected).
--
-- Settings: qc_wait_days (default 2), t, k.

\if :{?qc_wait_days}
\else
  \set qc_wait_days 2
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
\echo Open items as of :t, as recorded by :k

with items as (
  select flag, container_id, lot_id, detail from flags(:'t', :'k')
  union all
  select 'expired, still here', u.container_id, u.lot_id,
         round(u.held, 1) || ' left, expired ' || to_char(u.expires_at, 'YYYY-MM-DD HH24:MI') || ' (' || u.expiry_clock || '): throw away'
  from usable(:'t', :'k') u
  where 'expired' = any(u.reasons) and not u.reasons && array['discarded', 'shipped'] and u.held > 0
  union all
  select 'failed QC, still here', u.container_id, u.lot_id,
         round(u.held, 1) || ' left: return to supplier or throw away'
  from usable(:'t', :'k') u
  where 'failed QC' = any(u.reasons) and not u.reasons && array['discarded', 'shipped'] and u.held > 0
  union all
  select 'waiting for QC', u.container_id, u.lot_id,
         'received ' || to_char(e.occurred_at, 'YYYY-MM-DD') || ', no QC result yet'
  from usable(:'t', :'k') u
  join lot l on l.id = u.lot_id
  join event e on e.id = l.created_event_id
  where 'waiting for QC' = any(u.reasons) and not u.reasons && array['discarded', 'shipped'] and u.held > 0
    and e.occurred_at < :'t'::timestamptz - make_interval(days => :qc_wait_days)
),
bc as (
  select container_id, string_agg(barcode, ', ') as barcode from live_labels(:'t', :'k') group by 1
)
select i.flag, coalesce(bc.barcode, pbc.barcode || ' ' || c.position) as barcode,
       container_label(i.container_id) as container, l.material_id as material, i.detail,
       loc.path as "where"
from items i
left join container c on c.id = i.container_id
left join bc on bc.container_id = i.container_id
left join bc pbc on pbc.container_id = c.plate_id
left join lot l on l.id = i.lot_id
left join location(:'t', :'k') loc on loc.container_id = coalesce(c.plate_id, c.id)
order by i.flag, container;
