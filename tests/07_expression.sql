-- XFER-020: DNA comes in dry, is dissolved in water, goes into an expression
-- plate with cell-free mix, and the expression run turns each well into a new
-- protein lot. The DNA and the mix stay on record as that protein's parents.
begin;
do $$
declare
  p record; dna_plate bigint; expr bigint; mix_tube bigint; r bigint; ev bigint;
  water_bottle bigint; water_lot bigint; mix_lot bigint;
  designs text[] := array['D-0001', 'D-0002'];
  pos text; dna_lots bigint[] := '{}'; protein_lots bigint[] := '{}'; u record; x record;
begin
  select * into p from test_places();
  insert into material (id, kind_id, name, attributes)
  select 'dna:' || d, 'dna', 'DNA for design ' || d, jsonb_build_object('design_id', d) from unnest(designs) d
  union all
  select 'protein:' || d, 'sample_protein', 'Protein of design ' || d, jsonb_build_object('design_id', d) from unnest(designs) d;
  insert into product (id, material_id, supplier, catalog_number)
  select 'twist:' || d, 'dna:' || d, 'Twist', d from unnest(designs) d;

  water_bottle := register_container('bottle', '2026-09-01 09:00', 'p:lena', 'WAT-0001', p_into => p.bench);
  water_lot := receive('vendorC:WATER', water_bottle, 500000, 'volume', '2026-09-01 09:00', 'p:lena');
  mix_tube := register_container('tube_1_5ml', '2026-09-01 09:00', 'p:lena', 'MIX-0001', p_into => p.freezer);
  mix_lot := receive('vendorD:PURE', mix_tube, 1000, 'volume', '2026-09-01 09:00', 'p:lena', p_supplier_lot => 'PX-88');

  -- The DNA plate arrives dry: 2 µg of DNA per well, counted by mass.
  dna_plate := register_container('plate_96', '2026-09-14 09:00', 'p:lena', 'DNA-2001', p_into => p.freezer);
  for i in 1 .. 2 loop
    dna_lots := dna_lots || receive('twist:' || designs[i], well(dna_plate, 'A' || i), 2, 'mass', '2026-09-14 09:00', 'p:lena',
                                    p_supplier_lot => 'TW-' || designs[i]);
  end loop;

  -- Marco dissolves each well in 20 µL of water. It's the same DNA lot, now
  -- counted by volume, and he measures the concentration. There is no record
  -- function for this yet, so the test writes the lines itself.
  ev := new_event('reconstitute', '2026-09-15 09:00', 'p:marco', p_note => 'DNA dissolved in 20 µL water per well');
  for i in 1 .. 2 loop
    pos := 'A' || i;
    insert into quantity_entry (event_id, container_id, lot_id, dimension, amount, reason) values
      (ev, well(dna_plate, pos), dna_lots[i], 'mass',   -2, 'adjust'),
      (ev, well(dna_plate, pos), dna_lots[i], 'volume', 20, 'adjust'),
      (ev, water_bottle, water_lot, 'volume', -20, 'consume');
    insert into measurement (event_id, container_id, lot_id, property, value, unit)
    values (ev, well(dna_plate, pos), dna_lots[i], 'concentration', 0.1, 'ug/ul');
  end loop;

  select * into u from usable('2026-09-15 10:00', 'infinity') where container_id = well(dna_plate, 'A1');
  perform expect(u.dimension, 'volume', 'DNA is now counted by volume');
  perform expect(u.held, 20::numeric, 'DNA volume after dissolving');
  perform expect(u.lot_id, dna_lots[1], 'still the same DNA lot');
  perform expect((select count(*) from balances('2026-09-15 10:00', 'infinity') where container_id = well(dna_plate, 'A1')),
                 1::bigint, 'no dry mass left on record');

  -- Expression run: 5 µL DNA and 15 µL mix into each well, then 6 hours at 30 °C.
  expr := register_container('plate_96', '2026-09-15 10:00', 'p:marco', 'EXP-3001', p_into => p.bench);
  r := start_run('cell-free expression', '2026-09-15 10:00', 'p:marco', p_experiment => 'EXP-200');
  for i in 1 .. 2 loop
    pos := 'A' || i;
    perform transfer(well(dna_plate, pos), well(expr, pos), dna_lots[i], 5, 'volume', '2026-09-15 10:10', 'robot:hamilton-1', 'robot_log', r, i);
    perform transfer(mix_tube, well(expr, pos), mix_lot, 15, 'volume', '2026-09-15 10:20', 'robot:hamilton-1', 'robot_log', r, 10 + i);
  end loop;

  -- When expression finishes, each well's DNA and mix become one new protein lot.
  for i in 1 .. 2 loop
    pos := 'A' || i;
    protein_lots := protein_lots || make('protein:' || designs[i],
      jsonb_build_array(
        jsonb_build_object('container', well(expr, pos), 'lot', dna_lots[i], 'amount', 5),
        jsonb_build_object('container', well(expr, pos), 'lot', mix_lot, 'amount', 15)),
      well(expr, pos), 20, 'volume', '2026-09-15 16:30', 'p:marco', p_run => r, p_step => 20 + i);
  end loop;

  -- Each well now holds only its new protein lot, which is a different lot from its DNA.
  for i in 1 .. 2 loop
    pos := 'A' || i;
    perform expect((select array_agg(lot_id) from balances('2026-09-15 17:00', 'infinity') where container_id = well(expr, pos)),
                   array[protein_lots[i]], 'only protein left in well ' || pos);
    perform expect((select material_id from lot where id = protein_lots[i]), 'protein:' || designs[i], 'protein material in ' || pos);
  end loop;
  perform expect_true(protein_lots[1] <> dna_lots[1], 'protein lot is not the DNA lot');
  perform expect((select amount from balances('2026-09-15 17:00', 'infinity') where container_id = well(dna_plate, 'A1')),
                 15::numeric, 'DNA left on the DNA plate');

  -- The 14-day clock starts when the protein was made, not when the DNA arrived.
  select * into x from expiry('2026-09-15 17:00', 'infinity') where container_id = well(expr, 'A1');
  perform expect(x.expires_at, '2026-09-29 16:30'::timestamptz, 'protein expiry');
  perform expect(x.clock, 'since made', 'clock that set it');
  perform expect(x.rule_id, (select id from shelf_life_rule where material_kind_id = 'sample_protein'), 'rule that set it');
  perform expect((select reasons from usable('2026-09-30 09:00', 'infinity') where container_id = well(expr, 'A1')),
                 array['expired'], 'two weeks later');

  -- Backward lineage: the protein came from its DNA and the mix, and nothing else.
  perform expect((select array_agg(lot_id order by lot_id) from lot_ancestors(protein_lots[2], '2026-09-15 17:00') where depth = 1),
                 array[least(dna_lots[2], mix_lot), greatest(dna_lots[2], mix_lot)], 'parents of protein D-0002');
  -- Forward from the mix lot: both protein lots.
  perform expect((select count(*) from lot_descendants(mix_lot, '2026-09-15 17:00') where depth = 1), 2::bigint, 'lots made with the mix');
end $$;
rollback;
