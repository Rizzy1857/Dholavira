import { FALLBACK_PROFILES } from './keralaTerrainProfiles.mjs';
import { getCurrentSeasonTips, getTipsBySeason } from './seasonalTips.js';

const KSDMA_SOURCES = {
  home: 'https://sdma.kerala.gov.in/',
  about: 'https://sdma.kerala.gov.in/about-ksdma/',
  plans: 'https://sdma.kerala.gov.in/disaster-management-plans/',
  guidelines: 'https://sdma.kerala.gov.in/guidelines/',
  lsg: 'https://sdma.kerala.gov.in/local-self-government-dm-plans/',
  hospitalSafety: 'https://sdma.kerala.gov.in/hospital-safety/',
};

const WARNING_CHANNELS = [
  { key: 'rainfall', label: 'Rainfall', url: 'https://sdma.kerala.gov.in/rainfall-2/' },
  { key: 'highwave', label: 'Highwave', url: 'https://sdma.kerala.gov.in/highwave/' },
  { key: 'flood', label: 'Flood', url: 'https://sdma.kerala.gov.in/flood-homescreen/' },
  { key: 'dam_level', label: 'Dam Level', url: 'https://sdma.kerala.gov.in/dam-water-level/' },
  { key: 'fishermen', label: 'Fishermen Warning', url: 'https://sdma.kerala.gov.in/fishermen-warning/' },
  { key: 'lightning', label: 'Lightning', url: 'https://sdma.kerala.gov.in/lightning-warning/' },
  { key: 'wind', label: 'Strong Wind', url: 'https://sdma.kerala.gov.in/windwarning/' },
  { key: 'temperature', label: 'Temperature', url: 'https://sdma.kerala.gov.in/temperature/' },
  { key: 'uv', label: 'Ultra Violet', url: 'https://sdma.kerala.gov.in/ultra-violet/' },
  { key: 'imd_heavy_rainfall', label: 'IMD Heavy Rainfall', url: 'https://mausam.imd.gov.in/thiruvananthapuram/' },
  { key: 'incois_tsunami', label: 'INCOIS Tsunami', url: 'https://www.incois.gov.in/tsunami/eqevents.jsp' },
  { key: 'imd_cyclone', label: 'IMD Cyclone', url: 'http://www.rsmcnewdelhi.imd.gov.in/index.php?lang=en' },
  { key: 'earthquake', label: 'Earthquake Feed', url: 'https://seismo.gov.in/MIS/riseq/earthquake' },
];

const SECTOR_BRIEF = [
  { sector: 'Early Warning', scope: 'Rainfall, flood, wind, lightning, fishermen, temperature, UV and upstream warning feeds.' },
  { sector: 'Hazard Mapping', scope: 'Flood, landslide, lightning, earthquake, drought maps and zone awareness.' },
  { sector: 'Planning', scope: 'State/District/Urban/Panchayat plans, crisis plans, and departmental templates.' },
  { sector: 'Local Governance', scope: 'LSG risk mainstreaming and local disaster management plan institutionalization.' },
  { sector: 'Health & Hospital Safety', scope: 'Hospital safety assessments, training, and hospital disaster plans.' },
  { sector: 'School Safety', scope: 'School preparedness templates, drills, and awareness handbooks.' },
  { sector: 'Community Inclusion', scope: 'Disability-inclusive DRR, migrant labour inclusive DRR, and tribal planning.' },
  { sector: 'Safe Construction', scope: 'Earthquake/flood/landslide-resilient construction practices.' },
  { sector: 'Response & SOPs', scope: 'Orange Book SOP/ESF guidance and monsoon preparedness action guidance.' },
  { sector: 'Relief & Recovery', scope: 'Relief standards, recovery actions, and public CMDRF transparency links.' },
];

function clamp01(value) {
  return Math.max(0, Math.min(1, Number(value) || 0));
}

function hazardCategory(v) {
  if (v >= 0.8) return 'extreme';
  if (v >= 0.6) return 'high';
  if (v >= 0.3) return 'moderate';
  return 'low';
}

function dominantHazards(scores) {
  return Object.entries(scores)
    .sort((a, b) => b[1] - a[1])
    .map(([hazard, score]) => ({ hazard, score, category: hazardCategory(score) }));
}

function hazardSpecificBuildSafeActions(hazard, buildingType) {
  const base = {
    flood: [
      'Raise plinth/electrical points above local high-flood mark and install backflow prevention.',
      'Provide uninterrupted site drainage path to public drains and keep culverts free of debris.',
    ],
    landslide: [
      'Avoid toe cutting and unsupported slope excavation; stabilize cut slopes before monsoon.',
      'Install proper surface/subsurface drainage and inspect retaining walls for cracks or tilt.',
    ],
    cyclone: [
      'Use roof tie-downs, braced trusses, and secure openings (shutters/impact-resistant protection).',
      'Anchor rooftop utilities and loose external fixtures to reduce wind-borne debris risk.',
    ],
  };

  const actions = base[hazard] ?? [];
  if (buildingType === 'industrial') {
    actions.push('Prepare equipment anchoring and hazardous-material containment for shutdown scenarios.');
  }
  if (buildingType === 'institutional') {
    actions.push('Prepare occupant evacuation and continuity plans with clearly marked safe assembly zones.');
  }
  return actions;
}

