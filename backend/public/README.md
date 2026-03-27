# Dholavira Web App (Browser-First)

This is a single-page web dashboard that replaces the Flutter client for local operation.

## Modules

- SOS (`/v1/sos/panic`, `/v1/sos/recent`)
- Build Safe (`/api/v1/ai/risk-assessment`, `/api/v1/ai/remediation`)
- Alerts (`/api/v1/alerts`)
- Tips (`/api/v1/tips/current`)
- AI View (embedded iframe to `http://<host>:5001`)

## Run

Start everything from repo root:

```bash
./run_all.sh
```

Open:

- `http://127.0.0.1:3000/`

## Notes

- The dashboard uses backend-relative API calls, so no extra frontend dev server is needed.
- If AI service is unavailable, backend fallback responses are shown where supported.
