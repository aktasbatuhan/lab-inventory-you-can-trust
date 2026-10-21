-- Everything the lab reads is calculated here from facts and rules. Nothing in
-- this file stores a value.

create function container_label(c bigint) returns text language sql stable as $$
  select coalesce(
    case when x.plate_id is not null then container_label(x.plate_id) || ' ' || x.position end,
    x.name,
    x.type_id || ' #' || x.id)
  from container x where x.id = c
$$;

-- How much of each lot is in each container.
create function balances(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, dimension text, amount numeric)
language sql stable as $$
  select q.container_id, q.lot_id, q.dimension, sum(q.amount)
  from events_at(t, k) e join quantity_entry q on q.event_id = e.id
  group by 1, 2, 3
  having sum(q.amount) <> 0
$$;

-- The latest exit (thrown away or shipped) of each container, if any.
create function exits(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, kind text, exited_at timestamptz, event_id bigint, source text)
language sql stable as $$
  select distinct on (x.container_id) x.container_id, x.kind, e.occurred_at, e.id, e.source
  from events_at(t, k) e join container_exit x on x.event_id = e.id
  order by x.container_id, e.occurred_at desc, e.id desc
$$;

-- Where each container was, as a list of time spans. A well sits in its plate
-- forever; anything else sits where it was last put, until it's moved again or leaves.
create function parent_spans(k timestamptz default now())
returns table (container_id bigint, parent_id bigint, slot text, from_at timestamptz, to_at timestamptz, source text)
language sql stable as $$
  with timeline as (
    select p.container_id, p.parent_id, p.position, e.occurred_at, e.id, e.source
    from events_at('infinity', k) e join placement p on p.event_id = e.id
    union all
    select x.container_id, null, null, e.occurred_at, e.id, e.source
    from events_at('infinity', k) e join container_exit x on x.event_id = e.id
  ),
  spans as (
    select container_id, parent_id, position, occurred_at as from_at,
           coalesce(lead(occurred_at) over (partition by container_id order by occurred_at, id), 'infinity') as to_at,
           source
    from timeline
  )
  select container_id, parent_id, position, from_at, to_at, source from spans where parent_id is not null
  union all
  select id, plate_id, position, '-infinity', 'infinity', 'structure' from container where plate_id is not null
$$;

-- What storage condition each container was in, over time. A tube takes the
-- condition of the nearest place above it: tube in box in rack in a -80 freezer.
create function condition_spans(k timestamptz default now())
returns table (container_id bigint, condition text, from_at timestamptz, to_at timestamptz)
language sql stable as $$
  with recursive ps as (select * from parent_spans(k)),
  cs (container_id, condition, from_at, to_at, depth) as (
    select id, condition, '-infinity'::timestamptz, 'infinity'::timestamptz, 0
    from container where condition is not null
    union all
    select ps.container_id, cs.condition, greatest(ps.from_at, cs.from_at), least(ps.to_at, cs.to_at), cs.depth + 1
    from ps
    join cs on cs.container_id = ps.parent_id
    join container c on c.id = ps.container_id and c.condition is null
    where greatest(ps.from_at, cs.from_at) < least(ps.to_at, cs.to_at) and cs.depth < 15
  )
  select container_id, condition, from_at, to_at from cs
$$;

-- The same, with back-to-back spans in the same condition joined into one stretch.
create function condition_stretches(k timestamptz default now())
returns table (container_id bigint, condition text, from_at timestamptz, to_at timestamptz)
language sql stable as $$
  with s as (
    select *,
      case when lag(condition) over w = condition and lag(to_at) over w = from_at then 0 else 1 end as brk
    from condition_spans(k)
    window w as (partition by container_id order by from_at)
  ),
  g as (select *, sum(brk) over (partition by container_id order by from_at) as grp from s)
  select container_id, condition, min(from_at), max(to_at) from g group by container_id, condition, grp
$$;

-- Every moment a container came out of the freezer.
create function thaw_moments(k timestamptz default now())
returns table (container_id bigint, thawed_at timestamptz)
language sql stable as $$
  select container_id, from_at from (
    select *, lag(condition) over (partition by container_id order by from_at) as prev
    from condition_stretches(k)
  ) s
  where prev in ('minus80', 'minus20') and condition not in ('minus80', 'minus20')
