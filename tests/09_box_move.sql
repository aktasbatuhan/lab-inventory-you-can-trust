-- LOC-002, with a bit of LIFE-002: a box of ten target aliquots moves from the
-- -80 freezer to the fridge with one scan. Every tube in it moves too, and the
-- fridge clock starts for each of them.
begin;
do $$
declare
  p record; stock bigint; box bigint; l bigint; kids bigint[]; mv bigint; x record;
begin
  select * into p from test_places();
  stock := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0301', p_into => p.freezer);
  l := receive('vendorA:EGFR-100', stock, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L4471');
  perform qc(l, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- Thawed on the bench, split into 10 aliquots in a box, back into the -80.
  perform move(stock, p.bench, null, '2026-09-03 09:00', 'p:marco');
  box := register_container('box_9x9', '2026-09-03 09:30', 'p:marco', 'BOX-0012', p_into => p.freezer);
  kids := split(stock, l, 10, 40, 'tube_matrix', '2026-09-03 09:30', 'p:marco', 'ALQ-', p_into => box);
  perform move(stock, p.freezer, null, '2026-09-03 09:40', 'p:marco');

  perform expect((select count(*) from location('2026-09-10 12:00', 'infinity')
                  where container_id = any(kids) and path like 'Freezer F1 > %'), 10::bigint, 'all ten in the freezer');

  -- The week's binding runs need the target close at hand: the whole box goes to the fridge.
  mv := move(box, p.fridge, null, '2026-09-14 08:00', 'p:marco');
  perform expect((select count(*) from placement where event_id = mv), 1::bigint, 'one placement for the whole box');

  -- Every tube is now in the fridge, still in the same slot of the same box.
  perform expect((select count(*) from location('2026-09-14 09:00', 'infinity')
                  where container_id = any(kids) and path like 'Fridge R1 > %'), 10::bigint, 'all ten in the fridge');
  perform expect((select path from location('2026-09-14 09:00', 'infinity') where container_id = kids[4]),
                 'Fridge R1 > box_9x9 #' || box || ' @slot 4', 'aliquot 4 keeps its slot');

  -- Their storage condition changed with the box.
  perform expect((select count(*) from condition_stretches('infinity')
                  where container_id = any(kids) and condition = 'fridge'
                    and from_at = '2026-09-14 08:00' and to_at = 'infinity'), 10::bigint, 'tubes in fridge conditions from the move');
  perform expect((select count(*) from condition_stretches('infinity')
                  where container_id = any(kids) and condition = 'minus80' and to_at = '2026-09-14 08:00'), 10::bigint,
                 'tubes in the -80 until the move');

  -- The fridge clock for each tube starts at the move: 7 days for a thawed target.
  select * into x from expiry('2026-09-14 09:00', 'infinity') where container_id = kids[1];
  perform expect(x.expires_at, '2026-09-21 08:00'::timestamptz, 'aliquot expiry after the move');
  perform expect(x.clock, 'kept in fridge', 'clock that set it');
  perform expect((select count(*) from expiry_clocks('2026-09-14 09:00', 'infinity')
                  where container_id = any(kids) and clock = 'kept in fridge' and started_at = '2026-09-14 08:00'),
                 10::bigint, 'fridge clocks started at the move');

  -- Before the move, no fridge clock was running.
  perform expect((select count(*) from expiry_clocks('2026-09-13 09:00', 'infinity')
                  where container_id = any(kids) and clock = 'kept in fridge'), 0::bigint, 'no fridge clock before the move');

  -- One thaw before the split, one now.
  perform expect((select max(thaws) from usable('2026-09-14 09:00', 'infinity') where container_id = any(kids)), 2::bigint, 'thaws');
end $$;
rollback;
