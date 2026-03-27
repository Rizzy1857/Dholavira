function clamp01(value, fallback = 0.2) {
  const v = Number(value);
  if (!Number.isFinite(v)) return fallback;
  return Math.max(0, Math.min(1, v));
}

function riskBand(score) {
  if (score < 0.3) return 'L';
  if (score < 0.6) return 'M';
  if (score < 0.8) return 'H';
  return 'E';
}

function rangeCategory(score) {
  if (score < 0.3) return 'low';
  if (score < 0.6) return 'moderate';
  if (score < 0.8) return 'high';
  return 'extreme';
}

export function buildRiskCombo({ flood_risk, landslide_risk, cyclone_risk }) {
  const flood = clamp01(flood_risk);
  const landslide = clamp01(landslide_risk);
  const cyclone = clamp01(cyclone_risk);

  return {
    key: `F${riskBand(flood)}-L${riskBand(landslide)}-C${riskBand(cyclone)}`,
    categories: {
      flood: rangeCategory(flood),
      landslide: rangeCategory(landslide),
      cyclone: rangeCategory(cyclone),
    },
    scores: { flood, landslide, cyclone },
  };
}

const FALLBACK_RULES = [
  {
    rule_id: 'KL-FLOOD-HIGH-01',
    hazard_type: 'flood',
    building_type: 'all',
    flood_min: 0.6,
    flood_max: 1.0,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 1,
    recommendation: 'Move people and valuables above predicted flood level immediately and shut off ground-floor electrical circuits.',
  },
  {
    rule_id: 'KL-FLOOD-MODERATE-01',
    hazard_type: 'flood',
    building_type: 'all',
    flood_min: 0.3,
    flood_max: 0.6,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'preparedness',
    priority: 3,
    recommendation: 'Pre-position pumps/sandbags, clear drains, and keep evacuation bag ready for rapid rise scenarios.',
  },
  {
    rule_id: 'KL-LANDSLIDE-HIGH-01',
    hazard_type: 'landslide',
    building_type: 'all',
    flood_min: 0.0,
    flood_max: 1.0,
    landslide_min: 0.6,
    landslide_max: 1.0,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 1,
    recommendation: 'Evacuate structures below steep slopes, stop slope cutting, and watch for cracks, tilted poles, or muddy seepage.',
  },
  {
    rule_id: 'KL-LANDSLIDE-MODERATE-01',
    hazard_type: 'landslide',
    building_type: 'all',
    flood_min: 0.0,
    flood_max: 1.0,
    landslide_min: 0.3,
    landslide_max: 0.6,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'short_term',
    priority: 4,
    recommendation: 'Improve slope drainage, remove loose debris, and monitor hill-face movement during each heavy rain spell.',
  },
  {
    rule_id: 'KL-CYCLONE-HIGH-01',
    hazard_type: 'cyclone',
    building_type: 'all',
    flood_min: 0.0,
    flood_max: 1.0,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.6,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 2,
    recommendation: 'Secure roof sheets, windows, and loose outdoor items; relocate to reinforced shelter if wind alerts escalate.',
  },
  {
    rule_id: 'KL-CYCLONE-MODERATE-01',
    hazard_type: 'cyclone',
    building_type: 'all',
    flood_min: 0.0,
    flood_max: 1.0,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.3,
    cyclone_max: 0.6,
    action_bucket: 'preparedness',
    priority: 5,
    recommendation: 'Strengthen shutters/doors and maintain emergency power/communications for possible wind outages.',
  },
  {
    rule_id: 'KL-COMBO-FL-EXTREME',
    hazard_type: 'multi',
    building_type: 'all',
    flood_min: 0.55,
    flood_max: 1.0,
    landslide_min: 0.55,
    landslide_max: 1.0,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 1,
    recommendation: 'Treat this as compound flood-landslide emergency: avoid valleys and slope toes simultaneously; use pre-marked safe corridors only.',
  },
  {
    rule_id: 'KL-COMBO-FC-HIGH',
    hazard_type: 'multi',
    building_type: 'all',
    flood_min: 0.5,
    flood_max: 1.0,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.5,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 2,
    recommendation: 'Plan for flood + wind: move to upper reinforced floors, avoid coastal roads, and protect critical utilities from water ingress.',
  },
  {
    rule_id: 'KL-COMBO-LC-HIGH',
    hazard_type: 'multi',
    building_type: 'all',
    flood_min: 0.0,
    flood_max: 1.0,
    landslide_min: 0.5,
    landslide_max: 1.0,
    cyclone_min: 0.5,
    cyclone_max: 1.0,
    action_bucket: 'immediate',
    priority: 2,
    recommendation: 'Prepare for landslide + windfall hazards: avoid tree-covered slope roads and shift to structurally strong shelters.',
  },
  {
    rule_id: 'KL-RESIDENTIAL-RETROFIT',
    hazard_type: 'multi',
    building_type: 'residential',
    flood_min: 0.3,
    flood_max: 1.0,
    landslide_min: 0.3,
    landslide_max: 1.0,
    cyclone_min: 0.3,
    cyclone_max: 1.0,
    action_bucket: 'structural',
    priority: 6,
    recommendation: 'Retrofit residential structures with roof tie-downs, elevated sockets, and drainage redirection away from foundations.',
  },
  {
    rule_id: 'KL-COMMERCIAL-BUSINESS-CONT',
    hazard_type: 'multi',
    building_type: 'commercial',
    flood_min: 0.3,
    flood_max: 1.0,
    landslide_min: 0.3,
    landslide_max: 1.0,
    cyclone_min: 0.3,
    cyclone_max: 1.0,
    action_bucket: 'short_term',
    priority: 6,
    recommendation: 'Activate business continuity plan: off-site backup, alternate access routes, and staged staff evacuation protocol.',
  },
  {
    rule_id: 'KL-AGRI-FIELD-PROTECT',
    hazard_type: 'flood',
    building_type: 'agricultural',
    flood_min: 0.35,
    flood_max: 1.0,
    landslide_min: 0.0,
    landslide_max: 1.0,
    cyclone_min: 0.0,
    cyclone_max: 1.0,
    action_bucket: 'short_term',
    priority: 5,
    recommendation: 'Use field bund reinforcement, emergency drainage channels, and elevated storage for seed/fertilizer/livestock feed.',
  },
];

