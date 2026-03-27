"""
DisasterAI – Flask Web Application  (v4, enhanced with caching & remediation)
==============================================================================
Fetches REAL weather + elevation from Open-Meteo for every clicked location.
Enhanced with:
  • Request caching (30-min TTL) to reduce API calls
  • Comprehensive remediation generation based on risks
  • Multi-hazard risk scoring with explainability
  • Intelligent feature validation and normalization
  • Batch processing support for allocation

Data pipeline per request:
  1. Open-Meteo /forecast  → elevation, 7-day precipitation, wind,
                              soil-moisture, surface-pressure
  2. build_features()      → maps API values to model input arrays
  3. LSTM encoder          → 64-dim temporal vector
  4. XGBoost multi-output  → [flood, landslide, cyclone] probabilities
  5. physics_calibrate()   → safety-net: corrects extreme LSTM mismatches
  6. remediation_pipeline()→ generates context-aware mitigation strategies
"""

import os, math, warnings, requests, hashlib, json, time
from functools import lru_cache
from datetime import datetime, timedelta
import numpy as np
import joblib
import tensorflow as tf
from flask import Flask, render_template, request, jsonify
from threading import RLock

warnings.filterwarnings("ignore")

MODELS_DIR         = "models"
SEQ_LEN            = 7
N_DYNAMIC_FEATURES = 6
METEO_URL          = "https://api.open-meteo.com/v1/forecast"
CACHE_TTL          = 1800  # 30 minutes in seconds
PREDICTION_CACHE   = {}
CACHE_LOCK         = RLock()

app = Flask(__name__)

lstm_model = lstm_encoder = xgb_clf = static_scaler = dynamic_scaler = None
MODELS_READY = False


