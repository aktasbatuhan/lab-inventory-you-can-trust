-- Gaps the dice simulation found (journal/agent-runs/schema-gaps-sim.md, items 2, 4, 5 and 7).
begin;
do $$
declare
  p record; kit bigint[] := '{}'; kit_lot bigint; t1 bigint; t2 bigint; l1 bigint; l2 bigint;
  wrong bigint; fix bigint; kids bigint[]; plate bigint; pl bigint;
begin
  select * into p from test_places();

  -- Item 2: a kit is six tubes of one supplier lot. It's one lot, in six tubes,
  -- and nothing is flagged as a duplicate delivery.
  for i in 1 .. 6 loop
    kit := kit || register_container('tube_1_5ml', '2026-09-01 09:00', 'p:lena', 'KIT-' || i, p_into => p.freezer);
  end loop;
  kit_lot := receive('vendorD:PURE', kit[1], 1000, 'volume', '2026-09-01 09:00', 'p:lena', p_supplier_lot => 'K77', p_ref => 'delivery:DN-500');
  for i in 2 .. 6 loop
    perform receive('vendorD:PURE', kit[i], 1000, 'volume', '2026-09-01 09:00', 'p:lena', p_lot => kit_lot);
  end loop;
  perform expect((select count(distinct lot_id) from balances('2026-09-02', 'infinity') where container_id = any(kit)), 1::bigint, 'one lot across the kit');
  perform expect((select sum(amount) from balances('2026-09-02', 'infinity') where lot_id = kit_lot), 6000::numeric, 'whole kit on one lot');
  perform expect((select count(*) from flags('2026-09-02', 'infinity') where flag = 'possible duplicate delivery'), 0::bigint, 'no duplicate flag for a kit');

  -- Item 4: two real orders of the same supplier lot, two days apart. The flag
  -- is right to ask; a person checks the delivery notes and closes it.
  t1 := register_container('bottle', '2026-09-03 09:00', 'p:lena', 'WAT-1', p_into => p.bench);
  t2 := register_container('bottle', '2026-09-05 09:00', 'p:lena', 'WAT-2', p_into => p.bench);
  l1 := receive('vendorC:WATER', t1, 500000, 'volume', '2026-09-03 09:00', 'p:lena', p_supplier_lot => 'W1', p_ref => 'delivery:DN-601');
  l2 := receive('vendorC:WATER', t2, 500000, 'volume', '2026-09-05 09:00', 'p:lena', p_supplier_lot => 'W1', p_ref => 'delivery:DN-644');
  perform expect((select count(*) from flags('2026-09-05 12:00', 'infinity') where flag = 'possible duplicate delivery'), 1::bigint, 'two orders look like one delivery twice');
  perform review_flag('possible duplicate delivery', '2026-09-05 14:00', 'p:sara', 'Two separate orders, DN-601 and DN-644', p_lot => l2);
  perform expect((select count(*) from flags('2026-09-05 15:00', 'infinity') where flag = 'possible duplicate delivery'), 0::bigint, 'flag closed after review');
  perform expect((select count(*) from flags('2026-09-05 13:00', '2026-09-05 13:00') where flag = 'possible duplicate delivery'), 1::bigint, 'still open as known before the review');

  -- Item 5: a delivery typed as 500 µL was really 300 µL, and it was already
  -- split before anyone noticed. The correction keeps the same lot, so the
  -- aliquots stay connected to it.
  t1 := register_container('tube_1_5ml', '2026-09-10 09:00', 'p:lena', 'TGT-0900', p_into => p.freezer);
  l1 := receive('vendorA:EGFR-100', t1, 500, 'volume', '2026-09-10 09:00', 'p:lena', p_supplier_lot => 'L9', p_ref => 'delivery:DN-700');
  perform qc(l1, 'pass', 'SDS-PAGE', '2026-09-10 12:00', 'p:marco');
  kids := split(t1, l1, 10, 25, 'tube_matrix', '2026-09-11 10:00', 'p:marco', 'ALQ9-');
  wrong := (select created_event_id from lot where id = l1);
  fix := void(wrong, 'p:lena', 'Delivery note says 300 µL, not 500', '2026-09-12 09:00');
  perform receive('vendorA:EGFR-100', t1, 300, 'volume', '2026-09-10 09:00', 'p:lena', p_event => fix, p_lot => l1);
  perform expect((select amount from balances('2026-09-12 10:00', 'infinity') where container_id = t1), 50::numeric, 'stock tube after the corrected delivery');
  perform expect((select sum(amount) from balances('2026-09-12 10:00', 'infinity') where lot_id = l1), 300::numeric, 'lot total after the correction');
  perform expect((select count(*) from usable('2026-09-12 10:00', 'infinity') where container_id = any(kids) and cardinality(reasons) = 0), 10::bigint, 'aliquots still usable on the same lot');

  -- Item 7: a plate recorded as thrown away is later pipetted from. That counts
  -- as seeing it, so it's flagged, not just quietly left out of "usable".
  plate := register_container('plate_96', '2026-09-15 09:00', 'p:marco', 'PL-77', p_into => p.fridge);
  pl := receive('vendorA:EGFR-100', well(plate, 'A1'), 100, 'volume', '2026-09-15 09:00', 'p:marco', p_supplier_lot => 'L10', p_ref => 'delivery:DN-800');
  perform discard(plate, '2026-09-16 09:00', 'p:lena');
  perform consume(well(plate, 'A1'), pl, 20, 'volume', '2026-09-16 11:00', 'p:marco');
  perform expect((select count(*) from flags('2026-09-16 12:00', 'infinity') where flag = 'seen after it left' and container_id = plate), 1::bigint, 'pipetting from a binned plate is flagged');
end $$;
rollback;
