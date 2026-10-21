-- RCV-011, EDGE-023: the same delivery gets registered twice. A retry of the
-- same delivery note is refused by the database. A second registration under a
-- different reference gets through, is flagged, and is undone with a correction.
begin;
do $$
declare
  p record; tube1 bigint; tube2 bigint; lot1 bigint; lot2 bigint; fix bigint;
begin
  select * into p from test_places();

  -- Lena registers the box at the door from the packing slip.
  tube1 := register_container('tube_1_5ml', '2026-09-14 09:00', 'p:lena', 'TGT-0101', p_into => p.freezer);
  lot1 := receive('vendorA:EGFR-100', tube1, 400, 'volume', '2026-09-14 09:00', 'p:lena',
                  p_supplier_lot => 'B1102', p_ref => 'delivery:DN-1102');

  -- The import job times out and sends the same delivery note again. One real
  -- delivery can only be counted once, so the database says no.
  perform expect_error(
    format('select receive(%L, %s, 400, %L, %L, %L, p_supplier_lot => %L, p_ref => %L)',
           'vendorA:EGFR-100', tube1, 'volume', '2026-09-14 09:05', 'system:import', 'B1102', 'delivery:DN-1102'),
    'duplicate key', 'registering the same delivery note twice');
  perform expect((select count(*) from lot where product_id = 'vendorA:EGFR-100'), 1::bigint, 'lots after the refused retry');

  -- Marco unpacks the same box at the freezer and registers it again, scanning
  -- a fresh tube. He has no delivery note in hand, so the reference is his own.
  tube2 := register_container('tube_1_5ml', '2026-09-14 11:00', 'p:marco', 'TGT-0102', p_into => p.freezer);
  lot2 := receive('vendorA:EGFR-100', tube2, 400, 'volume', '2026-09-14 11:00', 'p:marco',
                  p_supplier_lot => 'B1102', p_ref => 'unpack:marco-0914-1');

  -- That gets through, but it looks like the first one: same product, same
  -- supplier lot, same amount, two hours apart.
  perform expect((select count(*) from flags('2026-09-14 12:00', '2026-09-14 12:00')
                  where flag = 'possible duplicate delivery' and lot_id = lot2), 1::bigint, 'duplicate delivery flag');
  perform expect((select sum(held) from usable('2026-09-14 12:00', '2026-09-14 12:00') where material_id = 'target:egfr'),
                 800::numeric, 'held while the double entry stands');

  -- Next morning Sara voids Marco's registration, and the tube he registered with it.
  fix := void((select created_event_id from lot where id = lot2), 'p:sara',
              'Same box registered twice, once at the door and once at the freezer', '2026-09-15 10:00');
  perform void((select created_event_id from container where id = tube2), 'p:sara',
               'Ghost tube from the double registration', '2026-09-15 10:00');

  -- The flag and the extra 400 µL are gone, and so is the ghost tube.
  perform expect((select count(*) from flags('2026-09-15 12:00', '2026-09-15 12:00')
                  where flag = 'possible duplicate delivery'), 0::bigint, 'flag after the correction');
  perform expect((select sum(held) from usable('2026-09-15 12:00', '2026-09-15 12:00') where material_id = 'target:egfr'),
                 400::numeric, 'held after the correction');
  perform expect((select count(*) from balances('2026-09-15 12:00', '2026-09-15 12:00') where container_id = tube2),
                 0::bigint, 'nothing left in the ghost tube');
  perform expect((select count(*) from location('2026-09-15 12:00', '2026-09-15 12:00') where container_id = tube2),
                 0::bigint, 'ghost tube no longer listed');

  -- Asked what the system said on the 14th, it still says 800.
  perform expect((select sum(held) from usable('2026-09-14 12:00', '2026-09-14 12:00') where material_id = 'target:egfr'),
                 800::numeric, 'what we believed on the 14th');

  -- Nothing was deleted: the lot, its event and the reason for undoing it are all on record.
  perform expect((select count(*) from lot where id = lot2), 1::bigint, 'voided lot still on record');
  perform expect((select note from event where id = fix), 'Same box registered twice, once at the door and once at the freezer',
                 'reason for the correction');
end $$;
rollback;
