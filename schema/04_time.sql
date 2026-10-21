-- Time travel.
--
-- Every calculated value takes two times:
--   t (as_of):    the moment in the lab we're asking about
--   k (known_at): how much of the record to believe, by when it was written down
--
-- "How much is in this tube now?"                      t = now,     k = now
-- "What did the system say last Tuesday?"              t = Tuesday, k = Tuesday
-- "What do we now know was really there last Tuesday?" t = Tuesday, k = now

-- Events that have been voided, as far as we knew at k. A correction can itself
-- be corrected, so we walk each chain of corrections from its newest end: the
-- newest stands, the one it voids falls, the one before that stands again, and so on.
create function voided_events(k timestamptz default now())
returns table (event_id bigint) language sql stable as $$
  with recursive v as (
    select id, voids_event_id from event
    where recorded_at <= k and voids_event_id is not null
  ),
  walk (id, lvl) as (
    select v.id, 0 from v
    where not exists (select 1 from v v2 where v2.voids_event_id = v.id)
    union all
    select v.voids_event_id, w.lvl + 1 from walk w join v on v.id = w.id
  )
  select id from walk where lvl % 2 = 1
$$;

-- The events that count: on record by k, happened by t, and not voided.
create function events_at(t timestamptz default now(), k timestamptz default now())
returns setof event language sql stable as $$
  select e.* from event e
  where e.recorded_at <= k
    and e.occurred_at <= t
    and e.id not in (select event_id from voided_events(k))
$$;