# ── REMEDIATION KNOWLEDGE BASE ───────────────────────────────────────────
REMEDIATION_DB = {
    "flood": {
        "low": {
            "residential": [
                "Elevate mechanical systems (HVAC, electrical panels) above 100-year flood level",
                "Install flood-resistant doors and seal utility penetrations",
                "Use permeable paving in driveways to reduce surface runoff",
                "Maintain gutters and ensure proper grading around foundation",
                "Create a sandbag storage area accessible during monsoon season",
            ],
            "commercial": [
                "Implement sump pump system with battery backup",
                "Install automatic flood barriers at ground-level entrances",
                "Relocate critical business infrastructure to upper floors",
                "Design parking areas with stormwater retention capacity",
                "Conduct regular flood drills for staff evacuation",
            ],
            "agricultural": [
                "Construct field-level drainage channels to guide water away",
                "Establish crop insurance policy covering flood damage",
                "Plant native wetland vegetation in low-lying farm areas",
                "Create firebreaks that double as water runoff channels",
                "Maintain detailed soil moisture monitoring records",
            ],
        },
        "moderate": {
            "residential": [
                "Install check valves in sewer drains to prevent backflow",
                "Raise first floor living areas above anticipated flood level",
                "Use water-resistant materials for walls below flood line",
                "Create detention basins in yard to temporarily store excess water",
                "Install submersible pumps in basement or lowest areas",
            ],
            "commercial": [
                "Design building foundation with water-resistant materials",
                "Implement warning system connected to weather alerts",
                "Train staff on emergency closure procedures during floods",
                "Install water-level sensors that trigger automatic shutdowns",
                "Establish supply chain backup outside flood-prone areas",
            ],
            "agricultural": [
                "Build elevated storage for seeds and critical equipment",
                "Implement terracing on sloped agricultural land",
                "Create buffer zones with flood-resistant crops",
                "Establish early warning system with local authorities",
                "Document field topography for better water management",
            ],
        },
        "high": {
            "residential": [
                "Consider relocation to higher elevation if feasible",
                "Install structural reinforcement to withstand water pressure",
                "Create waterproof seal around entire perimeter with pumping system",
                "Install permanent flood walls or shields on vulnerable sides",
                "Maintain emergency supplies: water, food, medications for 72 hours",
            ],
            "commercial": [
                "Relocate critical operations to flood-free secondary location",
                "Install multi-stage pumping system for rapid water removal",
                "Design all mechanical systems to be removable/portable",
                "Establish business continuity plan with off-site data backup",
                "Coordinate with municipal flood management infrastructure",
            ],
            "agricultural": [
                "Avoid permanent structures in high-flood-risk zones",
                "Establish crop rotation patterns accounting for flood cycles",
                "Invest in flood-resistant crop varieties for your region",
                "Create emergency access for livestock evacuation",
                "Maintain real-time coordination with disaster management authorities",
            ],
        },
    },
    "landslide": {
        "low": {
            "residential": [
                "Monitor slope stability with annual visual inspections",
                "Maintain vegetation on slopes to bind soil and intercept rainfall",
                "Ensure proper drainage away from slope base",
                "Avoid heavy loads or vibrations near slope edges",
                "Plant deep-rooted trees on slopes for additional reinforcement",
            ],
            "commercial": [
                "Conduct geological survey before groundbreaking construction",
                "Design retaining walls appropriate for local soil conditions",
                "Install surface and subsurface drainage systems",
                "Monitor adjacent slopes that could impact facility",
                "Maintain regular inspection logs for slope stability",
            ],
            "agricultural": [
                "Implement contour plowing to reduce water runoff downslope",
                "Plant nitrogen-fixing cover crops to strengthen soil structure",
                "Avoid deep excavation that could undermine slope stability",
                "Create mulch barriers to prevent soil erosion",
                "Monitor spring lines for changes in groundwater emergence",
            ],
        },
        "moderate": {
            "residential": [
                "Install slope monitoring system with tilt sensors for early warning",
                "Build retaining wall with proper drainage behind structure",
                "Avoid planting heavy trees directly upslope from building",
                "Create underground drain pipes to reduce soil saturation",
                "Evacuate immediately if cracks appear or ground shifts noticeably",
            ],
            "commercial": [
                "Conduct quarterly slope stability assessments by professionals",
                "Install ground anchors or soil nails to stabilize slope",
                "Implement GPS-based movement monitoring system",
                "Design building with flexible utility connections allowing movement",
                "Establish evacuation protocol triggerable by sensor alerts",
            ],
            "agricultural": [
                "Terrace steep slopes to reduce water velocity and erosion",
                "Install subsurface drainage in upper slope zones",
                "Avoid irrigation on slopes — use drip systems instead",
                "Plant deep-rooted perennial grasses between crop rows",
                "Establish cut-and-fill benches to reduce overall slope angle",
            ],
        },
        "high": {
            "residential": [
                "Do not construct on this slope — extreme risk of failure",
                "If already present, evacuation relocation assistance should be pursued",
                "Install steel cable anchors from building to stable bedrock",
                "Hire licensed geotechnical engineer for custom design",
                "Maintain continuous monitoring with automated alert systems",
            ],
            "commercial": [
                "Conduct detailed slope stability analysis by certified engineer",
                "Design building foundation anchored to stable bedrock",
                "Install ground stabilization techniques (e.g., grouting, nailing)",
                "Implement 24/7 automated monitoring with immediate alert dispatch",
                "Establish partnership with disaster management for rapid response",
            ],
            "agricultural": [
                "Do not cultivate on high-risk slopes; consider afforestation instead",
                "If already cultivated, transitioning to agroforestry is recommended",
                "Install major drainage infrastructure to reduce soil moisture",
                "Consult with geological survey before any land modification",
                "Maintain emergency access routes for livestock/equipment evacuation",
            ],
        },
    },
    "cyclone": {
        "low": {
            "residential": [
                "Maintain roof coverings in good condition; repair damaged tiles/shingles",
                "Trim tree branches overhanging roof and utilities",
                "Ensure gutters are clear and downspouts direct water away",
                "Reinforce garage doors to withstand wind pressure",
                "Keep emergency supplies: water, first aid, flashlights accessible",
            ],
            "commercial": [
                "Conduct annual wind-load assessment of building envelope",
                "Inspect and maintain HVAC equipment and ductwork connections",
                "Ensure signage and external fixtures are securely fastened",
                "Test backup power systems and fuel supply monthly",
                "Provide staff wind safety training before cyclone season",
            ],
            "agricultural": [
                "Establish windbreaks using native trees on farm perimeter",
                "Ensure fencing and structures are wind-resistant",
                "Secure water tanks and loose equipment before cyclone season",
                "Create shelter plans for livestock during high-wind events",
                "Monitor weather alerts and maintain evacuation supply kits",
            ],
        },
        "moderate": {
            "residential": [
                "Install storm shutters or plywood covers for all windows",
                "Reinforce entry doors with additional locks and metal bracing",
                "Trim all trees 6+ meters from house; remove weak branches",
                "Anchor HVAC units and water heaters to foundation",
                "Stock 72-hour emergency supplies: water, food, medications, batteries",
            ],
            "commercial": [
                "Upgrade roof to withstand higher wind speeds (engineers specification)",
                "Install wind-resistant glass in exposed windows/curtain walls",
                "Secure all rooftop equipment including satellite dishes and antennas",
                "Develop detailed evacuation plan with regular drills",
                "Maintain contracts with emergency response contractors",
            ],
            "agricultural": [
                "Create reinforced structures for equipment and crop storage",
                "Install wind-resistant fencing rated for cyclone conditions",
                "Establish clear evacuation routes for livestock",
                "Secure irrigation equipment and fuel storage",
                "Monitor extended weather forecasts starting August (cyclone season)",
            ],
        },
        "high": {
            "residential": [
                "Install reinforced concrete room (safe room) for family shelter",
                "Install hurricane-rated windows and reinforced entry doors",
                "Relocate to inland/elevated location during cyclone warnings",
                "Maintain continuous weather monitoring system",
                "Prepare evacuation kit and know multiple evacuation routes",
            ],
            "commercial": [
                "Fortify structure to exceed local cyclone-resistance codes",
                "Install emergency generators with sufficient fuel for 72+ hours",
                "Design safe rooms for staff during cyclone events",
                "Establish remote work capability for business continuity",
                "Maintain continuous liaison with disaster management authorities",
            ],
            "agricultural": [
                "Establish temporary relocation plan for livestock to interior shelters",
                "Invest in reinforced storage structures for critical supplies",
                "Create multiple evacuation routes from farm to safe zones",
                "Maintain detailed documentation for insurance claims",
                "Partner with agricultural extension services for guidance",
            ],
        },
    },
}



