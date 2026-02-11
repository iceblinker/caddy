# Troubleshooting & System Documentation

This document tracks known issues, fixes, and configuration details for the iceblinker.vip infrastructure.

---

## 🔌 Port Mappings

### Active Services (docker-compose.addons.yml)

| Service | Container Port | External Port | Protocol | Notes |
|---------|---------------|---------------|----------|-------|
| **jackett** | 9117 | - | HTTP | Torrent indexer |
| **redis** | 6379 | - | TCP | Cache for AIOStreams |
| **cors-anywhere** | 8080 | - | HTTP | CORS proxy |
| **aiostreams** | 3000 | - | HTTP | Python/FastAPI (uvicorn) |
| **mediaflow-proxy** | 8888 | - | HTTP | Media proxy |
| **comet** | 8000 | - | HTTP | Torrent addon |
| **sootio** | 3000 | - | HTTP | Node.js addon |
| **sootio-db** | 5432 | - | PostgreSQL | Database |
| **corsario** | 8001 | - | HTTP | Torrent addon |
| **corsario-db** | 5432 | - | PostgreSQL | Database |
| **leviathan** | 7000 | 7001 | HTTP | Stremio addon |
| **vixsrc-addon** | 3003 | - | HTTP | Node.js/Express catalog addon |

### Caddy Routing

| Subdomain | Backend | Port | Status |
|-----------|---------|------|--------|
| `mediaflow.iceblinker.vip` | mediaflow-proxy | 8888 | ✅ Active |
| `jackett.iceblinker.vip` | jackett | 9117 | ✅ Active |
| `cors.iceblinker.vip` | cors-anywhere | 8080 | ✅ Active |
| `aiostreams.iceblinker.vip` | aiostreams | 3000 | ✅ Active |
| `catalogs.iceblinker.vip` | vixsrc-addon | 3003 | ✅ Active |
| `leviathan.iceblinker.vip` | leviathan | 7000 | ✅ Active |
| `comet.iceblinker.vip` | comet | 8000 | ✅ Active |
| `sootio.iceblinker.vip` | sootio | 3000 | ✅ Active |
| `corsario.iceblinker.vip` | corsario | 8001 | ✅ Active |

---

## 🐛 Known Issues & Fixes

### Issue #1: VixSrc 503 Service Unavailable & Empty Catalogs (Feb 2026)

**Symptom:**
- Intermittent 503 errors when accessing `catalogs.iceblinker.vip`
- Some requests returned 404 with `uvicorn` headers instead of `Express`
- Caddy container crash-looping with syntax errors
- Catalogs returning empty `{"metas":[]}` even when service was responding

**Root Causes:**
1. **Docker DNS conflict**: Three services were using **port 3000** on the same network (`caddy_net`):
   - `aiostreams` (Python/uvicorn)
   - `sootio` (Node.js)
   - `vixsrc-addon` (Node.js/Express)
   
   When Caddy tried to resolve `vixsrc-addon:3000`, Docker's DNS sometimes returned the wrong container's IP.

2. **Caddy syntax error**: Attempted to use `health_status 2xx 404` to accept both 200 and 404 responses, but Caddy v2.9 doesn't support multiple status codes in this format, causing container crash loops.

3. **Missing database mount**: Database file `catalog.db` exists on VPS at `~/catalogs-vixsrc/catalog.db` but wasn't mounted into the container, causing empty catalog responses.

**Fix:**
1. Changed `vixsrc-addon` port from `3000` → `3003` to eliminate DNS conflict
2. Updated `Caddyfile` reverse proxy: `vixsrc-addon:3000` → `vixsrc-addon:3003`
3. Fixed Caddy syntax: Changed `health_status 2xx 404` → `health_status 2xx`
4. Rebuilt Caddy container with corrected Caddyfile
5. Added volume mount: `~/catalogs-vixsrc/catalog.db:/app/catalog.db` to `docker-compose.addons.yml`
6. Redeployed vixsrc-addon container with database access

**Commits:** 
- `b119380` - Port change (Feb 11, 2026)
- `f4474cc` - Caddy syntax fix (Feb 11, 2026)
- `a8d334f` - Database mount (Feb 11, 2026)

**Result:** ✅ Fully Resolved
- Service returns 200 OK
- Requests correctly routed to vixsrc-addon Express server
- Catalogs populated with full movie/series metadata