function matchesRange(rule, scores) {
  return (
    scores.flood >= Number(rule.flood_min) && scores.flood <= Number(rule.flood_max) &&
    scores.landslide >= Number(rule.landslide_min) && scores.landslide <= Number(rule.landslide_max) &&
    scores.cyclone >= Number(rule.cyclone_min) && scores.cyclone <= Number(rule.cyclone_max)
  );
}

function normalizeRule(rule, scores) {
  const maxRisk = Math.max(scores.flood, scores.landslide, scores.cyclone);
  return {
    rule_id: rule.rule_id,
    hazard: rule.hazard_type === 'multi' ? 'Multi-Hazard' : String(rule.hazard_type).replace(/^\w/, (c) => c.toUpperCase()),
    hazard_type: rule.hazard_type,
    building_type: rule.building_type,
    priority: Number(rule.priority),
    action_bucket: rule.action_bucket,
    recommendation: rule.recommendation,
    category: maxRisk >= 0.8 ? 'extreme' : maxRisk >= 0.6 ? 'high' : maxRisk >= 0.3 ? 'moderate' : 'low',
    risk_score: Number(maxRisk.toFixed(3)),
  };
}

async function queryRulesFromDb(pool, buildingType, scores) {
  const sql = `
    SELECT *
    FROM kerala_remediation_rules
    WHERE is_active = true
      AND district = 'Kerala'
      AND (building_type = $1 OR building_type = 'all')
      AND $2 BETWEEN flood_min AND flood_max
      AND $3 BETWEEN landslide_min AND landslide_max
      AND $4 BETWEEN cyclone_min AND cyclone_max
    ORDER BY priority ASC, rule_id ASC
    LIMIT 24
  `;

  const result = await pool.query(sql, [buildingType, scores.flood, scores.landslide, scores.cyclone]);
  return result.rows ?? [];
}

export async function resolveRemediationRules(pool, payload) {
  const buildingType = String(payload.building_type || 'residential').toLowerCase();
  const combo = buildRiskCombo(payload);
  const scores = combo.scores;

  try {
    const rows = await queryRulesFromDb(pool, buildingType, scores);
    if (rows.length > 0) {
      return {
        source: 'database',
        combo,
        recommendations: rows.map((r) => normalizeRule(r, scores)),
      };
    }
  } catch {
    // fall through to static rules
  }

  const fallback = FALLBACK_RULES
    .filter((rule) => rule.building_type === 'all' || rule.building_type === buildingType)
    .filter((rule) => matchesRange(rule, scores))
    .sort((a, b) => Number(a.priority) - Number(b.priority))
    .slice(0, 24)
    .map((rule) => normalizeRule(rule, scores));

  return {
    source: 'fallback',
    combo,
    recommendations: fallback,
  };
}