def load_models():
    global lstm_model, lstm_encoder, xgb_clf, static_scaler, dynamic_scaler
    print("[APP] Loading model artifacts …")
    lstm_model    = tf.keras.models.load_model(
                        os.path.join(MODELS_DIR, "lstm_encoder.keras"))
    lstm_encoder  = tf.keras.Model(
                        inputs  = lstm_model.input,
                        outputs = lstm_model.get_layer("layer_norm").output,
                        name    = "encoder")
    xgb_clf        = joblib.load(os.path.join(MODELS_DIR, "xgb_multi_clf.pkl"))
    static_scaler  = joblib.load(os.path.join(MODELS_DIR, "static_scaler.pkl"))
    dynamic_scaler = joblib.load(os.path.join(MODELS_DIR, "dynamic_scaler.pkl"))
    print("[APP] Models ready ✓")


# ── Coastline helper (unchanged) ──────────────────────────────────────────
COAST_PTS = [
    (23.0,68.4),(22.0,68.9),(21.0,70.1),(20.2,72.8),(19.0,72.8),
    (18.0,73.4),(16.0,73.5),(15.0,73.8),(14.5,74.3),(13.0,74.8),
    (11.5,75.3),(10.5,75.9),(10.0,76.3),(9.0,76.7),(8.4,77.1),
    (8.1,77.6),(8.7,78.2),(9.5,79.1),(10.0,79.8),(11.0,79.8),
    (12.0,80.0),(13.0,80.3),(15.0,80.1),(17.0,82.2),(18.0,83.5),
    (19.0,84.8),(20.0,86.0),(20.5,86.7),(21.5,87.2),(22.5,88.2),
    (23.5,91.0),
]

def _hav(la1,lo1,la2,lo2):
    R=6371.; d=math.radians
    a=math.sin(d(la2-la1)/2)**2+math.cos(d(la1))*math.cos(d(la2))*math.sin(d(lo2-lo1)/2)**2
    return R*2*math.asin(math.sqrt(a))

def _dist_coast(lat, lon):
    return min(_hav(lat,lon,c[0],c[1]) for c in COAST_PTS)


# ── Step 1: Fetch real data ───────────────────────────────────────────────
def fetch_real_data(lat: float, lon: float) -> dict:
    """
    Calls Open-Meteo for the last 7 days + next 2 days of weather data.
    Returns the raw JSON response.
    Raises requests.RequestException on network failure.
    """
    params = {
        "latitude":     lat,
        "longitude":    lon,
        "daily":        ["precipitation_sum", "windspeed_10m_max"],
        "hourly":       ["soil_moisture_0_to_7cm", "surface_pressure"],
        "past_days":    7,
        "forecast_days": 2,
        "timezone":     "Asia/Kolkata",
    }
    r = requests.get(METEO_URL, params=params, timeout=12)
    r.raise_for_status()
    return r.json()


# ── Step 2: Build model input arrays ─────────────────────────────────────
def _safe_list(lst, n, default=0.0):
    """Returns first n values, padding with default if shorter."""
    out = [v if v is not None else default for v in (lst or [])]
    while len(out) < n:
        out.append(default)
    return out[:n]


def _daily_avg_hourly(hourly_vals, day_idx: int, default=0.0):
    """Average 24 hourly values for the given day index (0 = oldest)."""
    vals = [v for v in hourly_vals[day_idx*24:(day_idx+1)*24]
            if v is not None]
    return float(np.mean(vals)) if vals else default


