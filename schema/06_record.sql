-- Recording facts.
--
-- These functions are how people, robots and imports write to the inventory.
-- Each one records one event and its lines. Most take an optional p_event: pass
-- the id of a correction event to attach the right lines to it instead of
-- starting a new event. That's how a wrong entry is replaced.
--
-- p_recorded is for replaying history (seed data, the simulation, late syncs).
-- When it's left out, the fact counts as written down the moment it happened.

create function new_event(
  p_kind text, p_at timestamptz, p_by text,
  p_source text default 'manual', p_note text default null,
  p_run bigint default null, p_step int default null, p_ref text default null,
  p_recorded timestamptz default null, p_voids bigint default null, p_performed text default null
) returns bigint language sql as $$
  insert into event (kind, occurred_at, recorded_at, recorded_by, performed_by, source,
                     run_id, run_step, external_ref, voids_event_id, note)
  values (p_kind, p_at, coalesce(p_recorded, p_at), p_by, p_performed, p_source,
          p_run, p_step, p_ref, p_voids, p_note)
  returning id
$$;

-- Void an event. Returns the correction event, so the right lines can be attached to it.
create function void(p_event bigint, p_by text, p_note text, p_recorded timestamptz default now(),
                     p_at timestamptz default null)
returns bigint language sql as $$
  select new_event('correction', coalesce(p_at, (select occurred_at from event where id = p_event)), p_by,
                   'manual', p_note, p_recorded => p_recorded, p_voids => p_event)
$$;

