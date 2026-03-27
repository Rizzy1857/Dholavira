-- Kerala-specific terrain hazard profiles for Build Safe risk diversification.
-- This table supports terrain-aware scoring by lat/lon bounds.

CREATE TABLE IF NOT EXISTS kerala_terrain_hazard_profiles (
  profile_id TEXT PRIMARY KEY,
  district TEXT NOT NULL,
  terrain_type TEXT NOT NULL,

  min_lat DOUBLE PRECISION NOT NULL,
  max_lat DOUBLE PRECISION NOT NULL,
  min_lon DOUBLE PRECISION NOT NULL,
  max_lon DOUBLE PRECISION NOT NULL,

  flood_risk DOUBLE PRECISION NOT NULL,
  landslide_risk DOUBLE PRECISION NOT NULL,
  cyclone_risk DOUBLE PRECISION NOT NULL,

  factors JSONB NOT NULL DEFAULT '{}'::jsonb,
  priority INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (min_lat <= max_lat),
  CHECK (min_lon <= max_lon),
  CHECK (flood_risk >= 0 AND flood_risk <= 1),
  CHECK (landslide_risk >= 0 AND landslide_risk <= 1),
  CHECK (cyclone_risk >= 0 AND cyclone_risk <= 1)
);

CREATE INDEX IF NOT EXISTS kerala_terrain_hazard_profiles_bbox_idx
  ON kerala_terrain_hazard_profiles (min_lat, max_lat, min_lon, max_lon, priority DESC);

INSERT INTO kerala_terrain_hazard_profiles (
  profile_id, district, terrain_type, min_lat, max_lat, min_lon, max_lon,
  flood_risk, landslide_risk, cyclone_risk, factors, priority, is_active
) VALUES
(
  'KL-COAST-NORTH', 'Kasaragod/Kannur', 'coastal_plain',
  11.6, 12.9, 74.85, 75.5,
  0.62, 0.22, 0.44,
  '{"flood":"Low-lying coastal plain with monsoon runoff accumulation and tidal influence.","landslide":"Mostly gentle coastal slopes reduce large slide probability.","cyclone":"Open Arabian Sea exposure increases cyclonic wind impact."}',
  10, true
),
(
  'KL-COAST-CENTRAL', 'Kozhikode/Thrissur/Ernakulam/Alappuzha', 'coastal_backwater',
  9.2, 11.6, 75.0, 76.0,
  0.70, 0.18, 0.42,
  '{"flood":"Backwater and river-mouth regions are highly prone to waterlogging and flash flooding.","landslide":"Flat deltaic terrain has low landslide susceptibility.","cyclone":"Moderate coastal wind and storm surge risk."}',
  9, true
),
(
  'KL-COAST-SOUTH', 'Kollam/Thiruvananthapuram coast', 'coastal_urban',
  8.0, 9.2, 76.0, 76.9,
  0.56, 0.24, 0.40,
  '{"flood":"Urban drainage stress and short intense rain bursts create flash flood pockets.","landslide":"Moderate slope sections near coast can fail in prolonged rain.","cyclone":"Coastal winds remain a regular hazard during severe systems."}',
  8, true
),
(
  'KL-MIDLAND-NORTH', 'Kannur/Kozhikode interior', 'midland_lateritic',
  11.0, 12.4, 75.5, 76.3,
  0.46, 0.40, 0.26,
  '{"flood":"Seasonal stream overflow and poor channel capacity in built-up stretches.","landslide":"Lateritic cut slopes become unstable in persistent monsoon saturation.","cyclone":"Inland buffering lowers cyclone intensity relative to coast."}',
  7, true
),
(
  'KL-MIDLAND-CENTRAL', 'Thrissur/Ernakulam/Kottayam', 'midland_riverine',
  9.5, 11.0, 75.8, 76.7,
  0.61, 0.32, 0.22,
  '{"flood":"Riverine and paddy basin overflow drives repeated flood events.","landslide":"Undulating terrain has moderate local slope failure risk.","cyclone":"Cyclone hazard decreases with inland distance."}',
  7, true
),
(
  'KL-MIDLAND-SOUTH', 'Pathanamthitta/Kollam interior', 'midland_humid',
  8.5, 9.8, 76.3, 77.2,
  0.50, 0.46, 0.20,
  '{"flood":"High rainfall and constrained drainage generate moderate flood recurrence.","landslide":"Hill-foot terrain and cut slopes can fail during continuous rainfall.","cyclone":"Mostly secondary cyclone impacts inland."}',
  7, true
),
(
  'KL-HIGHLAND-WAYANAD', 'Wayanad', 'highland_ghat',
  11.3, 12.1, 75.7, 76.4,
  0.28, 0.78, 0.14,
  '{"flood":"Highland drainage reduces standing flood depth except valley bottoms.","landslide":"Steep saturated slopes and weathered rock drive very high landslide hazard.","cyclone":"Topographic shielding lowers direct cyclone effects."}',
  10, true
),
(
  'KL-HIGHLAND-IDUKKI', 'Idukki', 'highland_steep',
  9.3, 10.4, 76.7, 77.4,
  0.26, 0.82, 0.12,
  '{"flood":"Localized valley flooding; broad floodplains are limited.","landslide":"Very steep ghat terrain has critical landslide susceptibility in monsoon.","cyclone":"Far inland and elevated terrain reduce cyclone wind risk."}',
  10, true
),
(
  'KL-HIGHLAND-PATHANAMTHITTA', 'Pathanamthitta uplands', 'highland_hill_foot',
  9.0, 9.6, 76.8, 77.3,
  0.34, 0.68, 0.15,
  '{"flood":"River catchments can create short-duration flood peaks in foothills.","landslide":"Hill-foot settlements face moderate-high landslide and debris flow risk.","cyclone":"Cyclone effects typically indirect and weakened inland."}',
  9, true
),
(
  'KL-PALAKKAD-GAP', 'Palakkad', 'gap_corridor',
  10.4, 11.1, 76.4, 77.1,
  0.40, 0.30, 0.26,
  '{"flood":"Flooding is moderate in low-lying agricultural tracts and river channels.","landslide":"Gentler slopes reduce major landslide frequency.","cyclone":"Gap corridor can channel strong winds from weather systems."}',
  8, true
),
(
  'KL-DEFAULT-KERALA', 'Kerala (general)', 'mixed',
  8.0, 12.9, 74.8, 77.7,
  0.48, 0.40, 0.26,
  '{"flood":"Kerala monsoon pattern creates moderate flood potential in many districts.","landslide":"Western Ghat influence creates notable landslide risk in hilly zones.","cyclone":"Cyclone risk is generally moderate to low and coastal-biased."}',
  1, true
)
ON CONFLICT (profile_id) DO UPDATE SET
  district = EXCLUDED.district,
  terrain_type = EXCLUDED.terrain_type,
  min_lat = EXCLUDED.min_lat,
  max_lat = EXCLUDED.max_lat,
  min_lon = EXCLUDED.min_lon,
  max_lon = EXCLUDED.max_lon,
  flood_risk = EXCLUDED.flood_risk,
  landslide_risk = EXCLUDED.landslide_risk,
  cyclone_risk = EXCLUDED.cyclone_risk,
  factors = EXCLUDED.factors,
  priority = EXCLUDED.priority,
  is_active = EXCLUDED.is_active,
  updated_at = now();
