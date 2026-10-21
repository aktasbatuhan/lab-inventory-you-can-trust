-- D7: freeze-thaw limits are rules at three levels, the most specific wins, and
-- going over warns instead of blocking. Vendor B's EGFR has no glycerol and
-- takes one thaw; any other target takes three.
begin;
do $$
declare
  p record; ta bigint; tb bigint; la bigint; lb bigint; ua record; ub record;
begin
  select * into p from test_places();
  ta := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0901', p_into => p.freezer);
  la := receive('vendorA:EGFR-100', ta, 200, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'A-1');
  tb := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0902', p_into => p.freezer);
  lb := receive('vendorB:EGFR-7', tb, 200, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'B-1');
  perform qc(la, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');
  perform qc(lb, 'pass', 'SDS-PAGE', '2026-09-02 09:00', 'p:marco');

  -- Both tubes go to the fridge for a day's work and back to the -80, twice.
  perform move(ta, p.fridge, null, '2026-09-03 09:00', 'p:marco');
  perform move(tb, p.fridge, null, '2026-09-03 09:00', 'p:marco');
  perform move(ta, p.freezer, null, '2026-09-03 17:00', 'p:marco');
  perform move(tb, p.freezer, null, '2026-09-03 17:00', 'p:marco');
  perform move(ta, p.fridge, null, '2026-09-05 09:00', 'p:marco');
  perform move(tb, p.fridge, null, '2026-09-05 09:00', 'p:marco');
  perform move(ta, p.freezer, null, '2026-09-05 17:00', 'p:marco');
  perform move(tb, p.freezer, null, '2026-09-05 17:00', 'p:marco');

  select * into ua from usable('2026-09-06 12:00', 'infinity') where container_id = ta;
  select * into ub from usable('2026-09-06 12:00', 'infinity') where container_id = tb;
  perform expect(ua.thaws, 2::bigint, 'vendor A tube thaws');
  perform expect(ub.thaws, 2::bigint, 'vendor B tube thaws');

  -- The limits come from different levels: the product rule for vendor B, the kind rule for vendor A.
  perform expect((select scope || ' ' || max_thaws from thaw_limits('2026-09-06 12:00', 'infinity') where lot_id = lb),
                 'product 1', 'limit for vendor B');
  perform expect((select scope || ' ' || max_thaws from thaw_limits('2026-09-06 12:00', 'infinity') where lot_id = la),
                 'kind 3', 'limit for vendor A');

  -- Only vendor B's tube warns, and neither tube is blocked.
  perform expect(ub.warnings, array['thawed 2 times, limit is 1'], 'warning on vendor B');
  perform expect(ua.warnings, '{}'::text[], 'no warning on vendor A');
  perform expect(ub.reasons, '{}'::text[], 'vendor B not blocked');
  perform expect(ua.reasons, '{}'::text[], 'vendor A not blocked');
  perform expect(ub.usable, 195::numeric, 'vendor B still usable');

  -- The flag list points at vendor B's tube only.
  perform expect((select array_agg(container_id) from flags('2026-09-06 12:00', 'infinity') where flag = 'over thaw limit'),
                 array[tb], 'over-thaw-limit flags');
end $$;
rollback;