def build_features(lat: float, lon: float, meteo: dict):
    """
    Maps Open-Meteo API response → (static_arr (5,), dynamic_arr (7,6)).

    Training feature ranges (so we stay in-distribution):
      soil_moisture     : 5 – 100  %
      rain_past_3d_cum  : 0 – 250  mm   (3-day rolling sum of daily precip)
      rain_fcst_48h     : 0 – 180  mm   (48-h forecast total)
      river_gauge       : 0.5 – 15 m    (derived from cumulative rain)
      wind_speed        : 0 – 220  km/h
      baro_drop         : 0 – 30   hPa  (daily pressure drop)
    """
    dc        = _dist_coast(lat, lon)
    elevation = float(meteo.get("elevation", 200.0))

    # ── Slope: estimated from DEM elevation ──────────────────────────────
    # Calibrated to training range 0–60 °:
    #   coastal / plains (elev < 100 m): 0.5 – 5 °
    #   plateau / hills  (100–1000 m)  : 5 – 25 °
    #   Himalayas        (>1000 m)     : 25 – 55 °
    if elevation < 100:
        slope = np.clip(0.5 + elevation * 0.05, 0.5, 5.0)
    elif elevation < 1000:
        slope = np.clip(5.0 + (elevation - 100) / 45, 5.0, 25.0)
    else:
        slope = np.clip(25.0 + (elevation - 1000) / 60, 25.0, 55.0)

    # ── Distance to nearest river (heuristic) ────────────────────────────
    # Low-elevation alluvial areas are close to rivers;
    # high mountains have streams; arid plateaus are far.
    if elevation < 80:
        dr = max(0.5, elevation * 0.08)          # 0–6 km for deltas/coasts
    elif elevation > 1500:
        dr = np.clip(elevation / 200, 5.0, 20.0) # 7-17 km for high terrain
    else:
        dr = np.clip(elevation / 30, 3.0, 50.0)  # 3-50 km for mid zones

    # ── Land cover (rough) ───────────────────────────────────────────────
    if elevation > 600:     land = 1   # forest / highland
    elif elevation < 50:    land = 0   # urban / coastal lowland
    else:                   land = 2   # agricultural

    static_arr = np.array([elevation, slope, dr, dc, float(land)],
                           dtype=np.float32)

    # ── Daily weather (7 historical days + 2 forecast) ───────────────────
    daily     = meteo.get("daily", {})
    # Open-Meteo with past_days=7, forecast_days=2 returns 9 daily rows
    all_precip = _safe_list(daily.get("precipitation_sum", []), 9, 0.0)
    all_wind   = _safe_list(daily.get("windspeed_10m_max",  []), 9, 10.0)

    precip_7d  = all_precip[:7]           # historical
    precip_f   = sum(all_precip[7:9])     # 48-h forecast total

    # 3-day rolling cumulative precipitation (matching training semantics)
    rain_cum = [
        float(sum(precip_7d[max(0, i-2):i+1]))
        for i in range(SEQ_LEN)
    ]

    # Clamp to training scales
    rain_cum  = [min(r, 250.0) for r in rain_cum]
    rain_fcst = min(precip_f, 180.0)
    wind_7d   = [min(w, 220.0) for w in _safe_list(all_wind[:7], 7, 10.0)]

    # ── Hourly → daily-averaged soil moisture & pressure ─────────────────
    hourly    = meteo.get("hourly", {})
    # Default 0.05 m³/m³ (5%) so missing data doesn't inflate soil moisture
    sm_hrly   = _safe_list(hourly.get("soil_moisture_0_to_7cm", []), 9*24, 0.05)
    pr_hrly   = _safe_list(hourly.get("surface_pressure",        []), 9*24, 1013.0)

    soil_7d = []
    baro_7d = []
    for d in range(SEQ_LEN):
        # Soil moisture: API returns m³/m³; × 100 → %
        sm = _daily_avg_hourly(sm_hrly, d, 0.05) * 100.0
        soil_7d.append(float(np.clip(sm, 5.0, 95.0)))

        # Barometric drop per day (hPa): first hour minus last in that day
        day_press = [v for v in pr_hrly[d*24:(d+1)*24] if v is not None]
        drop = max(0.0, day_press[0] - day_press[-1]) if len(day_press) >= 2 else 0.0
        baro_7d.append(float(min(drop, 30.0)))

    # Aridity guard (runs AFTER loop so soil_7d is populated):
    # If total recent rain is tiny, cap soil moisture — prevents missing/stale
    # API data from inflating the physics flood score above the 0.45 threshold.
    total_rain = sum(precip_7d)
    if total_rain < 10:
        soil_7d = [min(s, 18.0) for s in soil_7d]   # very dry: cap at 18%
    elif total_rain < 30:
        soil_7d = [min(s, 40.0) for s in soil_7d]   # semi-dry: cap at 40%

    # River gauge (m): proportional to 3-day rain cumulative
    gauge_7d = [float(np.clip(0.5 + r / 16.7, 0.5, 15.0)) for r in rain_cum]

    # ── Stack into (7, 6) ─────────────────────────────────────────────────
    dynamic_arr = np.array([
        soil_7d,                       # soil_moisture (%)
        rain_cum,                      # rain_past_3d (mm)
        [rain_fcst] * SEQ_LEN,         # rain_fcst_48h (mm)
        gauge_7d,                      # river_gauge (m)
        wind_7d,                       # wind_speed (km/h)
        baro_7d,                       # baro_drop (hPa)
    ], dtype=np.float32).T             # → (7, 6)

    return static_arr, dynamic_arr



