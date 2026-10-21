-- ASK-012, ASK-014: a target lot turns out to be bad. Walk forward to every
-- tube, plate, run and experiment it touched. Then walk backward from one BLI
-- well to the supplier lots that went into it.
begin;
do $$
declare
  p record; stock bigint; box bigint; kids bigint[]; bad bigint; other bigint; other_tube bigint;
  hepes_b bigint; nacl_b bigint; hepes bigint; nacl bigint; buf_b bigint; buf bigint;
  w_tube bigint; w bigint; p1 bigint; p2 bigint; p3 bigint; r1 bigint; r2 bigint; r3 bigint; ev bigint;
begin
  select * into p from test_places();

  stock := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0701', p_into => p.freezer);
  bad := receive('vendorA:EGFR-100', stock, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L7');
  perform qc(bad, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');
  other_tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0702', p_into => p.freezer);
  other := receive('vendorA:EGFR-100', other_tube, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L8');
  perform qc(other, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  hepes_b := register_container('bottle', '2026-09-01 10:00', 'p:lena', 'HEP-02', p_into => p.bench);
  hepes := receive('vendorC:HEPES', hepes_b, 100000, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'H-77');
  nacl_b := register_container('bottle', '2026-09-01 10:00', 'p:lena', 'NAC-02', p_into => p.bench);
  nacl := receive('vendorC:NACL', nacl_b, 100000, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'N-12');
  buf_b := register_container('bottle', '2026-09-02 09:00', 'p:marco', 'RUN-02', p_into => p.bench);
  buf := make('buffer:bli-running',
              jsonb_build_array(jsonb_build_object('container', hepes_b, 'lot', hepes, 'amount', 1000),
                                jsonb_build_object('container', nacl_b, 'lot', nacl, 'amount', 3000)),
              buf_b, 100000, 'volume', '2026-09-02 09:00', 'p:marco');

  -- L7 is split into three aliquots. They carry the same lot.
  perform move(stock, p.bench, null, '2026-09-03 09:00', 'p:marco');
  box := register_container('box_9x9', '2026-09-03 09:30', 'p:marco', 'BOX-0070', p_into => p.freezer);
  kids := split(stock, bad, 3, 50, 'tube_matrix', '2026-09-03 09:30', 'p:marco', 'L7-', p_into => box);
  perform move(stock, p.freezer, null, '2026-09-03 09:40', 'p:marco');

  -- Aliquot 1 is diluted into a working stock: a new lot made from L7 and running buffer.
  w_tube := register_container('tube_1_5ml', '2026-09-05 09:00', 'p:marco', 'WRK-0701', p_into => p.fridge);
  w := make('target:egfr',
            jsonb_build_array(jsonb_build_object('container', kids[1], 'lot', bad, 'amount', 20),
                              jsonb_build_object('container', buf_b, 'lot', buf, 'amount', 180)),
            w_tube, 200, 'volume', '2026-09-05 09:00', 'p:marco');

  -- BLI plate 1 gets the working stock, plate 2 gets aliquot 2 straight, plate 3 gets the other lot.
  p1 := register_container('plate_bli', '2026-09-05 10:00', 'p:marco', 'BLI-T-0071', p_into => p.bench);
  perform transfer(w_tube, well(p1, 'A1'), w, 50, 'volume', '2026-09-05 10:05', 'p:marco');
  perform transfer(w_tube, well(p1, 'A2'), w, 50, 'volume', '2026-09-05 10:05', 'p:marco');
  p2 := register_container('plate_bli', '2026-09-06 10:00', 'p:marco', 'BLI-T-0072', p_into => p.bench);
  perform transfer(kids[2], well(p2, 'A1'), bad, 40, 'volume', '2026-09-06 10:05', 'p:marco');
  p3 := register_container('plate_bli', '2026-09-06 10:00', 'p:marco', 'BLI-T-0073', p_into => p.bench);
  perform transfer(other_tube, well(p3, 'A1'), other, 40, 'volume', '2026-09-06 10:05', 'p:marco');

  r1 := start_run('BLI', '2026-09-05 11:00', 'p:marco', p_experiment => 'EXP-101');
  ev := consume(well(p1, 'A1'), w, 10, 'volume', '2026-09-05 11:30', 'instrument:gator-1', 'robot_log', r1);
  perform consume(well(p1, 'A2'), w, 10, 'volume', '2026-09-05 11:30', 'instrument:gator-1', p_event => ev);
  perform finish_run(r1, '2026-09-05 12:00', 'instrument:gator-1');
  r2 := start_run('BLI', '2026-09-06 11:00', 'p:marco', p_experiment => 'EXP-102');
  perform consume(well(p2, 'A1'), bad, 10, 'volume', '2026-09-06 11:30', 'instrument:gator-1', 'robot_log', r2);
  perform finish_run(r2, '2026-09-06 12:00', 'instrument:gator-1');
  r3 := start_run('BLI', '2026-09-06 13:00', 'p:marco', p_experiment => 'EXP-999');
  perform consume(well(p3, 'A1'), other, 10, 'volume', '2026-09-06 13:30', 'instrument:gator-1', 'robot_log', r3);
  perform finish_run(r3, '2026-09-06 14:00', 'instrument:gator-1');

  -- Three weeks later L7 is found to be degraded. Forward walk, step 1: the
  -- lots made from it. The aliquots are L7 itself; the working stock is a descendant.
  perform expect((select array_agg(lot_id order by lot_id) from lot_descendants(bad, 'infinity')),
                 array[bad, w], 'lots descended from L7');

  -- Step 2: every container that ever held any of them.
  perform expect((select count(distinct q.container_id)
                  from events_at('2026-09-25', 'infinity') e join quantity_entry q on q.event_id = e.id
                  where q.amount > 0 and q.lot_id in (select lot_id from lot_descendants(bad, 'infinity'))),
                 8::bigint, 'containers that held L7 or its working stock (stock, 3 aliquots, working tube, 3 wells)');

  -- Step 3: every run that consumed them, and the experiments those runs belong to.
  perform expect((select array_agg(distinct r.experiment_ref order by r.experiment_ref)
                  from events_at('2026-09-25', 'infinity') e
                  join quantity_entry q on q.event_id = e.id and q.reason = 'consume'
                  join run r on r.id = e.run_id
                  where q.lot_id in (select lot_id from lot_descendants(bad, 'infinity'))),
                 array['EXP-101', 'EXP-102'], 'experiments that used L7');

  -- And what's still in stock and needs to be quarantined: the BLI plates are gone,
  -- the stock tube, three aliquots and the working stock are not.
  perform expect((select count(*) from usable('2026-09-25', 'infinity')
                  where lot_id in (select lot_id from lot_descendants(bad, 'infinity')) and not 'discarded' = any(reasons)),
                 5::bigint, 'containers left to quarantine');

  -- ASK-014, backward from BLI plate 1 well A1: the working stock, then L7 and
  -- the running buffer, then the HEPES and NaCl the buffer was made from.
  perform expect((select array_agg(distinct q.lot_id) from quantity_entry q
                  where q.container_id = well(p1, 'A1') and q.amount > 0),
                 array[w], 'what went into plate 1 A1');
  perform expect((select array_agg(a.lot_id order by a.lot_id) from lot_ancestors(w, 'infinity') a
                  join lot l on l.id = a.lot_id where l.origin = 'received'),
                 array[bad, hepes, nacl], 'supplier lots behind plate 1 A1');
  perform expect((select array_agg(l.supplier_lot_code order by a.lot_id) from lot_ancestors(w, 'infinity') a
                  join lot l on l.id = a.lot_id where l.origin = 'received'),
                 array['L7', 'H-77', 'N-12'], 'their supplier lot codes');
  perform expect((select array_agg(a.lot_id) from lot_ancestors(w, 'infinity') a
                  join lot l on l.id = a.lot_id where l.material_id = 'buffer:bli-running'),
                 array[buf], 'the buffer lot behind plate 1 A1');
  -- The other target lot is nowhere in it.
  perform expect_true(not exists (select 1 from lot_ancestors(w, 'infinity') where lot_id = other), 'L8 is not behind plate 1 A1');
end $$;
rollback;
