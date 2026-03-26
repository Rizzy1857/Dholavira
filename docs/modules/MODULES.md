# ECHO System Modules

Three-part stack for **battery-aware, delay-tolerant disaster communications**:

1. **Communication** — BLE/LoRa/Wi-Fi Direct mesh + store-and-forward + RSSI suppression.
2. **Battery Optimization** — power-aware message filtering, LoRa CAD duty cycling, cloud-side node prioritization.
3. **DRI_CA Location Intelligence** — location-based hazard feasibility, historic disaster proximity, and community awareness workflows.

## 1. Communication Layer

**Purpose**: Mesh relay of SOS messages across Layer 1–3 (phones, ESP32, vehicles) before reaching cloud.

**Key components**:

- **BLE store-and-forward** ("frog-jump"): phones relay messages in range.
- **LoRa TX/RX** (ESP32 sentinels): capture from BLE, forward via LoRa ~10 km.
- **Vehicle DTN**: LoRa mules vacuum packets, dump to cloud when internet returns.
- **RSSI suppression**: skip rebroadcast if signal already strong (redundant, saves power).

**Constraints**:

- Delay tolerant: seconds to minutes.
- Broadcast-storm safe: dedupe by `msg_id`, TTL hops.
- Works offline-first.

**Referenced in**: `README.md` (Layers 1–3), `ALLOCATION.md` (Layer 4 integration).

## 2. Battery Optimization Layer

**Purpose**: Extend device lifetime by intelligent message routing + duty cycling.

**Files**: `backend/src/battery_optimization.py`

### On-device (phone / ESP32)

```python
from backend.src.battery_optimization import BatteryOptimizer, PowerState

optimizer = BatteryOptimizer(device_id="esp32_001")
optimizer.set_battery(18)  # 18% battery

# Decide: should I rebroadcast this SOS?
should_fwd, reason = optimizer.should_forward_message(
    msg_id="abc123",
    priority=2.5,
    rssi_dbm=-65  # -65 dBm = moderate signal
)
# Result: False, "low_battery" (critical/low battery = don't relay non-critical)

# LoRa CAD duty cycle: sleep 2.9s, sniff 0.1s
cycle = optimizer.lora_cad_duty_cycle()
# -> 97% power savings vs always-listening
```

### Strategy

**Message forwarding filters** (priority + RSSI + power state):

- `CRITICAL battery` (<5%): only forward emergency SOS (priority >= 3.0).
- `LOW battery` (5–20%): forward if strong signal (RSSI strong) OR high priority.
- `MEDIUM battery` (20–60%): forward all with jittered delay.
- `GOOD battery` (>60%): forward all.

**LoRa CAD duty cycle**:

- Sleep 2.9s, sniff ~0.1s = **97% power savings**.
- Still catches incoming LoRa packets (CAD detects preamble during sniff).

**Message retention** (cache time):

- CRITICAL: 1 hour (expire cache quickly, save memory).
- LOW: 24 hours.
- GOOD: 7 days.

### Cloud-side (resource allocator)

```python
from backend.src.battery_optimization import CloudBatteryAwareTriage

cloud_triage = CloudBatteryAwareTriage()
cloud_triage.update_node_state("esp32_A", battery_pct=5, timestamp=now)

# Adjust allocation weight: low-battery node gets lower priority
weight = cloud_triage.priority_weight_for_node("esp32_A", base_weight=1.0)
# -> 0.2 (avoid routing critical supplies through)

# Adjust route cost: prefer routes avoiding critical nodes
cost = cloud_triage.route_energy_cost("route_1", node_battery_map)
# -> higher cost = less likely to use (planners avoid)
```

The cloud knows device battery state (sent in SOS or separate heartbeat); it deprioritizes nodes at risk, avoiding routing critical supplies through them.

## 3. DRI_CA Location Intelligence + Community Awareness Layer

**Purpose**: Convert location input into actionable risk context and citizen-facing awareness outputs.

**Files**:

- `backend/src/routes/feasibility.js`
- `backend/src/routes/zones.js`
- `backend/src/routes/alerts.js`
- `backend/src/routes/tips.js`
- `backend/src/routes/simplify.js`
- `backend/src/routes/translate.js`
- `backend/src/routes/remediation.js`

### Capabilities

- **Location feasibility**: checks flood, landslide, coastal, and seismic overlap for a coordinate.
- **Historic proximity**: finds nearby historic disaster events around the queried location.
- **Community alerts**: supports local incident reporting and verification workflows.
- **Awareness delivery**: publishes seasonal preparedness tips and simplified multilingual guidance.

### Core APIs

- `POST /api/v1/feasibility` — location risk + historic proximity output.
- `GET /api/v1/zones/*` — hazard zone GeoJSON + stats.
- `POST /api/v1/alerts` and `GET /api/v1/alerts` — create/list community alerts.
- `GET /api/v1/tips/current` — current seasonal guidance.

## Integration: Communication + Battery + DRI_CA

### Typical flow

1. **Phone user in disaster zone** sends SOS with location and battery.
2. **Mesh + LoRa path** forwards the message to the cloud ingest endpoint.
3. **Core backend** validates and persists incoming disaster telemetry.
4. **DRI_CA feasibility service** evaluates location hazard overlap and historic event proximity.
5. **Community module** publishes/filters localized alerts and awareness tips for that district.
6. **Language support** simplifies and translates critical advisories for wider accessibility.

### Real-world scenario

**Flood rise near Aluva:**

- Residents report water rise through `/api/v1/alerts`.
- Coordinator runs `/api/v1/feasibility` for nearby shelters and roads.
- API returns flood-risk hits and nearby historic flood incidents.
- Verified alerts + seasonal monsoon tips are pushed in simplified local language.

## Modules summary

| Module | File | Purpose | Input | Output |
| --- | --- | --- | --- | --- |
| Communication | `README.md` (Layers 1–3) | BLE/LoRa mesh relay | Phone SOS | Packets relayed Layer 1→4 |
| Battery Opt | `backend/src/battery_optimization.py` | Power-aware filtering + duty cycling | Battery %, priority, RSSI | Forward decision, retention time, CAD cycle |
| DRI_CA | `backend/src/routes/*.js` + `backend/src/services/*.js` | Location risk, historic proximity, awareness | Coordinates, district, alert input | Risk profile, historic events, localized alerts/tips |

## Deployment checklist

- [ ] Phone/edge path is sending validated location + battery metadata.
- [ ] Core backend ingest (`/v1/ingest/sos`) is healthy and storing telemetry.
- [ ] DRI_CA database seeds (`DRI_CA/database/init/*.sql`) are loaded.
- [ ] DRI_CA APIs (`/api/v1/feasibility`, `/api/v1/alerts`, `/api/v1/tips`) return expected data.
- [ ] Operator/client view consumes DRI_CA outputs for local awareness updates.

---

See `backend/README.md`, `docs/DRI_CA_SERVER.md`, `quickstart.md`, and `README.md` for detailed integration steps.
