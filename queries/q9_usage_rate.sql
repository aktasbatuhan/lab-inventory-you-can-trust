-- How fast are we using it, and how long will what we have last?
--
-- Who asks: whoever orders targets, before the supplier's cut-off.
-- Why: found by the agent lab. The procurement agent asked four days running
-- how much target a run uses and was told nothing, so every order was a guess.
-- Stock alone can't answer "should I order today?"; stock and rate together can.
-- A trustworthy answer: how much left the stock tubes each week (taken into
-- plates, used in runs, or lost; splitting into aliquots doesn't count, the
-- liquid is still in stock), how many runs it went to, the average, what's
-- usable now, and how many weeks that covers at the recent rate. When there's
-- no history yet, it says so instead of showing zero.
--
-- Settings: material (a pattern, default 'target:%'), weeks (default 4), t, k.

\if :{?material}
\else
  \set material 'target:%'
\endif
\if :{?weeks}
\else
  \set weeks 4
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
\echo Use of :material over the last :weeks weeks, as of :t, as recorded by :k

with drawn as (
  -- liquid leaving a stock tube, unless it went into another stock tube
  select l.material_id, e.occurred_at, e.run_id, -q.amount as amount
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id and q.amount < 0
  join container c on c.id = q.container_id
  join container_type ct on ct.id = c.type_id and ct.category = 'tube'
  join lot l on l.id = q.lot_id
  where l.material_id like :'material'
    and q.dimension = 'volume'
    and e.occurred_at > :'t'::timestamptz - make_interval(weeks => :weeks)
    and not exists (
      select 1 from quantity_entry q2 join container c2 on c2.id = q2.container_id
      join container_type ct2 on ct2.id = c2.type_id
      where q2.event_id = e.id and q2.amount > 0 and q2.lot_id = q.lot_id and ct2.category = 'tube')
),
weekly as (
  select material_id, date_trunc('week', occurred_at) as week, sum(amount) as used, count(distinct run_id) as runs
  from drawn group by 1, 2
),
now_usable as (
  select material_id, sum(usable) as usable from usable(:'t', :'k') where material_id like :'material' group by 1
)
select coalesce(n.material_id, w.material_id) as material,
       round(coalesce(sum(w.used), 0), 1) as "used, µL",
       coalesce(sum(w.runs), 0) as runs,
       round(coalesce(sum(w.used), 0) / :weeks, 1) as "per week, µL",
       round(n.usable, 1) as "usable now, µL",
       case when coalesce(sum(w.used), 0) = 0 then 'no use recorded in this window, so no rate yet'
            else round(n.usable / (sum(w.used) / :weeks), 1) || ' weeks at this rate' end as "covers"
from now_usable n
full join weekly w on w.material_id = n.material_id
group by 1, n.usable
order by 1;

\echo
\echo Week by week

with drawn as (
  select l.material_id, e.occurred_at, e.run_id, -q.amount as amount
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id and q.amount < 0
  join container c on c.id = q.container_id
  join container_type ct on ct.id = c.type_id and ct.category = 'tube'
  join lot l on l.id = q.lot_id
  where l.material_id like :'material'
    and q.dimension = 'volume'
    and e.occurred_at > :'t'::timestamptz - make_interval(weeks => :weeks)
    and not exists (
      select 1 from quantity_entry q2 join container c2 on c2.id = q2.container_id
      join container_type ct2 on ct2.id = c2.type_id
      where q2.event_id = e.id and q2.amount > 0 and q2.lot_id = q.lot_id and ct2.category = 'tube')
)
select material_id as material, to_char(date_trunc('week', occurred_at), 'YYYY-MM-DD') as "week of",
       round(sum(amount), 1) as "used, µL", count(distinct run_id) as runs
from drawn group by 1, 2 order by 1, 2;