# ── Step 3: Physics-based calibration (no zones needed) ──────────────────
def _physics_flood(elev, soil_pct, rain_mm, fcst_mm, dr):
    """Reproduces the training-time flood_score formula."""
    return (  0.35 * (1 - elev    / 3500)
            + 0.20 * (soil_pct    / 100)
            + 0.20 * (rain_mm     / 250)
            + 0.15 * (fcst_mm     / 180)
            + 0.10 * (1 - dr      /  50))

def _physics_landslide(slope, rain_mm, soil_pct, fcst_mm):
    return (  0.40 * (slope    /  60)
            + 0.25 * (rain_mm  / 250)
            + 0.25 * (soil_pct / 100)
            + 0.10 * (fcst_mm  / 180))

def _physics_cyclone(wind_kmh, baro_hpa, dc):
    return (  0.40 * (wind_kmh /  220)
            + 0.35 * (baro_hpa /   30)
            + 0.25 * (1 - dc   / 600))

def physics_calibrate(static_arr, dynamic_arr, fp, lp, cp):
    """
    When physics score and XGBoost output disagree across the decision
    boundary, fully defer to the physics score.

    Physics  says SAFE  (<0.45) but model says DANGER (>0.5)?
        → Return physics score:  XGBoost is biased by elevation alone.
    Physics  says DANGER (>=0.45) but model says SAFE (<0.5)?
        → Return average: both signals carry information.
    Both agree?
        → Return model score (it has richer features).
    """
    elev, slope, dr, dc, _ = [float(v) for v in static_arr]
    last = dynamic_arr[-1]          # shape (6,): soil, rain, fcst, gauge, wind, baro
    soil_pct = float(last[0])
    rain_mm  = float(last[1])
    fcst_mm  = float(last[2])
    wind_kmh = float(last[4])
    baro_hpa = float(last[5])

    pf = float(np.clip(_physics_flood    (elev, soil_pct, rain_mm, fcst_mm, dr), 0, 1))
    pl = float(np.clip(_physics_landslide(slope, rain_mm, soil_pct, fcst_mm),   0, 1))
    pc = float(np.clip(_physics_cyclone  (wind_kmh, baro_hpa, dc),              0, 1))

    def resolve(phy, mdl, thr=0.45):
        phy_danger = phy >= thr
        mdl_danger = mdl >= 0.5
        if phy_danger == mdl_danger:
            return mdl                        # agree → trust model (richer signal)
        if not phy_danger and mdl_danger:
            return phy                        # physics says safe, model over-fires → use physics
        return float((phy + mdl) / 2.0)      # physics alarmed, model calm → split

    return resolve(pf, fp), resolve(pl, lp), resolve(pc, cp)


# ── Step 4: Human-readable risk factors ──────────────────────────────────
def risk_factors(static_arr, dynamic_arr, fp, lp, cp):
    elev, slope, dr, dc, _ = static_arr
    rain_mm = float(dynamic_arr[-1, 1])
    wind    = float(dynamic_arr[-1, 4])
    baro    = float(dynamic_arr[-1, 5])
    soil    = float(dynamic_arr[-1, 0])

    # Flood
    if elev < 50 and rain_mm > 60:
        f_why = "Low-lying terrain + heavy rainfall accumulation"
    elif elev < 100:
        f_why = "Coastal/alluvial low elevation increases runoff risk"
    elif rain_mm > 120:
        f_why = "High cumulative rainfall despite moderate terrain"
    elif rain_mm < 20 and elev > 800:
        f_why = "High elevation + dry conditions — minimal flood risk"
    else:
        f_why = f"Moderate elevation ({elev:.0f} m) with current rainfall"

    # Landslide
    if slope > 30 and soil > 55:
        l_why = "Steep terrain with saturated soil — high slide risk"
    elif slope > 20 and rain_mm > 80:
        l_why = "Hilly slopes + heavy rain — elevated slide potential"
    elif slope < 5:
        l_why = "Flat terrain — negligible landslide risk"
    else:
        l_why = f"Moderate gradient ({slope:.1f}°) — low-moderate risk"

    # Cyclone
    if dc < 80 and wind > 70:
        c_why = f"Exposed coastline ({dc:.0f} km) with elevated wind speeds"
    elif dc < 150 and baro > 8:
        c_why = "Coastal proximity + pressure drop detected"
    elif dc > 400:
        c_why = "Deep inland location — no cyclone pathway"
    else:
        c_why = f"Moderate coastal distance ({dc:.0f} km) — low risk"

    return {"flood": f_why, "landslide": l_why, "cyclone": c_why}


