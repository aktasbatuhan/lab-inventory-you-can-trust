-- Numbers for a re-run, as they will be on the day of the re-run.
--
-- Who asks: whoever plans the re-run after the data reviewer sends part of a
-- screen back (here: some designs of EXP-0457's BLI step, re-run on the 28th).
-- Why: the brief says re-run planners need numbers they can trust. "Usable
-- today" is the wrong number: the expression plate is good for 14 days and
-- loading buffer for a week, so what's fine today may be expired on the day.
-- A trustworthy answer: for each material the step used, how much it took
-- last time, how much is usable today, how much will still be usable on the
-- re-run date, and if that's nothing, why. Shared materials (target, buffers,
-- sensors) count every lot we hold, not only the one used last time, because
-- the re-run doesn't have to use the same bottle.
--
-- Note: for materials shared by all designs, "took last time" is for the
-- whole step, not only the designs being re-run.
--
-- Settings: experiment (default 'EXP-0457'), step (the run's protocol,
-- default 'BLI binding screen'), designs (comma separated, default four of
-- the 24), rerun_at (default 28 Oct 2026, 09:00), t, k.

\if :{?experiment}
\else
  \set experiment 'EXP-0457'
\endif
\if :{?step}
\else
  \set step 'BLI binding screen'
\endif
\if :{?designs}
\else
  \set designs 'D-003,D-010,D-017,D-021'
\endif
\if :{?rerun_at}
\else
  \set rerun_at '2026-10-28 09:00'
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
\echo Re-run of :step for :experiment, designs :designs, planned for :rerun_at
\echo Today is :t, record as written by :k

with step_runs as (
  select r.id from run r
  join events_at(:'t', :'k') e on e.id = r.created_event_id
  where r.experiment_ref = :'experiment' and r.protocol = :'step'
),
took as (
  select l.material_id, q.dimension, sum(-q.amount) as took
  from events_at(:'t', :'k') e
  join quantity_entry q on q.event_id = e.id
  join lot l on l.id = q.lot_id
  join material m on m.id = l.material_id
  where e.run_id in (select id from step_runs) and q.amount < 0
    and (m.attributes->>'design_id' is null
         or m.attributes->>'design_id' = any(string_to_array(:'designs', ',')))
  group by 1, 2
),
today as (
  select material_id, dimension, sum(usable) as usable
  from usable(:'t', :'k')
  where material_id in (select material_id from took) and not reasons && array['discarded', 'shipped']
  group by 1, 2
),
day_rows as (
  select * from usable(:'rerun_at', :'k')
  where material_id in (select material_id from took) and not reasons && array['discarded', 'shipped']
),
on_the_day as (
  select material_id, dimension, sum(usable) as usable,
         (select string_agg(distinct r, ', ') from day_rows d2, unnest(d2.reasons) r
          where d2.material_id = d.material_id and d2.dimension = d.dimension and d2.held > 0) as reasons,
         min(expires_at) filter (where usable > 0) as next_expiry
  from day_rows d
  group by 1, 2
)
select took.material_id as material,
       case took.dimension when 'volume' then 'µL' when 'mass' then 'µg' when 'count' then 'pieces' end as unit,
       round(took.took, 1) as "took last time",
       round(coalesce(today.usable, 0), 1) as "usable today",
       round(coalesce(d.usable, 0), 1) as "usable on the day",
       case when coalesce(d.usable, 0) >= took.took then 'enough'
            when coalesce(d.usable, 0) > 0 then 'short'
            else 'none' end as verdict,
       case when coalesce(d.usable, 0) < took.took then d.reasons end as "why not, on the day",
       d.next_expiry as "usable stock next expires"
from took
left join today on today.material_id = took.material_id and today.dimension = took.dimension
left join on_the_day d on d.material_id = took.material_id and d.dimension = took.dimension
order by verdict desc, material;
