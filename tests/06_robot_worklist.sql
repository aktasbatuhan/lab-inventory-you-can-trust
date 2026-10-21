-- XFER-007, EDGE-022, D10: a liquid handler copies a DNA plate well by well
-- from a worklist and stops partway. The plan is kept apart from what the robot
-- did. An aborted run assumes nothing; a run that finished normally is assumed
-- to have done its plan, and a missing log line is flagged instead.
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

  perform finish_run(r, '2026-09-15 09:30', 'robot:hamilton-1', p_outcome => 'aborted');

  -- The three steps the robot never reached show up at both ends: the source
  -- wells that may still be full, and the copy wells that may be empty.
  perform expect((select count(*) from flags('2026-09-15 10:00', 'infinity') where flag = 'robot run incomplete'),
                 6::bigint, 'steps planned but not logged, both ends');
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
                 4::bigint, 'steps still missing after the manual rerun');
end $$;
rollback;

-- D10: a run that finished normally, where one log line was lost on the way.
-- The robot almost certainly did the step, so it's recorded as done by rule and
-- flagged. The source well is no longer left looking fuller than it is.
begin;
do $$
declare
  p record; src bigint; dst bigint; r bigint; lots bigint[] := '{}'; u record;
begin
  select * into p from test_places();
  insert into material (id, kind_id, name, attributes) values ('dna:D-2001', 'dna', 'Designs D-2001', '{"design_id": "D-2001"}');
  insert into product (id, material_id, supplier, catalog_number) values ('twist:D-2001', 'dna:D-2001', 'Twist', 'D-2001');
  src := register_container('plate_96', '2026-09-14 08:00', 'p:lena', 'D-2001', p_into => p.fridge);
  dst := register_container('plate_96', '2026-09-15 08:30', 'p:lena', 'D-2001-C', p_into => p.bench);
  for i in 1 .. 4 loop
    lots := lots || receive('twist:D-2001', well(src, chr(64 + i) || '1'), 40, 'volume', '2026-09-14 08:00', 'p:lena');
  end loop;
  r := start_run('worklist copy', '2026-09-15 09:00', 'p:lena');
  insert into planned_transfer (run_id, step, from_container_id, to_container_id, lot_id, dimension, amount)
  select r, i, well(src, chr(64 + i) || '1'), well(dst, chr(64 + i) || '1'), lots[i], 'volume', 5
  from generate_series(1, 4) i;

  -- Steps 1, 2 and 4 are in the log. Step 3's line was lost.
  perform transfer(well(src, 'A1'), well(dst, 'A1'), lots[1], 5, 'volume', '2026-09-15 09:01', 'robot:hamilton-1', 'robot_log', r, 1);
  perform transfer(well(src, 'B1'), well(dst, 'B1'), lots[2], 5, 'volume', '2026-09-15 09:02', 'robot:hamilton-1', 'robot_log', r, 2);
  perform transfer(well(src, 'D1'), well(dst, 'D1'), lots[4], 5, 'volume', '2026-09-15 09:04', 'robot:hamilton-1', 'robot_log', r, 4);
  perform finish_run(r, '2026-09-15 09:30', 'robot:hamilton-1');

  -- Both ends of step 3 now read as if it happened, and a person is told it was assumed.
  perform expect((select held from usable('2026-09-15 10:00', 'infinity') where container_id = well(src, 'C1')), 35::numeric, 'source C1 after the assumed step');
  perform expect((select held from usable('2026-09-15 10:00', 'infinity') where container_id = well(dst, 'C1')), 5::numeric, 'copy C1 after the assumed step');
  perform expect((select count(*) from flags('2026-09-15 10:00', 'infinity') where flag = 'robot step assumed'), 1::bigint, 'assumed step flagged');
  perform expect((select source from event where run_id = r and run_step = 3), 'rule', 'the assumed step is marked as coming from a rule');

  -- The next morning the missing log line turns up (the robot PC had been
  -- offline). It replaces the assumption instead of being refused as a repeat.
  perform transfer(well(src, 'C1'), well(dst, 'C1'), lots[3], 4.5, 'volume', '2026-09-15 09:03', 'robot:hamilton-1', 'robot_log', r, 3,
                   p_recorded => '2026-09-16 08:00');
  perform expect((select held from usable('2026-09-16 10:00', 'infinity') where container_id = well(dst, 'C1')), 4.5::numeric, 'copy C1 from the real log line');
  perform expect((select count(*) from flags('2026-09-16 10:00', 'infinity') where flag = 'robot step assumed'), 0::bigint, 'flag gone once the log arrives');

  -- And on the evening of the 15th, the system said what it believed then.
  perform expect((select held from usable('2026-09-15 20:00', '2026-09-15 20:00') where container_id = well(dst, 'C1')), 5::numeric, 'copy C1 as known that evening');
end $$;
rollback;
