const state = {
  lastRisk: null,
  map: null,
  mapMarker: null,
  mapProfileLayerGroup: null,
  mapInitialized: false,
  mapProfiles: [],
  sectorsData: null,
  tipsData: null,
  tipsChecked: {},
  tipsStorageKey: 'dholavira_tips_progress',
};

const qs = (id) => document.getElementById(id);

const backendStatus = qs('backendStatus');
const aiStatus = qs('aiStatus');

const aiBase = `${window.location.protocol}//${window.location.hostname}:5001`;

function setChip(el, label, up, checking = false) {
  el.classList.remove('chip-ok', 'chip-bad', 'chip-warn');
  if (checking) {
    el.classList.add('chip-warn');
    el.textContent = `${label}: checking...`;
    return;
  }
  el.classList.add(up ? 'chip-ok' : 'chip-bad');
  el.textContent = `${label}: ${up ? 'UP' : 'DOWN'}`;
}

async function api(path, options = {}) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new Error(data?.error?.message || data?.error || data?.raw || `HTTP ${res.status}`);
  }
  return data;
}

function parseIntSafe(v) {
  if (v == null) return null;
  if (typeof v === 'number') return Math.trunc(v);
  return Number.parseInt(String(v).split('.')[0], 10);
}

function toRiskLabel(v) {
  if (v >= 0.6) return 'CRITICAL';
  if (v >= 0.4) return 'HIGH';
  if (v >= 0.2) return 'MODERATE';
  return 'LOW';
}

function pct(v) {
  return `${Math.round(Math.max(0, Math.min(1, Number(v || 0))) * 100)}%`;
}

function renderList(container, items, mapItem) {
  container.innerHTML = '';
  if (!items || items.length === 0) {
    container.innerHTML = '<div class="item">No data available.</div>';
    return;
  }
  for (const item of items) {
    const node = document.createElement('div');
    node.className = 'item';
    node.innerHTML = mapItem(item);
    container.appendChild(node);
  }
}

async function refreshStatus() {
  setChip(backendStatus, 'Backend', false, true);
  setChip(aiStatus, 'AI', false, true);

  const backendUp = await api('/healthz').then((d) => d.ok === true).catch(() => false);
  const aiUp = await api('/api/v1/ai/healthz')
    .then((d) => d.success === true && (d.data?.status === 'healthy' || d.data?.models_loaded !== undefined))
    .catch(() => false);

  setChip(backendStatus, 'Backend', backendUp);
  setChip(aiStatus, 'AI', aiUp);
}

function initTabs() {
  const tabs = [...document.querySelectorAll('.tab')];
  const panels = [...document.querySelectorAll('.panel')];

  tabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      tabs.forEach((t) => t.classList.remove('active'));
      panels.forEach((p) => p.classList.remove('active'));
      tab.classList.add('active');
      qs(tab.dataset.tab).classList.add('active');

      if (tab.dataset.tab === 'build-safe') {
        ensureBuildSafeMapReady();
      }
    });
  });
}

function initAIFrame() {
  const frame = qs('aiFrame');
  const link = qs('openAiNewTab');
  frame.src = aiBase;
  link.href = aiBase;
  qs('reloadAiFrameBtn').addEventListener('click', () => {
    frame.src = aiBase;
  });
}

function fillLocation(latId, lonId) {
  if (!navigator.geolocation) {
    alert('Geolocation is not supported in this browser.');
    return;
  }
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      qs(latId).value = pos.coords.latitude.toFixed(6);
      qs(lonId).value = pos.coords.longitude.toFixed(6);
    },
    () => {
      alert('Unable to get your location.');
    },
    { enableHighAccuracy: true, timeout: 12000 }
  );
}

async function loadRecentSos() {
  const container = qs('recentSos');
  container.innerHTML = '<div class="item">Loading...</div>';
  try {
    const data = await api('/v1/sos/recent');
    const items = data.items || [];
    renderList(container, items.slice(0, 20), (item) => {
      const ts = parseIntSafe(item.received_at_unix_ms);
      const time = ts ? new Date(ts).toLocaleString() : 'Unknown time';
      const lat = parseIntSafe(item.lat_e7);
      const lon = parseIntSafe(item.lon_e7);
      const loc = lat != null && lon != null
        ? `${(lat / 1e7).toFixed(4)}, ${(lon / 1e7).toFixed(4)}`
        : 'Unknown location';
      return `<h4>${item.msg_id_hex || 'SOS'}</h4><div>${time}</div><div>${loc}</div>`;
    });
  } catch (err) {
    container.innerHTML = `<div class="item">Failed to load SOS: ${err.message}</div>`;
  }
}

