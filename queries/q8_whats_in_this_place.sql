-- What's in this freezer (or fridge, or box)?
--
-- Who asks: someone about to open a freezer, plan a clear-out, or do a count;
-- also anyone moving a whole box, who wants to know what goes with it.
-- Why: places nest (freezer, rack, box, slot), and a box moved with one scan
-- takes everything in it along. The list has to follow that nesting as it
-- stands at the moment asked, not as it was when each tube was filed.
-- A trustworthy answer: everything inside the place at any depth, laid out
-- as a tree, with what each container holds, how much of it is usable, why
-- not if it isn't, and when its location was last confirmed. Plates show
-- one line, not one line per well.
--
-- Settings: place (barcode of the place, default 'LOC-F1'), t, k.
-- Try also: -v place=LOC-R1 (the fridge), -v place=BOX-0011 (one box).

\if :{?place}
\else
  \set place 'LOC-F1'
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
\echo Contents of :place, as of :t, as recorded by :k

with recursive
here as (
  select ps.container_id, ps.parent_id, ps.slot
  from parent_spans(:'k') ps
  join container c on c.id = ps.container_id and c.plate_id is null
  where ps.from_at <= :'t' and :'t' < ps.to_at
),
tree (id, depth, sort_key, slot) as (
  select ll.container_id, 0, container_label(ll.container_id), null::text
  from live_labels(:'t', :'k') ll where ll.barcode = :'place'
  union all
  select h.container_id, tree.depth + 1,
         tree.sort_key || ' > ' || coalesce(lpad(substring(h.slot from '\d+$'), 3, '0'), '') || container_label(h.container_id),
         h.slot
  from tree join here h on h.parent_id = tree.id
  where tree.depth < 15
),
u as (
  select u.*, coalesce(c.plate_id, c.id) as vessel_id
  from usable(:'t', :'k') u join container c on c.id = u.container_id
  where u.held <> 0
),
contents as (
  select vessel_id,
         case when count(distinct material_id) > 3
              then count(distinct material_id) || ' materials: ' || min(material_id) || ' .. ' || max(material_id)
              else string_agg(distinct material_id, ', ') end as holds,
         sum(held) as held, sum(usable) as usable,
         min(dimension) as dimension,
         (select string_agg(distinct r, ', ') from u u2, unnest(u2.reasons) r where u2.vessel_id = u.vessel_id) as reasons,
         (select string_agg(distinct w, ', ') from u u2, unnest(u2.warnings) w where u2.vessel_id = u.vessel_id) as warnings
  from u
  group by vessel_id
),
bc as (
  select container_id, string_agg(barcode, ', ') as barcode from live_labels(:'t', :'k') group by 1
)
select repeat('    ', t.depth) || container_label(t.id) || coalesce(' @' || t.slot, '') as container,
       bc.barcode, ct.holds,
       round(ct.held, 1) as held, round(ct.usable, 1) as usable,
       case ct.dimension when 'volume' then 'µL' when 'mass' then 'µg' when 'count' then 'pieces' end as unit,
       ct.reasons as "why not all usable", ct.warnings,
       to_char(loc.last_confirmed_at, 'YYYY-MM-DD') || ', ' || loc.last_confirmed_how as "last confirmed",
       nullif(loc.status, 'placed') as note
from tree t
left join contents ct on ct.vessel_id = t.id
left join bc on bc.container_id = t.id
left join location(:'t', :'k') loc on loc.container_id = t.id
order by t.sort_key;
