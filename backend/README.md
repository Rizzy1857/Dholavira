# Backend (Echo/Adrishya)

Unified Node.js/Express backend with three integrated modules for disaster communications.

## Modules

### Module 1: Communication (SOS Ingest)
- **Endpoint:** `POST /v1/ingest/sos`
- **Files:** Core in `src/index.mjs`
- **Purpose:** Ingest signed SOS messages from field devices

### Module 2: Battery Optimization
- **Endpoints:** `GET /v1/device/battery/:device_id`, `/v1/optimize/config`, `POST /v1/stats/battery/record`
- **Files:** `src/batteryManager.mjs`
- **Purpose:** Track device power state and provide optimization config to Flutter apps

### Module 3: DRI_CA (Location Intelligence + Community Awareness)
- **Routes:** `/api/v1/{feasibility,zones,remediation,alerts,tips,simplify,translate}`
- **Files:** `src/routes/*.js`, `src/services/*.js`, `src/config/*.js`, `src/middleware/*.js`, `src/utils/*.js`
- **Database:** `db/*.sql` (PostGIS schema + seeds)
- **Purpose:** Location-based hazard checks, community alerts, and disaster preparedness

## Quick Start

```bash
npm install
npm run dev
```

Server runs on `http://localhost:3000` (or `$PORT`).

## Environment

Create `.env`:
```
DATABASE_URL=postgresql://user:pass@localhost:5432/dholevira
PORT=3000
CORS_ORIGIN=http://localhost:3000,http://localhost:4000
BHASHINI_USER_ID=your_bhashini_user_id
BHASHINI_API_KEY=your_bhashini_api_key
```

## Database Setup

```bash
# PostgreSQL + PostGIS
psql -U postgres -c "CREATE DATABASE dholevira;"
psql -U postgres -d dholevira -f db/001_schema.sql
psql -U postgres -d dholevira -f db/002_alerts.sql
psql -U postgres -d dholevira -f db/003_historic_disasters.sql
psql -U postgres -d dholevira -f db/004_expanded_zones.sql
```

## Project Structure

```
backend/
├── src/
│   ├── index.mjs              # Main Express app + Module 1 endpoints
│   ├── db.mjs                 # Database pool (ESM)
│   ├── batteryManager.mjs     # Module 2: Battery optimization
│   ├── allocationWrapper.mjs  # Resource allocation v2 bridge
│   ├── ed25519.mjs            # Signature verification
│   ├── logger.mjs             # Structured logging
│   ├── sosPayloadV1.mjs       # SOS binary protocol
│   ├── send_sos.mjs           # SOS test sender
│   ├── config/
│   │   ├── db.js              # Database connection pool (ESM)
│   │   ├── constants.js       # Enums and constants
│   │   └── ... (other DRI_CA configs)
│   ├── middleware/
│   │   ├── errorHandler.js    # Centralized error handling
│   │   ├── validate.js        # Request schema validation
│   │   ├── rateLimiter.js     # Rate limiting
│   │   └── ... (other middleware)
│   ├── routes/                # Module 3: DRI_CA Route Handlers
│   │   ├── feasibility.js
│   │   ├── zones.js
│   │   ├── remediation.js
│   │   ├── alerts.js
│   │   ├── tips.js
│   │   ├── simplify.js
│   │   └── translate.js
│   ├── services/              # Module 3: Business Logic
│   │   ├── xaiEngine.js       # Explainable AI for remediation
│   │   ├── bhashiniClient.js  # Translation/TTS integration
│   │   ├── simplifier.js      # Domain glossary
│   │   └── seasonalTips.js    # Seasonal guidance
│   └── utils/
│       ├── apiResponse.js     # Standardized JSON responses
│       └── logger.js          # Logging utilities
├── db/
│   ├── 001_schema.sql         # Core tables
│   ├── 002_alerts.sql         # Community alerts schema
│   ├── 003_historic_disasters.sql  # Historic events
│   ├── 004_expanded_zones.sql      # Hazard zones (flood, landslide, etc.)
│   └── schema.sql             # Reference schema
├── scripts/
│   ├── migrate.mjs            # Database migration runner
│   ├── show_logs.mjs          # Log viewer
│   └── proof.mjs              # Signature proof utility
├── test/
│   ├── allocation-v2.test.mjs
│   ├── battery-endpoints.test.mjs
│   └── unit.test.mjs
├── package.json               # Dependencies
└── README.md                  # This file
```

## API Endpoints

### Module 1: SOS Ingest
- `POST /v1/ingest/sos` — Ingest signed SOS messages

### Module 2: Battery
- `GET /v1/device/battery/:device_id` — Device battery state
- `GET /v1/optimize/config` — Battery optimization config
- `POST /v1/stats/battery/record` — Record battery stats

### Module 3: DRI_CA
- `POST /api/v1/feasibility` — Check location hazard + historic proximity
- `GET /api/v1/zones/{flood,landslide,coastal,seismic}` — Zone data
- `POST /api/v1/remediation` — Generate XAI recommendations
- `POST /api/v1/alerts` — Create community alert
- `GET /api/v1/alerts` — List alerts
- `GET /api/v1/tips/{current,:season}` — Seasonal guidance
- `POST /api/v1/simplify` — Simplify jargon
- `POST /api/v1/translate` — Translate text
- `POST /api/v1/translate/tts` — Text-to-speech

## Testing

```bash
npm test                    # Run all tests
npm test allocation-v2      # Allocation tests only
```

## Documentation

- **Full API docs:** See `/docs/` folder
- **DRI_CA API Guide:** `docs/DRI_CA_SERVER.md`
- **Database setup:** `docs/DRI_CA_DATABASE.md`
- **Modules overview:** `docs/modules/MODULES.md`