function initSOS() {
  qs('useMyLocationBtn').addEventListener('click', () => fillLocation('sosLat', 'sosLon'));
  qs('refreshSosBtn').addEventListener('click', loadRecentSos);

  qs('sendSosBtn').addEventListener('click', async () => {
    const out = qs('sosResult');
    out.textContent = 'Sending SOS...';
    try {
      const lat = Number(qs('sosLat').value);
      const lon = Number(qs('sosLon').value);
      const data = await api('/v1/sos/panic', {
        method: 'POST',
        body: JSON.stringify({ lat, lon, emergency_code: 1, gateway_id: 'web-app', battery_pct: 55 }),
      });
      out.textContent = JSON.stringify(data, null, 2);
      loadRecentSos();
    } catch (err) {
      out.textContent = `SOS failed: ${err.message}`;
    }
  });

  loadRecentSos();
}

function renderRisk(name, value) {
  const pct = Math.round(Math.max(0, Math.min(1, Number(value))) * 100);
  return `
    <div class="item">
      <strong>${name}</strong>: ${pct}%
      <div class="risk-bar"><div class="risk-fill" style="width:${pct}%"></div></div>
    </div>
  `;
}

function initBuildSafe() {
  if (qs('build-safe')?.classList.contains('active')) {
    ensureBuildSafeMapReady();
  }

  loadBuildSafeMapProfiles();

  qs('riskMyLocationBtn').addEventListener('click', () => fillLocation('riskLat', 'riskLon'));

  qs('assessRiskBtn').addEventListener('click', async () => {
    const lat = Number(qs('riskLat').value);
    const lon = Number(qs('riskLon').value);
    const buildingType = qs('buildingType').value;

    qs('riskSummary').textContent = 'Assessing risk...';
    qs('riskBreakdown').innerHTML = '';

    try {
      const data = await api('/api/v1/ai/risk-assessment', {
        method: 'POST',
        body: JSON.stringify({ lat, lon, building_type: buildingType }),
      });

      const risk = data.data || data;
      state.lastRisk = risk;
      const f = Number(risk.flood_risk ?? 0);
      const l = Number(risk.landslide_risk ?? 0);
      const c = Number(risk.cyclone_risk ?? 0);
      const max = Math.max(f, l, c);
      const terrain = risk?.metadata?.terrain_type || 'mixed';
      const district = risk?.metadata?.terrain_district || 'Kerala';

      qs('riskSummary').textContent = `Overall: ${toRiskLabel(max)} | Building: ${(risk.building_type || buildingType).toUpperCase()} | Terrain: ${String(terrain).toUpperCase()} (${district})`;
      qs('riskBreakdown').innerHTML =
        renderRisk('Flood Risk', f) + renderRisk('Landslide Risk', l) + renderRisk('Cyclone Risk', c);

      await loadBuildSafeKnowledge({ lat, lon, buildingType });
    } catch (err) {
      qs('riskSummary').textContent = `Assessment failed: ${err.message}`;
    }
  });

  qs('getRemediationBtn').addEventListener('click', async () => {
    const container = qs('remediation');
    container.innerHTML = '<div class="item">Generating remediation...</div>';

    const risk = state.lastRisk;
    if (!risk) {
      container.innerHTML = '<div class="item">Run risk assessment first.</div>';
      return;
    }

    try {
      const data = await api('/api/v1/ai/remediation', {
        method: 'POST',
        body: JSON.stringify({
          building_type: risk.building_type || qs('buildingType').value,
          flood_risk: Number(risk.flood_risk ?? 0.2),
          landslide_risk: Number(risk.landslide_risk ?? 0.2),
          cyclone_risk: Number(risk.cyclone_risk ?? 0.2),
        }),
      });
      const recData = data.data || data;
      const recs = recData.recommendations || [];
      renderList(container, recs.slice(0, 12), (r) => `<h4>${r.hazard || 'General'} (${(r.category || '').toUpperCase()})</h4><div>${r.recommendation}</div>`);
    } catch (err) {
      container.innerHTML = `<div class="item">Remediation failed: ${err.message}</div>`;
    }
  });
}

