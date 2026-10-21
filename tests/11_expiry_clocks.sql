-- LIFE-002, LIFE-031: expiry worked out from storage history. GFP stock lasts
-- 6 months from when it was made, but only a month once it's kept in the
-- fridge. Loading buffer lasts a week. Each date comes with the rule behind it.
begin;
do $$
declare
  p record; water_bottle bigint; water bigint; stock bigint; gfp bigint; kids bigint[];
  lb_bottle bigint; lb bigint; x record;
  rule_gfp_made bigint; rule_gfp_fridge bigint; rule_lb bigint;
begin
  select * into p from test_places();
  select id into rule_gfp_made from shelf_life_rule where material_id = 'buffer:gfp-stock' and clock = 'since_origin';
  select id into rule_gfp_fridge from shelf_life_rule where material_id = 'buffer:gfp-stock' and clock = 'in_condition';
  select id into rule_lb from shelf_life_rule where material_id = 'buffer:loading';

  water_bottle := register_container('bottle', '2026-08-01 09:00', 'p:lena', 'WAT-0002', p_into => p.bench);
  water := receive('vendorC:WATER', water_bottle, 500000, 'volume', '2026-08-01 09:00', 'p:lena');

  -- GFP stock made on 1 August and split into two tubes kept at -80.
  stock := register_container('tube_1_5ml', '2026-08-01 10:00', 'p:marco', 'GFP-STOCK', p_into => p.freezer);
  gfp := make('buffer:gfp-stock', jsonb_build_array(jsonb_build_object('container', water_bottle, 'lot', water, 'amount', 1000)),
              stock, 1000, 'volume', '2026-08-01 10:00', 'p:marco');
  kids := split(stock, gfp, 2, 400, 'tube_1_5ml', '2026-08-01 10:30', 'p:marco', 'GFP-', p_into => p.freezer);

  -- Two months later one tube goes to the fridge to be used over the coming weeks.
  perform move(kids[1], p.fridge, null, '2026-10-01 09:00', 'p:marco');

  -- The tube in the fridge: a month from the move beats six months from making.
  select * into x from expiry('2026-10-05 12:00', 'infinity') where container_id = kids[1];
  perform expect(x.expires_at, '2026-11-01 09:00'::timestamptz, 'GFP tube in the fridge');
  perform expect(x.clock, 'kept in fridge', 'clock for the fridge tube');
  perform expect(x.rule_id, rule_gfp_fridge, 'rule for the fridge tube');

  -- The tube still in the freezer keeps the six-month date.
  select * into x from expiry('2026-10-05 12:00', 'infinity') where container_id = kids[2];
  perform expect(x.expires_at, '2027-02-01 10:00'::timestamptz, 'GFP tube in the freezer');
  perform expect(x.clock, 'since made', 'clock for the freezer tube');
  perform expect(x.rule_id, rule_gfp_made, 'rule for the freezer tube');

  -- Every clock is listed with its rule, not just the winner.
  perform expect((select array_agg(clock || ' ' || expires_at::date || ' rule ' || rule_id order by expires_at)
                  from expiry_clocks('2026-10-05 12:00', 'infinity') where container_id = kids[1]),
                 array['kept in fridge 2026-11-01 rule ' || rule_gfp_fridge, 'since made 2027-02-01 rule ' || rule_gfp_made],
                 'clocks on the fridge tube');

  -- Loading buffer made on 1 October lasts a week.
  lb_bottle := register_container('bottle', '2026-10-01 10:00', 'p:marco', 'LB-1001', p_into => p.fridge);
  lb := make('buffer:loading', jsonb_build_array(jsonb_build_object('container', water_bottle, 'lot', water, 'amount', 50000)),
             lb_bottle, 50000, 'volume', '2026-10-01 10:00', 'p:marco');
  select * into x from expiry('2026-10-05 12:00', 'infinity') where container_id = lb_bottle;
  perform expect(x.expires_at, '2026-10-08 10:00'::timestamptz, 'loading buffer expiry');
  perform expect(x.rule_id, rule_lb, 'loading buffer rule');

  -- On 5 October the buffer is fine but due soon; the GFP tube is not due yet.
  perform expect((select warnings from usable('2026-10-05 12:00', 'infinity') where container_id = lb_bottle),
                 array['expires within 14 days'], 'warning on the loading buffer');
  perform expect((select warnings from usable('2026-10-05 12:00', 'infinity') where container_id = kids[1]),
                 '{}'::text[], 'no warning on the GFP tube yet');

  -- "What expires in the next 14 days?" asked on 5 October and on 20 October.
  perform expect((select array_agg(container_id order by expires_at) from expiry('2026-10-05 12:00', 'infinity')
                  where expires_at > '2026-10-05 12:00' and expires_at <= '2026-10-19 12:00'),
                 array[lb_bottle], 'due within 14 days of 5 October');
  perform expect((select array_agg(container_id order by expires_at) from expiry('2026-10-20 12:00', 'infinity')
                  where expires_at > '2026-10-20 12:00' and expires_at <= '2026-11-03 12:00'),
                 array[kids[1]], 'due within 14 days of 20 October');

  -- By 9 October the loading buffer is expired, and by 20 October the GFP tube carries the warning.
  perform expect((select reasons from usable('2026-10-09 12:00', 'infinity') where container_id = lb_bottle),
                 array['expired'], 'loading buffer a week and a day later');
  perform expect((select warnings from usable('2026-10-20 12:00', 'infinity') where container_id = kids[1]),
                 array['expires within 14 days'], 'warning on the GFP tube');

  -- Decision D9: the fridge month is a budget of total fridge time. After 9 days
  -- in the fridge the tube goes back to the -80. The fridge clock pauses, so the
  -- six-month date is the one that counts again...
  perform move(kids[1], p.freezer, null, '2026-10-10 09:00', 'p:marco');
  perform expect((select expires_at from expiry('2026-10-15 12:00', 'infinity') where container_id = kids[1]),
                 '2027-02-01 10:00'::timestamptz, 'fridge tube back in the freezer');

  -- ...but the 9 days are gone for good. Back in the fridge on 20 October, it has
  -- one month minus 9 days left.
  perform move(kids[1], p.fridge, null, '2026-10-20 09:00', 'p:marco');
  select * into x from expiry('2026-10-21 12:00', 'infinity') where container_id = kids[1];
  perform expect(x.expires_at, '2026-11-11 09:00'::timestamptz, 'fridge tube back in the fridge');
  perform expect(x.clock, 'kept in fridge', 'clock after returning to the fridge');
