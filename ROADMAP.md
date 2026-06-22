# SpaceJunk Roadmap

## ✨ Done

- [x] 3D orbital visualization with CustomPainter + perspective projection
- [x] Zoom-dependent object sizing — debris dots and station markers now physically grow as you zoom in, making selection much easier at high zoom levels (relativeZoom multiplier, tap threshold scales proportionally)
- [x] Procedural debris generation (~15,800 particles in LEO/MEO/GEO/Debris/Station shells)
- [x] Interactive controls (drag to orbit, pinch to zoom, auto-rotation)
- [x] Live data from CelesTrak JSON API (TLE orbital elements)
- [x] SGP4 orbital propagator ported to Dart (km output fixed)
- [x] Color-coded shells + orbital reference rings (equatorial + inclined)
- [x] Stats HUD with per-shell object counts (including Station)
- [x] Filter panel with per-shell CupertinoSwitch toggles, contextual help, starfield toggle
- [x] Quick-access pill toggles on main screen (left side)
- [x] Historical time scrubber slider (-10 years to +10 years) with play/pause
- [x] Launch-year-aware filtering — objects not yet launched hidden when scrubbing into the past, with visible count in UI
- [x] Launch year metadata — populated from SATCAT (live) and weighted historical distribution (procedural), shown in tap popup
- [x] Decade filter chips (60s→20s) inline in time panel — instant "show me what orbit looked like in the [X] decade"; stacks with all other filters
- [x] Visual snapshot testing — Playwright + pixelmatch with 10 scenarios, reference baselines committed, CI-compatible
- [x] Tap popup info cards showing object name, shell, altitude, data source
- [x] Station markers drawn on top of Earth — refined diamond marker with subtle glow + white center
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
- [x] Desktop/tablet UI scaling — 150% zoom via SizedBox + MediaQuery + Transform.scale on screens >=600px (fixed: uses shortestSide to avoid scaling on phones in landscape)
- [x] Mouse wheel / trackpad scroll zoom for desktop web — scroll up zooms in, down zooms out
- [x] Constellation filtering — identify satellites by group (Starlink, OneWeb, GPS, Iridium, etc.) with per-group toggles, counts, and isolation mode
- [x] URL query parameter support — `?constellations=starlink,gps&hideShells=Debris&zoom=1.5&time=-30` for screenshot/embed/social previews
- [x] Shareable view links — top-level share button builds canonical web URLs from current filters, zoom, and time; Android opens the native share sheet
- [x] Self-hosted TLE cache priority — cache-first fetch with SATCAT enrichment, CelesTrak direct as fallback
- [x] Self-hosted TLE cache — build-time snapshot + nginx proxy with stale-while-revalidate
- [x] Multi-source fallback chain (cache-first → Celestrak → procedural)
- [x] Concurrent group fetching — groups tried in parallel for fast fallback (~15s max)
- [x] Platform-aware data fetching — cache skipped on mobile (where /api/tle.json doesn't apply)
- [x] Self-hosted cache enabled on mobile — absolute URL fetch with SATCAT enrichment
- [x] Country-of-origin filter — dedicated 🌍 button + searchable picker, isolates by SATCAT owner, stacks with shell + constellation filters, URL `?countries=US,PRC`
- [x] Objects without country data hidden when country filter active (clean isolation)
- [x] Share links use dynamic origin — works on test.4ft.me, spacejunk.4ft.me, localhost alike
- [x] Removed invalid "rocket-body" CelesTrak group
- [x] SATCAT metadata enrichment — country flags, launch dates, object types, RCS, decay info
- [x] Fixed type error in SATCAT RCS parsing (empty string → null)
- [x] `--exclude=api/` everywhere — protects prod cache from rsync --delete nuking it
- [x] Test site nginx — added /api/tle.json location block
- [x] gh-pages deploy script patched — --exclude=api/ added
- [x] Auto-show info panel on first visit (SharedPreferences)
- [x] Empty-cache safety guard in `server/fetch-tle.py` — preserves existing valid cache when a fetch returns zero objects (e.g. during rate-limiting) instead of overwriting with empty array
- [x] Reset Filters button under left-side shell pills
- [x] Particle names displaying in tap popup (SATCAT name priority)
- [x] `hasSeenInfo` flag persists after showing info dialog
- [x] Refined station diamond marker (subtle glow + white center)
- [x] `--exclude=api/` added to gh-pages deploy script

## ✅ CelesTrak Rate-Limiting (Resolved)

- Cooldown lasted ~2026-06-11 to 06-13 — server IP was blocked after 30min polling
- Resolution: cron reduced to 6h intervals (not 30min!), `--exclude=api/` everywhere, DO droplet workaround documented
- Current state: server cron at `/etc/cron.d/spacejunk-tle` runs every 6 hours; GH Action still skips TLE fetch (`if: false`) since the server's cache handles it fine
- `fetch-tle.py` now has a safety guard against rate-limited empty overwrites

## 🎯 Up Next

### Quality
- [ ] Update snapshot baselines to cover decade filter and extended time slider

### Polish & UX
- [ ] Orbital trails — draw faint paths behind objects to show orbit shapes
- [ ] Speed controls — slow down / speed up auto-rotation
- [ ] True blackout mode for OLED screens
- [ ] Animated transitions when toggling filter shells
- [ ] Remove "Data source" row from popup info cards (always CelesTrak for live data)

### Data & Reality
- [ ] Collision event overlays — mark known historical satellite collisions
- [ ] Distinguish live tracked objects from procedural in the view (e.g. different particle style/glow)

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
- [ ] Batch SATCAT pre-fetch — load SATCAT for all visible NORAD IDs at GP-fetch time to enable instant filtering

### Infrastructure & Ops
- [ ] WASM build via GitHub Action for better perf
- [ ] Health check endpoint monitoring
- [ ] Staging branch with preview deploys
- [ ] Re-enable CI TLE fetch in deploy workflow (currently `if: false` since cooldown; server cache handles it but CI build-time snapshot would improve mobile cold-start)
