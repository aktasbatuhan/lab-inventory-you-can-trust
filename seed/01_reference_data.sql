-- Reference data and rules shared by the tests, the demo and the simulation.
-- Numbers marked "assumption" are ours; see docs/assumptions.md.

insert into actor values
  ('p:lena',  'person', 'Lena (lab operations)'),
  ('p:marco', 'person', 'Marco (production scientist)'),
  ('p:sara',  'person', 'Sara (lab manager)'),
  ('robot:hamilton-1', 'robot', 'Hamilton liquid handler 1'),
  ('robot:echo-1',     'robot', 'Echo acoustic dispenser'),
  ('instrument:gator-1', 'instrument', 'Gator BLI 1'),
  ('rule:protocol-defaults', 'rule', 'What the protocol says happens next'),
  ('system:import', 'system', 'Imports and syncs');

insert into material_kind (id, description, base_dimension, needs_qc, required_attributes) values
  ('dna',            'DNA coding for a customer design',                 'mass',   false, '{design_id}'),
  ('sample_protein', 'A customer''s protein, usually expressed in-house','volume', false, '{design_id}'),
  ('target',         'The protein samples are tested against',          'volume', true,  '{protein}'),
  ('buffer',         'Liquids made in-house from components',           'volume', false, '{}'),
  ('reagent',        'Bought liquids and powders: buffer components, PBS, expression kits', 'volume', false, '{}'),
  ('consumable',     'Tips, plates, sensors, chips',                     'count',  false, '{}');

insert into material (id, kind_id, name, attributes) values
  ('target:egfr',      'target',  'EGFR extracellular domain', '{"protein": "EGFR", "species": "human", "tag": "His"}'),
  ('target:pdl1',      'target',  'PD-L1',                     '{"protein": "PD-L1", "species": "human", "tag": "His"}'),
  ('buffer:loading',   'buffer',  'Loading buffer',            '{}'),
  ('buffer:gfp-stock', 'buffer',  'GFP1-10 stock',             '{}'),
  ('buffer:bli-running','buffer', 'BLI running buffer',        '{"recipe": "10 mM HEPES, 150 mM NaCl, 3 mM EDTA, 0.2% Tween-20, pH 7.4"}'),
  ('reagent:water',    'reagent', 'Nuclease-free water',       '{}'),
  ('reagent:hepes',    'reagent', 'HEPES 1 M',                 '{}'),
  ('reagent:nacl',     'reagent', 'NaCl 5 M',                  '{}'),
  ('reagent:pure-mix', 'reagent', 'Cell-free expression mix',  '{}'),
  ('consumable:bli-sensors', 'consumable', 'Strep-Tactin XT biosensors', '{}');

-- Supplier names are placeholders.
insert into product (id, material_id, supplier, catalog_number) values
  ('vendorA:EGFR-100',   'target:egfr',      'Vendor A', 'EGFR-100'),
  ('vendorB:EGFR-7',     'target:egfr',      'Vendor B', 'EGFR-7'),
  ('vendorA:PDL1-200',   'target:pdl1',      'Vendor A', 'PDL1-200'),
  ('vendorC:WATER',      'reagent:water',    'Vendor C', 'NFW-500'),
  ('vendorC:HEPES',      'reagent:hepes',    'Vendor C', 'HEPES-1M'),
  ('vendorC:NACL',       'reagent:nacl',     'Vendor C', 'NACL-5M'),
  ('vendorD:PURE',       'reagent:pure-mix', 'Vendor D', 'PURE-1'),
  ('vendorE:SENSORS',    'consumable:bli-sensors', 'Vendor E', 'SXT-96');

-- Dead volumes are assumptions, see journal/agent-runs/research.md.
insert into container_type (id, category, description, capacity_ul, dead_volume_ul, grid_rows, grid_cols, well_type_id, single_use) values
  ('well_96',       'well',  'Well of a 96-well plate',        200, 2,  null, null, null, false),
  ('well_384',      'well',  'Well of a 384-well plate',        80, 2,  null, null, null, false),
  ('well_echo',     'well',  'Well of an Echo source plate',    65, 20, null, null, null, false),
  ('well_bli',      'well',  'Well of a BLI plate',            200, 0,  null, null, null, false),
  ('well_gfp',      'well',  'Well of a split-GFP plate',       80, 0,  null, null, null, false);