# ── Full prediction pipeline ──────────────────────────────────────────────
def run_prediction(lat: float, lon: float):
    meteo = fetch_real_data(lat, lon)

    static_raw, dynamic_raw = build_features(lat, lon, meteo)

    # Scale
    static_sc = static_scaler.transform(static_raw.reshape(1, -1))
    dyn_flat  = dynamic_scaler.transform(
                    dynamic_raw.reshape(-1, N_DYNAMIC_FEATURES))
    dyn_sc    = dyn_flat.reshape(1, SEQ_LEN, N_DYNAMIC_FEATURES)

    # LSTM → temporal vector (1, 64)
    temp_vec  = lstm_encoder.predict(dyn_sc, verbose=0)

    # XGBoost → raw probabilities
    X    = np.concatenate([static_sc, temp_vec], axis=-1)
    probs = [float(est.predict_proba(X)[0, 1]) for est in xgb_clf.estimators_]

    # Calibrate
    fp, lp, cp = physics_calibrate(static_raw, dynamic_raw,
                                   probs[0], probs[1], probs[2])

    factors = risk_factors(static_raw, dynamic_raw, fp, lp, cp)

    return round(fp, 3), round(lp, 3), round(cp, 3), factors, {
        "elevation_m": round(float(static_raw[0]), 1),
        "slope_deg":   round(float(static_raw[1]), 1),
        "dist_coast_km": round(float(static_raw[3]), 1),
        "rain_7day_mm":  round(float(sum(dynamic_raw[:, 1])), 1),
        "wind_max_kmh":  round(float(max(dynamic_raw[:, 4])), 1),
    }


def heuristic_prediction(lat: float, lon: float):
    """Fallback prediction used when model artifacts are unavailable."""
    dist_coast = _dist_coast(lat, lon)

    flood = 0.25 + (0.20 if dist_coast < 80 else 0.08)
    landslide = 0.20 + (0.18 if lat > 10.8 else 0.06)
    cyclone = 0.18 + (0.20 if dist_coast < 120 else 0.05)

    fp = max(0.05, min(0.85, flood))
    lp = max(0.05, min(0.85, landslide))
    cp = max(0.05, min(0.85, cyclone))

    factors = {
        "flood": "Fallback mode: coastal proximity estimate",
        "landslide": "Fallback mode: terrain/latitude estimate",
        "cyclone": "Fallback mode: coastal wind exposure estimate",
    }

    meta = {
        "elevation_m": None,
        "slope_deg": None,
        "dist_coast_km": round(float(dist_coast), 1),
        "rain_7day_mm": None,
        "wind_max_kmh": None,
        "fallback": True,
        "source": "heuristic",
    }

    return round(fp, 3), round(lp, 3), round(cp, 3), factors, meta


# ── REMEDIATION GENERATION ────────────────────────────────────────────────
def _get_risk_category(score: float) -> str:
    """Map numerical score to categorical risk level."""
    if score < 0.3:
        return "low"
    elif score < 0.5:
        return "moderate"
    else:
        return "high"