async function loadBuildSafeKnowledge({ lat, lon, buildingType }) {
  const container = qs('buildSafeKnowledge');
  container.innerHTML = '<div class="item">Loading KSDMA-aligned guidance...</div>';

  try {
    const data = await api(`/api/v1/knowledge/build-safe?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&building_type=${encodeURIComponent(buildingType)}`);
    const knowledge = data?.data?.knowledge || {};
    const hazards = knowledge.hazard_priority || [];
    const actions = knowledge.recommended_actions || [];
    const terrain = knowledge.terrain_context;

    const topHazards = hazards.slice(0, 3).map((h) => `<span class="hazard-badge">${h.hazard.toUpperCase()} ${pct(h.score)} (${String(h.category || '').toUpperCase()})</span>`).join('');

    const actionHtml = actions.length
      ? `<ul>${actions.map((a) => `<li>${a}</li>`).join('')}</ul>`
      : '<div>No specific actions available.</div>';

    container.innerHTML = `
      <div class="item">
        <h4>KSDMA Build Safe Context</h4>
        <div>${topHazards || 'No hazard ranking available.'}</div>
        <div class="meta">Terrain: ${(terrain?.terrain_type || 'mixed').toUpperCase()} · District context: ${terrain?.district || 'Kerala'}</div>
      </div>
      <div class="item">
        <h4>Priority Actions</h4>
        ${actionHtml}
        <a class="source-link" target="_blank" rel="noreferrer" href="${knowledge?.references?.guidelines || '#'}">KSDMA Guidelines</a>
      </div>
    `;
  } catch (err) {
    container.innerHTML = `<div class="item">Guidance unavailable: ${err.message}</div>`;
  }
}

function ensureBuildSafeMapReady() {
  if (!state.mapInitialized) {
    initBuildSafeMap();
    state.mapInitialized = true;
  }

  if (state.map) {
    setTimeout(() => {
      state.map.invalidateSize({ pan: false });
    }, 50);
  }
}

function updateMapMarker(lat, lon) {
  if (!state.map) return;
  if (!state.mapMarker) {
    state.mapMarker = L.marker([lat, lon]).addTo(state.map);
  } else {
    state.mapMarker.setLatLng([lat, lon]);
  }
  state.map.setView([lat, lon], Math.max(state.map.getZoom(), 11));
}

function setRiskLocation(lat, lon) {
  const latFixed = Number(lat.toFixed(6));
  const lonFixed = Number(lon.toFixed(6));
  qs('riskLat').value = latFixed;
  qs('riskLon').value = lonFixed;
  updateMapMarker(latFixed, lonFixed);
}

function initBuildSafeMap() {
  const mapEl = qs('buildSafeMap');
  if (!mapEl) return;

  if (typeof window.L === 'undefined') {
    mapEl.innerHTML = '<div class="item">Map library unavailable. Use manual coordinates below.</div>';
    return;
  }

  const defaultLat = Number(qs('riskLat').value || 10.8505);
  const defaultLon = Number(qs('riskLon').value || 76.2711);

  state.map = L.map('buildSafeMap', {
    zoomControl: true,
    preferCanvas: true,
  }).setView([defaultLat, defaultLon], 7);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    updateWhenIdle: true,
    keepBuffer: 4,
    attribution: '&copy; OpenStreetMap contributors',
  }).addTo(state.map);

  updateMapMarker(defaultLat, defaultLon);

  renderMapProfiles();

  state.map.on('click', (ev) => {
    setRiskLocation(ev.latlng.lat, ev.latlng.lng);
  });

  ['riskLat', 'riskLon'].forEach((id) => {
    qs(id).addEventListener('change', () => {
      const lat = Number(qs('riskLat').value);
      const lon = Number(qs('riskLon').value);
      if (Number.isFinite(lat) && Number.isFinite(lon)) {
        updateMapMarker(lat, lon);
      }
    });
  });
}

function hazardColor(hazard) {
  if (hazard === 'landslide') return '#7b1fa2';
  if (hazard === 'cyclone') return '#1976d2';
  return '#d32f2f';
}

