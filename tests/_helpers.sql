-- Small helpers for scenario tests. Each test runs inside a transaction and rolls back.
--
-- Every check is also written to a temporary table, so a test run can leave a
-- trace for the review console (share/build_data.py). With the setting
-- inv.trace = 'on', a failed check is recorded and the test carries on, so the
-- trace shows everything that happened, not just the first failure.

create function log_check(what text, expected text, actual text, ok boolean) returns void language plpgsql as $$
begin
  create temp table if not exists test_checks (
    n serial, what text, expected text, actual text, ok boolean);
  insert into test_checks (what, expected, actual, ok) values (what, expected, actual, ok);
  if not ok and coalesce(current_setting('inv.trace', true), 'off') <> 'on' then
    raise exception 'expected % to be %, got %', what, expected, actual;
  end if;
end $$;

create function expect(actual anyelement, expected anyelement, what text) returns void language plpgsql as $$
begin
  perform log_check(what, expected::text, actual::text, actual is not distinct from expected);
end $$;

create function expect_true(ok boolean, what text) returns void language plpgsql as $$
begin
  perform log_check(what, 'true', coalesce(ok::text, 'null'), ok is true);
end $$;

-- Run a statement and expect it to fail with a message containing `fragment`.
create function expect_error(stmt text, fragment text, what text) returns void language plpgsql as $$
declare msg text;
begin
  begin
    execute stmt;
  exception when others then
    msg := sqlerrm;
  end;
  perform log_check(what, 'refused with "' || fragment || '"',
                    coalesce('refused with "' || msg || '"', 'accepted'),
                    msg is not null and position(fragment in msg) > 0);
end $$;

-- Places most tests need: a -80 freezer, a fridge, a bench.
create function test_places() returns table (freezer bigint, fridge bigint, bench bigint) language sql as $$
  select register_container('freezer', '2026-01-01', 'p:sara', p_name => 'Freezer F1', p_condition => 'minus80', p_source => 'manual'),
         register_container('fridge',  '2026-01-01', 'p:sara', p_name => 'Fridge R1',  p_condition => 'fridge',  p_source => 'manual'),
         register_container('bench',   '2026-01-01', 'p:sara', p_name => 'Bench B1',   p_condition => 'room',    p_source => 'manual')
$$;

-- The temporary table only exists while a test runs, so don't check for it now.
set check_function_bodies = off;

-- Everything a test recorded, as one JSON document: each event with its lines,
-- in the order it happened, plus every check.
create function trace_json() returns jsonb language sql as $$
  select jsonb_build_object(
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'kind', e.kind, 'occurred_at', e.occurred_at, 'recorded_at', e.recorded_at,
        'by', e.recorded_by, 'performed_by', e.performed_by, 'source', e.source,
        'run', e.run_id, 'step', e.run_step, 'ref', e.external_ref, 'voids', e.voids_event_id,
        'voided_by', (select v.id from event v where v.voids_event_id = e.id),
        'note', e.note,
        'lines', coalesce((
          select jsonb_agg(x) from (
            select jsonb_build_object('type', 'amount', 'container', container_label(q.container_id),
                     'lot', q.lot_id, 'material', l.material_id, 'dimension', q.dimension,
                     'amount', q.amount, 'reason', q.reason) as x
            from quantity_entry q join lot l on l.id = q.lot_id where q.event_id = e.id
            union all
            select jsonb_build_object('type', 'move', 'container', container_label(p.container_id),
                     'into', container_label(p.parent_id), 'slot', p.position)
            from placement p where p.event_id = e.id
            union all
            select jsonb_build_object('type', 'label', 'container', container_label(lb.container_id),
                     'barcode', lb.barcode, 'action', lb.action)
            from label lb where lb.event_id = e.id
            union all
            select jsonb_build_object('type', 'scan', 'container', container_label(s.container_id), 'code', s.scanned_code)
            from sighting s where s.event_id = e.id
            union all
            select jsonb_build_object('type', 'exit', 'container', container_label(x.container_id),
                     'kind', x.kind, 'destination', x.destination)
            from container_exit x where x.event_id = e.id
            union all
            select jsonb_build_object('type', 'qc', 'lot', r.lot_id, 'assay', r.assay, 'outcome', r.outcome)
            from qc_result r where r.event_id = e.id
            union all
            select jsonb_build_object('type', 'hold', 'lot', h.lot_id, 'container', container_label(h.container_id), 'reason', h.reason)
            from hold_placed h where h.event_id = e.id
            union all
            select jsonb_build_object('type', 'release', 'hold', r.hold_event_id)
            from hold_released r where r.event_id = e.id
            union all
            select jsonb_build_object('type', 'count', 'container', container_label(c.container_id),
                     'found', c.found, 'amount', c.observed_amount)
            from count_line c where c.event_id = e.id
            union all
            select jsonb_build_object('type', 'measure', 'container', container_label(m.container_id),
                     'lot', m.lot_id, 'property', m.property, 'value', m.value, 'unit', m.unit)
            from measurement m where m.event_id = e.id
            union all
            select jsonb_build_object('type', 'new lot', 'lot', l.id, 'material', l.material_id, 'origin', l.origin,
                     'supplier_lot', l.supplier_lot_code,
                     'parents', (select jsonb_agg(parent_lot_id) from lot_parent where lot_id = l.id))
            from lot l where l.created_event_id = e.id
          ) lines), '[]'::jsonb)
      ) order by e.occurred_at, e.id)
      from event e
      where e.occurred_at > '2026-01-02' or e.kind <> 'register'
    ), '[]'::jsonb),
    'checks', coalesce((
      select jsonb_agg(jsonb_build_object('what', what, 'expected', expected, 'actual', actual, 'ok', ok) order by n)
      from pg_temp.test_checks
    ), '[]'::jsonb)
  )
$$;
