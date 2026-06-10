# TRASHMAP Roadmap

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


## 🎯 Up Next

### Polish & UX
- [ ] Orbital trails — draw faint paths behind objects to show orbit shapes
- [ ] Speed controls — slow down / speed up auto-rotation
- [ ] True blackout mode for OLED screens
- [ ] Animated transitions when toggling filter shells
- [ ] Remove "Data source" row from popup info cards (always CelesTrak for live data)

### Data & Reality
- [ ] Full catalog — add more CelesTrak groups for thousands more tracked objects
- [ ] Periodic auto-refresh — re-fetch live data every 30 min automatically
- [ ] Collision event overlays — mark known historical satellite collisions
- [ ] Distinguish live tracked objects from procedural in the view
- [ ] SATCAT metadata enrichment — country flags, launch dates, object types, RCS, decay info on tap popup (branch: satcat-enrichment)

### Performance
- [ ] GPU batching for higher particle counts
- [ ] LOD (level of detail) — fewer particles when zoomed out

### Future Ideas
- [ ] Satellite orbit paths (TLE-based ground tracks)
- [ ] Real collision risk indicators (conjunction warnings)
- [ ] Megaconstellation visualization (Starlink, OneWeb, Kuiper)
- [ ] Spacecraft debris avoidance maneuvers
- [ ] Kessler syndrome simulation (cascade effect)

### Infrastructure & Ops
- [x] Bundle favicon/apple-touch-icon for site — new flame favicon + PWA icons + maskable variants
- [x] Custom app icon design extracted from artwork and deployed to Android & web
- [x] Multi-platform icon set — Android (5 densities), web (favicon, PWA 192/512, maskable), apple-touch-icon
- [ ] Add `junk.4ft.me` sitemap / SEO meta
- [ ] WASM build via GitHub Action for better perf
- [ ] Health check endpoint monitoring
- [ ] Staging branch with preview deploys
