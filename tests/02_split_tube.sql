-- XFER-001: a scientist splits a target stock tube into single-use aliquots.
begin;
do $$
declare
  p record; stock bigint; box bigint; lot1 bigint; kids bigint[]; total numeric; u record;
begin
  select * into p from test_places();
  stock := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0001', p_into => p.freezer);
  lot1 := receive('vendorA:EGFR-100', stock, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L4471');
  perform qc(lot1, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- Thawed on the bench, split into 20 tubes of 24 µL, which go into a box in the freezer.
  perform move(stock, p.bench, null, '2026-09-03 09:00', 'p:marco');
  box := register_container('box_9x9', '2026-09-03 09:30', 'p:marco', 'BOX-0007', p_into => p.freezer);
  kids := split(stock, lot1, 20, 24, 'tube_matrix', '2026-09-03 09:30', 'p:marco', 'ALQ-', p_into => box);
  perform move(stock, p.freezer, null, '2026-09-03 09:40', 'p:marco');

  perform expect(cardinality(kids), 20, 'number of aliquots');

  -- Every aliquot carries the same lot, so it also carries the QC pass.
  perform expect((select count(distinct lot_id) from balances('2026-09-03 10:00') where container_id = any(kids)), 1::bigint, 'one lot across aliquots');
  perform expect((select count(*) from usable('2026-09-03 10:00') where container_id = any(kids) and cardinality(reasons) = 0), 20::bigint, 'all aliquots usable');

  -- Nothing appeared out of thin air: 480 µL in the aliquots, 20 µL left in the stock tube.
  select sum(held) into total from usable('2026-09-03 10:00') where lot_id = lot1;
  perform expect(total, 500::numeric, 'total held across stock and aliquots');
  select * into u from usable('2026-09-03 10:00') where container_id = stock;
  perform expect(u.held, 20::numeric, 'left in the stock tube');
  perform expect(u.usable, 15::numeric, 'usable in the stock tube, minus 5 µL dead volume');

  -- Each aliquot holds 24 µL but 10 µL is stuck at the bottom of a matrix tube.
  perform expect((select sum(usable) from usable('2026-09-03 10:00') where container_id = any(kids)), 280::numeric, 'usable across aliquots');

  -- The stock tube was thawed once before the split, so the aliquots inherit one thaw.
  perform expect((select max(thaws) from usable('2026-09-03 10:00') where container_id = any(kids)), 1::bigint, 'thaws inherited by aliquots');

  -- Each aliquot can be found: box, slot, freezer.
  perform expect((select path from location('2026-09-03 10:00') where container_id = kids[7]),
                 'Freezer F1 > box_9x9 #' || box || ' @slot 7', 'location of aliquot 7');
end $$;
rollback;