end $$;
rollback;

-- D9 the other way round: a target has 8 hours on the bench in total. A short
-- thaw to take an aliquot uses a little of it and doesn't doom the tube.
begin;
do $$
declare p record; tube bigint; t1 bigint;
begin
  select * into p from test_places();
  tube := register_container('tube_1_5ml', '2026-09-01 10:00', 'p:lena', 'TGT-0100', p_into => p.freezer);
  t1 := receive('vendorA:EGFR-100', tube, 200, 'volume', '2026-09-01 10:00', 'p:lena', p_supplier_lot => 'L1');
  perform qc(t1, 'pass', 'SDS-PAGE', '2026-09-01 12:00', 'p:marco');

  -- Out for 30 minutes on 3 September, then back in the -80.
  perform move(tube, p.bench, null, '2026-09-03 09:00', 'p:marco');
  perform move(tube, p.freezer, null, '2026-09-03 09:30', 'p:marco');
  perform expect((select reasons from usable('2026-09-04 12:00', 'infinity') where container_id = tube),
                 '{}'::text[], 'usable the day after a short thaw');

  -- Out again on 10 September and forgotten on the bench: 7.5 hours of budget
  -- left, so it expires at 17:30.
  perform move(tube, p.bench, null, '2026-09-10 10:00', 'p:marco');
  perform expect((select expires_at from expiry('2026-09-10 12:00', 'infinity') where container_id = tube),
                 '2026-09-10 17:30'::timestamptz, 'expiry while on the bench');

  -- Found and put back the next morning. Being cold again doesn't undo it.
  perform move(tube, p.freezer, null, '2026-09-11 08:00', 'p:lena');
  perform expect((select reasons from usable('2026-09-12 12:00', 'infinity') where container_id = tube),
                 array['expired'], 'still expired back in the freezer');
end $$;
rollback;