$$;

-- Where a lot in a container came from: the source container of the first
-- transfer that brought it in.
create function first_source(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, source_container_id bigint, arrived_at timestamptz)
language sql stable as $$
  select distinct on (i.container_id, i.lot_id) i.container_id, i.lot_id, o.container_id, e.occurred_at
  from events_at(t, k) e
  join quantity_entry i on i.event_id = e.id and i.amount > 0
  left join quantity_entry o on o.event_id = e.id and o.amount < 0 and o.lot_id = i.lot_id and o.container_id <> i.container_id
  order by i.container_id, i.lot_id, e.occurred_at, e.id, o.container_id
$$;

-- Freeze-thaw cycles a lot has been through in a container, including the ones
-- it went through in the tubes it was poured from before.
create function lot_thaws(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, thaws bigint)
language sql stable as $$
  with recursive fs as (select * from first_source(t, k)),
  tm as (select * from thaw_moments(k)),
  chain (container_id, lot_id, node_id, cutoff, depth) as (
    select b.container_id, b.lot_id, b.container_id, t, 0
    from (select distinct container_id, lot_id from balances(t, k)) b
    union all
    select ch.container_id, ch.lot_id, fs.source_container_id, fs.arrived_at, ch.depth + 1
    from chain ch
    join fs on fs.container_id = ch.node_id and fs.lot_id = ch.lot_id
    where fs.source_container_id is not null and ch.depth < 20
  )
  select ch.container_id, ch.lot_id,
         sum((select count(*) from tm where tm.container_id = ch.node_id and tm.thawed_at <= ch.cutoff))::bigint
  from chain ch
  group by 1, 2
$$;

-- Labels on containers. A barcode is live while it's attached and its container hasn't left.
create function live_labels(t timestamptz default now(), k timestamptz default now())
returns table (barcode text, container_id bigint, attached_at timestamptz)
language sql stable as $$
  select l.barcode, l.container_id, l.occurred_at
  from (
    select distinct on (l.barcode, l.container_id) l.barcode, l.container_id, l.action, e.occurred_at
    from events_at(t, k) e join label l on l.event_id = e.id
    order by l.barcode, l.container_id, e.occurred_at desc, e.id desc
  ) l
  where l.action = 'attach'
    and not exists (select 1 from exits(t, k) x where x.container_id = l.container_id)
$$;

create function barcode_clashes(t timestamptz default now(), k timestamptz default now())
returns table (barcode text, container_id bigint)
language sql stable as $$
  select barcode, container_id from live_labels(t, k)
  where barcode in (select barcode from live_labels(t, k) group by barcode having count(*) > 1)
$$;

-- Where each container is, how we know, and how sure we are.
create function location(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, path text, top_place_id bigint, status text,
               last_confirmed_at timestamptz, last_confirmed_how text)
language sql stable as $$
  with recursive ps as (select * from parent_spans(k) where from_at <= t and t < to_at),
  live as (select c.* from container c join events_at(t, k) e on e.id = c.created_event_id),
  up (container_id, node_id, depth, parts) as (
    select id, id, 0, array[]::text[] from live
    union all
    select up.container_id, ps.parent_id, up.depth + 1,
           array[container_label(ps.parent_id) || coalesce(' @' || ps.slot, '')] || up.parts
    from up join ps on ps.container_id = up.node_id
    where up.depth < 15
  ),
  top as (select distinct on (container_id) * from up order by container_id, depth desc),
  confirmations as (
    select s.container_id, e.occurred_at as at, 'scanned' as how
    from events_at(t, k) e join sighting s on s.event_id = e.id
    union all
    select p.container_id, e.occurred_at, case e.source when 'robot_log' then 'moved by robot' else 'moved with a scan' end
    from events_at(t, k) e join placement p on p.event_id = e.id where e.source in ('scan', 'robot_log')
    union all
    select cl.container_id, e.occurred_at, 'found in a count'
    from events_at(t, k) e join count_line cl on cl.event_id = e.id where cl.found
  ),
  conf as (
    select distinct on (container_id) container_id, at, how from confirmations
    order by container_id, at desc
  ),
  not_found as (
    select cl.container_id, max(e.occurred_at) as at
    from events_at(t, k) e join count_line cl on cl.event_id = e.id where not cl.found
    group by 1
  )
  select l.id,
         nullif(array_to_string(top.parts, ' > '), ''),
         case when top.depth > 0 then top.node_id end,
         case
           when x.kind = 'discard' then 'discarded'
           when x.kind = 'ship' then 'shipped'
           when ct.category in ('place') or l.condition is not null then 'fixed place'
           when nf.at is not null and nf.at > coalesce(conf.at, '-infinity') then 'uncertain'
           when top.depth = 0 then 'not placed'
           else 'placed'
         end,
         conf.at, conf.how
  from live l
  join container_type ct on ct.id = l.type_id
  join top on top.container_id = l.id
  left join conf on conf.container_id = l.id
  left join not_found nf on nf.container_id = l.id
  left join exits(t, k) x on x.container_id = l.id
