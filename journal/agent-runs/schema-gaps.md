# Schema gaps found by the scenario tests

Written while adding tests 04 to 20. Schema and seed were left untouched; each
failing test describes the behaviour we want and fails until the fix lands.

## 1. Seeded rules are "written down" when the seed is loaded, not when they started

Status: fixed in `seed/01_reference_data.sql` by someone else while these tests
were being written (seeded rules now carry `recorded_at` = their start date).
Both tests below pass on a fresh build. Kept here as the record of why.

Tests: `12_rule_change.sql` (last check), `16_rerun_planning.sql` (last check).

What fails: any question asked "as we knew it on day k" with k before the moment
`run.sh` loaded the seed sees no shelf-life rules at all. So on 9 September the
loading buffer has no expiry, and the re-run planner on 10 September sees an
expression well that will have expired as still usable.

Why: `shelf_life_rule.recorded_at` and `thaw_limit_rule.recorded_at` default to
`now()`, and `rules_for_lots` and `thaw_limits` filter on `recorded_at <= k`.
That filter is right. The seed is what's off: it means "these rules have always
been in force", but it records them as written down today.

Smallest fix, in `seed/01_reference_data.sql`: give the seeded rules a
`recorded_at` equal to their start date.

```sql
insert into shelf_life_rule (material_kind_id, material_id, product_id, clock, conditions, duration,
                             effective_from, recorded_at, recorded_by, note) values
  ('target', null, null, 'since_origin', null, '3 years', '2020-01-01', '2020-01-01', 'p:sara', '...'),
  ...;
-- and the same for thaw_limit_rule: add recorded_at = '2020-01-01' to every row.
```

The other tests read with k = 'infinity' ("what we know now") on purpose so this
one gap doesn't hide everything else.

## 2. Moving back into the freezer gives the fridge time back

Test: `11_expiry_clocks.sql` (last check).

What fails: a GFP stock tube that spent 1 to 10 October in the fridge expires on
1 November. Once it goes back into the -80 on 10 October, its expiry jumps back
to 1 February. LIFE-002 says the opposite: time already spent in the fridge
doesn't come back.

Why: `expiry_clocks` only looks at the storage stretch the container is in at t
(`here as (... where from_at <= t and t < to_at)`). As soon as the tube leaves
the fridge, the fridge clock disappears.

Smallest fix, in `expiry_clocks` (`schema/05_derived.sql`): start each
in-condition clock from the first time the container entered that condition
after the lot arrived, whether or not it's still there.

```sql
here as (
  select distinct on (container_id, condition) container_id, condition, from_at
  from condition_stretches(k)
  where from_at <= t
  order by container_id, condition, from_at
),
```

Trade-off to decide on: with this change the target "8 hours at room
temperature" clock also keeps running after a short thaw on the bench, so a tube
that sat out for 20 minutes would expire 8 hours later even back in the -80. If
that's too strict, count the time actually spent in the condition and expire
once the total reaches the rule's duration. That's a bigger query but closer to
how people think about it.

## 3. No record functions for dissolving powder or for measurements (not failing)

Test: `07_expression.sql`.

Dissolving dry DNA (2 µg turns into 20 µL of the same lot) and recording its
concentration both work with the existing tables, but there is no function in
`schema/06_record.sql` for either, so the test writes the `quantity_entry` and
`measurement` rows itself. Suggested additions: `reconstitute(container, lot,
mass, volume, solvent_container, solvent_lot, at, by)` writing the three
ledger lines in one event, and `measure(container, lot, property, value, unit,
at, by)`.
