-- D4: a physical count of a freezer box. A missing tube becomes "location
-- uncertain" straight away, but amounts only change once a person approves
-- what the count found.
begin;
do $$
declare
  p record; box bigint; a bigint; b bigint; c bigint; cnt bigint; x record;
begin
  select * into p from test_places();
  box := register_container('box_9x9', '2026-09-01 09:00', 'p:lena', 'BOX-0080', p_into => p.freezer);
  a := register_container('tube_1_5ml', '2026-09-01 09:00', 'p:lena', 'HEP-0801', p_into => box, p_position => 'A1');
  b := register_container('tube_1_5ml', '2026-09-01 09:00', 'p:lena', 'HEP-0802', p_into => box, p_position => 'A2');
  c := register_container('tube_1_5ml', '2026-09-01 09:00', 'p:lena', 'HEP-0803', p_into => box, p_position => 'A3');
  perform receive('vendorC:HEPES', a, 100, 'volume', '2026-09-01 09:00', 'p:lena');
  perform receive('vendorC:HEPES', b, 100, 'volume', '2026-09-01 09:00', 'p:lena');
  perform receive('vendorC:HEPES', c, 100, 'volume', '2026-09-01 09:00', 'p:lena');

  -- Sara counts the box. A1 is there and looks right, A2 is missing, A3 looks like 70 µL.
  cnt := count_place(jsonb_build_array(
           jsonb_build_object('container', a, 'found', true, 'amount', 100, 'dimension', 'volume'),
           jsonb_build_object('container', b, 'found', false),
           jsonb_build_object('container', c, 'found', true, 'amount', 70, 'dimension', 'volume')),
         '2026-09-10 10:00', 'p:sara', 'Monthly count of BOX-0080');

  -- The missing tube is uncertain at once, and can't be used.
  select * into x from location('2026-09-10 12:00', 'infinity') where container_id = b;
  perform expect(x.status, 'uncertain', 'missing tube status');
  perform expect((select reasons from usable('2026-09-10 12:00', 'infinity') where container_id = b),
                 array['location uncertain'], 'missing tube is not usable');
  perform expect((select count(*) from flags('2026-09-10 12:00', 'infinity') where flag = 'location uncertain' and container_id = b),
                 1::bigint, 'location uncertain flag');
  -- The tubes that were found are confirmed by the count.
  select * into x from location('2026-09-10 12:00', 'infinity') where container_id = a;
  perform expect(x.last_confirmed_how, 'found in a count', 'tube A1 confirmed by the count');

  -- But nothing has changed amounts yet.
  perform expect((select held from usable('2026-09-10 12:00', 'infinity') where container_id = b), 100::numeric, 'missing tube still held');
  perform expect((select held from usable('2026-09-10 12:00', 'infinity') where container_id = c), 100::numeric, 'short tube before approval');

  -- Next day Sara approves the count.
  perform approve_count(cnt, '2026-09-11 09:00', 'p:sara', 'Checked the box again, count stands');

  -- Now the balances match what was counted.
  perform expect((select held from usable('2026-09-11 12:00', 'infinity') where container_id = a), 100::numeric, 'A1 after approval');
  perform expect((select count(*) from balances('2026-09-11 12:00', 'infinity') where container_id = b), 0::bigint, 'A2 written off');
  perform expect((select held from usable('2026-09-11 12:00', 'infinity') where container_id = c), 70::numeric, 'A3 after approval');
  perform expect((select count(*) from quantity_entry q join event e on e.id = q.event_id
                  where e.kind = 'count approved' and q.reason = 'adjust'), 2::bigint, 'adjustments written by the approval');

  -- A week later the missing tube turns up in another box and gets scanned. It's no longer uncertain.
  perform scan(b, '2026-09-18 09:00', 'p:lena', 'HEP-0802', box);
  select * into x from location('2026-09-18 12:00', 'infinity') where container_id = b;
  perform expect(x.status, 'placed', 'found tube status');
  perform expect(x.last_confirmed_how, 'scanned', 'found tube confirmed by the scan');
  perform expect((select count(*) from flags('2026-09-18 12:00', 'infinity') where flag = 'location uncertain'), 0::bigint, 'no uncertain flags left');
end $$;
rollback;
