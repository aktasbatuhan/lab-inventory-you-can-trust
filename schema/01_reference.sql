-- Reference data and rules.
--
-- Reference data describes kinds of things (what a target protein is, how big a
-- 96-well plate is). Rules describe policy (how long loading buffer lasts). Rules
-- are versioned with a start date and never edited, so the past can always be
-- answered with the rule that applied at the time.

create table actor (
  id   text primary key,               -- 'p:lena', 'robot:hamilton-1', 'rule:protocol-defaults'
  kind text not null check (kind in ('person', 'robot', 'instrument', 'system', 'rule')),
  name text not null
);

-- A kind of material. New kinds (small molecules, enzymes) are new rows, not new tables.
create table material_kind (
  id                  text primary key,  -- 'dna', 'sample_protein', 'target', 'buffer', ...
  description         text not null,
  base_dimension      text not null check (base_dimension in ('volume', 'mass', 'count', 'activity')),
  needs_qc            boolean not null default false,
  required_attributes text[] not null default '{}'
);

-- A specific material: "EGFR extracellular domain", "Loading buffer", "the protein of design D-0042".
create table material (
  id         text primary key,
  kind_id    text not null references material_kind,
  name       text not null,
  attributes jsonb not null default '{}'
);

create function check_material_attributes() returns trigger language plpgsql as $$
declare missing text[];
begin
  select array_agg(a) into missing
  from unnest((select required_attributes from material_kind where id = new.kind_id)) a
  where not new.attributes ? a;
  if missing is not null then
    raise exception 'material % is missing attributes required for kind %: %', new.id, new.kind_id, missing;
  end if;
  return new;
end $$;

create trigger material_attributes before insert or update on material
  for each row execute function check_material_attributes();

-- Something a supplier sells: one material under one catalog number.
create table product (
  id             text primary key,
  material_id    text not null references material,
  supplier       text not null,
  catalog_number text not null,
  unique (supplier, catalog_number)
);

-- Kinds of containers and places. Tubes, plates and wells hold material; boxes,
-- racks, freezers, benches and instruments hold containers.
create table container_type (
  id             text primary key,
  category       text not null check (category in ('tube', 'plate', 'well', 'holder', 'place', 'instrument')),
  description    text not null,
  capacity_ul    numeric,
  dead_volume_ul numeric not null default 0,   -- liquid a pipette can't get back out
  grid_rows      int,
  grid_cols      int,
  well_type_id   text references container_type,
  single_use     boolean not null default false  -- thrown away after the run that uses it
);

-- How long material lasts. A rule targets a supplier product, a material, or a
-- whole kind; the most specific one wins for the same clock and storage
-- conditions. A null duration means "no limit" and overrides a broader rule.
--   since_origin: counted from when the lot was received or made
--   in_condition: counted from when the material entered one of these storage conditions
create table shelf_life_rule (
  id               bigint generated always as identity primary key,
  material_kind_id text references material_kind,
  material_id      text references material,
  product_id       text references product,
  clock            text not null check (clock in ('since_origin', 'in_condition')),
  conditions       text[] check (conditions <@ array['minus80', 'minus20', 'fridge', 'room']),
  duration         interval,
  effective_from   timestamptz not null,
  recorded_at      timestamptz not null default now(),
  recorded_by      text not null references actor,
  note             text,
  check (num_nonnulls(material_kind_id, material_id, product_id) = 1),
  check ((clock = 'in_condition') = (conditions is not null))
);

-- How many freeze-thaw cycles a material tolerates. Going over warns; it never blocks.
create table thaw_limit_rule (
  id               bigint generated always as identity primary key,
  material_kind_id text references material_kind,
  material_id      text references material,
  product_id       text references product,
  max_thaws        int,                          -- null means "don't judge"
  effective_from   timestamptz not null,
  recorded_at      timestamptz not null default now(),
  recorded_by      text not null references actor,
  note             text,
  check (num_nonnulls(material_kind_id, material_id, product_id) = 1)
);
