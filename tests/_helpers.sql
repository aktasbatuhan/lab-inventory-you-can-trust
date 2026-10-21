-- Small helpers for scenario tests. Each test runs inside a transaction and rolls back.

create function expect(actual anyelement, expected anyelement, what text) returns void language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'expected % to be %, got %', what, expected, actual;
  end if;
end $$;

create function expect_true(ok boolean, what text) returns void language plpgsql as $$
begin
  if ok is not true then raise exception 'expected: %', what; end if;
end $$;

-- Run a statement and expect it to fail with a message containing `fragment`.
create function expect_error(stmt text, fragment text, what text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    if position(fragment in sqlerrm) > 0 then return; end if;
    raise exception 'expected % to fail with "%", got "%"', what, fragment, sqlerrm;
  end;
  raise exception 'expected % to fail, but it succeeded', what;
end $$;

-- Places most tests need: a -80 freezer, a fridge, a bench.
create function test_places() returns table (freezer bigint, fridge bigint, bench bigint) language sql as $$
  select register_container('freezer', '2026-01-01', 'p:sara', p_name => 'Freezer F1', p_condition => 'minus80', p_source => 'manual'),
         register_container('fridge',  '2026-01-01', 'p:sara', p_name => 'Fridge R1',  p_condition => 'fridge',  p_source => 'manual'),
         register_container('bench',   '2026-01-01', 'p:sara', p_name => 'Bench B1',   p_condition => 'room',    p_source => 'manual')
$$;