$$;

-- QC state of each lot. Only kinds that need QC can be pending or failed.
create function lot_qc(t timestamptz default now(), k timestamptz default now())
returns table (lot_id bigint, status text, decided_at timestamptz, decided_by_event bigint)
language sql stable as $$
  select l.id,
         case when not mk.needs_qc then 'not required' else coalesce(q.outcome, 'pending') end,
         q.occurred_at, q.event_id
  from lot l
  join material m on m.id = l.material_id
  join material_kind mk on mk.id = m.kind_id
  left join lateral (
    select r.outcome, e.occurred_at, e.id as event_id
    from events_at(t, k) e join qc_result r on r.event_id = e.id
    where r.lot_id = l.id
    order by e.occurred_at desc, e.id desc limit 1
  ) q on true
$$;

create function active_holds(t timestamptz default now(), k timestamptz default now())
returns table (hold_event_id bigint, lot_id bigint, container_id bigint, reason text, placed_at timestamptz)
language sql stable as $$
  select h.event_id, h.lot_id, h.container_id, h.reason, e.occurred_at
  from events_at(t, k) e join hold_placed h on h.event_id = e.id
  where not exists (
    select 1 from events_at(t, k) e2 join hold_released r on r.event_id = e2.id
    where r.hold_event_id = h.event_id)
$$;

-- The shelf-life rules that apply to each lot at time t. For each clock and set
-- of storage conditions, the most specific rule wins, then the newest version.
create function rules_for_lots(t timestamptz default now(), k timestamptz default now())
returns table (lot_id bigint, rule_id bigint, clock text, conditions text[], duration interval, scope text)
language sql stable as $$
  select distinct on (l.id, r.clock, r.conditions)
         l.id, r.id, r.clock, r.conditions, r.duration,
         case when r.product_id is not null then 'product' when r.material_id is not null then 'material' else 'kind' end
  from lot l
  join material m on m.id = l.material_id
  join shelf_life_rule r on r.product_id = l.product_id or r.material_id = l.material_id or r.material_kind_id = m.kind_id
  where r.effective_from <= t and r.recorded_at <= k
  order by l.id, r.clock, r.conditions,
           case when r.product_id is not null then 3 when r.material_id is not null then 2 else 1 end desc,
           r.effective_from desc, r.id desc
$$;

-- Every expiry clock running on each lot in each container. The earliest one wins.
create function expiry_clocks(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, clock text, rule_id bigint, started_at timestamptz, expires_at timestamptz)
language sql stable as $$
  with held as (select distinct container_id, lot_id from balances(t, k)),
  lots as (
    select l.id, l.supplier_expiry, e.occurred_at as origin_at
    from lot l join event e on e.id = l.created_event_id
  ),
  rules as (select * from rules_for_lots(t, k)),
  here as (select * from condition_stretches(k) where from_at <= t and t < to_at),
  arrived as (select container_id, lot_id, arrived_at from first_source(t, k))
  select h.container_id, h.lot_id, 'supplier expiry date', null::bigint, null::timestamptz, lo.supplier_expiry::timestamptz
  from held h join lots lo on lo.id = h.lot_id
  where lo.supplier_expiry is not null
  union all
  select h.container_id, h.lot_id, 'since ' || case when l.origin = 'made' then 'made' else 'received' end,
         r.rule_id, lo.origin_at, lo.origin_at + r.duration
  from held h
  join lots lo on lo.id = h.lot_id
  join lot l on l.id = h.lot_id
  join rules r on r.lot_id = h.lot_id and r.clock = 'since_origin' and r.duration is not null
  union all
  select h.container_id, h.lot_id, 'kept in ' || s.condition,
         r.rule_id, greatest(s.from_at, a.arrived_at), greatest(s.from_at, a.arrived_at) + r.duration
  from held h
  join here s on s.container_id = h.container_id
  join rules r on r.lot_id = h.lot_id and r.clock = 'in_condition' and s.condition = any(r.conditions) and r.duration is not null
  left join arrived a on a.container_id = h.container_id and a.lot_id = h.lot_id
