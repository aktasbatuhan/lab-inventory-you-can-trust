-- How much do we have, and how much of it can we use?
--
-- Who asks: anyone planning work or ordering, most often lab operations.
-- Why: the brief's first question. "We have 400 µL of PD-L1" means nothing if
-- all of it failed QC.
-- A trustworthy answer: for each material, what the records say we hold, how
-- much of that is usable, and for the rest the reason it isn't (expired,
-- failed QC, on hold, location uncertain, a negative balance someone has to
-- explain, or liquid stuck at the bottom of a tube where a pipette can't reach).
-- The reasons come from usable() in schema/05_derived.sql; nothing is
-- recalculated here.
--
-- Settings (pass with -v name=value):
--   material           material id pattern, e.g. 'target:%' (default: everything)
--   t                  the moment we're asking about (default: the demo's "today")
--   k                  how much of the record to believe, by when it was written (default: now)
--   include_discarded  also count what's in containers already thrown away (default: false)

\if :{?material}
\else
  \set material '%'
\endif
\if :{?t}
\else
  \set t '2026-10-21 17:00'
\endif
\if :{?k}
\else
  \set k now
\endif
\if :{?include_discarded}
\else
  \set include_discarded false
\endif
set timezone = 'Europe/Zurich';
\pset null '-'
\echo Materials matching :material, as of :t, as recorded by :k

with u as (
  select u.*, m.kind_id, m.name,
         case u.dimension when 'volume' then 'µL' when 'mass' then 'µg' when 'count' then 'pieces' else u.dimension end as unit
  from usable(:'t', :'k') u
  join material m on m.id = u.material_id
  where u.material_id like :'material'
    and (:include_discarded or not u.reasons && array['discarded', 'shipped'])
)
select kind_id as kind, material_id as material, name, unit,
       round(sum(held), 1)                as held,
       round(sum(usable), 1)              as usable,
       round(sum(held) - sum(usable), 1)  as "can't use",
       count(*) filter (where usable > 0) as "tubes or wells usable",
       count(*)                           as "tubes or wells held"
from u
group by kind_id, material_id, name, unit
order by kind_id, material_id, unit;

\echo
\echo Why the rest is not usable. A tube with several reasons counts once, under all of them together.

with u as (
  select u.*,
         case u.dimension when 'volume' then 'µL' when 'mass' then 'µg' when 'count' then 'pieces' else u.dimension end as unit
  from usable(:'t', :'k') u
  where u.material_id like :'material'
    and (:include_discarded or not u.reasons && array['discarded', 'shipped'])
),
gap as (
  select material_id, unit, array_to_string(reasons, ' + ') as why, held as amount, container_id
  from u where cardinality(reasons) > 0
  union all
  select material_id, unit, 'below pipette reach (dead volume)', held - usable, container_id
  from u where cardinality(reasons) = 0 and held > usable
)
select material_id as material, why, unit, round(sum(amount), 1) as amount, count(*) as "tubes or wells"
from gap
group by material_id, why, unit
order by material_id, why;