create function attach_label(p_container bigint, p_barcode text, p_at timestamptz, p_by text,
                             p_source text default 'scan', p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := coalesce(p_event, new_event('label', p_at, p_by, p_source, p_recorded => p_recorded));
begin
  -- Decision D3: a barcode can be on only one live container. Imports are let
  -- through so a clash that already exists in the lab shows up as a flag.
  if p_source <> 'import' and exists (
       select 1 from live_labels(p_at, 'infinity') l
       where l.barcode = p_barcode and l.container_id <> p_container) then
    raise exception 'barcode % is already on a live container', p_barcode;
  end if;
  insert into label (event_id, container_id, barcode, action) values (ev, p_container, p_barcode, 'attach');
  return ev;
end $$;

create function move(p_container bigint, p_into bigint, p_position text, p_at timestamptz, p_by text,
                     p_source text default 'scan', p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare
  ev bigint := coalesce(p_event, new_event('move', p_at, p_by, p_source, p_recorded => p_recorded));
  node bigint := p_into;
  i int := 0;
begin
  -- Nothing can end up inside itself.
  while node is not null and i < 20 loop
    if node = p_container then
      raise exception 'container % can''t be put inside itself', p_container;
    end if;
    select ps.parent_id into node from parent_spans('infinity') ps
    where ps.container_id = node and ps.from_at <= p_at and p_at < ps.to_at;
    i := i + 1;
  end loop;
  insert into placement (event_id, container_id, parent_id, position) values (ev, p_container, p_into, p_position);
  return ev;
end $$;

create function register_container(p_type text, p_at timestamptz, p_by text,
                                   p_barcode text default null, p_name text default null,
                                   p_condition text default null, p_into bigint default null,
                                   p_position text default null, p_source text default 'scan',
                                   p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare
  ev bigint := new_event('register', p_at, p_by, p_source, p_recorded => p_recorded);
  ct container_type;
  c bigint;
begin
  select * into ct from container_type where id = p_type;
  insert into container (type_id, name, condition, created_event_id)
  values (p_type, p_name, p_condition, ev) returning id into c;
  if ct.well_type_id is not null then
    insert into container (type_id, plate_id, position, created_event_id)
    select ct.well_type_id, c, chr(64 + r) || col, ev
    from generate_series(1, ct.grid_rows) r, generate_series(1, ct.grid_cols) col;
  end if;
  if p_barcode is not null then perform attach_label(c, p_barcode, p_at, p_by, p_source, ev); end if;
  if p_into is not null then perform move(c, p_into, p_position, p_at, p_by, p_source, ev); end if;
  return c;
end $$;

create function well(p_plate bigint, p_position text) returns bigint language sql stable as $$
  select id from container where plate_id = p_plate and position = p_position
$$;

-- A delivery arrives: one new lot (decision D2: each delivery is its own batch).
create function receive(p_product text, p_container bigint, p_amount numeric, p_dimension text,
                        p_at timestamptz, p_by text, p_supplier_lot text default null,
                        p_ref text default null, p_expiry date default null, p_coa jsonb default null,
                        p_price numeric default null, p_source text default 'manual',
                        p_recorded timestamptz default null, p_event bigint default null)
returns bigint language plpgsql as $$
declare
  ev bigint := coalesce(p_event, new_event('receive', p_at, p_by, p_source, p_ref => p_ref, p_recorded => p_recorded));
  l bigint;
begin
  insert into lot (material_id, origin, created_event_id, product_id, supplier_lot_code, supplier_expiry, coa, unit_price, currency)
  values ((select material_id from product where id = p_product), 'received', ev, p_product, p_supplier_lot,
          p_expiry, p_coa, p_price, case when p_price is not null then 'CHF' end)
  returning id into l;
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  values (ev, p_container, l, p_dimension, p_amount, 'receive');
  return l;
end $$;

-- Liquid (or powder, or pieces) moves from one container to another. The lot stays the same.
create function transfer(p_from bigint, p_to bigint, p_lot bigint, p_amount numeric, p_dimension text,
                         p_at timestamptz, p_by text, p_source text default 'manual',
                         p_run bigint default null, p_step int default null,
                         p_event bigint default null, p_recorded timestamptz default null,
                         p_note text default null)
returns bigint language plpgsql as $$
declare
  assumed event;
  ev bigint := p_event;
begin
  -- A robot log line that arrives for a step we had assumed (see finish_run)
  -- replaces the assumption instead of being refused as a duplicate.
  if ev is null and p_run is not null and p_step is not null and p_source <> 'rule' then
    select e.* into assumed from event e
    where e.run_id = p_run and e.run_step = p_step and e.source = 'rule'
      and e.id not in (select event_id from voided_events('infinity'));
    if assumed.id is not null then
      ev := void(assumed.id, p_by, 'robot log line arrived for step ' || p_step || ', replacing the assumed transfer',
                 greatest(coalesce(p_recorded, p_at), assumed.recorded_at), p_at);
    end if;
  end if;
  if ev is null then
    ev := new_event('transfer', p_at, p_by, p_source, p_note, p_run, p_step, p_recorded => p_recorded);
  end if;
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason) values
    (ev, p_from, p_lot, p_dimension, -p_amount, 'transfer'),
    (ev, p_to,   p_lot, p_dimension,  p_amount, 'transfer');
  return ev;
end $$;

-- Split one tube into many: new tubes are registered and filled in one event.
-- Returns the new tubes in order.
create function split(p_from bigint, p_lot bigint, p_count int, p_each numeric, p_tube_type text,
                      p_at timestamptz, p_by text, p_barcode_prefix text default null,
                      p_into bigint default null, p_recorded timestamptz default null)
returns bigint[] language plpgsql as $$
declare
  ev bigint;
  tubes bigint[] := '{}';
  c bigint;
begin
  for i in 1 .. p_count loop
    c := register_container(p_tube_type, p_at, p_by,
                            case when p_barcode_prefix is not null then p_barcode_prefix || lpad(i::text, 3, '0') end,
                            p_into => p_into, p_position => case when p_into is not null then 'slot ' || i end,
                            p_recorded => p_recorded);
    tubes := tubes || c;
  end loop;
  ev := new_event('split', p_at, p_by, 'manual', p_recorded => p_recorded);
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  values (ev, p_from, p_lot, 'volume', -(p_count * p_each), 'transfer');
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  select ev, t, p_lot, 'volume', p_each, 'transfer' from unnest(tubes) t;
  return tubes;
end $$;

-- Make something new from other lots: a buffer from its components, protein
-- from DNA. p_inputs is a list of {"container":…, "lot":…, "amount":…, "dimension":…}.
create function make(p_material text, p_inputs jsonb, p_out_container bigint, p_out_amount numeric,
                     p_out_dimension text, p_at timestamptz, p_by text, p_source text default 'manual',
                     p_run bigint default null, p_step int default null,
                     p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare
  ev bigint := coalesce(p_event, new_event('make', p_at, p_by, p_source, p_run => p_run, p_step => p_step, p_recorded => p_recorded));
  l bigint;
  i jsonb;
begin
  insert into lot (material_id, origin, created_event_id) values (p_material, 'made', ev) returning id into l;
  for i in select * from jsonb_array_elements(p_inputs) loop
    insert into lot_parent (lot_id, parent_lot_id) values (l, (i->>'lot')::bigint) on conflict do nothing;
    insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
    values (ev, (i->>'container')::bigint, (i->>'lot')::bigint, coalesce(i->>'dimension', 'volume'), -(i->>'amount')::numeric, 'make');
  end loop;
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  values (ev, p_out_container, l, p_out_dimension, p_out_amount, 'make');
  return l;
end $$;

create function consume(p_container bigint, p_lot bigint, p_amount numeric, p_dimension text,
                        p_at timestamptz, p_by text, p_source text default 'manual',
                        p_run bigint default null, p_step int default null, p_note text default null,
                        p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := coalesce(p_event, new_event('consume', p_at, p_by, p_source, p_note, p_run, p_step, p_recorded => p_recorded));
begin
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  values (ev, p_container, p_lot, p_dimension, -p_amount, 'consume');
  return ev;
end $$;

-- Liquid gone without being used: evaporation, a spill, liquid left in tips.
create function lose(p_container bigint, p_lot bigint, p_amount numeric, p_dimension text,
                     p_at timestamptz, p_by text, p_note text,
                     p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := coalesce(p_event, new_event('loss', p_at, p_by, 'manual', p_note, p_recorded => p_recorded));
begin
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  values (ev, p_container, p_lot, p_dimension, -p_amount, 'loss');
  return ev;
end $$;

create function scan(p_container bigint, p_at timestamptz, p_by text, p_code text default null,
                     p_seen_in bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('scan', p_at, p_by, 'scan', p_recorded => p_recorded);
begin
  insert into sighting (event_id, container_id, scanned_code, seen_in_id) values (ev, p_container, p_code, p_seen_in);
  return ev;
end $$;

create function discard(p_container bigint, p_at timestamptz, p_by text, p_source text default 'scan',
                        p_note text default null, p_event bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := coalesce(p_event, new_event('discard', p_at, p_by, p_source, p_note, p_recorded => p_recorded));
begin
  insert into container_exit (event_id, container_id, kind) values (ev, p_container, 'discard');
  return ev;
end $$;

create function ship(p_container bigint, p_destination text, p_at timestamptz, p_by text,
                     p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('ship', p_at, p_by, 'scan', p_recorded => p_recorded);
begin
  insert into container_exit (event_id, container_id, kind, destination) values (ev, p_container, 'ship', p_destination);
  return ev;
end $$;

create function qc(p_lot bigint, p_outcome text, p_assay text, p_at timestamptz, p_by text,
                   p_measured jsonb default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('qc', p_at, p_by, 'manual', p_recorded => p_recorded);
begin
  insert into qc_result (event_id, lot_id, assay, outcome, measured) values (ev, p_lot, p_assay, p_outcome, p_measured);
  return ev;
end $$;

create function hold(p_reason text, p_at timestamptz, p_by text, p_lot bigint default null,
                     p_container bigint default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('hold', p_at, p_by, 'manual', p_reason, p_recorded => p_recorded);
begin
  insert into hold_placed (event_id, lot_id, container_id, reason) values (ev, p_lot, p_container, p_reason);
  return ev;
end $$;

create function release(p_hold bigint, p_at timestamptz, p_by text, p_note text,
                        p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('release', p_at, p_by, 'manual', p_note, p_recorded => p_recorded);
begin
  insert into hold_released (event_id, hold_event_id) values (ev, p_hold);
  return ev;
end $$;

-- A physical count. p_lines: [{"container":…, "found":true|false, "amount":…, "dimension":…}].
-- Decision D4: a count changes how sure we are of locations straight away, but
-- amounts only change through approve_count.
create function count_place(p_lines jsonb, p_at timestamptz, p_by text, p_note text default null,
                            p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare
  ev bigint := new_event('count', p_at, p_by, 'scan', p_note, p_recorded => p_recorded);
  i jsonb;
begin
  for i in select * from jsonb_array_elements(p_lines) loop
    insert into count_line (event_id, container_id, found, observed_amount, dimension)
    values (ev, (i->>'container')::bigint, (i->>'found')::boolean, (i->>'amount')::numeric, i->>'dimension');
  end loop;
  return ev;
end $$;

-- A person accepts what a count found: each line sets the amount to what was counted.
create function approve_count(p_count bigint, p_at timestamptz, p_by text, p_note text,
                              p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('count approved', p_at, p_by, 'manual', p_note || ' (count ' || p_count || ')', p_recorded => p_recorded);
begin
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason)
  select ev, b.container_id, b.lot_id, b.dimension,
         case when cl.found then cl.observed_amount - b.amount else -b.amount end, 'adjust'
  from count_line cl
  join balances(p_at, coalesce(p_recorded, p_at)) b on b.container_id = cl.container_id
  where cl.event_id = p_count
    and (not cl.found or (cl.observed_amount is not null and cl.dimension = b.dimension))
    and (case when cl.found then cl.observed_amount - b.amount else -b.amount end) <> 0;
  return ev;
end $$;

create function start_run(p_protocol text, p_at timestamptz, p_by text, p_instrument bigint default null,
                          p_experiment text default null, p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare
  ev bigint := new_event('run started', p_at, p_by, 'manual', p_recorded => p_recorded);
  r bigint;
begin
  insert into run (protocol, instrument_id, experiment_ref, created_event_id) values (p_protocol, p_instrument, p_experiment, ev)
  returning id into r;
  return r;
end $$;

-- Principle 3 / decisions D6 and D10: when a run ends, what the protocol says
-- happens next is recorded for it, marked as coming from a rule, so the
-- exceptions are the only thing anyone has to report.
--   * A run that finished normally did its planned steps. Steps with no robot
--     log line are recorded as assumed transfers and flagged; if the log line
--     turns up later it replaces the assumption.
--   * An aborted run assumes nothing: missing steps are flagged at both ends.
--   * Single-use plates used in the run, or sitting in its instrument while it
--     ran, are recorded as thrown away.
create function finish_run(p_run bigint, p_at timestamptz, p_by text, p_recorded timestamptz default null,
                           p_outcome text default 'completed')
returns bigint language plpgsql as $$
declare
  ev bigint := new_event(case p_outcome when 'aborted' then 'run aborted' else 'run finished' end,
                         p_at, p_by, 'manual', p_run => p_run, p_recorded => p_recorded);
  defaults bigint;
  s record;
  vessels bigint[];
begin
  if p_outcome not in ('completed', 'aborted') then
    raise exception 'a run ends as completed or aborted, not %', p_outcome;
  end if;

  if p_outcome = 'completed' then
    for s in
      select pt.* from planned_transfer pt
      where pt.run_id = p_run
        and not exists (select 1 from event e where e.run_id = p_run and e.run_step = pt.step)
      order by pt.step
    loop
      perform transfer(s.from_container_id, s.to_container_id,
                       coalesce(s.lot_id, (select b.lot_id from balances(p_at, 'infinity') b
                                           where b.container_id = s.from_container_id and b.amount > 0
                                           order by b.amount desc limit 1)),
                       s.amount, s.dimension, p_at, 'rule:protocol-defaults', 'rule', p_run, s.step,
                       p_recorded => p_recorded,
                       p_note => 'assumed from the worklist: the robot log has no line for this step');
    end loop;
  end if;

  select array_agg(distinct v.vessel) into vessels
  from (
    select coalesce(c.plate_id, c.id) as vessel
    from event e join quantity_entry q on q.event_id = e.id join container c on c.id = q.container_id
    where e.run_id = p_run
    union
    select ps.container_id
    from run r
    join event rs on rs.id = r.created_event_id
    join parent_spans('infinity') ps on ps.parent_id = r.instrument_id
    where r.id = p_run and ps.from_at < p_at and ps.to_at > rs.occurred_at
  ) v
  join container c on c.id = v.vessel
  join container_type ct on ct.id = c.type_id
  where ct.single_use and not exists (select 1 from exits(p_at, 'infinity') x where x.container_id = v.vessel);

  if vessels is not null then
    defaults := new_event('discard', p_at, 'rule:protocol-defaults', 'rule',
                          'single-use container thrown away after run ' || p_run, p_recorded => p_recorded);
    insert into container_exit (event_id, container_id, kind)
    select defaults, unnest(vessels), 'discard';
  end if;
  return ev;
end $$;

-- Dissolve dry material: the same lot goes from a mass to a volume. The solvent
-- is used up and the concentration is recorded as a measurement, so the amount
-- in µg stays recoverable without guessing.
create function reconstitute(p_container bigint, p_lot bigint, p_mass_ug numeric, p_volume_ul numeric,
                             p_solvent_container bigint, p_solvent_lot bigint,
                             p_at timestamptz, p_by text, p_source text default 'manual',
                             p_run bigint default null, p_step int default null,
                             p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('reconstitute', p_at, p_by, p_source, p_run => p_run, p_step => p_step, p_recorded => p_recorded);
begin
  insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason) values
    (ev, p_container, p_lot, 'mass', -p_mass_ug, 'make'),
    (ev, p_container, p_lot, 'volume', p_volume_ul, 'make'),
    (ev, p_solvent_container, p_solvent_lot, 'volume', -p_volume_ul, 'consume');
  insert into measurement (event_id, container_id, lot_id, property, value, unit)
  values (ev, p_container, p_lot, 'concentration', p_mass_ug / p_volume_ul, 'ug/ul');
  return ev;
end $$;

create function measure(p_container bigint, p_lot bigint, p_property text, p_value numeric, p_unit text,
                        p_at timestamptz, p_by text, p_source text default 'manual',
                        p_recorded timestamptz default null)
returns bigint language plpgsql as $$
declare ev bigint := new_event('measure', p_at, p_by, p_source, p_recorded => p_recorded);
begin
  insert into measurement (event_id, container_id, lot_id, property, value, unit)
  values (ev, p_container, p_lot, p_property, p_value, p_unit);
  return ev;
end $$;