def generate_remediation(building_type: str, flood_risk: float, 
                        landslide_risk: float, cyclone_risk: float) -> dict:
    """
    Generates context-aware remediation strategies based on:
      • Building type (residential, commercial, industrial, agricultural, institutional)
      • Individual hazard risk scores
    
    Returns structured recommendations with priority and explainability.
    """
    if building_type not in ["residential", "commercial", "industrial", "institutional", "agricultural"]:
        building_type = "residential"
    
    recommendations = []
    summary_factors = []
    overall_severity = "low"
    
    # Flood recommendations
    flood_cat = _get_risk_category(flood_risk)
    if flood_risk > 0.2:
        flood_recs = REMEDIATION_DB.get("flood", {}).get(flood_cat, {}).get(building_type, [])
        if flood_recs:
            recommendations.extend([
                {
                    "hazard": "Flood",
                    "priority": 1 if flood_cat == "high" else 2 if flood_cat == "moderate" else 3,
                    "risk_score": round(flood_risk, 3),
                    "recommendation": rec,
                    "category": flood_cat,
                }
                for rec in flood_recs[:3]  # Top 3 recommendations
            ])
            summary_factors.append(f"Flood risk ({flood_cat}): {flood_risk:.1%}")
    
    # Landslide recommendations
    landslide_cat = _get_risk_category(landslide_risk)
    if landslide_risk > 0.2:
        landslide_recs = REMEDIATION_DB.get("landslide", {}).get(landslide_cat, {}).get(building_type, [])
        if landslide_recs:
            recommendations.extend([
                {
                    "hazard": "Landslide",
                    "priority": 1 if landslide_cat == "high" else 2 if landslide_cat == "moderate" else 3,
                    "risk_score": round(landslide_risk, 3),
                    "recommendation": rec,
                    "category": landslide_cat,
                }
                for rec in landslide_recs[:3]
            ])
            summary_factors.append(f"Landslide risk ({landslide_cat}): {landslide_risk:.1%}")
    
    # Cyclone recommendations
    cyclone_cat = _get_risk_category(cyclone_risk)
    if cyclone_risk > 0.2:
        cyclone_recs = REMEDIATION_DB.get("cyclone", {}).get(cyclone_cat, {}).get(building_type, [])
        if cyclone_recs:
            recommendations.extend([
                {
                    "hazard": "Cyclone",
                    "priority": 1 if cyclone_cat == "high" else 2 if cyclone_cat == "moderate" else 3,
                    "risk_score": round(cyclone_risk, 3),
                    "recommendation": rec,
                    "category": cyclone_cat,
                }
                for rec in cyclone_recs[:3]
            ])
            summary_factors.append(f"Cyclone risk ({cyclone_cat}): {cyclone_risk:.1%}")
    
    # Determine overall severity
    max_risk = max(flood_risk, landslide_risk, cyclone_risk)
    if max_risk > 0.6:
        overall_severity = "critical"
    elif max_risk > 0.4:
        overall_severity = "high"
    elif max_risk > 0.25:
        overall_severity = "moderate"
    
    # Sort by priority
    recommendations.sort(key=lambda x: (x["priority"], -x["risk_score"]))
    
    summary = f"Multi-hazard assessment for {building_type.upper()} building. " \
              f"Overall severity: {overall_severity.upper()}. " \
              f"Key factors: {', '.join(summary_factors) if summary_factors else 'Low multi-hazard risk'}. " \
              f"Implement top-priority recommendations immediately."
    
    return {
        "summary": summary,
        "overall_severity": overall_severity,
        "recommendations": recommendations[:12],  # Limit to 12 total recommendations
        "building_type": building_type,
        "risk_breakdown": {
            "flood": {"score": round(flood_risk, 3), "category": flood_cat},
            "landslide": {"score": round(landslide_risk, 3), "category": landslide_cat},
            "cyclone": {"score": round(cyclone_risk, 3), "category": cyclone_cat},
        }
    }


# ── REQUEST CACHING ──────────────────────────────────────────────────────
def _get_cache_key(lat: float, lon: float) -> str:
    """Generate cache key from coordinates (rounded to 0.01 precision)."""
    lat_rounded = round(lat, 2)
    lon_rounded = round(lon, 2)
    return f"{lat_rounded}_{lon_rounded}"


def _cache_get(key: str) -> dict | None:
    """Retrieve cached prediction if valid (not expired)."""
    with CACHE_LOCK:
        if key in PREDICTION_CACHE:
            cached_data, timestamp = PREDICTION_CACHE[key]
            if time.time() - timestamp < CACHE_TTL:
                return cached_data
            else:
                del PREDICTION_CACHE[key]
    return None


def _cache_set(key: str, data: dict) -> None:
    """Store prediction in cache with timestamp."""
    with CACHE_LOCK:
        PREDICTION_CACHE[key] = (data, time.time())
        # Optional: cleanup old entries if cache grows too large
        if len(PREDICTION_CACHE) > 1000:
            oldest_key = min(PREDICTION_CACHE.keys(), 
                            key=lambda k: PREDICTION_CACHE[k][1])
            del PREDICTION_CACHE[oldest_key]