$$;

create function expiry(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, expires_at timestamptz, clock text, rule_id bigint)
language sql stable as $$
  select distinct on (container_id, lot_id) container_id, lot_id, expires_at, clock, rule_id
  from expiry_clocks(t, k)
  order by container_id, lot_id, expires_at
$$;

create function thaw_limits(t timestamptz default now(), k timestamptz default now())
returns table (lot_id bigint, max_thaws int, rule_id bigint, scope text)
language sql stable as $$
  select distinct on (l.id) l.id, r.max_thaws, r.id,
         case when r.product_id is not null then 'product' when r.material_id is not null then 'material' else 'kind' end
  from lot l
  join material m on m.id = l.material_id
  join thaw_limit_rule r on r.product_id = l.product_id or r.material_id = l.material_id or r.material_kind_id = m.kind_id
  where r.effective_from <= t and r.recorded_at <= k
  order by l.id,
           case when r.product_id is not null then 3 when r.material_id is not null then 2 else 1 end desc,
           r.effective_from desc, r.id desc
$$;

-- Exists versus usable. Every row is something we hold (or held until it was
-- thrown away); `reasons` says why it can't be used, `warnings` what to look at.
create function usable(t timestamptz default now(), k timestamptz default now())
returns table (container_id bigint, lot_id bigint, material_id text, dimension text,
               held numeric, usable numeric, reasons text[], warnings text[],
               expires_at timestamptz, expiry_clock text, thaws bigint)
language sql stable as $$
  with b as (select * from balances(t, k)),
  holder as (
    select c.id, coalesce(c.plate_id, c.id) as vessel_id, ct.dead_volume_ul
    from container c join container_type ct on ct.id = c.type_id
  ),
  vol_total as (
    select container_id, sum(amount) as total from b where dimension = 'volume' and amount > 0 group by 1
  ),
  ex as (select * from exits(t, k)),
  qc as (select * from lot_qc(t, k)),
  hl as (select * from active_holds(t, k)),
  xp as (select * from expiry(t, k)),
  loc as (select container_id, status from location(t, k)),
  clash as (select distinct container_id from barcode_clashes(t, k)),
  th as (select * from lot_thaws(t, k)),
  lim as (select * from thaw_limits(t, k)),
  rows as (
    select b.*, l.material_id, h.vessel_id,
      case when b.dimension = 'volume' and b.amount > 0
           then h.dead_volume_ul * b.amount / nullif(vt.total, 0) else 0 end as dead_share,
      array_remove(array[
        case (select kind from ex where ex.container_id = h.vessel_id) when 'discard' then 'discarded' when 'ship' then 'shipped' end,
        case when b.amount < 0 then 'negative balance' end,
        case qc.status when 'pending' then 'waiting for QC' when 'fail' then 'failed QC' end,
        case when exists (select 1 from hl where hl.lot_id = b.lot_id) then 'lot on hold' end,
        case when exists (select 1 from hl where hl.container_id in (b.container_id, h.vessel_id)) then 'container on hold' end,
        case when xp.expires_at <= t then 'expired' end,
        case when exists (select 1 from clash where clash.container_id = h.vessel_id) then 'barcode clash' end,
        case when (select status from loc where loc.container_id = h.vessel_id) = 'uncertain' then 'location uncertain' end,
        case when b.dimension = 'volume' and b.amount > 0 and vt.total <= h.dead_volume_ul then 'below dead volume' end
      ], null) as reasons,
      array_remove(array[
        case when lim.max_thaws is not null and th.thaws > lim.max_thaws
             then 'thawed ' || th.thaws || ' times, limit is ' || lim.max_thaws end,
        case when xp.expires_at > t and xp.expires_at <= t + interval '14 days' then 'expires within 14 days' end
      ], null) as warnings,
      xp.expires_at, xp.clock, coalesce(th.thaws, 0) as thaws
    from b
    join lot l on l.id = b.lot_id
    join holder h on h.id = b.container_id
    left join vol_total vt on vt.container_id = b.container_id
    left join qc on qc.lot_id = b.lot_id
    left join xp on xp.container_id = b.container_id and xp.lot_id = b.lot_id
    left join th on th.container_id = b.container_id and th.lot_id = b.lot_id
    left join lim on lim.lot_id = b.lot_id
  )
  select container_id, lot_id, material_id, dimension, amount,
         case when cardinality(reasons) = 0 then greatest(amount - dead_share, 0) else 0 end,
         reasons, warnings, expires_at, clock, thaws
  from rows
