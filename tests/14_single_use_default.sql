-- LIFE-004, D6: a BLI plate is single use. When the run finishes, the system
-- records it as thrown away without anyone scanning the bin. If it shows up
-- again later, that's a mismatch someone has to explain.
begin;
do $$
declare
  p record; gator bigint; tube bigint; l bigint; bli bigint; samples bigint; prot bigint; r bigint; ev bigint; x record;
begin
  select * into p from test_places();
  insert into material (id, kind_id, name, attributes) values
    ('protein:D-0042', 'sample_protein', 'Protein of design D-0042', '{"design_id": "D-0042"}');
  gator := register_container('instrument', '2026-01-01', 'p:sara', p_name => 'Gator BLI 1', p_source => 'manual');

  tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0501', p_into => p.fridge);
  l := receive('vendorA:EGFR-100', tube, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L4471');
  perform qc(l, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- A BLI target plate with target in two wells, and a regular 96-well sample plate.
  bli := register_container('plate_bli', '2026-09-03 09:00', 'p:marco', 'BLI-T-0050', p_into => gator);
  perform transfer(tube, well(bli, 'A1'), l, 50, 'volume', '2026-09-03 09:05', 'p:marco');
  perform transfer(tube, well(bli, 'B1'), l, 50, 'volume', '2026-09-03 09:05', 'p:marco');
  samples := register_container('plate_96', '2026-09-03 09:00', 'p:marco', 'SMP-0050', p_into => gator);
  prot := make('protein:D-0042', '[]', well(samples, 'A1'), 60, 'volume', '2026-09-02 16:00', 'p:marco');

  -- The run draws from both plates.
  r := start_run('BLI', '2026-09-03 10:00', 'p:marco', gator, 'EXP-401');
  ev := consume(well(bli, 'A1'), l, 10, 'volume', '2026-09-03 10:30', 'instrument:gator-1', 'robot_log', r);
  perform consume(well(bli, 'B1'), l, 10, 'volume', '2026-09-03 10:30', 'instrument:gator-1', p_event => ev);
  perform consume(well(samples, 'A1'), prot, 20, 'volume', '2026-09-03 10:30', 'instrument:gator-1', p_event => ev);
  perform finish_run(r, '2026-09-03 12:00', 'instrument:gator-1');

  -- The BLI plate is recorded as thrown away, by the protocol rule, not by a person.
  select * into x from exits('2026-09-03 13:00', 'infinity') where container_id = bli;
  perform expect(x.kind, 'discard', 'BLI plate exit');
  perform expect(x.source, 'rule', 'recorded by rule');
  perform expect(x.exited_at, '2026-09-03 12:00'::timestamptz, 'when');
  perform expect((select recorded_by from event where id = x.event_id), 'rule:protocol-defaults', 'who recorded it');

  -- The sample plate is not single use and stays.
  perform expect((select count(*) from exits('2026-09-03 13:00', 'infinity') where container_id = samples), 0::bigint, 'sample plate kept');

  -- The 80 µL of target left in the BLI plate is no longer usable stock.
  perform expect((select sum(held) from usable('2026-09-03 13:00', 'infinity')
                  where container_id in (select id from container where plate_id = bli) and 'discarded' = any(reasons)),
                 80::numeric, 'target left in the thrown-away plate');
  perform expect((select sum(usable) from usable('2026-09-03 13:00', 'infinity')
                  where container_id in (select id from container where plate_id = bli)), 0::numeric, 'usable in the BLI plate');

  -- Finishing the run again doesn't throw it away twice.
  perform finish_run(r, '2026-09-03 12:05', 'instrument:gator-1');
  perform expect((select count(*) from container_exit where container_id = bli), 1::bigint, 'one exit for the plate');

  -- Next day someone scans the plate on the bench: it was kept for a re-read. That's a flag.
  perform scan(bli, '2026-09-04 09:00', 'p:lena', 'BLI-T-0050', p.bench);
  perform expect((select count(*) from flags('2026-09-04 10:00', 'infinity') where flag = 'seen after it left' and container_id = bli),
                 1::bigint, 'seen-after-it-left flag');
end $$;
rollback;
