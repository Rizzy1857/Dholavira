-- Kerala remediation rule database for hazard-type + range-combination selection.

CREATE TABLE IF NOT EXISTS kerala_remediation_rules (
  rule_id TEXT PRIMARY KEY,
  district TEXT NOT NULL DEFAULT 'Kerala',
  hazard_type TEXT NOT NULL CHECK (hazard_type IN ('flood', 'landslide', 'cyclone', 'multi')),
  building_type TEXT NOT NULL DEFAULT 'all',

  flood_min DOUBLE PRECISION NOT NULL,
  flood_max DOUBLE PRECISION NOT NULL,
  landslide_min DOUBLE PRECISION NOT NULL,
  landslide_max DOUBLE PRECISION NOT NULL,
  cyclone_min DOUBLE PRECISION NOT NULL,
  cyclone_max DOUBLE PRECISION NOT NULL,

  action_bucket TEXT NOT NULL CHECK (action_bucket IN ('immediate', 'short_term', 'structural', 'preparedness')),
  priority INTEGER NOT NULL DEFAULT 10,
  recommendation TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (flood_min <= flood_max),
  CHECK (landslide_min <= landslide_max),
  CHECK (cyclone_min <= cyclone_max),
  CHECK (flood_min >= 0 AND flood_max <= 1),
  CHECK (landslide_min >= 0 AND landslide_max <= 1),
  CHECK (cyclone_min >= 0 AND cyclone_max <= 1)
);

CREATE INDEX IF NOT EXISTS kerala_remediation_rules_match_idx
  ON kerala_remediation_rules (district, building_type, hazard_type, priority);

INSERT INTO kerala_remediation_rules (
  rule_id, district, hazard_type, building_type,
  flood_min, flood_max, landslide_min, landslide_max, cyclone_min, cyclone_max,
  action_bucket, priority, recommendation, is_active
) VALUES
('KL-FLOOD-HIGH-01', 'Kerala', 'flood', 'all', 0.6, 1.0, 0.0, 1.0, 0.0, 1.0, 'immediate', 1,
 'Move people and valuables above predicted flood level immediately and shut off ground-floor electrical circuits.', true),

('KL-FLOOD-MODERATE-01', 'Kerala', 'flood', 'all', 0.3, 0.6, 0.0, 1.0, 0.0, 1.0, 'preparedness', 3,
 'Pre-position pumps/sandbags, clear drains, and keep evacuation bag ready for rapid rise scenarios.', true),

('KL-LANDSLIDE-HIGH-01', 'Kerala', 'landslide', 'all', 0.0, 1.0, 0.6, 1.0, 0.0, 1.0, 'immediate', 1,
 'Evacuate structures below steep slopes, stop slope cutting, and watch for cracks, tilted poles, or muddy seepage.', true),

('KL-LANDSLIDE-MODERATE-01', 'Kerala', 'landslide', 'all', 0.0, 1.0, 0.3, 0.6, 0.0, 1.0, 'short_term', 4,
 'Improve slope drainage, remove loose debris, and monitor hill-face movement during each heavy rain spell.', true),

('KL-CYCLONE-HIGH-01', 'Kerala', 'cyclone', 'all', 0.0, 1.0, 0.0, 1.0, 0.6, 1.0, 'immediate', 2,
 'Secure roof sheets, windows, and loose outdoor items; relocate to reinforced shelter if wind alerts escalate.', true),

('KL-CYCLONE-MODERATE-01', 'Kerala', 'cyclone', 'all', 0.0, 1.0, 0.0, 1.0, 0.3, 0.6, 'preparedness', 5,
 'Strengthen shutters/doors and maintain emergency power/communications for possible wind outages.', true),

('KL-COMBO-FL-EXTREME', 'Kerala', 'multi', 'all', 0.55, 1.0, 0.55, 1.0, 0.0, 1.0, 'immediate', 1,
 'Treat this as compound flood-landslide emergency: avoid valleys and slope toes simultaneously; use pre-marked safe corridors only.', true),

('KL-COMBO-FC-HIGH', 'Kerala', 'multi', 'all', 0.5, 1.0, 0.0, 1.0, 0.5, 1.0, 'immediate', 2,
 'Plan for flood + wind: move to upper reinforced floors, avoid coastal roads, and protect critical utilities from water ingress.', true),

('KL-COMBO-LC-HIGH', 'Kerala', 'multi', 'all', 0.0, 1.0, 0.5, 1.0, 0.5, 1.0, 'immediate', 2,
 'Prepare for landslide + windfall hazards: avoid tree-covered slope roads and shift to structurally strong shelters.', true),

('KL-RESIDENTIAL-RETROFIT', 'Kerala', 'multi', 'residential', 0.3, 1.0, 0.3, 1.0, 0.3, 1.0, 'structural', 6,
 'Retrofit residential structures with roof tie-downs, elevated sockets, and drainage redirection away from foundations.', true),

('KL-COMMERCIAL-BUSINESS-CONT', 'Kerala', 'multi', 'commercial', 0.3, 1.0, 0.3, 1.0, 0.3, 1.0, 'short_term', 6,
 'Activate business continuity plan: off-site backup, alternate access routes, and staged staff evacuation protocol.', true),

('KL-AGRI-FIELD-PROTECT', 'Kerala', 'flood', 'agricultural', 0.35, 1.0, 0.0, 1.0, 0.0, 1.0, 'short_term', 5,
 'Use field bund reinforcement, emergency drainage channels, and elevated storage for seed/fertilizer/livestock feed.', true)
ON CONFLICT (rule_id) DO UPDATE SET
  district = EXCLUDED.district,
  hazard_type = EXCLUDED.hazard_type,
  building_type = EXCLUDED.building_type,
  flood_min = EXCLUDED.flood_min,
  flood_max = EXCLUDED.flood_max,
  landslide_min = EXCLUDED.landslide_min,
  landslide_max = EXCLUDED.landslide_max,
  cyclone_min = EXCLUDED.cyclone_min,
  cyclone_max = EXCLUDED.cyclone_max,
  action_bucket = EXCLUDED.action_bucket,
  priority = EXCLUDED.priority,
  recommendation = EXCLUDED.recommendation,
  is_active = EXCLUDED.is_active,
  updated_at = now();
