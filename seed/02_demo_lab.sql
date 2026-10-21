-- A small demo lab, September to October 2026.
--
-- This walks one Binding experiment through the workflow in
-- case/binding-workflow.png, the way it would be recorded on the day: a target
-- arrives and is checked and split, a customer's 24 designs arrive as DNA, get
-- expressed into protein, and are measured on the BLI against the target.
-- Around it are the ordinary mistakes a real lab makes, each one marked
-- "Mess:" below so you can find it again in the query answers.
--
-- Everything goes through the record functions in schema/06_record.sql, the
-- same way a person, a robot log or an import would write. The only plain
-- inserts are reference rows (the customer's designs, a few extra products)
-- and the robot's worklist, which is a plan and not a fact.
--
-- "Today" in the demo is 21 October 2026, late afternoon.
-- Load it with ./run.sh demo.

set timezone = 'Europe/Zurich';

-- Reference rows the demo needs on top of seed/01_reference_data.sql.
-- The customer campaign: 24 designed binders against EGFR. Each design is two
-- materials, its DNA and its protein, tied together by design_id.
insert into material (id, kind_id, name, attributes)
select 'dna:D-' || lpad(i::text, 3, '0'), 'dna', 'DNA for design D-' || lpad(i::text, 3, '0'),
       jsonb_build_object('design_id', 'D-' || lpad(i::text, 3, '0'), 'campaign', 'ACME EGFR binders', 'customer', 'ACME Bio')
from generate_series(1, 24) i
union all
select 'protein:D-' || lpad(i::text, 3, '0'), 'sample_protein', 'Protein of design D-' || lpad(i::text, 3, '0'),
       jsonb_build_object('design_id', 'D-' || lpad(i::text, 3, '0'), 'campaign', 'ACME EGFR binders', 'customer', 'ACME Bio')
from generate_series(1, 24) i;

-- Twist sells each custom gene once, so each design's DNA is its own product
-- line on the order.
insert into product (id, material_id, supplier, catalog_number)
select 'twist:SO-77812/D-' || lpad(i::text, 3, '0'), 'dna:D-' || lpad(i::text, 3, '0'), 'Twist', 'SO-77812/D-' || lpad(i::text, 3, '0')
from generate_series(1, 24) i;

insert into material (id, kind_id, name, attributes) values
  ('reagent:bsa',     'reagent', 'BSA 10%',                   '{}'),
  ('reagent:gfp1-10', 'reagent', 'GFP1-10 detector concentrate', '{}');
insert into product (id, material_id, supplier, catalog_number) values
  ('vendorC:BSA',    'reagent:bsa',     'Vendor C', 'BSA-10'),
  ('vendorD:GFP110', 'reagent:gfp1-10', 'Vendor D', 'GFP110-1');
insert into actor values ('instrument:reader-1', 'instrument', 'Plate reader 1');
insert into container_type (id, category, description, capacity_ul, dead_volume_ul) values
  ('sensor_tray', 'plate', 'Tray of BLI biosensors', null, 0);

do $$
declare
  -- places
  f1 bigint; f2 bigint; f3 bigint; r1 bigint; shelf bigint; bench bigint;
  rack_a bigint; hamilton bigint; incubator bigint; reader bigint; gator bigint;
  -- reagents and their lots
  water bigint; hepes bigint; nacl bigint; bsa bigint; pure bigint; gfp110 bigint; sensors bigint;
  water_l bigint; hepes_l bigint; nacl_l bigint; bsa_l bigint; pure_l bigint; gfp110_l bigint; sensors_l bigint;
  -- buffers
  rb1 bigint; lb1 bigint; gfpstock bigint; rb2 bigint; lb2 bigint;
  rb1_l bigint; lb1_l bigint; gfp_l bigint; rb2_l bigint; lb2_l bigint;
  -- targets
  egfr bigint; egfr_l bigint; box1 bigint; egfr_kids bigint[];
  pdl1_bad bigint; pdl1_bad_l bigint; pdl1 bigint; pdl1_l bigint; dup_l bigint; box2 bigint; pdl1_kids bigint[];
  dup_ev bigint; typo_ev bigint; fix bigint; cnt bigint;
  -- the campaign
  twist bigint; expr bigint; gfpplate bigint; bli_s bigint; bli_t bigint; bli_t_old bigint;
  twist_l bigint[] := '{}'; dna_l bigint[] := '{}'; prot_l bigint[] := '{}';
  pos text; run_prep bigint; run_expr bigint; run_gfp bigint; run_bli bigint; run_old bigint;
  i int; s int;
  t timestamptz;
begin
  ---------------------------------------------------------------------------
  -- 1 September: the lab as it stands. Three freezers, a fridge, a reagent
  -- shelf, a bench and the instruments. Places that set a temperature say so.
  ---------------------------------------------------------------------------
  t := '2026-09-01 08:00';
  f1 := register_container('freezer', t, 'p:sara', 'LOC-F1', 'Freezer F1 (-80)', 'minus80', p_source => 'manual');
  f2 := register_container('freezer', t, 'p:sara', 'LOC-F2', 'Freezer F2 (-20)', 'minus20', p_source => 'manual');
  f3 := register_container('freezer', t, 'p:sara', 'LOC-F3', 'Freezer F3 (-80)', 'minus80', p_source => 'manual');
  r1 := register_container('fridge',  t, 'p:sara', 'LOC-R1', 'Fridge R1', 'fridge', p_source => 'manual');
  shelf := register_container('bench', t, 'p:sara', 'LOC-S1', 'Reagent shelf S1', 'room', p_source => 'manual');
  bench := register_container('bench', t, 'p:sara', 'LOC-B1', 'Bench B1', 'room', p_source => 'manual');
  -- Instruments count as room temperature. The incubator really runs at 37 °C,
  -- which isn't one of the storage conditions the schema knows; nothing is
  -- stored there for long, so we let it pass as room.
  hamilton  := register_container('instrument', t, 'p:sara', 'INS-HAM1', 'Hamilton STAR 1', 'room', p_source => 'manual');
  incubator := register_container('instrument', t, 'p:sara', 'INS-INC1', 'Incubator 37C', 'room', p_source => 'manual');
  reader    := register_container('instrument', t, 'p:sara', 'INS-PR1', 'Plate reader 1', 'room', p_source => 'manual');
  gator     := register_container('instrument', t, 'p:sara', 'INS-GAT1', 'Gator BLI 1', 'room', p_source => 'manual');
  rack_a := register_container('rack', t, 'p:sara', 'RACK-A', 'Rack A', p_into => f1, p_position => 'shelf 1');

  ---------------------------------------------------------------------------
  -- 1 to 30 September: everyday reagents arrive and go on the shelf or into a
  -- freezer. None of these kinds needs QC.
  ---------------------------------------------------------------------------
  water := register_container('bottle', '2026-09-01 10:00', 'p:lena', 'H2O-0901', 'Water H2O-0901', p_into => shelf);
  water_l := receive('vendorC:WATER', water, 500000, 'volume', '2026-09-01 10:00', 'p:lena', 'W-2291', 'delivery:DN-5101/1', p_price => 40);
  hepes := register_container('bottle', '2026-09-01 10:05', 'p:lena', 'HEPES-0901', 'HEPES 1 M', p_into => shelf);
  hepes_l := receive('vendorC:HEPES', hepes, 100000, 'volume', '2026-09-01 10:05', 'p:lena', 'H-0731', 'delivery:DN-5101/2', p_price => 120);
  nacl := register_container('bottle', '2026-09-01 10:10', 'p:lena', 'NACL-0901', 'NaCl 5 M', p_into => shelf);
  nacl_l := receive('vendorC:NACL', nacl, 100000, 'volume', '2026-09-01 10:10', 'p:lena', 'N-1180', 'delivery:DN-5101/3', p_price => 60);
  bsa := register_container('bottle', '2026-09-01 10:15', 'p:lena', 'BSA-0901', 'BSA 10%', p_into => r1);
  bsa_l := receive('vendorC:BSA', bsa, 50000, 'volume', '2026-09-01 10:15', 'p:lena', 'B-5520', 'delivery:DN-5101/4', p_price => 180);
  sensors := register_container('sensor_tray', '2026-09-15 11:00', 'p:lena', 'SENS-0915', 'BLI sensor tray', p_into => shelf);
  sensors_l := receive('vendorE:SENSORS', sensors, 96, 'count', '2026-09-15 11:00', 'p:lena', 'SX-7731', 'delivery:DN-5544', p_price => 960);
  gfp110 := register_container('tube_1_5ml', '2026-09-20 10:00', 'p:lena', 'GFP110-0920', 'GFP1-10 concentrate', p_into => f2);
  gfp110_l := receive('vendorD:GFP110', gfp110, 1000, 'volume', '2026-09-20 10:00', 'p:lena', 'G-0099', 'delivery:DN-5602', p_price => 450);
  pure := register_container('tube_1_5ml', '2026-09-30 10:00', 'p:lena', 'PURE-0930', 'PURE expression mix', p_into => f1);
  pure_l := receive('vendorD:PURE', pure, 500, 'volume', '2026-09-30 10:00', 'p:lena', 'PX-4410', 'delivery:DN-5719', p_price => 1200);

  ---------------------------------------------------------------------------
  -- 2 to 4 September: the EGFR target. One delivery of supplier lot L4471
  -- arrives as 500 µL, waits for QC, passes, and is split into 16 single-use
  -- aliquots of 25 µL in a freezer box. 100 µL stays in the stock tube.
  ---------------------------------------------------------------------------
  egfr := register_container('tube_1_5ml', '2026-09-02 10:00', 'p:lena', 'TGT-0101', 'EGFR stock L4471', p_into => f1);
  egfr_l := receive('vendorA:EGFR-100', egfr, 500, 'volume', '2026-09-02 10:00', 'p:lena', 'L4471', 'delivery:DN-5212',
                    '2028-09-01', '{"concentration_mg_ml": 1.0, "purity_pct": 95}', 300);
  perform qc(egfr_l, 'pass', 'SDS-PAGE and A280', '2026-09-03 11:00', 'p:marco', '{"concentration_mg_ml": 0.98, "purity_pct": 96}');

  -- The stock is thawed on the bench, split, and goes back in the freezer.
  perform move(egfr, bench, null, '2026-09-04 09:00', 'p:lena');
  box1 := register_container('box_9x9', '2026-09-04 09:20', 'p:lena', 'BOX-0011', 'Box EGFR L4471', p_into => rack_a, p_position => 'slot 1');
  egfr_kids := split(egfr, egfr_l, 16, 25, 'tube_matrix', '2026-09-04 09:30', 'p:lena', 'EGFR-L4471-', p_into => box1);
  perform move(egfr, f1, null, '2026-09-04 09:45', 'p:lena');

  ---------------------------------------------------------------------------
  -- 8 to 9 September: PD-L1, first delivery, lot P-2209.
  -- Mess: it fails QC. The tube stays in the freezer (the supplier wants it
  -- back for their own check), so we hold 400 µL we can't use.
  ---------------------------------------------------------------------------
  pdl1_bad := register_container('tube_1_5ml', '2026-09-08 10:00', 'p:lena', 'TGT-0102', 'PD-L1 stock P-2209', p_into => f1);
  pdl1_bad_l := receive('vendorA:PDL1-200', pdl1_bad, 400, 'volume', '2026-09-08 10:00', 'p:lena', 'P-2209', 'delivery:DN-5301',
                        '2028-06-30', '{"concentration_mg_ml": 0.8}', 420);
  perform qc(pdl1_bad_l, 'fail', 'SDS-PAGE and A280', '2026-09-09 14:00', 'p:marco',
             '{"concentration_mg_ml": 0.21, "note": "band at half the expected size, likely clipped"}');

  ---------------------------------------------------------------------------
  -- 11 September. Mess: an EGFR aliquot (slot 16) is knocked off the bench
  -- while thawing and goes in the bin with all 25 µL still inside.
  ---------------------------------------------------------------------------
  perform move(egfr_kids[16], bench, null, '2026-09-11 08:50', 'p:marco');
  perform discard(egfr_kids[16], '2026-09-11 09:05', 'p:marco', p_note => 'dropped while thawing, tube cracked');

  ---------------------------------------------------------------------------
  -- 15 to 18 September: PD-L1 again, a new lot P-2231. This one passes and is
  -- split into 8 aliquots.
  -- Mess: the same delivery comes in twice. Lena scans the delivery note in
  -- the morning, and the supplier-portal sync imports the same shipment that
  -- night into the same tube. For three days the records say 800 µL. The
  -- duplicate flag catches it and Sara voids the import on the 18th.
  ---------------------------------------------------------------------------
  pdl1 := register_container('tube_1_5ml', '2026-09-15 10:00', 'p:lena', 'TGT-0103', 'PD-L1 stock P-2231', p_into => f1);
  pdl1_l := receive('vendorA:PDL1-200', pdl1, 400, 'volume', '2026-09-15 10:00', 'p:lena', 'P-2231', 'delivery:DN-5530',
                    '2028-08-31', '{"concentration_mg_ml": 0.8}', 420);
  dup_l := receive('vendorA:PDL1-200', pdl1, 400, 'volume', '2026-09-15 10:00', 'system:import', 'P-2231', 'acro-portal:SHP-88123',
                   '2028-08-31', null, 420, p_source => 'import', p_recorded => '2026-09-15 23:30');
  perform qc(pdl1_l, 'pass', 'SDS-PAGE and A280', '2026-09-16 11:00', 'p:marco', '{"concentration_mg_ml": 0.79}');
  perform move(pdl1, bench, null, '2026-09-17 09:00', 'p:lena');
  box2 := register_container('box_9x9', '2026-09-17 09:10', 'p:lena', 'BOX-0012', 'Box PD-L1 P-2231', p_into => rack_a, p_position => 'slot 2');
  pdl1_kids := split(pdl1, pdl1_l, 8, 25, 'tube_matrix', '2026-09-17 09:20', 'p:lena', 'PDL1-P2231-', p_into => box2);
  perform move(pdl1, f1, null, '2026-09-17 09:40', 'p:lena');
  select e.id into dup_ev from event e where e.external_ref = 'acro-portal:SHP-88123';
  perform void(dup_ev, 'p:sara', 'Same delivery as DN-5530, imported a second time from the supplier portal', '2026-09-18 08:40');

  ---------------------------------------------------------------------------
  -- 22 to 24 September: weekly buffer day. Running buffer from its
  -- components, loading buffer from running buffer and BSA, and GFP1-10 stock
  -- for split-GFP, which goes into the -20.
  -- Mess (later): the loading buffer made today expires on the 29th, but the
  -- bottle is never thrown out. It's still in the fridge at the end.
  ---------------------------------------------------------------------------
  rb1 := register_container('bottle', '2026-09-22 09:00', 'p:lena', 'RB-0922', 'Running buffer RB-0922', p_into => r1);
  rb1_l := make('buffer:bli-running', jsonb_build_array(
                  jsonb_build_object('container', water, 'lot', water_l, 'amount', 240000),
                  jsonb_build_object('container', hepes, 'lot', hepes_l, 'amount', 2500),
                  jsonb_build_object('container', nacl,  'lot', nacl_l,  'amount', 7500)),
                rb1, 250000, 'volume', '2026-09-22 09:00', 'p:lena');
  lb1 := register_container('bottle', '2026-09-22 09:30', 'p:lena', 'LB-0922', 'Loading buffer LB-0922', p_into => r1);
  lb1_l := make('buffer:loading', jsonb_build_array(
                  jsonb_build_object('container', rb1, 'lot', rb1_l, 'amount', 49500),
                  jsonb_build_object('container', bsa, 'lot', bsa_l, 'amount', 500)),
                lb1, 50000, 'volume', '2026-09-22 09:30', 'p:lena');
  perform move(gfp110, bench, null, '2026-09-24 09:00', 'p:lena');
  gfpstock := register_container('bottle', '2026-09-24 09:30', 'p:lena', 'GFP-0924', 'GFP1-10 stock GFP-0924', p_into => f2);
  gfp_l := make('buffer:gfp-stock', jsonb_build_array(
                  jsonb_build_object('container', gfp110, 'lot', gfp110_l, 'amount', 1000),
                  jsonb_build_object('container', rb1, 'lot', rb1_l, 'amount', 9000)),
                gfpstock, 10000, 'volume', '2026-09-24 09:30', 'p:lena');
  perform discard(gfp110, '2026-09-24 09:40', 'p:lena', p_note => 'empty');

  ---------------------------------------------------------------------------
  -- 23 September: an earlier experiment, EXP-0431, for another customer. It
  -- uses two EGFR aliquots (slots 14 and 15) for a BLI target plate. The
  -- samples of that experiment are left out to keep the demo small.
  -- Mess: the same morning Marco takes 20 µL from the EGFR stock tube for a
  -- SEC re-check and types 200. The tube goes 100 µL negative and is flagged.
  -- He finds it in his notebook two days later and corrects it.
  ---------------------------------------------------------------------------
  perform move(egfr, bench, null, '2026-09-23 09:00', 'p:marco');
  typo_ev := consume(egfr, egfr_l, 200, 'volume', '2026-09-23 09:10', 'p:marco', p_note => 'SEC re-check');
  perform move(egfr, f1, null, '2026-09-23 09:30', 'p:marco');

  run_old := start_run('BLI binding screen', '2026-09-23 10:00', 'p:marco', gator, 'EXP-0431');
  bli_t_old := register_container('plate_bli', '2026-09-23 10:00', 'p:marco', 'BLI-T-0431', 'BLI target plate EXP-0431', p_into => bench);
  perform move(egfr_kids[14], bench, null, '2026-09-23 10:00', 'p:marco');
  perform move(egfr_kids[15], bench, null, '2026-09-23 10:00', 'p:marco');
  s := 0;
  for i in 1 .. 6 loop
    pos := chr(64 + i) || '1';
    s := s + 1;
    perform transfer(egfr_kids[case when i <= 3 then 14 else 15 end], well(bli_t_old, pos), egfr_l, 5, 'volume',
                     '2026-09-23 10:20', 'p:marco', p_run => run_old, p_step => s);
    s := s + 1;
    perform transfer(rb1, well(bli_t_old, pos), rb1_l, 195, 'volume', '2026-09-23 10:25', 'p:marco', p_run => run_old, p_step => s);
  end loop;
  -- Used aliquots go in the bin with the 10 µL a pipette can't reach.
  perform discard(egfr_kids[14], '2026-09-23 10:30', 'p:marco');
  perform discard(egfr_kids[15], '2026-09-23 10:30', 'p:marco');
  perform move(bli_t_old, gator, 'plate 1', '2026-09-23 10:40', 'p:marco');
  perform finish_run(run_old, '2026-09-23 16:00', 'p:marco');

  -- 25 September: Marco's correction. The wrong entry stays, marked as voided.
  fix := void(typo_ev, 'p:marco', 'Typed 200, took 20 (notebook p. 41)', '2026-09-25 14:00');
  perform consume(egfr, egfr_l, 20, 'volume', '2026-09-23 09:10', 'p:marco', p_note => 'SEC re-check', p_event => fix,
                  p_recorded => '2026-09-25 14:00');

  ---------------------------------------------------------------------------
  -- 25 September. Mess: Lena makes room in F1 and carries the PD-L1 box to
  -- F3. She types the move in later instead of scanning, so the system knows
  -- where the box should be but nobody has confirmed it since the 17th.
  ---------------------------------------------------------------------------
  perform move(box2, f3, 'shelf 2', '2026-09-25 16:00', 'p:lena', p_source => 'manual', p_recorded => '2026-09-25 17:30');

  ---------------------------------------------------------------------------
  -- 1 to 2 October: DNA arrival and reconstitution. Twist ships the 24
  -- designs as dry DNA, 1 µg per well, in wells A1 to B12 of one plate. Next
  -- day each well gets 20 µL of water. Reconstituting makes a new lot of the
  -- same DNA, now measured in µL instead of µg, in the same well.
  ---------------------------------------------------------------------------
  twist := register_container('plate_96', '2026-10-01 11:00', 'p:lena', 'TW-77812', 'Twist plate SO-77812', p_into => shelf);
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    twist_l := twist_l || receive('twist:SO-77812/D-' || lpad(i::text, 3, '0'), well(twist, pos), 1, 'mass',
                                  '2026-10-01 11:00', 'p:lena', 'SO-77812', 'twist:SO-77812:' || pos, p_price => 85);
  end loop;
  perform move(twist, bench, null, '2026-10-02 09:00', 'p:marco');
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    dna_l := dna_l || make('dna:D-' || lpad(i::text, 3, '0'), jsonb_build_array(
                             jsonb_build_object('container', well(twist, pos), 'lot', twist_l[i], 'amount', 1, 'dimension', 'mass'),
                             jsonb_build_object('container', water, 'lot', water_l, 'amount', 20)),
                           well(twist, pos), 20, 'volume', '2026-10-02 09:30', 'p:marco');
  end loop;
  perform move(twist, f2, 'shelf 1', '2026-10-02 10:00', 'p:marco');

  ---------------------------------------------------------------------------
  -- 9 October: expression plate prep on the Hamilton, from a worklist.
  -- Steps 1-24 put 5 µL of each design's DNA into the expression plate,
  -- steps 25-48 add 15 µL of PURE mix to each well.
  -- Mess: the robot log comes back without step 17 (D-017's DNA into B5). The
  -- robot did pipette it, the log line was lost. So the DNA plate still shows
  -- 20 µL in B5 and the expression well never "received" DNA, which turns
  -- negative when expression uses it. Both show up as flags.
  ---------------------------------------------------------------------------
  expr := register_container('plate_384', '2026-10-09 08:30', 'p:marco', 'EXPR-0457', 'Expression plate EXP-0457', p_into => bench);
  perform move(twist, hamilton, 'deck 1', '2026-10-09 08:40', 'p:marco');
  perform move(pure, hamilton, 'deck 3', '2026-10-09 08:40', 'p:marco');
  perform move(expr, hamilton, 'deck 2', '2026-10-09 08:41', 'p:marco');
  run_prep := start_run('expression plate prep', '2026-10-09 09:00', 'p:marco', hamilton, 'EXP-0457');
  insert into planned_transfer (run_id, step, from_container_id, to_container_id, lot_id, dimension, amount)
  select run_prep, g.n, well(twist, chr(65 + (g.n - 1) / 12) || ((g.n - 1) % 12 + 1)),
         well(expr, chr(65 + (g.n - 1) / 12) || ((g.n - 1) % 12 + 1)), dna_l[g.n], 'volume', 5
  from generate_series(1, 24) g(n)
  union all
  select run_prep, 24 + g.n, pure, well(expr, chr(65 + (g.n - 1) / 12) || ((g.n - 1) % 12 + 1)), pure_l, 'volume', 15
  from generate_series(1, 24) g(n);
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    if i <> 17 then
      perform transfer(well(twist, pos), well(expr, pos), dna_l[i], 5, 'volume', '2026-10-09 09:05'::timestamptz + i * interval '20 seconds',
                       'robot:hamilton-1', 'robot_log', run_prep, i, p_recorded => '2026-10-09 09:40');
    end if;
    perform transfer(pure, well(expr, pos), pure_l, 15, 'volume', '2026-10-09 09:20'::timestamptz + i * interval '20 seconds',
                     'robot:hamilton-1', 'robot_log', run_prep, 24 + i, p_recorded => '2026-10-09 09:40');
  end loop;
  perform finish_run(run_prep, '2026-10-09 09:35', 'robot:hamilton-1', '2026-10-09 09:40');
  perform move(twist, f2, 'shelf 1', '2026-10-09 09:45', 'p:marco');
  perform move(pure, f1, null, '2026-10-09 09:45', 'p:marco');

  ---------------------------------------------------------------------------
  -- 9 to 10 October: the expression run. Eight hours at 37 °C turn each
  -- well's DNA and mix into 20 µL of that design's protein, a new lot per well
  -- (the expression plate is good for 14 days from here). Then the plate goes
  -- into the fridge.
  ---------------------------------------------------------------------------
  perform move(expr, incubator, null, '2026-10-09 10:00', 'p:marco');
  run_expr := start_run('cell-free expression', '2026-10-09 10:00', 'p:marco', incubator, 'EXP-0457');
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    prot_l := prot_l || make('protein:D-' || lpad(i::text, 3, '0'), jsonb_build_array(
                               jsonb_build_object('container', well(expr, pos), 'lot', dna_l[i], 'amount', 5),
                               jsonb_build_object('container', well(expr, pos), 'lot', pure_l, 'amount', 15)),
                             well(expr, pos), 20, 'volume', '2026-10-09 18:00', 'p:marco',
                             p_run => run_expr, p_step => i, p_recorded => '2026-10-10 08:30');
  end loop;
  perform finish_run(run_expr, '2026-10-09 18:00', 'p:marco', '2026-10-10 08:30');
  perform move(expr, r1, null, '2026-10-10 08:35', 'p:marco');

  ---------------------------------------------------------------------------
  -- 13 October: split-GFP. The GFP1-10 stock comes out of the -20 into the
  -- fridge for good (its clock switches from 6 months frozen to 1 month in
  -- the fridge). 2 µL of each protein plus 18 µL of stock go into a split-GFP
  -- plate, which is read on the plate reader. The plate is single use, so
  -- when the run finishes the system records it as thrown away by rule.
  ---------------------------------------------------------------------------
  perform move(gfpstock, r1, null, '2026-10-13 08:30', 'p:marco');
  perform move(expr, bench, null, '2026-10-13 08:45', 'p:marco');
  gfpplate := register_container('plate_gfp', '2026-10-13 09:00', 'p:marco', 'GFP-0457', 'Split-GFP plate EXP-0457', p_into => bench);
  run_gfp := start_run('split-GFP', '2026-10-13 09:00', 'p:marco', reader, 'EXP-0457');
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    perform transfer(well(expr, pos), well(gfpplate, pos), prot_l[i], 2, 'volume', '2026-10-13 09:15', 'p:marco',
                     p_run => run_gfp, p_step => i);
    perform transfer(gfpstock, well(gfpplate, pos), gfp_l, 18, 'volume', '2026-10-13 09:25', 'p:marco',
                     p_run => run_gfp, p_step => 24 + i);
  end loop;
  perform move(expr, r1, null, '2026-10-13 09:40', 'p:marco');
  perform move(gfpplate, reader, null, '2026-10-13 11:30', 'p:marco');
  perform finish_run(run_gfp, '2026-10-13 11:45', 'p:marco');

  ---------------------------------------------------------------------------
  -- 16 October: running buffer for the BLI run.
  -- Mess: Lena also counts the EGFR box. 13 tubes should be there; slot 9
  -- isn't. The tube becomes "location uncertain" straight away, but its
  -- amount doesn't change until someone approves the count, and nobody has.
  ---------------------------------------------------------------------------
  rb2 := register_container('bottle', '2026-10-16 09:00', 'p:lena', 'RB-1016', 'Running buffer RB-1016', p_into => r1);
  rb2_l := make('buffer:bli-running', jsonb_build_array(
                  jsonb_build_object('container', water, 'lot', water_l, 'amount', 240000),
                  jsonb_build_object('container', hepes, 'lot', hepes_l, 'amount', 2500),
                  jsonb_build_object('container', nacl,  'lot', nacl_l,  'amount', 7500)),
                rb2, 250000, 'volume', '2026-10-16 09:00', 'p:lena');
  select count_place(jsonb_agg(jsonb_build_object(
           'container', egfr_kids[g.n], 'found', g.n <> 9,
           'amount', case when g.n <> 9 then 25 end, 'dimension', case when g.n <> 9 then 'volume' end)),
         '2026-10-16 15:00', 'p:lena', 'monthly count of box BOX-0011')
    into cnt
  from generate_series(1, 13) g(n);

  ---------------------------------------------------------------------------
  -- 19 October: fresh loading buffer, then the BLI plates for EXP-0457.
  -- Sample plate: 4 µL of each protein and 76 µL of loading buffer.
  -- Target plate: EGFR from two aliquots (slots 1 and 2) in A1-F1 with running
  -- buffer, and running buffer alone in A2-F2 for the baseline.
  -- The plates wait in the fridge overnight.
  ---------------------------------------------------------------------------
  lb2 := register_container('bottle', '2026-10-19 08:30', 'p:lena', 'LB-1019', 'Loading buffer LB-1019', p_into => r1);
  lb2_l := make('buffer:loading', jsonb_build_array(
                  jsonb_build_object('container', rb2, 'lot', rb2_l, 'amount', 49500),
                  jsonb_build_object('container', bsa, 'lot', bsa_l, 'amount', 500)),
                lb2, 50000, 'volume', '2026-10-19 08:30', 'p:lena');

  run_bli := start_run('BLI binding screen', '2026-10-19 14:00', 'p:marco', gator, 'EXP-0457');
  bli_s := register_container('plate_bli', '2026-10-19 14:00', 'p:marco', 'BLI-S-0457', 'BLI sample plate EXP-0457', p_into => bench);
  bli_t := register_container('plate_bli', '2026-10-19 14:00', 'p:marco', 'BLI-T-0457', 'BLI target plate EXP-0457', p_into => bench);
  perform move(expr, bench, null, '2026-10-19 14:05', 'p:marco');
  s := 0;
  for i in 1 .. 24 loop
    pos := chr(65 + (i - 1) / 12) || ((i - 1) % 12 + 1);
    s := s + 1;
    perform transfer(well(expr, pos), well(bli_s, pos), prot_l[i], 4, 'volume', '2026-10-19 14:20', 'p:marco', p_run => run_bli, p_step => s);
    s := s + 1;
    perform transfer(lb2, well(bli_s, pos), lb2_l, 76, 'volume', '2026-10-19 14:30', 'p:marco', p_run => run_bli, p_step => s);
  end loop;
  perform move(expr, r1, null, '2026-10-19 14:40', 'p:marco');
  perform move(egfr_kids[1], bench, null, '2026-10-19 15:00', 'p:marco');
  perform move(egfr_kids[2], bench, null, '2026-10-19 15:00', 'p:marco');
  for i in 1 .. 6 loop
    pos := chr(64 + i) || '1';
    s := s + 1;
    perform transfer(egfr_kids[case when i <= 3 then 1 else 2 end], well(bli_t, pos), egfr_l, 5, 'volume',
                     '2026-10-19 15:20', 'p:marco', p_run => run_bli, p_step => s);
    s := s + 1;
    perform transfer(rb2, well(bli_t, pos), rb2_l, 195, 'volume', '2026-10-19 15:25', 'p:marco', p_run => run_bli, p_step => s);
    s := s + 1;
    perform transfer(rb2, well(bli_t, chr(64 + i) || '2'), rb2_l, 200, 'volume', '2026-10-19 15:30', 'p:marco', p_run => run_bli, p_step => s);
  end loop;
  perform discard(egfr_kids[1], '2026-10-19 15:35', 'p:marco');
  perform discard(egfr_kids[2], '2026-10-19 15:35', 'p:marco');
  perform move(bli_s, r1, null, '2026-10-19 15:45', 'p:marco');
  perform move(bli_t, r1, null, '2026-10-19 15:45', 'p:marco');

  ---------------------------------------------------------------------------
  -- 20 October: the BLI run on the Gator, one sensor per design. When the run
  -- finishes, both single-use BLI plates are recorded as thrown away by rule.
  -- On the 21st the data reviewer sends part of the screen back for a re-run,
  -- planned for the 28th (see queries/q1c_rerun_numbers.sql).
  ---------------------------------------------------------------------------
  perform move(bli_s, gator, 'plate 1', '2026-10-20 08:30', 'p:marco');
  perform move(bli_t, gator, 'plate 2', '2026-10-20 08:30', 'p:marco');
  s := s + 1;
  perform consume(sensors, sensors_l, 24, 'count', '2026-10-20 09:00', 'instrument:gator-1', 'robot_log', run_bli, s);
  perform finish_run(run_bli, '2026-10-20 15:00', 'p:marco');
end $$;
