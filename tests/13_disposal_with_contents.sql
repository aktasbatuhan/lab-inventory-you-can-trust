-- LIFE-017, EDGE-016: a plate is thrown away with 30 µL still in three wells.
-- The leftover stays on record as what was thrown out. Then the plate turns up
-- on the bench, and the disposal is undone.
begin;
do $$
declare
  p record; tube bigint; l bigint; plate bigint; disp bigint; fix bigint; u record;
begin
  select * into p from test_places();
  tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0401', p_into => p.fridge);
  l := receive('vendorA:EGFR-100', tube, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L4471');
  perform qc(l, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- A working plate in the fridge with 30 µL of target in A1, A2 and A3.
  plate := register_container('plate_96', '2026-09-03 09:00', 'p:marco', 'WP-0101', p_into => p.fridge);
  for i in 1 .. 3 loop
    perform transfer(tube, well(plate, 'A' || i), l, 30, 'volume', '2026-09-03 09:10', 'p:marco');
  end loop;
  perform expect((select sum(usable) from usable('2026-09-04 12:00', 'infinity') where container_id in
                  (select id from container where plate_id = plate)), 84::numeric, 'usable in the plate before disposal');

  -- The project is done; Marco scans the plate into the bin.
  disp := discard(plate, '2026-09-05 16:00', 'p:marco', p_note => 'project done');

  -- Each well still shows what was in it, but none of it is usable, and the reason is 'discarded'.
  perform expect((select count(*) from usable('2026-09-05 17:00', 'infinity')
                  where container_id in (select id from container where plate_id = plate)
                    and held = 30 and usable = 0 and reasons = array['discarded']), 3::bigint, 'wells after disposal');
  perform expect((select status from location('2026-09-05 17:00', 'infinity') where container_id = plate), 'discarded', 'plate status');

  -- The write-off is the amount held at the moment of disposal: 90 µL of target, thrown out, not consumed.
  perform expect((select sum(b.amount)
                  from exits('2026-09-05 17:00', 'infinity') x
                  join container w on w.plate_id = x.container_id
                  join lateral balances(x.exited_at, 'infinity') b on b.container_id = w.id
                  where x.container_id = plate and x.kind = 'discard'), 90::numeric, 'target thrown away with the plate');
  perform expect((select count(*) from quantity_entry where reason = 'consume' and container_id in
                  (select id from container where plate_id = plate)), 0::bigint, 'nothing recorded as consumed');

  -- Next morning it turns up on the bench and someone scans it. That doesn't fit the record.
  perform scan(plate, '2026-09-06 09:00', 'p:lena', 'WP-0101', p.bench);
  perform expect((select count(*) from flags('2026-09-06 10:00', 'infinity') where flag = 'seen after it left' and container_id = plate),
                 1::bigint, 'seen-after-it-left flag');

  -- Marco admits he never threw it out. The disposal is voided.
  fix := void(disp, 'p:marco', 'Scanned into the bin by mistake, plate was left on the bench', '2026-09-06 09:30');

  -- The plate is back, its wells usable again, and the flag is gone.
  perform expect((select count(*) from usable('2026-09-06 10:00', 'infinity')
                  where container_id in (select id from container where plate_id = plate)
                    and usable = 28 and reasons = '{}'), 3::bigint, 'wells after the disposal was undone');
  perform expect((select count(*) from flags('2026-09-06 10:00', 'infinity') where container_id = plate), 0::bigint, 'flags after undo');
  perform expect((select count(*) from exits('2026-09-06 10:00', 'infinity') where container_id = plate), 0::bigint, 'no exit on record');

  -- What the system said on the evening of the 5th hasn't changed.
  perform expect((select status from location('2026-09-05 17:00', '2026-09-05 17:00') where container_id = plate),
                 'discarded', 'the 5th, as known on the 5th');
end $$;
rollback;
