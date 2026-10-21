-- ASK-005: planning a re-run for next week. "Usable" is asked about the re-run
-- date, not today, so wells that will have expired by then drop out even
-- though they're fine right now.
begin;
do $$
declare
  p record; mix_tube bigint; mix bigint; e1 bigint; e2 bigint; u record;
begin
  select * into p from test_places();
  insert into material (id, kind_id, name, attributes) values
    ('protein:D-0101', 'sample_protein', 'Protein of design D-0101', '{"design_id": "D-0101"}'),
    ('protein:D-0102', 'sample_protein', 'Protein of design D-0102', '{"design_id": "D-0102"}');

  mix_tube := register_container('tube_1_5ml', '2026-08-20 09:00', 'p:lena', 'MIX-0002', p_into => p.freezer);
  mix := receive('vendorD:PURE', mix_tube, 1000, 'volume', '2026-08-20 09:00', 'p:lena');

  -- Two expression plates, a week apart. Each protein lasts 14 days from expression.
  e1 := register_container('plate_96', '2026-09-01 09:00', 'p:marco', 'EXP-4001', p_into => p.fridge);
  perform make('protein:D-0101', jsonb_build_array(jsonb_build_object('container', mix_tube, 'lot', mix, 'amount', 20)),
               well(e1, 'A1'), 20, 'volume', '2026-09-01 16:00', 'p:marco');
  e2 := register_container('plate_96', '2026-09-08 09:00', 'p:marco', 'EXP-4002', p_into => p.fridge);
  perform make('protein:D-0102', jsonb_build_array(jsonb_build_object('container', mix_tube, 'lot', mix, 'amount', 20)),
               well(e2, 'A1'), 20, 'volume', '2026-09-08 16:00', 'p:marco');

  -- Today, 10 September, both wells are usable. Both expire within two weeks, so both warn.
  select * into u from usable('2026-09-10 12:00', 'infinity') where container_id = well(e1, 'A1');
  perform expect(u.usable, 18::numeric, 'D-0101 usable today');
  perform expect(u.warnings, array['expires within 14 days'], 'D-0101 warning today');
  select * into u from usable('2026-09-10 12:00', 'infinity') where container_id = well(e2, 'A1');
  perform expect(u.usable, 18::numeric, 'D-0102 usable today');

  -- The re-run is planned for 18 September. Asked about that day, D-0101 will
  -- have expired on the 15th; D-0102 is still good until the 22nd.
  select * into u from usable('2026-09-18 09:00', 'infinity') where container_id = well(e1, 'A1');
  perform expect(u.usable, 0::numeric, 'D-0101 on the re-run date');
  perform expect(u.reasons, array['expired'], 'why D-0101 drops out');
  perform expect(u.expires_at, '2026-09-15 16:00'::timestamptz, 'when D-0101 expires');
  select * into u from usable('2026-09-18 09:00', 'infinity') where container_id = well(e2, 'A1');
  perform expect(u.usable, 18::numeric, 'D-0102 on the re-run date');
  perform expect(u.expires_at, '2026-09-22 16:00'::timestamptz, 'when D-0102 expires');

  -- The planner's list: what will be usable on the re-run date, from what we
  -- know today (k = 10 September). This needs the seeded shelf-life rules to be
  -- on record by then; see journal/agent-runs/schema-gaps.md.
  perform expect((select array_agg(material_id order by material_id)
                  from usable('2026-09-18 09:00', '2026-09-10 12:00')
                  where material_id like 'protein:%' and usable > 0),
                 array['protein:D-0102'], 'proteins usable for the re-run');
end $$;
rollback;
