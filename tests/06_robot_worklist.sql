-- XFER-007, EDGE-022: a liquid handler copies a DNA plate well by well from a
-- worklist and stops partway. The plan is kept apart from what the robot did,
-- and only what the robot log confirms moves any liquid.
begin;
do $$
declare
  p record; src bigint; dst bigint; r bigint; lots bigint[] := '{}'; u record;
begin
  select * into p from test_places();
  insert into material (id, kind_id, name, attributes) values
    ('dna:D-1001', 'dna', 'DNA plate D-1001 designs', '{"design_id": "D-1001"}');
  insert into product (id, material_id, supplier, catalog_number) values
    ('twist:D-1001', 'dna:D-1001', 'Twist', 'D-1001');

  -- DNA plate D-1001: column 1 has 8 wells of 40 µL each. The copy plate is empty.
  src := register_container('plate_96', '2026-09-14 08:00', 'p:lena', 'D-1001', p_into => p.fridge);
  dst := register_container('plate_96', '2026-09-15 08:30', 'p:lena', 'D-1001-C', p_into => p.bench);
  for i in 1 .. 8 loop
    lots := lots || receive('twist:D-1001', well(src, chr(64 + i) || '1'), 40, 'volume', '2026-09-14 08:00', 'p:lena');
  end loop;

  -- The worklist: 5 µL from each source well into the same well of the copy plate.
  r := start_run('worklist copy', '2026-09-15 09:00', 'p:lena', p_experiment => 'EXP-150');
  insert into planned_transfer (run_id, step, from_container_id, to_container_id, lot_id, dimension, amount)
  select r, i, well(src, chr(64 + i) || '1'), well(dst, chr(64 + i) || '1'), lots[i], 'volume', 5
  from generate_series(1, 8) i;

  -- The robot log only has steps 1 to 5. A tip jam stopped it after that.
  for i in 1 .. 5 loop
    perform transfer(well(src, chr(64 + i) || '1'), well(dst, chr(64 + i) || '1'), lots[i], 5, 'volume',
                     '2026-09-15 09:00'::timestamptz + i * interval '1 minute', 'robot:hamilton-1',
                     'robot_log', r, i);
  end loop;

  -- While the run is still going, missing steps are not a problem yet.
  perform expect((select count(*) from flags('2026-09-15 09:10', 'infinity') where flag = 'robot run incomplete'),
                 0::bigint, 'no incomplete-run flag while the run is going');

  perform finish_run(r, '2026-09-15 09:30', 'robot:hamilton-1');

  -- Now the three steps the robot never logged show up, one flag per destination well.
  perform expect((select count(*) from flags('2026-09-15 10:00', 'infinity') where flag = 'robot run incomplete'),
                 3::bigint, 'steps planned but not logged');
  perform expect((select array_agg(c.position order by c.position) from flags('2026-09-15 10:00', 'infinity') f
                  join container c on c.id = f.container_id
                  where f.flag = 'robot run incomplete' and c.plate_id = dst),
                 array['F1', 'G1', 'H1'], 'copy plate wells left empty');

  -- Only the logged transfers moved liquid.
  select * into u from usable('2026-09-15 10:00', 'infinity') where container_id = well(src, 'A1');
  perform expect(u.held, 35::numeric, 'source A1 after its step ran');
  select * into u from usable('2026-09-15 10:00', 'infinity') where container_id = well(dst, 'A1');
  perform expect(u.held, 5::numeric, 'copy A1 holds 5 µL');
  perform expect(u.lot_id, lots[1], 'copy A1 holds the same DNA lot as its source');
  select * into u from usable('2026-09-15 10:00', 'infinity') where container_id = well(src, 'F1');
  perform expect(u.held, 40::numeric, 'source F1 untouched');
  perform expect((select count(*) from balances('2026-09-15 10:00', 'infinity') where container_id = well(dst, 'F1')),
                 0::bigint, 'copy F1 still empty');
  perform expect((select sum(amount) from balances('2026-09-15 10:00', 'infinity') b
                  join container c on c.id = b.container_id where c.plate_id = dst), 25::numeric, 'total in the copy plate');

  -- The log upload is retried and step 3 arrives a second time. Same run, same
  -- step: it's the same physical action, so the database refuses to count it again.
  perform expect_error(format('select transfer(%s, %s, %s, 5, %L, %L, %L, %L, %s, 3)',
                              well(src, 'C1'), well(dst, 'C1'), lots[3], 'volume', '2026-09-15 09:03', 'robot:hamilton-1', 'robot_log', r),
                       'duplicate key', 'the same robot step logged twice');
  perform expect((select amount from balances('2026-09-15 10:00', 'infinity') where container_id = well(dst, 'C1')),
                 5::numeric, 'copy C1 after the retry');

  -- Lena reruns step 6 by hand; logging it under the run fills that gap.
  perform transfer(well(src, 'F1'), well(dst, 'F1'), lots[6], 5, 'volume', '2026-09-15 11:00', 'p:lena', 'manual', r, 6);
  perform expect((select count(*) from flags('2026-09-15 12:00', 'infinity') where flag = 'robot run incomplete'),
                 2::bigint, 'steps still missing after the manual rerun');
end $$;
rollback;
