<p align="center">
  <img alt="TrashMap — 3D space debris visualization" src="screenshot.png" width="100%">
</p>

<p align="center">
  <b>Interactive 3D visualization of space debris orbiting Earth</b><br>
  Built with Flutter • Live data from CelesTrak • SGP4 orbital propagation
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20%7C%20Web-brightgreen?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square">
  <img alt="Debris count" src="https://img.shields.io/badge/particles-~15,800-orange?style=flat-square">
</p>

---

TrashMap renders the orbital debris environment around Earth in real-time 3D. Hundreds of thousands of human-made objects — defunct satellites, rocket bodies, collision fragments, and active spacecraft — orbit our planet at speeds up to 28,000 km/h. This app visualises them all in a single interactive view.

## ✨ Features

- **3D orbital view** — drag to orbit, pinch to zoom, auto-rotation with gyroscopic feel
- **Live tracked objects** — fetches current TLE data from [CelesTrak](https://celestrak.org), propagated via SGP4
- **Procedural debris** — ~4,000 simulated untracked fragments supplement live data for a complete picture
- **Orbital shells** — colour-coded layers: LEO (orange), MEO (yellow), GEO (cyan), Debris (red), Station (gold)
- **Reference rings** — equatorial and inclined rings at 400 km, 20,200 km, 35,786 km
- **Tap popups** — tap any object to see its name, shell, altitude, and data source
- **Historical scrubber** — slide through time (±1 year) with play/pause to watch orbital evolution
- **Filter panel** — toggle individual shells, show/hide starfield, all with tactile Cupertino-style switches
- **Quick-access pills** — one-tap shell toggles anchored to the left of the viewport
- **Station markers** — gold crosshair+ring markers for crewed outposts (ISS, Tiangong)
- **Info dialog** — learn about orbital shells, data sources, and the space debris problem

## 📸 Screenshots

| Debris view | Filter panel | Tap popup |
|:---:|:---:|:---:|
| ![Main view](screenshot.png) | *(filter sheet with per-shell toggles)* | *(tap any object for details)* |

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- Android device or emulator (for deployment)
- A [CelesTrak](https://celestrak.org) account is **not** required — data is freely accessible

### Run on Android

```bash
cd trashmap
flutter run -d <device-id>
```

### Release build

```bash
flutter build apk --release
flutter install -d <device-id>
```

### Run on Web

```bash
flutter run -d chrome
```

> **Note:** CelesTrak does not send CORS headers, so the web build automatically falls back to `corsproxy.io`. This may be slower or rate-limited. Android builds fetch directly.

## 🧭 Orbital Shells

| Shell | Altitude | Colour | Description |
|-------|----------|--------|-------------|
| **LEO** | 200–2,000 km | 🟠 Orange | Earth observation, ISS, Starlink, most debris |
| **MEO** | 2,000–35,786 km | 🟡 Yellow | GPS, navigation satellites |
| **GEO** | 35,786 km | 🔵 Cyan | Weather, TV broadcast, communications |
| **Debris** | various | 🔴 Red | Untracked fragments <10 cm (procedural) |
| **Station** | ~400–420 km | 🟡 Gold | Crewed space stations (ISS, Tiangong) |

## 🔧 Architecture

```
lib/
├── main.dart                    — App entry point
├── models/
│   └── debris_data.dart         — Particle model + procedural generator
├── painters/
│   └── space_debris_painter.dart — CustomPainter: 3D projection, Earth, rings, markers
├── screens/
│   └── home_screen.dart         — Main screen: gestures, filters, time slider, popups, UI
└── services/
    ├── celestrak_service.dart   — CelesTrak API client with CORS proxy fallback
    └── sgp4.dart                — SGP4 orbital propagator (Dart port)
```

### Data flow

```
CelesTrak JSON  →  CelestrakService.fetch()  →  Sgp4.propagate()
                                                      ↓
DebrisGenerator.generate()  →  _allParticles  →  _displayParticles  →  SpaceDebrisPainter
                                     ↑                     ↑
                              Filter + time scrub    rotation/zoom
```

## 📡 Data Sources

**[CelesTrak](https://celestrak.org)** — Real-time TLE (Two-Line Element) sets maintained by the US Space Force. Fetched groups: `stations`, `visual`, `last-30-days`, `amateur`, `cubesat`, `active`.

**SGP4** — The Simplified General Perturbations model (#4) is the standard algorithm for propagating near-Earth orbit elements. This Dart implementation handles secular perturbations (drag, J₂ gravity) and Kepler equation solving.

**Procedural fallback** — When live data is unavailable, the app generates ~15,800 particles across all shells using a deterministic seed for reproducible results.

## 📜 License

MIT — use freely, adapt openly.

---

<p align="center">
  <sub>Built with Flutter • SGP4 • CelesTrak</sub>
</p>

---

*Built from scratch in a single ~3-hour session with [Paseo](https://github.com/4fthawaiian/trashmap) — an AI coding companion that turns ideas into working software. No templates, no boilerplate, just a conversation and a vision.*
