import express from 'express';
import dotenv from 'dotenv';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import cors from 'cors';
import helmet from 'helmet';

import { createDbPool } from './db.mjs';
import { parseSosPayloadV1 } from './sosPayloadV1.mjs';
import { verifyEd25519 } from './ed25519.mjs';
import { createLogger } from './logger.mjs';
import { BatteryOptimizationManager } from './batteryManager.mjs';
import allocationV2 from './allocationWrapper.mjs';

// Module 3: DRI_CA Routes
import feasibilityRouter from './routes/feasibility.js';
import zonesRouter from './routes/zones.js';
import remediationRouter from './routes/remediation.js';
import simplifyRouter from './routes/simplify.js';
import translateRouter from './routes/translate.js';
import alertsRouter from './routes/alerts.js';
import tipsRouter from './routes/tips.js';
import { applyTerrainAwareRisk, resolveKeralaTerrainProfile } from './services/keralaTerrainProfiles.mjs';
import { resolveRemediationRules } from './services/remediationRules.mjs';
import {
  buildSafeKnowledge,
  getEnrichedTips,
  getKsdmaReferenceBundle,
  getTerrainMapProfiles,
} from './services/ksdmaKnowledge.mjs';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.resolve(__dirname, '../public');

const app = express();
app.use(express.json({ limit: '256kb' }));

// CORS support for DRI_CA client
const corsOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:4000')
  .split(',')
  .map((o) => o.trim());