function buildContextTips(baseTips, hazards) {
  const topHazards = hazards.slice(0, 2).map((h) => h.hazard);
  const curated = [
    {
      id: 'CTX-KSDMA-ALERTS',
      title: 'Track official Kerala warning channels daily',
      priority: 'critical',
      description: 'Follow KSDMA/IMD/INCOIS warning feeds and act only on verified advisories for your district.',
      source: 'KSDMA warning systems',
      source_url: KSDMA_SOURCES.home,
      sector: 'Early Warning',
      hazards: ['flood', 'landslide', 'cyclone'],
    },
  ];

  if (topHazards.includes('flood')) {
    curated.push({
      id: 'CTX-FLOOD-DRAINAGE',
      title: 'Keep property drainage clear before every heavy-rain spell',
      priority: 'high',
      description: 'Clear rooftop outlets, yard drains, and nearby culverts; move valuables and critical appliances above expected flood levels.',
      source: 'KSDMA Monsoon Preparedness',
      source_url: KSDMA_SOURCES.guidelines,
      sector: 'Build Safe',
      hazards: ['flood'],
    });
  }
  if (topHazards.includes('landslide')) {
    curated.push({
      id: 'CTX-LANDSLIDE-SIGNS',
      title: 'Watch for early landslide signs on slopes',
      priority: 'critical',
      description: 'Treat fresh cracks, tilting trees/poles, and muddy seepage as immediate warning signs and move to safer ground.',
      source: 'KSDMA Landslide Safety',
      source_url: KSDMA_SOURCES.guidelines,
      sector: 'Slope Safety',
      hazards: ['landslide'],
    });
  }
  if (topHazards.includes('cyclone')) {
    curated.push({
      id: 'CTX-CYCLONE-ROOF',
      title: 'Secure roofs and loose outdoor elements before high-wind alerts',
      priority: 'high',
      description: 'Secure roofing members, shutters, and external objects; avoid coastal travel during severe wind warnings.',
      source: 'KSDMA Wind/Cyclone Preparedness',
      source_url: KSDMA_SOURCES.guidelines,
      sector: 'Wind Safety',
      hazards: ['cyclone'],
    });
  }

  const merged = [...curated, ...(baseTips || [])];
  return merged.map((tip) => ({
    ...tip,
    source_url: tip.source_url || KSDMA_SOURCES.guidelines,
    sector: tip.sector || 'Community Preparedness',
    hazards: tip.hazards || [],
  }));
}

export function getKsdmaReferenceBundle() {
  return {
    verified_on: new Date().toISOString(),
    sources: KSDMA_SOURCES,
    sectors: SECTOR_BRIEF,
    warning_channels: WARNING_CHANNELS,
  };
}

export function getTerrainMapProfiles() {
  return FALLBACK_PROFILES.map((p) => ({
    id: p.id,
    district: p.district,
    terrain: p.terrain,
    bbox: {
      min_lat: p.minLat,
      max_lat: p.maxLat,
      min_lon: p.minLon,
      max_lon: p.maxLon,
    },
    risk: {
      flood: p.floodRisk,
      landslide: p.landslideRisk,
      cyclone: p.cycloneRisk,
    },
    dominant_hazard: dominantHazards({ flood: p.floodRisk, landslide: p.landslideRisk, cyclone: p.cycloneRisk })[0]?.hazard ?? 'flood',
  }));
}

export function buildSafeKnowledge({ terrainProfile, buildingType, riskData }) {
  const scores = {
    flood: clamp01(riskData?.flood_risk),
    landslide: clamp01(riskData?.landslide_risk),
    cyclone: clamp01(riskData?.cyclone_risk),
  };
  const hazards = dominantHazards(scores);

  const actions = hazards.slice(0, 2).flatMap((h) => hazardSpecificBuildSafeActions(h.hazard, String(buildingType || 'residential').toLowerCase()));
  const uniqueActions = [...new Set(actions)].slice(0, 6);

  return {
    terrain_context: terrainProfile
      ? {
          profile_id: terrainProfile.id,
          district: terrainProfile.district,
          terrain_type: terrainProfile.terrain,
          factors: terrainProfile.factors ?? {},
        }
      : null,
    hazard_priority: hazards,
    recommended_actions: uniqueActions,
    references: {
      plans: KSDMA_SOURCES.plans,
      guidelines: KSDMA_SOURCES.guidelines,
      warning_channels: WARNING_CHANNELS.slice(0, 6),
    },
  };
}

export function getEnrichedTips({ season, riskData }) {
  const base = season ? getTipsBySeason(season) : getCurrentSeasonTips();
  const scores = {
    flood: clamp01(riskData?.flood_risk),
    landslide: clamp01(riskData?.landslide_risk),
    cyclone: clamp01(riskData?.cyclone_risk),
  };
  const hazards = dominantHazards(scores);
  const tips = buildContextTips(base?.tips, hazards);

  return {
    ...base,
    dominant_hazards: hazards,
    tips,
    tip_count: tips.length,
    references: {
      ...KSDMA_SOURCES,
      warning_channels: WARNING_CHANNELS,
    },
  };
}