# ── Flask routes ──────────────────────────────────────────────────────────
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/predict", methods=["POST"])
def predict():
    """Enhanced prediction endpoint with caching and better error handling."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body provided"}), 400
        
        lat  = float(data.get("lat", 0))
        lon  = float(data.get("lon", 0))
        name = data.get("name", "Selected Location")

        if not (6.5 <= lat <= 37.5 and 67.0 <= lon <= 98.0):
            return jsonify({"error": "Please select a location within India."}), 400

        # Check cache first
        cache_key = _get_cache_key(lat, lon)
        cached_result = _cache_get(cache_key)
        if cached_result:
            cached_result["cached"] = True
            return jsonify(cached_result), 200

        try:
            if MODELS_READY:
                fp, lp, cp, factors, meta = run_prediction(lat, lon)
            else:
                fp, lp, cp, factors, meta = heuristic_prediction(lat, lon)
        except requests.RequestException as e:
            return jsonify({"error": f"Weather API unavailable: {str(e)[:80]}"}), 503
        except Exception as e:
            return jsonify({"error": f"Prediction failed: {str(e)[:80]}"}), 500

        result = {
            "name":      name,
            "lat":       round(lat, 4),
            "lon":       round(lon, 4),
            "flood":     fp,
            "landslide": lp,
            "cyclone":   cp,
            "factors":   factors,
            "meta":      meta,
            "cached":    False,
            "timestamp": datetime.now().isoformat(),
        }
        
        # Cache the result
        _cache_set(cache_key, result)
        
        return jsonify(result), 200

    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Invalid request format: {str(e)[:80]}"}), 400
    except Exception as e:
        return jsonify({"error": f"Server error: {str(e)[:80]}"}), 500


@app.route("/remediation", methods=["POST"])
def remediation():
    """Generate remediation recommendations based on risks and building type."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body provided"}), 400
        
        building_type = data.get("building_type", "residential").lower()
        flood_risk = float(data.get("flood_risk", 0.2))
        landslide_risk = float(data.get("landslide_risk", 0.2))
        cyclone_risk = float(data.get("cyclone_risk", 0.1))
        
        # Clamp scores to [0, 1]
        flood_risk = max(0.0, min(1.0, flood_risk))
        landslide_risk = max(0.0, min(1.0, landslide_risk))
        cyclone_risk = max(0.0, min(1.0, cyclone_risk))
        
        remediation_result = generate_remediation(
            building_type, flood_risk, landslide_risk, cyclone_risk
        )
        
        return jsonify({
            "success": True,
            "data": remediation_result,
        }), 200
    
    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Invalid request format: {str(e)[:80]}"}), 400
    except Exception as e:
        return jsonify({"error": f"Server error: {str(e)[:80]}"}), 500


@app.route("/healthz", methods=["GET"])
def healthz():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "models_loaded": MODELS_READY,
        "timestamp": datetime.now().isoformat(),
    }), 200


@app.route("/risk-assessment", methods=["POST"])
def risk_assessment():
    """
    Quick risk assessment for a given location.
    Returns pre-computed risks without waiting for full prediction.
    Useful for map-based real-time analysis.
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body provided"}), 400
        
        lat  = float(data.get("lat", 0))
        lon  = float(data.get("lon", 0))
        building_type = data.get("building_type", "residential")
        
        if not (6.5 <= lat <= 37.5 and 67.0 <= lon <= 98.0):
            return jsonify({"error": "Location outside India boundary"}), 400
        
        # Check cache first for faster response
        cache_key = _get_cache_key(lat, lon)
        cached_result = _cache_get(cache_key)
        if cached_result:
            return jsonify({
                "success": True,
                "data": {
                    "latitude": lat,
                    "longitude": lon,
                    "flood_risk": cached_result.get("flood", 0.5),
                    "landslide_risk": cached_result.get("landslide", 0.5),
                    "cyclone_risk": cached_result.get("cyclone", 0.5),
                    "building_type": building_type,
                    "factors": cached_result.get("factors", {}),
                    "metadata": cached_result.get("meta", {}),
                    "cached": True,
                }
            }), 200
        
        # If not cached, run prediction (or fallback heuristic)
        try:
            if MODELS_READY:
                fp, lp, cp, factors, meta = run_prediction(lat, lon)
            else:
                fp, lp, cp, factors, meta = heuristic_prediction(lat, lon)
            result = {
                "success": True,
                "data": {
                    "latitude": lat,
                    "longitude": lon,
                    "flood_risk": fp,
                    "landslide_risk": lp,
                    "cyclone_risk": cp,
                    "building_type": building_type,
                    "factors": factors,
                    "metadata": meta,
                    "cached": False,
                    "timestamp": datetime.now().isoformat(),
                }
            }
            # Cache for next request
            prediction_cache = {
                "flood": fp,
                "landslide": lp,
                "cyclone": cp,
                "factors": factors,
                "meta": meta,
            }
            _cache_set(cache_key, prediction_cache)
            return jsonify(result), 200
        except requests.RequestException as e:
            return jsonify({"error": f"Weather API unavailable: {str(e)[:80]}"}), 503
        except Exception as e:
            return jsonify({"error": f"Risk assessment failed: {str(e)[:80]}"}), 500
    
    except (ValueError, TypeError) as e:
        return jsonify({"error": f"Invalid request format: {str(e)[:80]}"}), 400
    except Exception as e:
        return jsonify({"error": f"Server error: {str(e)[:80]}"}), 500


# ── ENTRY ─────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    has_models = os.path.exists(os.path.join(MODELS_DIR, "xgb_multi_clf.pkl"))
    if has_models:
        try:
            load_models()
            MODELS_READY = True
            print("[APP] Starting DisasterAI with ML models on http://127.0.0.1:5001")
        except Exception as e:
            MODELS_READY = False
            print(f"[APP] Model load failed, continuing in fallback mode: {e}")
    else:
        MODELS_READY = False
        print("[APP] Model artifacts missing, continuing in fallback mode.")

    print("[APP] Starting DisasterAI on http://127.0.0.1:5001")
    app.run(debug=False, host="127.0.0.1", port=5001)
