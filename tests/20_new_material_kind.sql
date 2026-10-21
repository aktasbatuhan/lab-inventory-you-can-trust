-- A new kind of material without a schema change: small molecules. A kind is a
-- row with its own required attributes and its own shelf-life rule.
begin;
do $$
declare
  p record; stock bigint; box bigint; l bigint; kids bigint[]; x record; rule bigint;
begin
  select * into p from test_places();

  insert into material_kind (id, description, base_dimension, needs_qc, required_attributes)
  values ('small_molecule', 'Small-molecule compounds, dissolved for screening', 'mass', false, '{smiles,solvent}');
  insert into shelf_life_rule (material_kind_id, clock, duration, effective_from, recorded_at, recorded_by, note)
  values ('small_molecule', 'since_origin', '1 year', '2026-09-01', '2026-09-01', 'p:sara', 'Assumption: a year in DMSO at -20.')
  returning id into rule;

  -- A compound without its solvent is refused: the kind says every one needs it.
  perform expect_error($sql$insert into material (id, kind_id, name, attributes)
                            values ('sm:caffeine', 'small_molecule', 'Caffeine', '{"smiles": "CN1C=NC2=C1C(=O)N(C(=O)N2C)C"}')$sql$,
                       'missing attributes', 'a small molecule without a solvent');

  insert into material (id, kind_id, name, attributes)
  values ('sm:caffeine', 'small_molecule', 'Caffeine', '{"smiles": "CN1C=NC2=C1C(=O)N(C(=O)N2C)C", "solvent": "DMSO"}');
  insert into product (id, material_id, supplier, catalog_number) values ('vendorF:CAF-10MM', 'sm:caffeine', 'Vendor F', 'CAF-10MM');

  -- It arrives as 1 mL of a 10 mM solution, is split into four 50 µL tubes, and works like anything else.
  stock := register_container('tube_1_5ml', '2026-09-15 10:00', 'p:lena', 'SM-0001', p_into => p.freezer);
  l := receive('vendorF:CAF-10MM', stock, 1000, 'volume', '2026-09-15 10:00', 'p:lena', p_supplier_lot => 'C-221');
  box := register_container('box_9x9', '2026-09-16 09:00', 'p:marco', 'BOX-0200', p_into => p.freezer);
  kids := split(stock, l, 4, 50, 'tube_matrix', '2026-09-16 09:00', 'p:marco', 'SM-A', p_into => box);

  perform expect((select sum(held) from usable('2026-09-16 12:00', 'infinity') where material_id = 'sm:caffeine'),
                 1000::numeric, 'caffeine held');
  perform expect((select sum(usable) from usable('2026-09-16 12:00', 'infinity') where material_id = 'sm:caffeine'),
                 955::numeric, 'caffeine usable (795 in the stock tube, 4 x 40 in the aliquots)');
  perform expect((select count(*) from usable('2026-09-16 12:00', 'infinity')
                  where container_id = any(kids) and reasons = '{}' and usable = 40), 4::bigint, 'aliquots usable');

  -- Its expiry comes from the new kind's rule.
  select * into x from expiry('2026-09-16 12:00', 'infinity') where container_id = kids[1];
  perform expect(x.expires_at, '2027-09-15 10:00'::timestamptz, 'caffeine expiry');
  perform expect(x.rule_id, rule, 'rule that set it');
end $$;
rollback;