$$;

-- Lineage. Lots made from a lot, at any depth, and the other way round.
create function lot_descendants(root bigint, k timestamptz default now())
returns table (lot_id bigint, depth int) language sql stable as $$
  with recursive d (lot_id, depth) as (
    select root, 0
    union
    select lp.lot_id, d.depth + 1
    from d join lot_parent lp on lp.parent_lot_id = d.lot_id
    join lot l on l.id = lp.lot_id
    join events_at('infinity', k) e on e.id = l.created_event_id
  )
  select lot_id, min(depth) from d group by 1
$$;

create function lot_ancestors(root bigint, k timestamptz default now())
returns table (lot_id bigint, depth int) language sql stable as $$
  with recursive a (lot_id, depth) as (
    select root, 0
    union
    select lp.parent_lot_id, a.depth + 1 from a join lot_parent lp on lp.lot_id = a.lot_id
  )
  select lot_id, min(depth) from a group by 1
$$;

-- Things that need a person to look at them. All calculated; a flag goes away
-- when the facts behind it are corrected.
create function flags(t timestamptz default now(), k timestamptz default now())
returns table (flag text, container_id bigint, lot_id bigint, detail text)
language sql stable as $$
  select 'negative balance', container_id, lot_id,
         'records say ' || amount || ' ' || dimension || ', more was taken than was there'
  from balances(t, k) where amount < 0
  union all
  select 'barcode clash', container_id, null, 'barcode ' || barcode || ' is on more than one live container'
  from barcode_clashes(t, k)
  union all
  select 'seen after it left', s.container_id, null,
         'scanned at ' || e.occurred_at || ' but recorded as ' || x.kind || ' at ' || x.exited_at
  from events_at(t, k) e join sighting s on s.event_id = e.id
  join exits(t, k) x on x.container_id = s.container_id and e.occurred_at > x.exited_at
  union all
  select 'possible duplicate delivery', null, l2.id,
         'lot ' || l2.id || ' looks like lot ' || l1.id || ' (same product, supplier lot and amount, received within 3 days)'
  from lot l1
  join events_at(t, k) e1 on e1.id = l1.created_event_id
  join lot l2 on l2.product_id = l1.product_id and l2.supplier_lot_code = l1.supplier_lot_code and l2.id > l1.id
  join events_at(t, k) e2 on e2.id = l2.created_event_id
  where l1.origin = 'received' and abs(extract(epoch from e2.occurred_at - e1.occurred_at)) < 3 * 86400
    and (select sum(amount) from quantity_entry where lot_id = l1.id and reason = 'receive')
      = (select sum(amount) from quantity_entry where lot_id = l2.id and reason = 'receive')
  union all
  select 'robot run incomplete', pt.to_container_id, pt.lot_id,
         'run ' || pt.run_id || ' step ' || pt.step || ' was planned but the robot log has no record of it'
  from planned_transfer pt
  where exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.kind = 'run finished')
    and not exists (select 1 from events_at(t, k) e where e.run_id = pt.run_id and e.run_step = pt.step)
  union all
  select 'location uncertain', container_id, null, 'not found in the last count and not seen since'
  from location(t, k) where status = 'uncertain'
  union all
  select 'over thaw limit', container_id, lot_id, w
  from usable(t, k), unnest(warnings) w where w like 'thawed %'
$$;
