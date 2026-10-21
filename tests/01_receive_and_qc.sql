-- RCV-003, RCV-001: a target arrives, waits for QC, then passes or fails.
begin;
do $$
declare
  p record; tube bigint; tube2 bigint; lot1 bigint; lot2 bigint; u record;
begin
  select * into p from test_places();
  tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0001', p_into => p.freezer);
  lot1 := receive('vendorA:EGFR-100', tube, 500, 'volume', '2026-09-01 10:00', 'p:lena',
                  p_supplier_lot => 'L4471', p_ref => 'delivery:DN-9001', p_price => 300);

  -- Arrived, but nobody has checked it yet: we hold 500 µL and can use none of it.
  select * into u from usable('2026-09-01 12:00') where container_id = tube;
  perform expect(u.held, 500::numeric, 'held after arrival');
  perform expect(u.usable, 0::numeric, 'usable before QC');
  perform expect(u.reasons, array['waiting for QC'], 'reasons before QC');

  -- QC passes the next day. Now it's usable, minus the 5 µL a pipette can't reach.
  perform qc(lot1, 'pass', 'SDS-PAGE and concentration', '2026-09-02 09:00', 'p:marco');
  select * into u from usable('2026-09-02 12:00') where container_id = tube;
  perform expect(u.usable, 495::numeric, 'usable after QC pass');

  -- Looking back at yesterday still says "waiting for QC".
  select * into u from usable('2026-09-01 12:00') where container_id = tube;
  perform expect(u.reasons, array['waiting for QC'], 'yesterday, seen from today');

  -- A second delivery of the same supplier lot is a new batch and waits for its own QC (decision D2).
  tube2 := register_container('tube_1_5ml', '2026-09-20 10:00', 'p:lena', 'TGT-0002', p_into => p.freezer);
  lot2 := receive('vendorA:EGFR-100', tube2, 500, 'volume', '2026-09-20 10:00', 'p:lena',
                  p_supplier_lot => 'L4471', p_ref => 'delivery:DN-9377');
  perform expect_true(lot2 <> lot1, 'second delivery is its own batch');
  select * into u from usable('2026-09-20 12:00') where container_id = tube2;
  perform expect(u.reasons, array['waiting for QC'], 'second delivery of a checked lot');

  -- It fails. It still exists, and the record says exactly why it can't be used.
  perform qc(lot2, 'fail', 'SDS-PAGE and concentration', '2026-09-21 09:00', 'p:marco', '{"concentration_mg_ml": 0.21}');
  select * into u from usable('2026-09-21 12:00') where container_id = tube2;
  perform expect(u.held, 500::numeric, 'failed lot is still held');
  perform expect(u.reasons, array['failed QC'], 'reasons after QC fail');
end $$;
rollback;