app.use(cors({
  origin: corsOrigins,
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));

app.use(express.static(publicDir));

app.get('/', (_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

const pool = createDbPool();
const logger = createLogger({ pool });
const batteryMgr = new BatteryOptimizationManager(pool);
const inMemoryPanicSos = [];

function buildHeuristicRisk(lat, lon, buildingType = 'residential') {
  const coastalBias = lon > 75.5 ? 0.15 : 0.05;
  const hillBias = lat > 10.8 ? 0.15 : 0.05;
  const flood = Math.max(0.05, Math.min(0.85, 0.25 + coastalBias));
  const landslide = Math.max(0.05, Math.min(0.85, 0.20 + hillBias));
  const cyclone = Math.max(0.05, Math.min(0.85, 0.18 + coastalBias));

  return {
    latitude: lat,
    longitude: lon,
    flood_risk: Number(flood.toFixed(3)),
    landslide_risk: Number(landslide.toFixed(3)),
    cyclone_risk: Number(cyclone.toFixed(3)),
    building_type: buildingType,
    factors: {
      flood: 'Fallback mode: estimated from coarse regional profile',
      landslide: 'Fallback mode: estimated from coarse regional profile',
      cyclone: 'Fallback mode: estimated from coarse regional profile',
    },
    metadata: {
      fallback: true,
      source: 'backend-heuristic',
      timestamp: new Date().toISOString(),
    },
    cached: false,
  };
}

async function applyKeralaTerrainProfile(baseData, lat, lon, buildingType) {
  const { profile, source } = await resolveKeralaTerrainProfile(pool, lat, lon);
  if (!profile) return baseData;

  const adjusted = applyTerrainAwareRisk(baseData, profile, buildingType);
  adjusted.metadata = {
    ...(adjusted.metadata ?? {}),
    kerala_profile_source: source,
    kerala_profile_applied: true,
  };
  return adjusted;
}

app.use((req, res, next) => {
  const reqId = crypto.randomUUID();
  req.reqId = reqId;
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const ms = Number(end - start) / 1e6;
    void logger.info({
      event: 'http_request',
      req_id: reqId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration_ms: Math.round(ms * 10) / 10,
    });
  });

  next();
});

app.get('/healthz', async (_req, res) => {
  try {
    const result = await pool.query('SELECT 1 AS ok');
    res.json({
      ok: result.rows?.[0]?.ok === 1,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    await logger.error({ event: 'healthz_error', error: String(err) });
    res.status(500).json({ ok: false, error: String(err), timestamp: new Date().toISOString() });
  }
});

app.post('/v1/ingest/sos', async (req, res) => {
  const {
    payload_b64,
    pubkey_b64,
    sig_b64,
    rssi = null,
    gateway_id = null,
    received_at_unix_ms = null,
  } = req.body ?? {};

  if (typeof payload_b64 !== 'string' || typeof pubkey_b64 !== 'string' || typeof sig_b64 !== 'string') {
    await logger.warn({
      event: 'sos_rejected',
      reason: 'missing_fields',
      req_id: req.reqId,
    });
    return res.status(422).json({ error: 'missing_fields', details: 'payload_b64, pubkey_b64, sig_b64 are required strings' });
  }

  let payload;
  let pubkey;
  let signature;
  try {
    payload = Buffer.from(payload_b64, 'base64');
    pubkey = Buffer.from(pubkey_b64, 'base64');
    signature = Buffer.from(sig_b64, 'base64');
  } catch (err) {
    await logger.warn({
      event: 'sos_rejected',
      reason: 'invalid_base64',
      req_id: req.reqId,
      gateway_id,
      rssi,
      error: String(err),
    });
    return res.status(422).json({ error: 'invalid_base64', details: String(err) });
  }

  const verified = verifyEd25519({ payload, pubkey, signature });
  if (!verified) {
    await logger.warn({
      event: 'sos_rejected',
      reason: 'invalid_signature',
      req_id: req.reqId,
      gateway_id,
      rssi,
    });
    return res.status(401).json({ error: 'invalid_signature' });
  }

  let decoded;
  try {
    decoded = parseSosPayloadV1(payload);
  } catch (err) {
    await logger.warn({
      event: 'sos_rejected',
      reason: 'invalid_payload',
      req_id: req.reqId,
      gateway_id,
      rssi,
      error: String(err),
    });
    return res.status(422).json({ error: 'invalid_payload', details: String(err) });
  }

  const receivedAt =
    typeof received_at_unix_ms === 'number' && Number.isFinite(received_at_unix_ms)
      ? new Date(received_at_unix_ms)
      : new Date();

  try {
    const insert = await pool.query(
      `INSERT INTO sos_messages (
        msg_id_hex, version, ts_unix_ms, lat_e7, lon_e7, accuracy_m, battery_pct, emergency_code, flags, ttl_hops,
        pubkey, signature, payload, gateway_id, rssi, received_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
        $11,$12,$13,$14,$15,$16
      )
      ON CONFLICT (msg_id_hex) DO NOTHING
      RETURNING msg_id_hex`,
      [
        decoded.msgIdHex,
        decoded.version,
        decoded.tsUnixMs,
        decoded.latE7,
        decoded.lonE7,
        decoded.accuracyM,
        decoded.batteryPct,
        decoded.emergencyCode,
        decoded.flags,
        decoded.ttlHops,
        pubkey,
        signature,
        payload,
        gateway_id,
        rssi,
        receivedAt,
      ]
    );

    if (insert.rowCount === 0) {
      await logger.info({
        event: 'sos_duplicate',
        req_id: req.reqId,
        msg_id: decoded.msgIdHex,
        gateway_id,
        rssi,
      });
      return res.status(409).json({ error: 'duplicate', msg_id: decoded.msgIdHex });
    }

    // Track device battery state (using pubkey as device_id)
    const deviceId = pubkey_b64;
    if (decoded.batteryPct !== null && typeof decoded.batteryPct === 'number') {
      void batteryMgr.updateDeviceBatteryState(deviceId, decoded.batteryPct, decoded.msgIdHex);
    }

    await logger.info({
      event: 'sos_accepted',
      req_id: req.reqId,
      msg_id: decoded.msgIdHex,
      lat_e7: decoded.latE7,
      lon_e7: decoded.lonE7,
      emergency_code: decoded.emergencyCode,
      battery_pct: decoded.batteryPct,
      gateway_id,
      rssi,
    });
    return res.json({ status: 'accepted', msg_id: decoded.msgIdHex });
  } catch (err) {
    await logger.error({
      event: 'sos_db_error',
      req_id: req.reqId,
      error: String(err),
    });
    return res.status(500).json({ error: 'db_error', details: String(err) });
  }
});

app.post('/v1/sos/panic', async (req, res) => {
  const lat = Number(req.body?.lat ?? 10.8505);
  const lon = Number(req.body?.lon ?? 76.2711);
  const emergencyCode = Number(req.body?.emergency_code ?? 1);
  const gatewayId = typeof req.body?.gateway_id === 'string' ? req.body.gateway_id : 'citizen-app';
  const batteryPct = Number(req.body?.battery_pct ?? 50);

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return res.status(422).json({ error: 'invalid_coordinates', details: 'lat/lon must be numeric' });
  }

  const msgIdHex = crypto.randomBytes(16).toString('hex');
  const tsUnixMs = Date.now();
  const latE7 = Math.round(lat * 1e7);
  const lonE7 = Math.round(lon * 1e7);
  const payload = Buffer.from(`PANIC|${msgIdHex}|${tsUnixMs}|${lat}|${lon}`, 'utf8');
  const pubkey = crypto.randomBytes(32);
  const signature = crypto.randomBytes(64);

  try {
    await pool.query(
      `INSERT INTO sos_messages (
        msg_id_hex, version, ts_unix_ms, lat_e7, lon_e7, accuracy_m, battery_pct, emergency_code, flags, ttl_hops,
        pubkey, signature, payload, gateway_id, rssi, received_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
        $11,$12,$13,$14,$15,$16
      )`,
      [
        msgIdHex,
        1,
        tsUnixMs,
        latE7,
        lonE7,
        null,
        Math.max(0, Math.min(100, Math.round(batteryPct))),
        Math.max(0, Math.min(32767, Math.round(emergencyCode))),
        0,
        0,
        pubkey,
        signature,
        payload,
        gatewayId,
        null,
        new Date(tsUnixMs),
      ]
    );

    await logger.warn({
      event: 'civilian_panic_sos',
      req_id: req.reqId,
      msg_id: msgIdHex,
      lat_e7: latE7,
      lon_e7: lonE7,
      gateway_id: gatewayId,
    });

    return res.json({
      status: 'accepted',
      mode: 'panic',
      msg_id: msgIdHex,
      ts_unix_ms: tsUnixMs,
      lat,
      lon,
    });
  } catch (err) {
    await logger.error({ event: 'panic_sos_db_error', req_id: req.reqId, error: String(err) });

    const fallbackItem = {
      msg_id_hex: msgIdHex,
      ts_unix_ms: tsUnixMs,
      lat_e7: latE7,
      lon_e7: lonE7,
      battery_pct: Math.max(0, Math.min(100, Math.round(batteryPct))),
      emergency_code: Math.max(0, Math.min(32767, Math.round(emergencyCode))),
      gateway_id: gatewayId,
      received_at_unix_ms: tsUnixMs,
    };
    inMemoryPanicSos.unshift(fallbackItem);
    if (inMemoryPanicSos.length > 500) inMemoryPanicSos.pop();

    return res.json({
      status: 'accepted',
      mode: 'panic_memory',
      msg_id: msgIdHex,
      ts_unix_ms: tsUnixMs,
      lat,
      lon,
      warning: 'Stored in memory because database is unavailable',
    });
  }
});

app.get('/v1/sos/recent', async (req, res) => {
  const since = typeof req.query.since === 'string' ? Number(req.query.since) : null;
  const sinceMs = Number.isFinite(since) ? since : null;

  try {
    const result = await pool.query(
      `SELECT
        msg_id_hex,
        ts_unix_ms,
        lat_e7,
        lon_e7,
        accuracy_m,
        battery_pct,
        emergency_code,
        flags,
        ttl_hops,
        gateway_id,
        rssi,
        EXTRACT(EPOCH FROM received_at) * 1000 AS received_at_unix_ms
      FROM sos_messages
      WHERE ($1::bigint IS NULL OR ts_unix_ms >= $1)
      ORDER BY received_at DESC
      LIMIT 500`,
      [sinceMs]
    );

    res.json({ items: result.rows });
  } catch (err) {
    await logger.error({ event: 'recent_db_error', req_id: req.reqId, error: String(err) });
    res.json({ items: inMemoryPanicSos });
  }
});

// === Flutter/Mobile Device Battery Endpoints ===

/**
 * GET /v1/device/battery/:device_id
 * 
 * Return cloud's view of device battery state + recommendations.
 * device_id is base64-encoded pubkey.
 */
app.get('/v1/device/battery/:device_id', async (req, res) => {
  const { device_id } = req.params;

  if (!device_id || typeof device_id !== 'string') {
    return res.status(422).json({ error: 'invalid_device_id' });
  }

  try {
    const state = await batteryMgr.getDeviceBatteryState(device_id);

    if (!state) {
      // Device has never sent an SOS; return default good state
      return res.json({
        device_id,
        battery_pct: 100,
        power_state: 'GOOD',
        suppression_recommended: false,
        retention_sec: 604800,
        last_seen_ts: null,
        config: batteryMgr.getOptimizationConfig('GOOD')
      });
    }

    res.json({
      device_id,
      battery_pct: state.battery_pct,
      power_state: state.power_state,
      suppression_recommended: state.should_suppress_rebroadcast,
      retention_sec: state.recommended_message_retention_sec,
      last_seen_ts: state.last_seen_ts ? new Date(state.last_seen_ts).toISOString() : null,
      config: batteryMgr.getOptimizationConfig(state.power_state)
    });
  } catch (err) {
    await logger.error({
      event: 'battery_state_error',
      req_id: req.reqId,
      device_id,
      error: String(err)
    });
    res.status(500).json({ error: 'db_error', details: String(err) });
  }
});

/**
 * GET /v1/optimize/config
 * 
 * Return battery optimization config (for Flutter apps to apply locally).
 * Optional query param: ?power_state=GOOD|MEDIUM|LOW|CRITICAL
 */
app.get('/v1/optimize/config', async (req, res) => {
  const powerState = req.query.power_state ?? 'GOOD';

  const validStates = ['GOOD', 'MEDIUM', 'LOW', 'CRITICAL'];
  if (!validStates.includes(powerState)) {
    return res.status(422).json({ error: 'invalid_power_state', valid_states: validStates });
  }

  try {
    const config = batteryMgr.getOptimizationConfig(powerState);
    res.json({
      power_state: powerState,
      config,
      description: 'Battery optimization parameters for local device filtering and relay.'
    });
  } catch (err) {
    await logger.error({
      event: 'optimize_config_error',
      req_id: req.reqId,
      power_state: req.query.power_state,
      error: String(err)
    });
    res.status(500).json({ error: 'error', details: String(err) });
  }
});

/**
 * GET /v1/stats/battery?device_id=...&hours=24
 * 
 * Return battery optimization stats for a device (analytics dashboard).
 */
app.get('/v1/stats/battery', async (req, res) => {
  const deviceId = req.query.device_id;
  const hoursBack = typeof req.query.hours === 'string' ? Number(req.query.hours) : 24;

  if (!deviceId || typeof deviceId !== 'string') {
    return res.status(422).json({ error: 'device_id is required' });
  }

  if (!Number.isFinite(hoursBack) || hoursBack < 1 || hoursBack > 720) {
    return res.status(422).json({ error: 'hours must be 1-720' });
  }

  try {
    const stats = await batteryMgr.getDeviceStats(deviceId, hoursBack);
    res.json({
      device_id: deviceId,
      hours_back: hoursBack,
      sample_count: stats.length,
      stats
    });
  } catch (err) {
    await logger.error({
      event: 'battery_stats_error',
      req_id: req.reqId,
      device_id: deviceId,
      hours: hoursBack,
      error: String(err)
    });
    res.status(500).json({ error: 'db_error', details: String(err) });
  }
});

/**
 * GET /v1/admin/battery-status
 * 
 * Return network-wide battery status (ops dashboard).
 */
app.get('/v1/admin/battery-status', async (req, res) => {
  try {
    const status = await batteryMgr.getNetworkBatteryStatus();
    res.json({
      at: new Date().toISOString(),
      status
    });
  } catch (err) {
    await logger.error({
      event: 'battery_status_error',
      req_id: req.reqId,
      error: String(err)
    });
    res.status(500).json({ error: 'db_error', details: String(err) });
  }
});

/**
 * POST /v1/stats/battery/record
 * 
 * Device sends battery stats to cloud for persistence + analytics.
 * Body: { device_id, battery_pct, messages_suppressed, messages_forwarded, power_saved_pct }
 */
app.post('/v1/stats/battery/record', async (req, res) => {
  const { device_id, battery_pct, messages_suppressed, messages_forwarded, power_saved_pct } = req.body ?? {};

  if (!device_id || typeof battery_pct !== 'number') {
    return res.status(422).json({ error: 'device_id and battery_pct are required' });
  }

  const msgSuppressed = typeof messages_suppressed === 'number' ? messages_suppressed : 0;
  const msgForwarded = typeof messages_forwarded === 'number' ? messages_forwarded : 0;
  const powerSaved = typeof power_saved_pct === 'number' ? power_saved_pct : 0;

  try {
    await batteryMgr.recordBatteryStats(device_id, battery_pct, msgSuppressed, msgForwarded, powerSaved);
    await logger.info({
      event: 'battery_stats_recorded',
      req_id: req.reqId,
      device_id,
      battery_pct,
      messages_suppressed: msgSuppressed,
      messages_forwarded: msgForwarded,
      power_saved_pct: powerSaved
    });
    res.json({ status: 'recorded' });
  } catch (err) {
    await logger.error({
      event: 'battery_stats_record_error',
      req_id: req.reqId,
      device_id,
      error: String(err)
    });
    res.status(500).json({ error: 'db_error', details: String(err) });
  }
});

/**
 * Allocation v2 Endpoints
 * POST /v1/allocate/v2 - Run advanced allocation
 * POST /v1/allocate/compare - Compare v1 vs v2 results
 */

app.post('/v1/allocate/v2', async (req, res) => {
  try {
    const { nodes, edges, scenarios, mode = 'static', rolling_steps = 1, hitl_overrides } = req.body;
    
    if (!Array.isArray(nodes) || !Array.isArray(edges) || !Array.isArray(scenarios)) {
      await logger.warn({
        event: 'allocate_v2_rejected',
        reason: 'missing_fields',
        req_id: req.reqId
      });
      return res.status(422).json({ error: 'missing_fields', details: 'nodes, edges, scenarios arrays required' });
    }

    const result = await allocationV2.allocate({
      nodes,
      edges,
      scenarios,
      mode,
      rolling_steps,
      hitl_overrides
    });

    await logger.info({
      event: 'allocate_v2_success',
      req_id: req.reqId,
      flows: result.flows?.length || 0,
      scenarios: scenarios.length,
      mode
    });

    res.json({
      version: 'v2',
      status: 'success',
      ...result,
      _metadata: {
        timestamp: new Date().toISOString(),
        mode,
        req_id: req.reqId
      }
    });
  } catch (err) {
    await logger.error({
      event: 'allocate_v2_error',
      req_id: req.reqId,
      error: String(err)
    });
    res.status(500).json({
      version: 'v2',
      status: 'error',
      error: String(err),
      flows: [],
      active_nodes: [],
      critical_routes: [],
      unmet_demand: [],
      explanations: [],
      robust_margin: {}
    });
  }
});

app.post('/v1/allocate/compare', async (req, res) => {
  try {
    const { nodes, edges, scenarios, rolling_steps = 1, hitl_overrides } = req.body;
    
    if (!Array.isArray(nodes) || !Array.isArray(edges) || !Array.isArray(scenarios)) {
      await logger.warn({
        event: 'allocate_compare_rejected',
        reason: 'missing_fields',
        req_id: req.reqId
      });
      return res.status(422).json({ error: 'missing_fields', details: 'nodes, edges, scenarios arrays required' });
    }

    // Get v2 result
    const v2Result = await allocationV2.allocate({
      nodes,
      edges,
      scenarios,
      mode: 'static',
      rolling_steps,
      hitl_overrides
    });

    // Get v1 result for comparison (from legacy allocator if available)
    // For now, we'll just note that v1 comparison would go here
    const comparison = allocationV2.compareResults(
      { flows: [], active_nodes: [], unmet_demand: {}, critical_routes: [] },
      v2Result
    );

    await logger.info({
      event: 'allocate_compare_success',
      req_id: req.reqId,
      v2_flows: v2Result.flows?.length || 0,
      recommendation: comparison.recommendation
    });

    res.json({
      version: 'comparison',
      status: 'success',
      v2_result: v2Result,
      comparison_metrics: comparison,
      _metadata: {
        timestamp: new Date().toISOString(),
        req_id: req.reqId
      }
    });
  } catch (err) {
    await logger.error({
      event: 'allocate_compare_error',
      req_id: req.reqId,
      error: String(err)
    });
    res.status(500).json({
      version: 'comparison',
      status: 'error',
      error: String(err),
      v2_result: {},
      comparison_metrics: {}
    });
  }
});

// ============================================================
// Module 3: DRI_CA Routes (Location Intelligence + Community Awareness)
// ============================================================
app.post('/api/v1/ai/risk-assessment', async (req, res) => {
  const lat = Number(req.body?.lat);
  const lon = Number(req.body?.lon);
  const buildingType = typeof req.body?.building_type === 'string' ? req.body.building_type : 'residential';

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return res.status(422).json({ error: { message: 'lat and lon are required numeric values' } });
  }

  try {
    const aiBaseUrl = process.env.PYTHON_AI_URL || 'http://127.0.0.1:5001';
    const response = await fetch(`${aiBaseUrl}/risk-assessment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        lat,
        lon,
        building_type: buildingType,
      }),
    });

    const raw = await response.json().catch(() => ({}));
    if (!response.ok) {
      await logger.warn({
        event: 'ai_risk_proxy_error',
        req_id: req.reqId,
        status: response.status,
        details: raw,
      });
      return res.status(response.status).json(raw);
    }

    const rawData = raw?.data ?? raw;
    const data = await applyKeralaTerrainProfile(rawData, lat, lon, buildingType);
    return res.json({ success: true, data });
  } catch (err) {
    await logger.error({ event: 'ai_risk_proxy_exception', req_id: req.reqId, error: String(err) });
    const heuristic = buildHeuristicRisk(lat, lon, buildingType);
    const data = await applyKeralaTerrainProfile(heuristic, lat, lon, buildingType);
    return res.json({ success: true, data });
  }
});

app.post('/api/v1/ai/remediation', async (req, res) => {
  const body = req.body ?? {};
  const payload = {
    building_type: typeof body.building_type === 'string' ? body.building_type : 'residential',
    flood_risk: Number.isFinite(Number(body.flood_risk)) ? Number(body.flood_risk) : 0.2,
    landslide_risk: Number.isFinite(Number(body.landslide_risk)) ? Number(body.landslide_risk) : 0.2,
    cyclone_risk: Number.isFinite(Number(body.cyclone_risk)) ? Number(body.cyclone_risk) : 0.2,
  };

  try {
    const dbRules = await resolveRemediationRules(pool, payload);

    const aiBaseUrl = process.env.PYTHON_AI_URL || 'http://127.0.0.1:5001';
    const response = await fetch(`${aiBaseUrl}/remediation`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const raw = await response.json().catch(() => ({}));
    if (!response.ok) {
      await logger.warn({
        event: 'ai_remediation_proxy_error',
        req_id: req.reqId,
        status: response.status,
        details: raw,
      });
      return res.status(response.status).json(raw);
    }

    const aiData = raw?.data ?? raw;
    const aiRecommendations = Array.isArray(aiData?.recommendations) ? aiData.recommendations : [];
    const data = {
      ...aiData,
      building_type: payload.building_type,
      risk_combo: dbRules.combo,
      hazard_rule_recommendations: dbRules.recommendations,
      recommendations: [...dbRules.recommendations, ...aiRecommendations],
      metadata: {
        ...(aiData?.metadata ?? {}),
        remediation_rule_source: dbRules.source,
        matched_rule_count: dbRules.recommendations.length,
      },
    };

    if (typeof data.summary === 'string' && data.summary.length > 0) {
      data.summary = `${data.summary} | Rule engine combo: ${dbRules.combo.key}`;
    } else {
      data.summary = `Remediation based on combo ${dbRules.combo.key} for ${payload.building_type.toUpperCase()}.`;
    }

    return res.json({ success: true, data });
  } catch (err) {
    await logger.error({ event: 'ai_remediation_proxy_exception', req_id: req.reqId, error: String(err) });
    const dbRules = await resolveRemediationRules(pool, payload);
    const maxRisk = Math.max(payload.flood_risk, payload.landslide_risk, payload.cyclone_risk);
    const overall = maxRisk >= 0.6 ? 'high' : maxRisk >= 0.3 ? 'moderate' : 'low';
    const fallback = {
      summary: `Fallback remediation for ${payload.building_type.toUpperCase()} (${overall.toUpperCase()} risk).`,
      overall_severity: overall,
      building_type: payload.building_type,
      risk_combo: dbRules.combo,
      hazard_rule_recommendations: dbRules.recommendations,
      recommendations: dbRules.recommendations,
      risk_breakdown: {
        flood: { score: payload.flood_risk, category: payload.flood_risk >= 0.6 ? 'high' : payload.flood_risk >= 0.3 ? 'moderate' : 'low' },
        landslide: { score: payload.landslide_risk, category: payload.landslide_risk >= 0.6 ? 'high' : payload.landslide_risk >= 0.3 ? 'moderate' : 'low' },
        cyclone: { score: payload.cyclone_risk, category: payload.cyclone_risk >= 0.6 ? 'high' : payload.cyclone_risk >= 0.3 ? 'moderate' : 'low' },
      },
      metadata: {
        fallback: true,
        source: 'backend-remediation-rule-engine',
        remediation_rule_source: dbRules.source,
        matched_rule_count: dbRules.recommendations.length,
        timestamp: new Date().toISOString(),
      },
    };
    return res.json({ success: true, data: fallback });
  }
});

app.get('/api/v1/knowledge/sectors', (_req, res) => {
  return res.json({ success: true, data: getKsdmaReferenceBundle() });
});

app.get('/api/v1/knowledge/map-profiles', (_req, res) => {
  return res.json({
    success: true,
    data: {
      profiles: getTerrainMapProfiles(),
      sources: getKsdmaReferenceBundle().sources,
    },
  });
});

app.get('/api/v1/knowledge/build-safe', async (req, res) => {
  const lat = Number(req.query.lat);
  const lon = Number(req.query.lon);
  const buildingType = typeof req.query.building_type === 'string' ? req.query.building_type : 'residential';

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return res.status(422).json({ error: { message: 'lat and lon query params are required numeric values' } });
  }

  let riskData = null;
  try {
    const aiBaseUrl = process.env.PYTHON_AI_URL || 'http://127.0.0.1:5001';
    const response = await fetch(`${aiBaseUrl}/risk-assessment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ lat, lon, building_type: buildingType }),
    });
    const raw = await response.json().catch(() => ({}));
    if (response.ok) {
      riskData = raw?.data ?? raw;
    }
  } catch {
    // fallback below
  }

  if (!riskData) {
    riskData = buildHeuristicRisk(lat, lon, buildingType);
  }

  const adjustedRisk = await applyKeralaTerrainProfile(riskData, lat, lon, buildingType);
  const { profile } = await resolveKeralaTerrainProfile(pool, lat, lon);

  return res.json({
    success: true,
    data: {
      risk: adjustedRisk,
      knowledge: buildSafeKnowledge({ terrainProfile: profile, buildingType, riskData: adjustedRisk }),
    },
  });
});

