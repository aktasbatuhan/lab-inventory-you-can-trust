-- D5: the lab decides loading buffer only lasts 5 days, not 7. The new rule
-- applies to buffer that already exists from the day it starts, and questions
-- about earlier days are still answered with the old rule.
begin;
do $$
declare
  p record; water_bottle bigint; water bigint; bottle bigint; lb bigint; old_rule bigint; new_rule bigint; x record;
begin
  select * into p from test_places();
  select id into old_rule from shelf_life_rule where material_id = 'buffer:loading';

  water_bottle := register_container('bottle', '2026-09-01 09:00', 'p:lena', 'WAT-0003', p_into => p.bench);
  water := receive('vendorC:WATER', water_bottle, 500000, 'volume', '2026-09-01 09:00', 'p:lena');

  -- Loading buffer made on Tuesday 8 September.
  bottle := register_container('bottle', '2026-09-08 10:00', 'p:marco', 'LB-0908', p_into => p.fridge);
  lb := make('buffer:loading', jsonb_build_array(jsonb_build_object('container', water_bottle, 'lot', water, 'amount', 50000)),
             bottle, 50000, 'volume', '2026-09-08 10:00', 'p:marco');

  -- Under the 7-day rule it lasts until the 15th.
  select * into x from expiry('2026-09-09 12:00', 'infinity') where container_id = bottle;
  perform expect(x.expires_at, '2026-09-15 10:00'::timestamptz, 'expiry under the 7-day rule');

  -- On the 10th Sara writes down the new rule, starting that day.
  insert into shelf_life_rule (material_id, clock, duration, effective_from, recorded_at, recorded_by, note)
  values ('buffer:loading', 'since_origin', '5 days', '2026-09-10 00:00', '2026-09-10 08:00', 'p:sara',
          'Binding signal drops after day 5, so loading buffer now lasts 5 days.')
  returning id into new_rule;

  -- From the 10th on, the buffer already in the fridge follows the new rule: it expires on the 13th.
  select * into x from expiry('2026-09-11 12:00', 'infinity') where container_id = bottle;
  perform expect(x.expires_at, '2026-09-13 10:00'::timestamptz, 'expiry under the 5-day rule');
  perform expect(x.rule_id, new_rule, 'the new rule set it');
  perform expect((select reasons from usable('2026-09-13 12:00', 'infinity') where container_id = bottle),
                 array['expired'], 'expired on the 13th');

  -- Asked about the 9th, before the new rule started, the answer still uses the 7-day rule.
  select * into x from expiry('2026-09-09 12:00', 'infinity') where container_id = bottle;
  perform expect(x.expires_at, '2026-09-15 10:00'::timestamptz, 'the 9th, under the rule of the day');
  perform expect(x.rule_id, old_rule, 'the old rule on the 9th');

  -- And what did the system say on the 9th itself, before the new rule was written down?
  -- Also the 7-day rule. This needs the seeded rules to be on record before the 9th.
  select * into x from expiry('2026-09-13 12:00', '2026-09-09 12:00') where container_id = bottle;
  perform expect(x.expires_at, '2026-09-15 10:00'::timestamptz, 'the 13th, as we knew it on the 9th');
  perform expect(x.rule_id, old_rule, 'the old rule, as known on the 9th');
end $$;
rollback;