**Prevention:**
- Always use unique ports for services on the same network
- Test Caddy configuration syntax before deploying (`caddy validate`)
- Ensure database files/volumes are mounted before first deployment
- Document port assignments in this file before deploying new services

---

### Issue #2: AIOStreams 502 Bad Gateway

**Symptom:**
- AIOStreams returning 502 errors on startup

**Root Cause:**
- Missing Redis dependency in `docker-compose.addons.yml`
- AIOStreams requires Redis for caching but container wasn't defined

**Fix:**
1. Added Redis service to `docker-compose.addons.yml`
2. Redeployed stack

**Status:** ✅ Resolved

---

### Issue #3: CORS Errors on Stremio Addons

**Symptom:**
- Stremio Web unable to load addon manifests
- Browser console showing CORS policy errors

**Root Cause:**
- Missing CORS headers or duplicate CORS headers from multiple sources

**Fix:**
1. Deployed `cors-anywhere` proxy service (testcab/cors-anywhere:latest)
2. Added Caddy configuration for `cors.iceblinker.vip`
3. Whitelisted domains: `iceblinker.vip`, `stremio.com`, `web.stremio.com`

**Usage:**
Prefix addon URLs with CORS proxy:
```
https://cors.iceblinker.vip/https://comet.iceblinker.vip/manifest.json
```

**Status:** ✅ Resolved

---

### Issue #4: Caddy Version Instability

**Symptom:**
- Potential breaking changes from using `caddy:latest` tag

**Fix:**
1. Pinned Caddy to specific version `2.9` in `Dockerfile.caddy`
2. Changed base images:
   - `caddy:builder` → `caddy:2.9-builder`
   - `caddy:latest` → `caddy:2.9-alpine`

**Status:** ✅ Resolved

---

## ⚙️ System Architecture Notes

### Docker Networks

- **caddy_net**: Main network for Caddy and all web-facing services
- **ai_network**: Shared network for services requiring inter-communication

### Health Checks

Caddy performs active health checks on backend services:
- **Interval:** 10s
- **Timeout:** 2s
- **Expected Status:** `2xx` (some services also allow `404`)

If a service fails health checks, Caddy marks it as "down" and returns 503 to clients.

### Service Dependencies

```
aiostreams
├── redis (cache)
├── mediaflow-proxy (streaming)
└── comet (self-hosted addon)

sootio
├── sootio-db (PostgreSQL)
├── gluetun (FlareSolverr proxy)
└── jackett (indexer)

corsario
└── corsario-db (PostgreSQL)

vixsrc-addon
└── (standalone, file-based database)
```

---

## 📋 Maintenance Checklist

### Before Deploying New Services

- [ ] Check port availability (see Port Mappings table)
- [ ] Verify network assignments (`caddy_net`, `ai_network`)
- [ ] Add health check configuration
- [ ] Update this documentation
- [ ] Test with `docker-compose config` before deploying

### Regular Maintenance

- [ ] Monitor Caddy logs: `docker logs caddy --tail 50`
- [ ] Check service health: `docker ps`
- [ ] Verify disk space: `df -h`
- [ ] Review health check status in Caddy logs
- [ ] Update Caddy and service images monthly

---

## 🔍 Debugging Commands

### Check Service Logs
```bash
docker logs --tail 50 <service-name>
docker logs --follow <service-name>
```

### Inspect Caddy Configuration
```bash
docker exec caddy caddy config
docker exec -w /etc/caddy caddy caddy fmt --overwrite
```

### Test DNS Resolution (Inside Docker Network)
```bash
docker exec <container> nslookup <service-name>
docker exec caddy ping -c 3 vixsrc-addon
```

### Restart Services
```bash
cd ~/caddy
docker-compose -f docker-compose.addons.yml restart <service-name>
docker exec -w /etc/caddy caddy caddy reload
```

### View Active Connections
```bash
docker network inspect caddy_net
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## 📝 Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-02-11 | VixSrc port: 3000 → 3003 | Resolve Docker DNS conflict |
| 2026-02-11 | Caddy: latest → 2.9 | Pin version for stability |
| 2026-02-11 | Added CORS proxy service | Fix Stremio addon CORS errors |
| 2026-02-11 | Added Redis service | AIOStreams dependency |

---

**Last Updated:** February 11, 2026
