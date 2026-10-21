-- ASK-001, ASK-003: how much EGFR do we hold, and how much of it can we use?
-- The answer is always two numbers plus the reasons for the gap.
begin;
do $$
declare
  p record; stock bigint; good bigint; old bigint; held_tube bigint; dregs bigint; bad_tube bigint;
  la bigint; lb bigint; h bigint; s record;
begin
  select * into p from test_places();

  -- Lot A passed QC and was poured out into several tubes. Lot B failed QC.
  stock := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0601', p_into => p.freezer);
  la := receive('vendorA:EGFR-100', stock, 500, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'LA-1');
  perform qc(la, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');
  bad_tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0602', p_into => p.freezer);
  lb := receive('vendorB:EGFR-7', bad_tube, 200, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'LB-9');
  perform qc(lb, 'fail', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  good := register_container('tube_1_5ml', '2026-09-03 09:00', 'p:marco', 'TGT-0611', p_into => p.freezer);
  old := register_container('tube_1_5ml', '2026-09-03 09:00', 'p:marco', 'TGT-0612', p_into => p.fridge);
  held_tube := register_container('tube_1_5ml', '2026-09-03 09:00', 'p:marco', 'TGT-0613', p_into => p.freezer);
  dregs := register_container('tube_1_5ml', '2026-09-03 09:00', 'p:marco', 'TGT-0614', p_into => p.freezer);
  perform transfer(stock, good, la, 100, 'volume', '2026-09-03 09:10', 'p:marco');
  perform transfer(stock, old, la, 100, 'volume', '2026-09-03 09:10', 'p:marco');       -- in the fridge: 7 days
  perform transfer(stock, held_tube, la, 100, 'volume', '2026-09-03 09:10', 'p:marco');
  perform transfer(stock, dregs, la, 4, 'volume', '2026-09-03 09:10', 'p:marco');       -- less than the 5 µL a pipette can't reach
  perform hold('looks cloudy, check before use', '2026-09-04 09:00', 'p:sara', p_container => held_tube);

  -- The per-material answer on 20 September.
  select sum(held) as held, sum(usable) as usable into s
  from usable('2026-09-20 12:00', 'infinity') where material_id = 'target:egfr' and dimension = 'volume';
  perform expect(s.held, 700::numeric, 'EGFR held');
  perform expect(s.usable, 286::numeric, 'EGFR usable (191 in the stock tube, 95 in the good one)');

  -- And the gap, by reason. Each µL that isn't usable has a reason; the last
  -- line is the liquid stuck at the bottom of tubes that are otherwise fine.
  perform expect((
    select array_agg(reason || ' ' || trim_scale(amount) order by reason) from (
      select r as reason, sum(held) as amount
      from usable('2026-09-20 12:00', 'infinity'), unnest(reasons) r
      where material_id = 'target:egfr' and dimension = 'volume'
      group by r
      union all
      select 'dead volume', sum(held - usable)
      from usable('2026-09-20 12:00', 'infinity')
      where material_id = 'target:egfr' and dimension = 'volume' and cardinality(reasons) = 0
    ) gap),
    array['below dead volume 4', 'container on hold 100', 'dead volume 10', 'expired 100', 'failed QC 200'],
    'EGFR gap by reason');

  -- ASK-003: the same answer per lot, so a planner can see what's left of each before ordering.
  perform expect((select array_agg(lot_id || ':' || trim_scale(held) || '/' || trim_scale(usable) order by lot_id) from (
                    select lot_id, sum(held) as held, sum(usable) as usable
                    from usable('2026-09-20 12:00', 'infinity') where material_id = 'target:egfr' group by lot_id) x),
                 array[la || ':500/286', lb || ':200/0'], 'held and usable per lot');

  -- A hold on lot A blocks every container of it at once.
  h := hold('supplier warning about lot LA-1', '2026-09-21 09:00', 'p:sara', p_lot => la);
  perform expect((select sum(usable) from usable('2026-09-21 12:00', 'infinity') where lot_id = la), 0::numeric, 'lot A usable while on hold');
  perform expect((select count(*) from usable('2026-09-21 12:00', 'infinity') where lot_id = la and 'lot on hold' = any(reasons)),
                 5::bigint, 'containers of lot A blocked by the hold');

  -- Released the next day, and the two good tubes are usable again.
  perform release(h, '2026-09-22 09:00', 'p:sara', 'Supplier says the warning was for another lot');
  perform expect((select sum(usable) from usable('2026-09-22 12:00', 'infinity') where lot_id = la), 286::numeric, 'lot A usable after release');
  -- The container hold on the cloudy tube is separate and still there.
  perform expect((select reasons from usable('2026-09-22 12:00', 'infinity') where container_id = held_tube),
                 array['container on hold'], 'container hold outlives the lot hold');
end $$;
rollback;
