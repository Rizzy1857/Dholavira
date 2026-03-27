const KERALA_BOUNDS = {
  minLat: 8.0,
  maxLat: 12.9,
  minLon: 74.8,
  maxLon: 77.7,
};

const FALLBACK_PROFILES = [
  {
    id: 'KL-COAST-NORTH',
    district: 'Kasaragod/Kannur',
    terrain: 'coastal_plain',
    minLat: 11.6,
    maxLat: 12.9,
    minLon: 74.85,
    maxLon: 75.5,
    floodRisk: 0.62,
    landslideRisk: 0.22,
    cycloneRisk: 0.44,
    factors: {
      flood: 'Low-lying coastal plain with monsoon runoff accumulation and tidal influence.',
      landslide: 'Mostly gentle coastal slopes reduce large slide probability.',
      cyclone: 'Open Arabian Sea exposure increases cyclonic wind impact.',
    },
    priority: 10,
  },
  {
    id: 'KL-COAST-CENTRAL',
    district: 'Kozhikode/Thrissur/Ernakulam/Alappuzha',
    terrain: 'coastal_backwater',
    minLat: 9.2,
    maxLat: 11.6,
    minLon: 75.0,
    maxLon: 76.0,
    floodRisk: 0.70,
    landslideRisk: 0.18,
    cycloneRisk: 0.42,
    factors: {
      flood: 'Backwater and river-mouth regions are highly prone to waterlogging and flash flooding.',
      landslide: 'Flat deltaic terrain has low landslide susceptibility.',
      cyclone: 'Moderate coastal wind and storm surge risk.',
    },
    priority: 9,
  },
  {
    id: 'KL-COAST-SOUTH',
    district: 'Kollam/Thiruvananthapuram coast',
    terrain: 'coastal_urban',
    minLat: 8.0,
    maxLat: 9.2,
    minLon: 76.0,
    maxLon: 76.9,
    floodRisk: 0.56,
    landslideRisk: 0.24,
    cycloneRisk: 0.40,
    factors: {
      flood: 'Urban drainage stress and short intense rain bursts create flash flood pockets.',
      landslide: 'Moderate slope sections near coast can fail in prolonged rain.',
      cyclone: 'Coastal winds remain a regular hazard during severe systems.',
    },
    priority: 8,
  },
  {
    id: 'KL-MIDLAND-NORTH',
    district: 'Kannur/Kozhikode interior',
    terrain: 'midland_lateritic',
    minLat: 11.0,
    maxLat: 12.4,
    minLon: 75.5,
    maxLon: 76.3,
    floodRisk: 0.46,
    landslideRisk: 0.40,
    cycloneRisk: 0.26,
    factors: {
      flood: 'Seasonal stream overflow and poor channel capacity in built-up stretches.',
      landslide: 'Lateritic cut slopes become unstable in persistent monsoon saturation.',
      cyclone: 'Inland buffering lowers cyclone intensity relative to coast.',
    },
    priority: 7,
  },
  {
    id: 'KL-MIDLAND-CENTRAL',
    district: 'Thrissur/Ernakulam/Kottayam',
    terrain: 'midland_riverine',
    minLat: 9.5,
    maxLat: 11.0,
    minLon: 75.8,
    maxLon: 76.7,
    floodRisk: 0.61,
    landslideRisk: 0.32,
    cycloneRisk: 0.22,
    factors: {
      flood: 'Riverine and paddy basin overflow drives repeated flood events.',
      landslide: 'Undulating terrain has moderate local slope failure risk.',
      cyclone: 'Cyclone hazard decreases with inland distance.',
    },
    priority: 7,
  },
  {
    id: 'KL-MIDLAND-SOUTH',
    district: 'Pathanamthitta/Kollam interior',
    terrain: 'midland_humid',
    minLat: 8.5,
    maxLat: 9.8,
    minLon: 76.3,
    maxLon: 77.2,
    floodRisk: 0.50,
    landslideRisk: 0.46,
    cycloneRisk: 0.20,
    factors: {
      flood: 'High rainfall and constrained drainage generate moderate flood recurrence.',
      landslide: 'Hill-foot terrain and cut slopes can fail during continuous rainfall.',
      cyclone: 'Mostly secondary cyclone impacts inland.',
    },
    priority: 7,
  },
  {
    id: 'KL-HIGHLAND-WAYANAD',
    district: 'Wayanad',
    terrain: 'highland_ghat',
    minLat: 11.3,
    maxLat: 12.1,
    minLon: 75.7,
    maxLon: 76.4,
    floodRisk: 0.28,
    landslideRisk: 0.78,
    cycloneRisk: 0.14,
    factors: {
      flood: 'Highland drainage reduces standing flood depth except valley bottoms.',
      landslide: 'Steep saturated slopes and weathered rock drive very high landslide hazard.',
      cyclone: 'Topographic shielding lowers direct cyclone effects.',
    },
    priority: 10,
  },
  {
    id: 'KL-HIGHLAND-IDUKKI',
    district: 'Idukki',
    terrain: 'highland_steep',
    minLat: 9.3,
    maxLat: 10.4,
    minLon: 76.7,
    maxLon: 77.4,
    floodRisk: 0.26,
    landslideRisk: 0.82,
    cycloneRisk: 0.12,
    factors: {
      flood: 'Localized valley flooding; broad floodplains are limited.',
      landslide: 'Very steep ghat terrain has critical landslide susceptibility in monsoon.',
      cyclone: 'Far inland and elevated terrain reduce cyclone wind risk.',
    },
    priority: 10,
  },
  {
    id: 'KL-HIGHLAND-PATHANAMTHITTA',
    district: 'Pathanamthitta uplands',
    terrain: 'highland_hill_foot',
    minLat: 9.0,
    maxLat: 9.6,
    minLon: 76.8,
    maxLon: 77.3,
    floodRisk: 0.34,
    landslideRisk: 0.68,
    cycloneRisk: 0.15,
    factors: {
      flood: 'River catchments can create short-duration flood peaks in foothills.',
      landslide: 'Hill-foot settlements face moderate-high landslide and debris flow risk.',
      cyclone: 'Cyclone effects typically indirect and weakened inland.',
    },
    priority: 9,
  },
  {
    id: 'KL-PALAKKAD-GAP',
    district: 'Palakkad',
    terrain: 'gap_corridor',
    minLat: 10.4,
    maxLat: 11.1,
    minLon: 76.4,
    maxLon: 77.1,
    floodRisk: 0.40,
    landslideRisk: 0.30,
    cycloneRisk: 0.26,
    factors: {
      flood: 'Flooding is moderate in low-lying agricultural tracts and river channels.',
      landslide: 'Gentler slopes reduce major landslide frequency.',
      cyclone: 'Gap corridor can channel strong winds from weather systems.',
    },
    priority: 8,
  },
  {
    id: 'KL-DEFAULT-KERALA',
    district: 'Kerala (general)',
    terrain: 'mixed',
    minLat: 8.0,
    maxLat: 12.9,
    minLon: 74.8,
    maxLon: 77.7,
    floodRisk: 0.48,
    landslideRisk: 0.40,
    cycloneRisk: 0.26,
    factors: {
      flood: 'Kerala monsoon pattern creates moderate flood potential in many districts.',
      landslide: 'Western Ghat influence creates notable landslide risk in hilly zones.',
      cyclone: 'Cyclone risk is generally moderate to low and coastal-biased.',
    },
    priority: 1,
  },
];