insert into container_type (id, category, description, capacity_ul, dead_volume_ul, grid_rows, grid_cols, well_type_id, single_use) values
  ('plate_96',      'plate', '96-well plate',                   null, 0, 8, 12, 'well_96',   false),
  ('plate_384',     'plate', '384-well plate',                  null, 0, 16, 24, 'well_384', false),
  ('plate_echo',    'plate', 'Echo 384-well source plate',      null, 0, 16, 24, 'well_echo', false),
  ('plate_bli',     'plate', 'BLI plate, thrown away after use',null, 0, 8, 12, 'well_bli',  true),
  ('plate_gfp',     'plate', 'Split-GFP plate, thrown away after use', null, 0, 16, 24, 'well_gfp', true),
  ('tube_1_5ml',    'tube',  '1.5 mL tube',                     1500, 5, null, null, null, false),
  ('tube_matrix',   'tube',  '2D-barcoded 0.5 mL tube',          500, 10, null, null, null, false),
  ('bottle',        'tube',  'Bottle',                         500000, 1000, null, null, null, false),
  ('box_9x9',       'holder','Freezer box, 9 x 9',              null, 0, 9, 9, null, false),
  ('rack',          'holder','Freezer rack',                    null, 0, null, null, null, false),
  ('freezer',       'place', 'Freezer',                         null, 0, null, null, null, false),
  ('fridge',        'place', 'Fridge',                          null, 0, null, null, null, false),
  ('bench',         'place', 'Bench',                           null, 0, null, null, null, false),
  ('instrument',    'instrument', 'Instrument',                 null, 0, null, null, null, false);

-- Shelf life. Effective from long ago so they apply to everything in the tests.
-- recorded_at is set to the same day on purpose: left to default, it would be
-- the moment this file was loaded, and any "as we knew it then" question about
-- an earlier day would see no rules at all.
insert into shelf_life_rule (material_kind_id, material_id, product_id, clock, conditions, duration, effective_from, recorded_at, recorded_by, note) values
  ('target',  null, null, 'since_origin', null, '3 years',  '2020-01-01', '2020-01-01', 'p:sara', 'Brief: many years in the freezer. 3 years is our assumption.'),
  ('target',  null, null, 'in_condition', '{fridge}', '7 days', '2020-01-01', '2020-01-01', 'p:sara', 'Assumption: thawed target is good for a week at 4 °C.'),
  ('target',  null, null, 'in_condition', '{room}',   '8 hours','2020-01-01', '2020-01-01', 'p:sara', 'Assumption: a working day on the bench.'),
  ('dna',     null, null, 'since_origin', null, '5 years',  '2020-01-01', '2020-01-01', 'p:sara', 'Brief: many years in the freezer.'),
  ('sample_protein', null, null, 'since_origin', null, '14 days', '2020-01-01', '2020-01-01', 'p:sara', 'Brief: expression plates last 2 weeks.'),
  ('buffer',  null, null, 'since_origin', null, '1 month',  '2020-01-01', '2020-01-01', 'p:sara', 'Brief: buffers other than GFP stock and loading buffer last 1 month.'),
  (null, 'buffer:loading',   null, 'since_origin', null, '7 days',   '2020-01-01', '2020-01-01', 'p:sara', 'Brief: loading buffer lasts 1 week.'),
  (null, 'buffer:gfp-stock', null, 'since_origin', null, '6 months', '2020-01-01', '2020-01-01', 'p:sara', 'Brief: GFP stock lasts 6 months frozen. Outer limit.'),
  (null, 'buffer:gfp-stock', null, 'in_condition', '{fridge}', '1 month', '2020-01-01', '2020-01-01', 'p:sara', 'Assumption: once in the fridge, the usual buffer month.'),
  ('reagent', null, null, 'since_origin', null, '2 years',  '2020-01-01', '2020-01-01', 'p:sara', 'Brief: varies, typically long. 2 years is our assumption.');

-- Freeze-thaw limits (decision D7). Assumptions.
insert into thaw_limit_rule (material_kind_id, material_id, product_id, max_thaws, effective_from, recorded_at, recorded_by, note) values
  ('target', null, null, 3, '2020-01-01', '2020-01-01', 'p:sara', 'Assumption: a common default for proteins.'),
  (null, null, 'vendorB:EGFR-7', 1, '2020-01-01', '2020-01-01', 'p:sara', 'Example of a supplier-specific limit: this formulation has no glycerol.');
