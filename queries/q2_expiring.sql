-- What has expired, and what expires soon?
--
-- Who asks: lab operations on their weekly check, and anyone about to use a
-- buffer or a plate.
-- Why: the brief's second question. Shelf life depends on what the material
-- is and how it has been kept since when, so a single "expiry date" field
-- would be wrong as soon as a tube moved from the freezer to the fridge.
-- A trustworthy answer: everything we still hold that has expired or will
-- within N days, with the clock that decided it (since received, since made,
-- kept in the fridge, the supplier's date), when that clock started, and the
-- rule behind it, so anyone can check why the date is what it is. Plates are
-- shown once, not well by well.
--
-- Settings: days (default 7), t, k.

\if :{?days}
\else
  \set days 7
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
\echo Expired or expiring within :days days of :t, as recorded by :k

with u as (
  select u.*, coalesce(c.plate_id, c.id) as vessel_id
  from usable(:'t', :'k') u
  join container c on c.id = u.container_id
  where not u.reasons && array['discarded', 'shipped'] and u.held > 0
    and u.expires_at <= :'t'::timestamptz + make_interval(days => :days)
),
clk as (
  select * from expiry_clocks(:'t', :'k')
),
rows as (
  select u.vessel_id, u.material_id, u.held, u.dimension, u.expires_at, u.expiry_clock,
         clk.started_at, clk.rule_id
  from u
  left join clk on clk.container_id = u.container_id and clk.lot_id = u.lot_id
                and clk.clock = u.expiry_clock and clk.expires_at = u.expires_at
),
bc as (
  select container_id, string_agg(barcode, ', ') as barcode from live_labels(:'t', :'k') group by 1
)
select case when r.expires_at <= :'t'::timestamptz then 'expired ' || date_trunc('hour', :'t'::timestamptz - r.expires_at) || ' ago'
            else 'expires in ' || date_trunc('hour', r.expires_at - :'t'::timestamptz) end as status,
       r.expires_at as expires,
       bc.barcode,
       container_label(r.vessel_id) as container,
       case when count(*) > 1 then count(*) || ' wells: ' || min(r.material_id) || ' .. ' || max(r.material_id)
            else min(r.material_id) end as material,
       round(sum(r.held), 1) || case min(r.dimension) when 'volume' then ' µL' when 'mass' then ' µg' else ' ' || min(r.dimension) end as held,
       r.expiry_clock as clock,
       r.started_at as "clock started",
       coalesce(s.duration::text || ', set at ' ||
                case when s.product_id is not null then 'product' when s.material_id is not null then 'material' else 'kind' end
                || ' level: ' || s.note, 'printed by the supplier') as rule,
       loc.path as "where"
from rows r
left join shelf_life_rule s on s.id = r.rule_id
left join bc on bc.container_id = r.vessel_id
left join location(:'t', :'k') loc on loc.container_id = r.vessel_id
group by r.vessel_id, r.expires_at, r.expiry_clock, r.started_at, s.id, s.duration, s.product_id, s.material_id, s.note, bc.barcode, loc.path
order by r.expires_at;