function renderMapProfiles() {
  if (!state.map || typeof window.L === 'undefined') return;

  if (state.mapProfileLayerGroup) {
    state.mapProfileLayerGroup.remove();
  }

  const profiles = state.mapProfiles || [];
  const group = L.layerGroup();

  profiles.forEach((p) => {
    const b = p.bbox;
    if (!b) return;
    const rect = L.rectangle(
      [[b.min_lat, b.min_lon], [b.max_lat, b.max_lon]],
      {
        color: hazardColor(p.dominant_hazard),
        weight: 1,
        fillOpacity: 0.08,
        bubblingMouseEvents: false,
      }
    );

    rect.bindPopup(`
      <strong>${p.district}</strong><br/>
      Terrain: ${String(p.terrain || 'mixed').replace(/_/g, ' ')}<br/>
      Flood: ${pct(p.risk?.flood)} · Landslide: ${pct(p.risk?.landslide)} · Cyclone: ${pct(p.risk?.cyclone)}
    `);

    rect.on('click', (ev) => {
      if (ev?.latlng) {
        setRiskLocation(ev.latlng.lat, ev.latlng.lng);
      }
      rect.openPopup(ev.latlng);
    });

    rect.addTo(group);
  });

  group.addTo(state.map);
  state.mapProfileLayerGroup = group;
}

async function loadBuildSafeMapProfiles() {
  try {
    const data = await api('/api/v1/knowledge/map-profiles');
    state.mapProfiles = data?.data?.profiles || [];
    renderMapProfiles();
  } catch {
    state.mapProfiles = [];
  }
}

async function loadAlerts() {
  const list = qs('alertsList');
  list.innerHTML = '<div class="item">Loading alerts...</div>';
  try {
    const data = await api('/api/v1/alerts?page=1&limit=20');
    const items = data.data || [];
    renderList(list, items, (a) => `
      <h4>${(a.title || 'Untitled').toString()}</h4>
      <div><strong>${(a.severity || 'info').toUpperCase()}</strong> · ${(a.alert_type || 'general').toUpperCase()} · ${a.district || 'Unknown'}</div>
      <div>${a.description || ''}</div>
    `);
  } catch (err) {
    list.innerHTML = `<div class="item">Failed to load alerts: ${err.message}</div>`;
  }
}

