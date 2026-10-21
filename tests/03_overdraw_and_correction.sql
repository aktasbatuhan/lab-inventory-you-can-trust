-- XFER-003, D1, ASK-016, ASK-017: someone takes more than the record says is
-- there. We record it, flag it, and later fix the real mistake. The history
-- keeps both versions.
begin;
do $$
declare
  p record; tube bigint; lot1 bigint; bad bigint; fix bigint; u record;
begin
  select * into p from test_places();
  tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0001', p_into => p.freezer);
  lot1 := receive('vendorA:EGFR-100', tube, 100, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L4471');
  perform qc(lot1, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- Monday: Marco takes 80 µL, but types 30 (an extra zero lost the other way round happens too).
  bad := consume(tube, lot1, 30, 'volume', '2026-09-07 10:00', 'p:marco');
  -- Tuesday: Lena takes 75 µL. The record says only 70 is there.
  perform consume(tube, lot1, 75, 'volume', '2026-09-08 10:00', 'p:lena');

  -- Decision D1: we don't refuse. The balance goes negative, it's flagged, and nothing in the tube counts as usable.
  select * into u from usable('2026-09-08 12:00') where container_id = tube;
  perform expect(u.held, -5::numeric, 'balance after overdraw');
  perform expect_true('negative balance' = any(u.reasons), 'negative balance blocks use');
  perform expect((select count(*) from flags('2026-09-08 12:00') where flag = 'negative balance' and container_id = tube), 1::bigint, 'flag raised');

  -- Thursday: Marco checks his notebook. It was 80, not 30. He records a correction.
  fix := void(bad, 'p:marco', 'Typed 30, notebook says 80', '2026-09-10 16:00');
  perform consume(tube, lot1, 80, 'volume', '2026-09-07 10:00', 'p:marco', p_event => fix);

  -- Now Tuesday's draw looks impossible instead (only 20 was left), and that is the truth.
  select * into u from usable('2026-09-08 12:00') where container_id = tube;
  perform expect(u.held, -55::numeric, 'Tuesday, as we know it now');

  -- But what did the system say on Tuesday evening? Exactly what it said then.
  select * into u from usable('2026-09-08 18:00', '2026-09-08 18:00') where container_id = tube;
  perform expect(u.held, -5::numeric, 'Tuesday, as we knew it on Tuesday');

  -- The old entry is still there, marked as corrected, with who and why.
  perform expect((select count(*) from event where id = bad), 1::bigint, 'original entry kept');
  perform expect((select note from event where voids_event_id = bad), 'Typed 30, notebook says 80', 'reason for the correction');

  -- Lena admits she took 15, not 75. Her correction makes the books balance.
  fix := void((select e.id from event e join quantity_entry q on q.event_id = e.id
               where q.container_id = tube and q.amount = -75), 'p:lena', 'Took 15, typed 75', '2026-09-11 09:00');
  perform consume(tube, lot1, 15, 'volume', '2026-09-08 10:00', 'p:lena', p_event => fix);
  select * into u from usable('2026-09-11 12:00') where container_id = tube;
  perform expect(u.held, 5::numeric, 'balance after both corrections');
  perform expect((select count(*) from flags('2026-09-11 12:00') where flag = 'negative balance'), 0::bigint, 'flag gone');

  -- A correction can be corrected too: undoing Lena's fix brings the old numbers back.
  perform void(fix, 'p:sara', 'Lena''s fix was entered on the wrong tube', '2026-09-12 09:00');
  select * into u from usable('2026-09-12 12:00') where container_id = tube;
  perform expect(u.held, -55::numeric, 'after the correction is corrected');

  -- Facts can't be edited or deleted.
  perform expect_error(format('update quantity_entry set amount = -1 where event_id = %s', bad), 'append-only', 'editing a fact');
  perform expect_error(format('delete from event where id = %s', bad), 'append-only', 'deleting a fact');
end $$;
rollback;
