-- Guards: the few things the database refuses outright.

-- Facts and rules are append-only. Mistakes are fixed with a correction event.
create function forbid_change() returns trigger language plpgsql as $$
begin
  raise exception '% is append-only: record a correction instead of changing or deleting a row', tg_table_name;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'event', 'container', 'run', 'planned_transfer', 'lot', 'lot_parent', 'quantity_entry',
    'placement', 'sighting', 'label', 'qc_result', 'hold_placed', 'hold_released',
    'container_exit', 'count_line', 'measurement', 'shelf_life_rule', 'thaw_limit_rule'
  ] loop
    execute format('create trigger %I before update or delete on %I for each row execute function forbid_change()', t || '_append_only', t);
    execute format('create trigger %I before truncate on %I execute function forbid_change()', t || '_no_truncate', t);
  end loop;
end $$;

-- A correction can only void something that was already on record.
create function check_void() returns trigger language plpgsql as $$
declare target_recorded timestamptz;
begin
  if new.voids_event_id is null then return new; end if;
  select recorded_at into target_recorded from event where id = new.voids_event_id;
  if target_recorded is null then
    raise exception 'event % does not exist', new.voids_event_id;
  end if;
  if new.recorded_at < target_recorded then
    raise exception 'a correction can''t be recorded before the event it corrects';
  end if;
  return new;
end $$;

create trigger event_void before insert on event for each row execute function check_void();