function initAlerts() {
  loadOfficialChannels();
  qs('refreshAlertsBtn').addEventListener('click', loadAlerts);

  qs('createAlertBtn').addEventListener('click', async () => {
    const out = qs('createAlertResult');
    out.textContent = 'Submitting alert...';
    try {
      const payload = {
        title: qs('alertTitle').value.trim() || 'Community Alert',
        description: qs('alertDescription').value.trim() || 'Reported via web dashboard.',
        alert_type: qs('alertType').value,
        severity: qs('alertSeverity').value,
        district: qs('alertDistrict').value.trim() || 'Ernakulam',
      };
      const data = await api('/api/v1/alerts', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      out.textContent = JSON.stringify(data, null, 2);
      loadAlerts();
    } catch (err) {
      out.textContent = `Create alert failed: ${err.message}`;
    }
  });

  loadAlerts();
}

async function loadOfficialChannels() {
  const container = qs('officialChannels');
  if (!container) return;

  container.innerHTML = '<div class="item">Loading official channels...</div>';
  try {
    const data = await api('/api/v1/knowledge/sectors');
    state.sectorsData = data?.data || null;
    const channels = state.sectorsData?.warning_channels || [];

    renderList(container, channels.slice(0, 10), (channel) => `
      <h4>${channel.label}</h4>
      <a class="source-link" target="_blank" rel="noreferrer" href="${channel.url}">${channel.url}</a>
    `);
  } catch (err) {
    container.innerHTML = `<div class="item">Failed to load official channels: ${err.message}</div>`;
  }
}

async function loadTips() {
  const container = qs('tipsContainer');
  container.innerHTML = '<div class="item">Loading tips...</div>';
  try {
    const lat = Number(qs('riskLat')?.value || 10.8505);
    const lon = Number(qs('riskLon')?.value || 76.2711);
    const buildingType = qs('buildingType')?.value || 'residential';
    const data = await api(`/api/v1/knowledge/tips/current?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&building_type=${encodeURIComponent(buildingType)}`);
    const tipsData = data.data || {};
    const tips = tipsData.tips || [];
    state.tipsData = tipsData;
    state.tipsStorageKey = `dholavira_tips_progress_${tipsData.season || 'default'}_${tipsData.month || 'na'}`;
    try {
      state.tipsChecked = JSON.parse(localStorage.getItem(state.tipsStorageKey) || '{}');
    } catch {
      state.tipsChecked = {};
    }

    container.innerHTML = `
      <div class="item">
        <h4>${(tipsData.label || tipsData.season || 'Season').toString()}</h4>
        <div>${tipsData.overview || ''}</div>
        <div class="meta">Dominant hazards: ${(tipsData.dominant_hazards || []).slice(0, 3).map((h) => `${h.hazard} ${pct(h.score)}`).join(' · ') || 'n/a'}</div>
      </div>
    `;
    renderTipsList();
  } catch (err) {
    container.innerHTML = `<div class="item">Failed to load tips: ${err.message}</div>`;
  }
}

function saveTipsProgress() {
  localStorage.setItem(state.tipsStorageKey, JSON.stringify(state.tipsChecked));
}

function updateTipsProgressView(filteredTips) {
  const progressEl = qs('tipsProgress');
  if (!progressEl) return;
  const allTips = (state.tipsData?.tips || []);
  const doneAll = allTips.filter((t, idx) => state.tipsChecked[t.id || `tip-${idx}`] === true).length;
  const pctAll = allTips.length ? Math.round((doneAll / allTips.length) * 100) : 0;

  const doneFiltered = filteredTips.filter((t) => state.tipsChecked[t._key] === true).length;
  const pctFiltered = filteredTips.length ? Math.round((doneFiltered / filteredTips.length) * 100) : 0;

  progressEl.textContent = `Progress: ${doneAll}/${allTips.length} completed (${pctAll}%). Current filter: ${doneFiltered}/${filteredTips.length} (${pctFiltered}%).`;
}

function renderTipsList() {
  const container = qs('tipsContainer');
  if (!container || !state.tipsData) return;

  const search = (qs('tipsSearchInput')?.value || '').trim().toLowerCase();
  const priority = qs('tipsPriorityFilter')?.value || 'all';

  const tips = state.tipsData.tips || [];
  const tipsWithKeys = tips.map((t, idx) => ({ ...t, _key: t.id || `tip-${idx}` }));
  const filtered = tipsWithKeys.filter((t) => {
    const text = `${t.title || ''} ${t.description || ''} ${t.sector || ''}`.toLowerCase();
    const matchSearch = !search || text.includes(search);
    const p = (t.priority || '').toLowerCase();
    const matchPriority = priority === 'all' || p === priority;
    return matchSearch && matchPriority;
  });

  const existing = container.querySelector('.tips-dynamic');
  if (existing) existing.remove();

  const listWrap = document.createElement('div');
  listWrap.className = 'list tips-dynamic';

  filtered.forEach((t) => {
    const id = t._key;
    const checked = state.tipsChecked[id] === true;
    const el = document.createElement('div');
    el.className = `item tip-item ${checked ? 'done' : ''}`;
    el.innerHTML = `
      <input type="checkbox" data-tip-id="${id}" ${checked ? 'checked' : ''} />
      <div>
        <div class="tip-meta">PRIORITY: ${(t.priority || 'n/a').toUpperCase()}</div>
        <h4>${t.title || 'Tip'}</h4>
        <div>${t.description || ''}</div>
        <div class="meta">Sector: ${t.sector || 'Community Preparedness'}${Array.isArray(t.hazards) && t.hazards.length ? ` · Hazards: ${t.hazards.join(', ')}` : ''}</div>
        ${t.source_url ? `<a class="source-link" target="_blank" rel="noreferrer" href="${t.source_url}">Source</a>` : ''}
      </div>
    `;
    listWrap.appendChild(el);
  });

  if (filtered.length === 0) {
    listWrap.innerHTML = '<div class="item">No tips match current filters.</div>';
  }

  listWrap.addEventListener('change', (ev) => {
    const input = ev.target;
    if (!(input instanceof HTMLInputElement)) return;
    if (input.type !== 'checkbox') return;

    const tipId = input.dataset.tipId;
    if (!tipId) return;
    state.tipsChecked[tipId] = input.checked;
    saveTipsProgress();
    renderTipsList();
  });

  container.appendChild(listWrap);
  updateTipsProgressView(filtered);
}

function initTips() {
  qs('refreshTipsBtn').addEventListener('click', loadTips);
  qs('tipsSearchInput').addEventListener('input', renderTipsList);
  qs('tipsPriorityFilter').addEventListener('change', renderTipsList);
  qs('resetTipsProgressBtn').addEventListener('click', () => {
    state.tipsChecked = {};
    saveTipsProgress();
    renderTipsList();
  });
  loadTips();
}

async function boot() {
  initTabs();
  initAIFrame();
  initSOS();
  initBuildSafe();
  initAlerts();
  initTips();
  await refreshStatus();
  setInterval(refreshStatus, 10000);
}

boot();
