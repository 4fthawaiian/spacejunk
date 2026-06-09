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

## 🎯 Up Next

### Polish & UX
- [ ] Orbital trails — draw faint paths behind objects to show orbit shapes
- [ ] Speed controls — slow down / speed up auto-rotation
- [ ] True blackout mode for OLED screens
- [ ] Animated transitions when toggling filter shells

### Data & Reality
- [ ] Full catalog — add more CelesTrak groups for thousands more tracked objects
- [ ] Periodic auto-refresh — re-fetch live data every 30 min automatically
- [ ] Collision event overlays — mark known historical satellite collisions
- [ ] Distinguish live tracked objects from procedural in the view

### Performance
- [ ] GPU batching for higher particle counts
- [ ] LOD (level of detail) — fewer particles when zoomed out

### Future Ideas
- [ ] Satellite orbit paths (TLE-based ground tracks)
- [ ] Real collision risk indicators (conjunction warnings)
- [ ] Megaconstellation visualization (Starlink, OneWeb, Kuiper)
- [ ] Spacecraft debris avoidance maneuvers
- [ ] Kessler syndrome simulation (cascade effect)