function isKerala(lat, lon) {
  return (
    lat >= KERALA_BOUNDS.minLat &&
    lat <= KERALA_BOUNDS.maxLat &&
    lon >= KERALA_BOUNDS.minLon &&
    lon <= KERALA_BOUNDS.maxLon
  );
}

function clamp01(value) {
  return Math.max(0.02, Math.min(0.98, Number(value)));
}

function buildingVulnerabilityMultiplier(buildingType = 'residential') {
  const normalized = String(buildingType).toLowerCase();
  switch (normalized) {
    case 'agricultural':
      return { flood: 1.18, landslide: 1.04, cyclone: 1.08 };
    case 'commercial':
      return { flood: 1.05, landslide: 1.0, cyclone: 1.03 };
    case 'industrial':
      return { flood: 1.08, landslide: 1.02, cyclone: 1.06 };
    case 'institutional':
      return { flood: 1.03, landslide: 1.0, cyclone: 1.02 };
    default:
      return { flood: 1.0, landslide: 1.0, cyclone: 1.0 };
  }
}

function mapDbRowToProfile(row) {
  return {
    id: row.profile_id,
    district: row.district,
    terrain: row.terrain_type,
    minLat: Number(row.min_lat),
    maxLat: Number(row.max_lat),
    minLon: Number(row.min_lon),
    maxLon: Number(row.max_lon),
    floodRisk: Number(row.flood_risk),
    landslideRisk: Number(row.landslide_risk),
    cycloneRisk: Number(row.cyclone_risk),
    factors: row.factors ?? {},
    priority: Number(row.priority ?? 0),
  };
}

