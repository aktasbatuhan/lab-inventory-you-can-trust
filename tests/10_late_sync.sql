-- LOC-014, EDGE-010: an offline handheld scanner syncs a move hours late. The
-- late move adds history but doesn't drag the tube back to where it was, and
-- every location answer says when and how it was last confirmed.
begin;
do $$
declare
  p record; f2 bigint; tube bigint; l bigint; x record;
begin
  select * into p from test_places();
  f2 := register_container('freezer', '2026-01-01', 'p:sara', p_name => 'Freezer F2', p_condition => 'minus20', p_source => 'manual');
  tube := register_container('tube_1_5ml', '2026-09-21 08:00', 'p:lena', 'T1', p_into => p.freezer);
  l := receive('vendorC:HEPES', tube, 1000, 'volume', '2026-09-21 08:00', 'p:lena');

  -- 10:00 Lena's scanner, offline, records T1 going to the bench. It doesn't sync yet.
  -- 11:00 Marco, online, scans T1 into freezer F2.
  perform move(tube, f2, null, '2026-09-21 11:00', 'p:marco');

  -- Before the sync, the record says T1 went straight from F1 to F2.
  select * into x from location('2026-09-21 10:30', '2026-09-21 12:00') where container_id = tube;
  perform expect(x.path, 'Freezer F1', 'at 10:30, as known before the sync');

  -- 13:00 the scanner comes back online and sends its 3-hour-old move.
  perform move(tube, p.bench, null, '2026-09-21 10:00', 'p:lena', p_recorded => '2026-09-21 13:00');

  -- Where is T1 now? Still F2: the late move happened before Marco's, so it can't undo it.
  select * into x from location('2026-09-21 14:00', 'infinity') where container_id = tube;
  perform expect(x.path, 'Freezer F2', 'location now');
  perform expect(x.last_confirmed_at, '2026-09-21 11:00'::timestamptz, 'last confirmed');
  perform expect(x.last_confirmed_how, 'moved with a scan', 'how it was last confirmed');

  -- But the bench hour is now part of the story: at 10:30 T1 was on the bench.
  select * into x from location('2026-09-21 10:30', 'infinity') where container_id = tube;
  perform expect(x.path, 'Bench B1', 'at 10:30, as known after the sync');
  -- And asked as of before the sync, the old answer stays what it was.
  select * into x from location('2026-09-21 10:30', '2026-09-21 12:00') where container_id = tube;
  perform expect(x.path, 'Freezer F1', 'at 10:30, as known before the sync, asked again');

  -- 15:00 Sara moves T1 to the fridge and types it in by hand, no scan. The
  -- place changes, but nobody actually confirmed it, so the last confirmation stays at 11:00.
  perform move(tube, p.fridge, null, '2026-09-21 15:00', 'p:sara', 'manual');
  select * into x from location('2026-09-21 16:00', 'infinity') where container_id = tube;
  perform expect(x.path, 'Fridge R1', 'location after the typed move');
  perform expect(x.last_confirmed_at, '2026-09-21 11:00'::timestamptz, 'a typed move is not a confirmation');
  perform expect(x.last_confirmed_how, 'moved with a scan', 'still the 11:00 scan');

  -- A scan of the tube in the fridge confirms it.
  perform scan(tube, '2026-09-21 17:00', 'p:lena', 'T1', p.fridge);
  select * into x from location('2026-09-21 18:00', 'infinity') where container_id = tube;
  perform expect(x.last_confirmed_at, '2026-09-21 17:00'::timestamptz, 'confirmed by the scan');
  perform expect(x.last_confirmed_how, 'scanned', 'how');
end $$;
rollback;
