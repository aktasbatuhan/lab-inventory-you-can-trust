-- Facts: things that happened.
--
-- Every fact belongs to one event. An event has two times: when it happened in
-- the lab (occurred_at) and when it was written down (recorded_at). Nothing in
-- this file is ever updated or deleted. A mistake is fixed by a new event that
-- voids the wrong one and, if needed, carries the right lines instead.

create table event (
  id             bigint generated always as identity primary key,
  kind           text not null,          -- 'receive', 'register', 'move', 'transfer', 'split', 'make', 'consume', 'discard', 'correction', ...
  occurred_at    timestamptz not null,
  recorded_at    timestamptz not null default now(),
  recorded_by    text not null references actor,
  performed_by   text references actor,  -- who did it at the bench, if not the recorder
  source         text not null default 'manual'
                 check (source in ('manual', 'scan', 'robot_log', 'import', 'rule')),
  run_id         bigint,
  run_step       int,
  external_ref   text unique,            -- delivery note, robot log line: the same real action can't be counted twice
  voids_event_id bigint unique references event,
  note           text,
  check (voids_event_id is null or note is not null),  -- every correction says why
  check (voids_event_id is distinct from id),
  unique (run_id, run_step)
);

-- A tube, plate, well, box, rack, freezer, bench or instrument. Wells are
-- containers too, fixed inside their plate. Places that set a storage
-- condition (a -80 freezer, a fridge, the bench) carry it here.
create table container (
  id               bigint generated always as identity primary key,
  type_id          text not null references container_type,
  plate_id         bigint references container,
  position         text,
  name             text,
  condition        text check (condition in ('minus80', 'minus20', 'fridge', 'room')),
  created_event_id bigint not null references event,
  unique (plate_id, position),
  check ((plate_id is null) = (position is null))
);

-- A group of events that belong to one lab task: a robot run, a split, a BLI run.
create table run (
  id               bigint generated always as identity primary key,
  protocol         text not null,
  instrument_id    bigint references container,
  experiment_ref   text,                 -- id in the planning system, which is out of scope
  created_event_id bigint not null references event
);

alter table event add foreign key (run_id) references run;

-- What a robot was told to do. What it actually did arrives as events with the same run and step.
create table planned_transfer (
  run_id            bigint not null references run,
  step              int not null,
  from_container_id bigint not null references container,
  to_container_id   bigint not null references container,
  lot_id            bigint,
  dimension         text not null check (dimension in ('volume', 'mass', 'count', 'activity')),
  amount            numeric not null check (amount > 0),
  primary key (run_id, step)
);

-- One batch of material. A received lot is one delivery of one supplier lot
-- (decision D2); a made lot is one making of something from other lots.
create table lot (
  id                bigint generated always as identity primary key,
  material_id       text not null references material,
  origin            text not null check (origin in ('received', 'made')),
  created_event_id  bigint not null references event,
  product_id        text references product,
  supplier_lot_code text,
  supplier_expiry   date,
  coa               jsonb,                -- what the certificate of analysis claims
  unit_price        numeric,
  currency          text,
  check (origin = 'made' or product_id is not null)
);

-- Made from. The parent is always older than the child, so lineage can't loop.
create table lot_parent (
  lot_id        bigint not null references lot,
  parent_lot_id bigint not null references lot,
  primary key (lot_id, parent_lot_id),
  check (parent_lot_id < lot_id)
);

-- The ledger. Amounts are in the base unit of their dimension:
-- volume in µL, mass in µg, count in pieces, activity in U.
create table quantity_entry (
  id           bigint generated always as identity primary key,
  event_id     bigint not null references event,
  container_id bigint not null references container,
  lot_id       bigint not null references lot,
  dimension    text not null check (dimension in ('volume', 'mass', 'count', 'activity')),
  amount       numeric not null check (amount <> 0),
  reason       text not null check (reason in ('receive', 'transfer', 'make', 'consume', 'loss', 'adjust'))
);

-- A container was put into another one (a tube into a box slot, a box into a freezer).
create table placement (
  event_id     bigint not null references event,
  container_id bigint not null references container,
  parent_id    bigint not null references container,
  position     text,
  primary key (event_id, container_id),
  check (container_id <> parent_id)
);

-- Someone or something saw a container: a barcode scan, a rack scan, a robot reading a plate.
create table sighting (
  event_id     bigint not null references event,
  container_id bigint not null references container,
  scanned_code text,
  seen_in_id   bigint references container,
  primary key (event_id, container_id)
);

-- A barcode is a label a container wears for a while, not the container itself.
create table label (
  event_id     bigint not null references event,
  container_id bigint not null references container,
  barcode      text not null,
  action       text not null check (action in ('attach', 'detach')),
  primary key (event_id, container_id, barcode)
);

create table qc_result (
  event_id bigint not null references event,
  lot_id   bigint not null references lot,
  assay    text not null,
  outcome  text not null check (outcome in ('pass', 'fail')),
  measured jsonb,
  primary key (event_id, lot_id)
);

create table hold_placed (
  event_id     bigint primary key references event,
  lot_id       bigint references lot,
  container_id bigint references container,
  reason       text not null,
  check (num_nonnulls(lot_id, container_id) = 1)
);

create table hold_released (
  event_id      bigint primary key references event,
  hold_event_id bigint not null unique references hold_placed
);

-- A container leaves the inventory: thrown away (with whatever was left in it) or shipped out.
create table container_exit (
  event_id     bigint not null references event,
  container_id bigint not null references container,
  kind         text not null check (kind in ('discard', 'ship')),
  destination  text,
  primary key (event_id, container_id)
);

-- One line of a physical count: was it there, and how much did it look like.
create table count_line (
  event_id        bigint not null references event,
  container_id    bigint not null references container,
  found           boolean not null,
  observed_amount numeric,
  dimension       text check (dimension in ('volume', 'mass', 'count', 'activity')),
  primary key (event_id, container_id)
);

-- A measured property, such as concentration. Kept apart from amounts on purpose.
create table measurement (
  event_id     bigint not null references event,
  container_id bigint not null references container,
  lot_id       bigint not null references lot,
  property     text not null,          -- 'concentration'
  value        numeric not null,
  unit         text not null,          -- 'ug/ul', 'nM'
  primary key (event_id, container_id, lot_id, property)
);

create index on quantity_entry (container_id, lot_id);
create index on quantity_entry (lot_id);
create index on quantity_entry (event_id);
create index on placement (container_id);
create index on placement (parent_id);
create index on sighting (container_id);
create index on label (barcode);
create index on container_exit (container_id);
create index on event (run_id);
create index on event (occurred_at);
create index on event (recorded_at);

-- A person reviewed a flag and closed it. Only flags that ask for judgement can
-- be closed this way; the ones backed by numbers go away when the numbers are fixed.
create table flag_review (
  event_id     bigint primary key references event,
  flag         text not null check (flag in ('possible duplicate delivery', 'seen after it left',
                                             'robot step assumed', 'over thaw limit')),
  container_id bigint references container,
  lot_id       bigint references lot,
  check (num_nonnulls(container_id, lot_id) >= 1)
);