function resolveFallbackProfile(lat, lon) {
  return FALLBACK_PROFILES
    .filter((p) => lat >= p.minLat && lat <= p.maxLat && lon >= p.minLon && lon <= p.maxLon)
    .sort((a, b) => b.priority - a.priority)[0] ?? null;
}

async function resolveProfileFromDatabase(pool, lat, lon) {
  const sql = `
    SELECT *
    FROM kerala_terrain_hazard_profiles
    WHERE $1 BETWEEN min_lat AND max_lat
      AND $2 BETWEEN min_lon AND max_lon
      AND is_active = true
    ORDER BY priority DESC
    LIMIT 1
  `;

  const result = await pool.query(sql, [lat, lon]);
  if (!result.rows?.length) return null;
  return mapDbRowToProfile(result.rows[0]);
}

export async function resolveKeralaTerrainProfile(pool, lat, lon) {
  if (!isKerala(lat, lon)) {
    return { profile: null, source: 'out_of_scope' };
  }

  try {
    const dbProfile = await resolveProfileFromDatabase(pool, lat, lon);
    if (dbProfile) return { profile: dbProfile, source: 'database' };
  } catch {
    // ignore DB lookup failure and fallback to static profiles
  }

  const fallback = resolveFallbackProfile(lat, lon);
  return {
    profile: fallback,
    source: fallback ? 'fallback' : 'none',
  };
}

export function applyTerrainAwareRisk(baseRisk, profile, buildingType = 'residential') {
  if (!profile) return baseRisk;

  const mult = buildingVulnerabilityMultiplier(buildingType);

  const flood = clamp01((Number(baseRisk.flood_risk) * 0.35 + profile.floodRisk * 0.65) * mult.flood);
  const landslide = clamp01((Number(baseRisk.landslide_risk) * 0.35 + profile.landslideRisk * 0.65) * mult.landslide);
  const cyclone = clamp01((Number(baseRisk.cyclone_risk) * 0.35 + profile.cycloneRisk * 0.65) * mult.cyclone);

  return {
    ...baseRisk,
    flood_risk: Number(flood.toFixed(3)),
    landslide_risk: Number(landslide.toFixed(3)),
    cyclone_risk: Number(cyclone.toFixed(3)),
    factors: {
      ...baseRisk.factors,
      flood: profile.factors?.flood ?? baseRisk.factors?.flood,
      landslide: profile.factors?.landslide ?? baseRisk.factors?.landslide,
      cyclone: profile.factors?.cyclone ?? baseRisk.factors?.cyclone,
    },
    metadata: {
      ...(baseRisk.metadata ?? {}),
      terrain_profile_id: profile.id,
      terrain_type: profile.terrain,
      terrain_district: profile.district,
    },
  };
}

export { FALLBACK_PROFILES, isKerala };
