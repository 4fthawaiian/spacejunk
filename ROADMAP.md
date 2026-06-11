# SpaceJunk Roadmap

## ✨ Done
- [x] 3D orbital visualization with CustomPainter + perspective projection
- [x] Procedural debris generation (~15,800 particles in LEO/MEO/GEO/Debris/Station shells)
- [x] Interactive controls (drag to orbit, pinch to zoom, auto-rotation)
- [x] Live data from CelesTrak JSON API (TLE orbital elements)
- [x] SGP4 orbital propagator ported to Dart (km output fixed)
- [x] Color-coded shells + orbital reference rings (equatorial + inclined)
- [x] Stats HUD with per-shell object counts (including Station)
- [x] Filter panel with per-shell CupertinoSwitch toggles, contextual help, starfield toggle
- [x] Quick-access pill toggles on main screen (left side)
- [x] Historical time scrubber slider (-1 year to +1 year) with play/pause
- [x] Tap popup info cards showing object name, shell, altitude, data source
- [x] Station markers drawn on top of Earth — gold ring + crosshair + white center
- [x] Info dialog (ⓘ) — explains app concept, orbital shells, data sources, scale
- [x] CORS proxy fallback for web builds
- [x] Android release build (network permissions + cleartext traffic enabled)
- [x] Android deployment (Impeller/Vulkan renderer)
- [x] Rocket body support — CelesTrak data ingestion, orange coloring, shell mapping
- [x] Rocket body toggle — quick-access pill + filter-sheet row with live CupertinoSwitch
- [x] Rocket body counter — per-shell object counts extended to Rocket-Body shell
- [x] Rocket body legend entry — dot + label on the right-side legend
- [x] Reactive filter sheet — `_FilterSheet` converted to `StatefulWidget` with local state for instant toggle feedback
- [x] Render order fix — debris particles drawn on top of Earth so objects don't disappear behind the planet
- [x] Multi-proxy CORS fallback chain for web reliability (corsproxy.io, allorigins.win, corsproxy.org)
- [x] WebAssembly/CanvasKit build support (`flutter build web --wasm`)
- [x] Live site at https://junk.4ft.me — nginx vhost, Let's Encrypt SSL, SPA routing
- [x] Auto-deploy pipeline — GitHub Action builds web + rsyncs to server on every push to main
- [x] Desktop/tablet UI scaling — 150% zoom via SizedBox + MediaQuery + Transform.scale on screens >=600px
- [x] Mouse wheel / trackpad scroll zoom for desktop web — scroll up zooms in, down zooms out
- [x] Constellation filtering — identify satellites by group (Starlink, OneWeb, GPS, Iridium, etc.) with per-group toggles, counts, and isolation mode
- [x] URL query parameter support — `?constellations=starlink,gps&hideShells=Debris&zoom=1.5&time=-30` for screenshot/embed/social previews
- [x] Self-hosted TLE cache priority — cache-first fetch with SATCAT enrichment, CelesTrak direct as fallback


## 🚧 Cooldown (CelesTrak rate-limit, ~2026-06-11 to 06-13)
- Server IP blocked by CelesTrak — no TLE fetches from prod until it lifts
- Cache static at 15,834 objects (12MB, all SATCAT-enriched) — fresh enough for 48h
- Cron at 30min hammered CelesTrak — lesson learned: use 6h interval going forward
- GH Action TLE fetch disabled (`if: false`) during cooldown
- $0.26 DO droplet used for one-off full-cache grab — documented in AGENTS.md
- `--exclude=api/` added to all rsync commands to protect prod cache

### To re-enable after cooldown
- Re-enable cron on server.4ft.me with 6h interval (not 30min!)
- Un-skip the TLE fetch step in `.github/workflows/deploy-web.yml`
- Remove `--exclude=api/` from GH Action rsync (or keep it, cache pushes via separate scp)

## 🎯 Up Next

### Polish & UX
- [ ] Orbital trails — draw faint paths behind objects to show orbit shapes
- [ ] Speed controls — slow down / speed up auto-rotation
- [ ] True blackout mode for OLED screens
- [ ] Animated transitions when toggling filter shells
- [ ] Remove "Data source" row from popup info cards (always CelesTrak for live data)

### Data & Reality
- [x] Full catalog — 15,834 tracked objects across 14 CelesTrak groups (cache-first priority)
- [x] Periodic auto-refresh — server cron refreshes cached TLE snapshot (disabled during cooldown, 6h interval when re-enabled)
- [x] Self-hosted TLE cache — build-time snapshot + nginx proxy with stale-while-revalidate
- [x] Multi-source fallback chain (cache-first → Celestrak → procedural)
- [x] Concurrent group fetching — groups tried in parallel for fast fallback (~15s max)
- [x] Platform-aware data fetching — cache skipped on mobile (where /api/tle.json doesn't apply)
- [x] Removed invalid "rocket-body" CelesTrak group
- [x] SATCAT metadata enrichment — country flags, launch dates, object types, RCS, decay info
- [x] Fixed type error in SATCAT RCS parsing (empty string → null)
- [x] `--exclude=api/` everywhere — protects prod cache from rsync --delete nuking it
- [x] Test site nginx — added /api/tle.json location block
- [x] gh-pages deploy script patched — --exclude=api/ added
- [ ] Collision event overlays — mark known historical satellite collisions
- [ ] Distinguish live tracked objects from procedural in the view

### Performance
- [ ] GPU batching for higher particle counts
- [ ] LOD (level of detail) — fewer particles when zoomed out

### Future Ideas
- [ ] Satellite orbit paths (TLE-based ground tracks)
- [ ] Real collision risk indicators (conjunction warnings)
- [ ] Megaconstellation visualization (Starlink, OneWeb, Kuiper) — constellation filtering partially covers this; dedicated orbit paths / shell highlighting still TBD
- [ ] Spacecraft debris avoidance maneuvers
- [ ] Kessler syndrome simulation (cascade effect)

### Filtering & Discovery
- [ ] Filtering UI — filter debris cloud by country of origin, object type (payload/rocket body/debris), RCS range, launch date range
- [ ] Batch SATCAT pre-fetch — load SATCAT for all visible NORAD IDs at GP-fetch time to enable instant filtering

### Infrastructure & Ops
- [x] Bundle favicon/apple-touch-icon for site — new flame favicon + PWA icons + maskable variants
- [x] Custom app icon design extracted from artwork and deployed to Android & web
- [x] Multi-platform icon set — Android (5 densities), web (favicon, PWA 192/512, maskable), apple-touch-icon
- [x] Add `spacejunk.4ft.me` sitemap / SEO meta
- [x] Self-hosted TLE cache — nginx proxy_cache to Celestrak with stale-while-revalidate
- [x] Server cron — Python script fetches + deduplicates TLE groups every 30 min
- [x] CI build-time TLE snapshot — `scripts/fetch-tle.mjs` bundles data with every deploy
- [ ] WASM build via GitHub Action for better perf
- [ ] Health check endpoint monitoring
- [ ] Staging branch with preview deploys
