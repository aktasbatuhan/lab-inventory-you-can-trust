-- EDGE-004: one well of a BLI target plate gets target from two lots plus
-- running buffer. The well keeps all three, and a problem with either target
-- lot reaches the run that used the well.
begin;
do $$
declare
  p record; t1 bigint; t2 bigint; l1 bigint; l2 bigint; buf_bottle bigint; buf bigint;
  hepes_tube bigint; nacl_tube bigint; hepes bigint; nacl bigint; plate bigint; a1 bigint; r bigint; ev bigint;
begin
  select * into p from test_places();

  -- Two deliveries of the same target, both QC'd and thawed in the fridge.
  t1 := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0201', p_into => p.fridge);
  l1 := receive('vendorA:EGFR-100', t1, 100, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L1');
  t2 := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0202', p_into => p.fridge);
  l2 := receive('vendorA:EGFR-100', t2, 100, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L2');
  perform qc(l1, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');
  perform qc(l2, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- Running buffer made from HEPES and NaCl stock.
  hepes_tube := register_container('bottle', '2026-09-01 10:00', 'p:lena', 'HEP-01', p_into => p.bench);
  hepes := receive('vendorC:HEPES', hepes_tube, 100000, 'volume', '2026-09-01 10:00', 'p:lena');
  nacl_tube := register_container('bottle', '2026-09-01 10:00', 'p:lena', 'NAC-01', p_into => p.bench);
  nacl := receive('vendorC:NACL', nacl_tube, 100000, 'volume', '2026-09-01 10:00', 'p:lena');
  buf_bottle := register_container('bottle', '2026-09-03 09:00', 'p:marco', 'RUN-01', p_into => p.bench);
  buf := make('buffer:bli-running',
              jsonb_build_array(jsonb_build_object('container', hepes_tube, 'lot', hepes, 'amount', 1000),
                                jsonb_build_object('container', nacl_tube, 'lot', nacl, 'amount', 3000)),
              buf_bottle, 100000, 'volume', '2026-09-03 09:00', 'p:marco');

  -- Lot L1 runs short, so Marco tops well A1 up from L2, then adds buffer.
  plate := register_container('plate_bli', '2026-09-04 09:00', 'p:marco', 'BLI-T-0040', p_into => p.bench);
  a1 := well(plate, 'A1');
  perform transfer(t1, a1, l1, 20, 'volume', '2026-09-04 09:05', 'p:marco');
  perform transfer(t2, a1, l2, 30, 'volume', '2026-09-04 09:06', 'p:marco');
  perform transfer(buf_bottle, a1, buf, 50, 'volume', '2026-09-04 09:07', 'p:marco');

  -- The well shows all three, nothing forced into one lot.
  perform expect((select count(*) from usable('2026-09-04 10:00', 'infinity') where container_id = a1), 3::bigint, 'rows for well A1');
  perform expect((select sum(held) from usable('2026-09-04 10:00', 'infinity') where container_id = a1), 100::numeric, 'total in well A1');
  perform expect((select held from usable('2026-09-04 10:00', 'infinity') where container_id = a1 and lot_id = l2), 30::numeric, 'L2 in well A1');

  -- The BLI run draws 10 µL from the well. We record it against each lot in the mix.
  r := start_run('BLI', '2026-09-04 11:00', 'p:marco', p_experiment => 'EXP-301');
  ev := consume(a1, l1, 2, 'volume', '2026-09-04 11:30', 'instrument:gator-1', 'robot_log', r);
  perform consume(a1, l2, 3, 'volume', '2026-09-04 11:30', 'instrument:gator-1', p_event => ev);
  perform consume(a1, buf, 5, 'volume', '2026-09-04 11:30', 'instrument:gator-1', p_event => ev);

  -- Forward trace from either target lot reaches the well and the run.
  perform expect_true(exists (
    select 1 from events_at('2026-09-05', 'infinity') e join quantity_entry q on q.event_id = e.id
    where q.lot_id in (select lot_id from lot_descendants(l1, 'infinity')) and q.amount > 0 and q.container_id = a1),
    'forward trace from L1 reaches well A1');
  perform expect_true(exists (
    select 1 from events_at('2026-09-05', 'infinity') e join quantity_entry q on q.event_id = e.id
    where q.lot_id in (select lot_id from lot_descendants(l2, 'infinity')) and q.amount > 0 and q.container_id = a1),
    'forward trace from L2 reaches well A1');

  -- Weeks later L2 fails a re-test. The run that used the mixed well is exposed to it.
  perform qc(l2, 'fail', 'SDS-PAGE re-test', '2026-09-25 09:00', 'p:marco');
  perform expect((select array_agg(distinct ru.experiment_ref)
                  from events_at('2026-09-25 10:00', 'infinity') e
                  join quantity_entry q on q.event_id = e.id
                  join run ru on ru.id = e.run_id
                  where q.lot_id in (select lot_id from lot_descendants(l2, 'infinity'))),
                 array['EXP-301'], 'experiments exposed to L2');
end $$;
rollback;
