-- EDGE-011, LOC-007, D3: a barcode is a label a container wears, not the container.
begin;
do $$
declare
  p record; old_plate bigint; other_plate bigint; new_plate bigint; t1 bigint; t2 bigint; hepes bigint;
begin
  select * into p from test_places();

  -- Plate P-500 sits on the bench with a buffer component in two wells.
  old_plate := register_container('plate_96', '2026-09-01 09:00', 'p:marco', 'P-500', p_into => p.bench);
  hepes := receive('vendorC:HEPES', well(old_plate, 'A1'), 50, 'volume', '2026-09-01 09:00', 'p:marco');
  perform transfer(well(old_plate, 'A1'), well(old_plate, 'A2'), hepes, 20, 'volume', '2026-09-01 09:10', 'p:marco');

  -- Someone sticks a second P-500 label on another plate while the first is still in use. Refused.
  other_plate := register_container('plate_96', '2026-09-02 09:00', 'p:marco', 'P-501', p_into => p.bench);
  perform expect_error(format('select attach_label(%s, %L, %L, %L)', other_plate, 'P-500', '2026-09-02 09:05', 'p:marco'),
                       'already on a live container', 'a second live container with barcode P-500');

  -- An import from the old system brings in a tube whose label clashes with one
  -- we already have (two labels printed from the same roll). Imports are let
  -- through, so the clash shows up instead of being lost.
  t1 := register_container('tube_1_5ml', '2026-09-03 09:00', 'p:lena', '004271', p_into => p.fridge);
  perform receive('vendorC:NACL', t1, 300, 'volume', '2026-09-03 09:00', 'p:lena');
  t2 := register_container('tube_1_5ml', '2026-09-03 10:00', 'system:import', '004271', p_into => p.fridge, p_source => 'import');
  perform receive('vendorC:NACL', t2, 200, 'volume', '2026-09-03 10:00', 'system:import', p_source => 'import');

  -- Both tubes are flagged and neither is usable until someone says which is which.
  perform expect((select count(*) from flags('2026-09-03 12:00', '2026-09-03 12:00')
                  where flag = 'barcode clash' and container_id in (t1, t2)), 2::bigint, 'clash flagged on both tubes');
  perform expect((select count(*) from usable('2026-09-03 12:00', '2026-09-03 12:00')
                  where container_id in (t1, t2) and usable = 0 and 'barcode clash' = any(reasons)), 2::bigint, 'both tubes unusable');
  -- Scanning 004271 can't pick a tube: the barcode points at two.
  perform expect((select count(*) from live_labels('2026-09-03 12:00', '2026-09-03 12:00') where barcode = '004271'),
                 2::bigint, 'containers behind barcode 004271');

  -- Plate P-500 is thrown away at the end of the month, label and all.
  perform discard(old_plate, '2026-09-30 17:00', 'p:marco');

  -- In October an old sheet of labels comes out and P-500 goes on a brand new plate. That's allowed now.
  new_plate := register_container('plate_96', '2026-10-05 09:00', 'p:marco', 'P-500', p_into => p.bench);
  perform scan(new_plate, '2026-10-05 10:00', 'p:marco', 'P-500', p.bench);

  -- The barcode now means the new plate, and the old plate stays thrown away.
  perform expect((select container_id from live_labels('2026-10-05 12:00', '2026-10-05 12:00') where barcode = 'P-500'),
                 new_plate, 'P-500 now means the new plate');
  perform expect((select status from location('2026-10-05 12:00', '2026-10-05 12:00') where container_id = old_plate),
                 'discarded', 'old plate is still thrown away');
  perform expect((select count(*) from usable('2026-10-05 12:00', '2026-10-05 12:00')
                  where container_id in (well(old_plate, 'A1'), well(old_plate, 'A2')) and 'discarded' = any(reasons) and usable = 0),
                 2::bigint, 'old plate wells still count as discarded');
  perform expect((select count(*) from flags('2026-10-05 12:00', '2026-10-05 12:00') where container_id = old_plate),
                 0::bigint, 'scanning the new plate says nothing about the old one');

  -- The label history remembers that two plates have worn P-500.
  perform expect((select count(distinct container_id) from label where barcode = 'P-500'), 2::bigint, 'plates that have worn P-500');
end $$;
rollback;