app.get('/api/v1/knowledge/tips/current', async (req, res) => {
  const season = typeof req.query.season === 'string' ? req.query.season : null;
  const buildingType = typeof req.query.building_type === 'string' ? req.query.building_type : 'residential';
  const lat = Number(req.query.lat);
  const lon = Number(req.query.lon);

  let riskData = {
    flood_risk: 0.35,
    landslide_risk: 0.35,
    cyclone_risk: 0.3,
    building_type: buildingType,
  };

  if (Number.isFinite(lat) && Number.isFinite(lon)) {
    try {
      const aiBaseUrl = process.env.PYTHON_AI_URL || 'http://127.0.0.1:5001';
      const response = await fetch(`${aiBaseUrl}/risk-assessment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lat, lon, building_type: buildingType }),
      });
      const raw = await response.json().catch(() => ({}));
      if (response.ok) {
        riskData = raw?.data ?? raw;
      } else {
        riskData = buildHeuristicRisk(lat, lon, buildingType);
      }
      riskData = await applyKeralaTerrainProfile(riskData, lat, lon, buildingType);
    } catch {
      riskData = await applyKeralaTerrainProfile(buildHeuristicRisk(lat, lon, buildingType), lat, lon, buildingType);
    }
  }

  return res.json({
    success: true,
    data: getEnrichedTips({ season, riskData }),
  });
});

app.get('/api/v1/ai/healthz', async (req, res) => {
  try {
    const aiBaseUrl = process.env.PYTHON_AI_URL || 'http://127.0.0.1:5001';
    const response = await fetch(`${aiBaseUrl}/healthz`);
    const raw = await response.json().catch(() => ({}));

    if (!response.ok) {
      await logger.warn({
        event: 'ai_health_proxy_error',
        req_id: req.reqId,
        status: response.status,
        details: raw,
      });
      return res.status(response.status).json({ success: false, data: raw });
    }

    return res.json({ success: true, data: raw });
  } catch (err) {
    await logger.error({ event: 'ai_health_proxy_exception', req_id: req.reqId, error: String(err) });
    return res.status(503).json({ success: false, error: { message: 'AI service unavailable' } });
  }
});

app.use('/api/v1/feasibility', feasibilityRouter);
app.use('/api/v1/zones', zonesRouter);
app.use('/api/v1/remediation', remediationRouter);
app.use('/api/v1/simplify', simplifyRouter);
app.use('/api/v1/translate', translateRouter);
app.use('/api/v1/alerts', alertsRouter);
app.use('/api/v1/tips', tipsRouter);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`echo backend listening on http://localhost:${port}`);
});
