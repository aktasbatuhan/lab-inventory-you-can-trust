-- What did we throw away with material still in it, and what was it worth?
--
-- Who asks: the lab manager and whoever watches costs; also the scientist
-- wondering why the EGFR runs out sooner than the sum of experiments says.
-- Why: containers are thrown away with liquid inside, sometimes by protocol
-- (single-use BLI and split-GFP plates after their run, the 10 µL a pipette
-- can't reach in a used aliquot) and sometimes by accident. Both are real
-- losses, but only the accidents are worth chasing.
-- A trustworthy answer: each container thrown away in the period, by rule or
-- by hand, by whom and why, what was still in it and how much, and its value
-- where we can know it. Value is the lot's purchase price times the share of
-- the delivery that was thrown away. For material we made ourselves the value
-- is shown as unknown rather than guessed (principle 1).
-- Material written off without throwing the container away (spills,
-- evaporation, recorded with lose()) is listed at the end.
--
-- Settings: from (default 1 Sep 2026), t (the end of the period), k.

\if :{?from}
\else
  \set from '2026-09-01'
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
\echo Thrown away between :from and :t, as recorded by :k

create temp table waste as
  with x as (
    select x.container_id, x.exited_at, x.source, e.note, coalesce(pa.name, ra.name) as who
    from exits(:'t', :'k') x
    join event e on e.id = x.event_id
    left join actor ra on ra.id = e.recorded_by
    left join actor pa on pa.id = e.performed_by
    where x.kind = 'discard' and x.exited_at >= :'from'
  ),
  received as (
    select q.lot_id, sum(q.amount) as amount
    from events_at(:'t', :'k') e join quantity_entry q on q.event_id = e.id
    where q.reason = 'receive' group by 1
  )
  select x.container_id as vessel_id, x.exited_at, x.source, x.note, x.who,
         u.lot_id, u.material_id, m.kind_id, u.dimension, u.held,
         case when l.origin = 'received' and l.unit_price is not null and r.amount > 0
              then round(l.unit_price * u.held / r.amount, 2) end as value,
         l.currency
  from x
  join container c on c.id = x.container_id or c.plate_id = x.container_id
  join usable(:'t', :'k') u on u.container_id = c.id and u.held > 0
  join lot l on l.id = u.lot_id
  join material m on m.id = u.material_id
  left join received r on r.lot_id = u.lot_id;

\echo
\echo Each container thrown away with something in it

select w.exited_at as "thrown away", container_label(w.vessel_id) as container,
       case when w.source = 'rule' then 'by rule (single use)' else 'by hand' end as how,
       w.who, w.note,
       case when count(distinct w.lot_id) > 1 then count(distinct w.lot_id) || ' lots: ' || string_agg(distinct w.kind_id, ', ')
            else min(w.material_id) end as "what was in it",
       string_agg(distinct round(w.held_sum, 1) || case w.dimension when 'volume' then ' µL' when 'mass' then ' µg' else ' ' || w.dimension end, ', ') as amount,
       case when bool_and(w.value is not null) then sum(w.value)::text
            when bool_or(w.value is not null) then sum(w.value) || ' + unknown'
            else 'unknown' end as "value CHF"
from (select *, sum(held) over (partition by vessel_id, dimension) as held_sum from waste) w
group by w.exited_at, w.vessel_id, w.source, w.who, w.note
order by w.exited_at;

\echo
\echo Totals by kind of material, accidents and protocol apart

select case when source = 'rule' then 'by rule (single use)' else 'by hand' end as how, kind_id as kind,
       round(sum(held), 1) || case min(dimension) when 'volume' then ' µL' when 'mass' then ' µg' else ' ' || min(dimension) end as amount,
       coalesce(sum(value)::text, 'unknown') ||
         case when bool_or(value is null) and bool_or(value is not null) then ' + unknown (made in-house)' else '' end as "value CHF",
       count(distinct vessel_id) as containers
from waste
group by 1, kind_id, dimension
order by 1, kind_id;

\echo
\echo Written off without throwing the container away (spills, evaporation)

select e.occurred_at as "when", container_label(q.container_id) as container, l.material_id as material,
       -q.amount as amount, q.dimension, coalesce(pa.name, ra.name) as who, e.note
from events_at(:'t', :'k') e
join quantity_entry q on q.event_id = e.id and q.reason = 'loss'
join lot l on l.id = q.lot_id
left join actor ra on ra.id = e.recorded_by
left join actor pa on pa.id = e.performed_by
where e.occurred_at >= :'from'
order by e.occurred_at;

drop table waste;
