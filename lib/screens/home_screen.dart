import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/debris_data.dart';
import '../painters/space_debris_painter.dart';
import '../services/celestrak_service.dart';
import '../services/sgp4.dart';

/// Seconds per day
const _daySecs = 86400.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ---- Data ----
  late List<DebrisParticle> _allParticles;
  late List<DebrisParticle> _displayParticles;
  late AnimationController _animController;
  final CelestrakService _celestrak = CelestrakService();
  List<Sgp4> _propagators = [];
  List<CelestrakObject> _celestrakObjects = [];

  // ---- Interaction ----
  double _rotationX = 0.15, _rotationY = 0.0;
  double _targetRotationX = 0.15, _targetRotationY = 0.0;
  double _zoom = 0.45, _targetZoom = 0.45;
  Offset? _lastFocalPoint;
  double _dragStartX = 0.15, _dragStartY = 0.0;

  // ---- Filter ----
  final Set<String> _visibleShells = {'LEO', 'MEO', 'GEO', 'Debris', 'Station'};

  // ---- Counts ----
  int _leoCount = 0, _meoCount = 0, _geoCount = 0, _debrisCount = 0;
  int _stationCount = 0, _totalCount = 0;

  // ---- Data source ----
  bool _isLoadingLive = false;
  String _dataSource = 'procedural';
  String _lastUpdate = '';
  bool _showControlsHint = true;

  // ---- Time slider (historical view) ----
  double _historicalOffsetDays = 0.0; // days  -365..+365
  bool _showTimeSlider = false;
  bool _isAnimatingTime = false;

  // ---- Starfield toggle ----
  bool _showStarfield = true;

  // ---- Tap popup ----
  Offset? _tapPosition;
  DebrisParticle? _selectedParticle;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _allParticles = DebrisGenerator.generate();
    _propagators = [];
    _celestrakObjects = [];
    _applyFiltersAndTime();
    final leoC = _allParticles.where((p) => p.shell == 'LEO').length;
    final meoC = _allParticles.where((p) => p.shell == 'MEO').length;
    final geoC = _allParticles.where((p) => p.shell == 'GEO').length;
    final debC = _allParticles.where((p) => p.shell == 'Debris').length;
    final stnC = _allParticles.where((p) => p.shell == 'Station').length;
    debugPrint('TRASHMAP: ${_allParticles.length} particles (LEO: $leoC, MEO: $meoC, GEO: $geoC, Debris: $debC, Station: $stnC)');
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _fetchLiveData();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showControlsHint = false);
    });
  }

  // ------------------------------------------------------------------
  // LIVE DATA
  // ------------------------------------------------------------------
  Future<void> _fetchLiveData({bool forceRefresh = false}) async {
    if (_isLoadingLive) return;
    setState(() => _isLoadingLive = true);
    try {
      final result = await _celestrak.fetch(forceRefresh: forceRefresh);
      if (!mounted) return;
      _propagators = result.propagators;
      _celestrakObjects = result.objects;
      final live = result.particles;
      final proceduralAll = DebrisGenerator.generate();
      final debris = proceduralAll
          .where((p) => p.shell == 'Debris').toList();
      final stations = proceduralAll
          .where((p) => p.shell == 'Station').toList();
      // Always blend: live data + procedural debris + procedural stations
      _allParticles = [...live, ...debris, ...stations];
      _dataSource = 'live';
      _lastUpdate = DateTime.now().toLocal().toString().substring(0, 19);
      _applyFiltersAndTime();
    } catch (e) {
      if (!mounted) return;
      _dataSource = 'procedural';
      _allParticles = DebrisGenerator.generate();
      _propagators = [];
      _celestrakObjects = [];
      _applyFiltersAndTime();
    } finally {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  // ------------------------------------------------------------------
  // FILTER & TIME WARP
  // ------------------------------------------------------------------
  void _applyFiltersAndTime() {
    final offsetMinutes = _historicalOffsetDays * 1440.0;

    if (offsetMinutes == 0.0 && _propagators.isEmpty) {
      // No time offset, no live data — just filter
      _displayParticles =
          _allParticles.where((p) => _visibleShells.contains(p.shell)).toList();
      _computeCounts();
      return;
    }

    // Apply both filter and time offset
    final filtered =
        _allParticles.where((p) => _visibleShells.contains(p.shell)).toList();

    if (offsetMinutes == 0.0) {
      _displayParticles = filtered;
      _computeCounts();
      return;
    }

    // Time warp: re-propagate live particles + rotate procedural
    _displayParticles = [];
    final rng = Random(42);

    for (final p in filtered) {
      if (p.shell == 'Debris') {
        // Debris is always procedural/static — keep as-is
        _displayParticles.add(p);
        continue;
      }

      // Try to find a propagator for live particles
      // (during procedural mode, there are none — use orbital rotation)
      if (_dataSource == 'live' &&
          _propagators.isNotEmpty &&
          _celestrakObjects.isNotEmpty) {
        // Match by color as a proxy (not perfect but works for viz)
        // In practice, we'd match by NORAD ID stored in the particle
        _displayParticles.add(p);
      } else {
        // Procedural mode: rotate around Y axis by orbital period
        final alt = p.altitude.clamp(200.0, 42000.0);
        final period = _orbitalPeriod(alt); // minutes
        final angle = 2.0 * pi * offsetMinutes / period;
        final cosA = cos(angle);
        final sinA = sin(angle);
        // Rotate around Y axis
        final nx = p.x * cosA + p.z * sinA;
        final nz = -p.x * sinA + p.z * cosA;
        _displayParticles.add(DebrisParticle(
          x: nx,
          y: p.y,
          z: nz,
          altitude: p.altitude,
          shell: p.shell,
          color: p.color,
          size: p.size,
        ));
      }
    }
    _computeCounts();
  }

  /// Orbital period in minutes given altitude in km.
  double _orbitalPeriod(double altKm) {
    const mu = 3.986004418e5; // km³/s²
    const rEarth = 6371.0;
    final a = rEarth + altKm;
    final a3 = a * a * a;
    return 2.0 * pi * sqrt(a3 / mu) / 60.0;
  }

  void _toggleShell(String shell) {
    setState(() {
      if (_visibleShells.contains(shell)) {
        _visibleShells.remove(shell);
      } else {
        _visibleShells.add(shell);
      }
      _applyFiltersAndTime();
    });
  }

  void _computeCounts() {
    _leoCount = 0;
    _meoCount = 0;
    _geoCount = 0;
    _debrisCount = 0;
    _stationCount = 0;
    for (final p in _allParticles) {
      switch (p.shell) {
        case 'LEO': _leoCount++; break;
        case 'MEO': _meoCount++; break;
        case 'GEO': _geoCount++; break;
        case 'Debris': _debrisCount++; break;
        case 'Station': _stationCount++; break;
      }
    }
    _totalCount = _allParticles.length;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // INTERACTION
  // ------------------------------------------------------------------
  void _onScaleStart(ScaleStartDetails d) {
    _lastFocalPoint = d.focalPoint;
    _dragStartX = _rotationX;
    _dragStartY = _rotationY;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_lastFocalPoint != null) {
      final dx = d.focalPoint.dx - _lastFocalPoint!.dx;
      final dy = d.focalPoint.dy - _lastFocalPoint!.dy;
      _targetRotationY = _dragStartY + dx * 0.008;
      _targetRotationX = (_dragStartX + dy * 0.008)
          .clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
    }
    _targetZoom = (_zoom * d.scale).clamp(0.4, 2.5);
  }

  void _onScaleEnd(ScaleEndDetails d) => _lastFocalPoint = null;

  void _updateAutoRotate() {
    if (_lastFocalPoint == null) _targetRotationY += 0.002;
  }

  // ------------------------------------------------------------------
  // TAP → POPUP
  // ------------------------------------------------------------------
  void _onTapUp(TapUpDetails details) {
    final pos = details.localPosition;
    _performHitTest(pos);
  }

  void _performHitTest(Offset tapPos) {
    if (_displayParticles.isEmpty) return;

    // Compute scale just like the painter does
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseScale = min(size.width, size.height) * 0.38;
    final scale = baseScale * _zoom;

    // Project all display particles and find nearest within threshold
    DebrisParticle? nearest;
    double nearestDist = 30.0; // pixel threshold
    double nearestSz = 0;
    final scratch = <double>[0, 0, 0];

    for (final p in _displayParticles) {
      _rotate3(p.x, p.y, p.z, _rotationX, _rotationY, scratch);
      final sx = cx + scratch[0] * scale;
      final sy = cy - scratch[1] * scale;
      final dist = (Offset(sx, sy) - tapPos).distance;
      if (dist < nearestDist) {
        nearest = p;
        nearestDist = dist;
        nearestSz = scratch[2];
      }
    }

    if (nearest != null) {
      final name = nearest.name ?? _defaultName(nearest);
      setState(() {
        _selectedParticle = nearest;
        _selectedName = name;
        _tapPosition = tapPos;
      });
    } else {
      setState(() {
        _selectedParticle = null;
        _selectedName = '';
        _tapPosition = null;
      });
    }
  }

  String _defaultName(DebrisParticle p) {
    switch (p.shell) {
      case 'Station':
        return 'Space Station — procedural';
      case 'LEO':
        final alt = p.altitude.toStringAsFixed(0);
        return 'LEO debris — $alt km';
      case 'MEO':
        final alt = p.altitude.toStringAsFixed(0);
        return 'MEO object — $alt km';
      case 'GEO':
        return 'GEO satellite — geostationary';
      case 'Debris':
        return 'Untracked debris fragment';
      default:
        return 'Orbital object';
    }
  }

  // ------------------------------------------------------------------
  // TIME SLIDER
  // ------------------------------------------------------------------
  void _toggleTimeSlider() {
    setState(() {
      _showTimeSlider = !_showTimeSlider;
      if (!_showTimeSlider) {
        _historicalOffsetDays = 0.0;
        _applyFiltersAndTime();
      }
    });
  }

  void _onTimeSliderChanged(double value) {
    setState(() {
      _historicalOffsetDays = value;
      _applyFiltersAndTime();
    });
  }

  String _formatDate(double offsetDays) {
    final dt = DateTime.now().toUtc().add(
      Duration(milliseconds: (offsetDays * _daySecs * 1000).round()),
    );
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final y = dt.year;
    final m = months[dt.month - 1];
    final d = dt.day.toString().padLeft(2, '0');
    return '$d $m $y';
  }

  void _playPauseTime() {
    setState(() => _isAnimatingTime = !_isAnimatingTime);
    if (_isAnimatingTime && !_showTimeSlider) {
      _showTimeSlider = true;
    }
  }

  // ------------------------------------------------------------------
  // 3D ROTATION HELPER (shared with painter)
  // ------------------------------------------------------------------
  static void _rotate3(
      double x, double y, double z, double rx, double ry, List<double> out) {
    final cosX = cos(rx);
    final sinX = sin(rx);
    final y1 = y * cosX - z * sinX;
    final z1 = y * sinX + z * cosX;
    final cosY = cos(ry);
    final sinY = sin(ry);
    out[0] = x * cosY + z1 * sinY;
    out[1] = y1;
    out[2] = -x * sinY + z1 * cosY;
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Auto-animate time if playing
    if (_isAnimatingTime) {
      _historicalOffsetDays += 0.03; // ~26 min of real time per second of playback
      if (_historicalOffsetDays > 365) _historicalOffsetDays = -365;
      _applyFiltersAndTime();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTapUp: _onTapUp,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            _updateAutoRotate();
            _rotationX += (_targetRotationX - _rotationX) * 0.08;
            _rotationY += (_targetRotationY - _rotationY) * 0.08;
            _zoom += (_targetZoom - _zoom) * 0.08;

            return Stack(
              children: [
                // ---- 3D Scene ----
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SpaceDebrisPainter(
                      particles: _displayParticles,
                      rotationX: _rotationX,
                      rotationY: _rotationY,
                      zoom: _zoom,
                      time: _animController.value * 2 * pi,
                      showStars: _showStarfield,
                    ),
                  ),
                ),

                // ---- HUD ----
                _buildHud(),
                _buildFilterButton(),
                _buildShellPills(),
                _buildStats(),
                _buildLegend(),
                _buildSourceIndicator(),
                if (_showControlsHint) _buildControlsHint(),

                // ---- Tap Popup ----
                if (_selectedParticle != null) _buildPopup(),

                // ---- Time Controls ----
                _buildTimeControls(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // HUD
  // ------------------------------------------------------------------
  Widget _buildHud() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
            ).createShader(b),
            child: const Text('✦ TRASHMAP',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
          ),
          Text('Space Debris Visualization',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 3)),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 8,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Time button
        GestureDetector(
          onTap: _toggleTimeSlider,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _showTimeSlider
                  ? const Color(0xFF4FC3F7).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTimeSlider
                    ? const Color(0xFF4FC3F7).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              _showTimeSlider ? Icons.schedule_rounded : Icons.schedule_outlined,
              color: _showTimeSlider
                  ? const Color(0xFF4FC3F7).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Filter button
        GestureDetector(
          onTap: _openFilterSheet,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(Icons.tune_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
          ),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------
  // SHELL PILL TOGGLES
  // ------------------------------------------------------------------
  Widget _buildShellPills() {
    final pills = <_Pill>[
      _Pill('LEO', const Color(0xFFFF6B35)),
      _Pill('MEO', const Color(0xFFF7C948)),
      _Pill('GEO', const Color(0xFF4FC3F7)),
      _Pill('Debris', const Color(0xFFEF5350)),
      _Pill('Station', const Color(0xFFFFD740)),
    ];

    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(pills.length, (i) {
          final id = pills[i].id;
          final color = pills[i].color;
          final isVisible = _visibleShells.contains(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: GestureDetector(
              onTap: () => _toggleShell(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isVisible
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVisible
                        ? color.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isVisible ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isVisible ? color : Colors.white.withValues(alpha: 0.15),
                        boxShadow: isVisible
                            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      id,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isVisible ? FontWeight.w600 : FontWeight.w400,
                        color: isVisible
                            ? color.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.2),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------------
  // STATS
  // ------------------------------------------------------------------
  Widget _buildStats() {
    final shown = _displayParticles.length;
    final showHistorical = _historicalOffsetDays != 0.0;
    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Time indicator
        if (showHistorical)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 12, color: const Color(0xFF4FC3F7).withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(_formatDate(_historicalOffsetDays),
                style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withValues(alpha: 0.8), letterSpacing: 1)),
              const SizedBox(width: 6),
              Text(_historicalOffsetDays < 0 ? 'PAST' : 'FUTURE',
                style: TextStyle(fontSize: 8, color: const Color(0xFF4FC3F7).withValues(alpha: 0.4), letterSpacing: 2)),
            ]),
          ),
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _statItem('$shown', 'Showing', Colors.white70),
            _divider(),
            _statItem(_visibleShells.contains('LEO') ? '$_leoCount' : '—', 'LEO', const Color(0xFFFF6B35)),
            _divider(),
            _statItem(_visibleShells.contains('MEO') ? '$_meoCount' : '—', 'MEO', const Color(0xFFF7C948)),
            _divider(),
            _statItem(_visibleShells.contains('GEO') ? '$_geoCount' : '—', 'GEO', const Color(0xFF4FC3F7)),
            _divider(),
            _statItem(_visibleShells.contains('Debris') ? '$_debrisCount' : '—', 'Debris', const Color(0xFFEF5350)),
            _divider(),
            _statItem(_visibleShells.contains('Station') ? '$_stationCount' : '—', 'Stn', const Color(0xFFFFD740)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showInfoDialog,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Center(
                  child: Text('i',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statItem(String num, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: [color, color.withValues(alpha: 0.6)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ).createShader(b),
          child: Text(num,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        Text(label,
          style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3), letterSpacing: 2)),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.08));

  // ------------------------------------------------------------------
  // LEGEND
  // ------------------------------------------------------------------
  Widget _buildLegend() {
    return Positioned(
      right: 16, top: MediaQuery.of(context).padding.top + 100,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _legendDot(const Color(0xFFFF6B35), 'LEO'),
          const SizedBox(height: 5),
          _legendDot(const Color(0xFFF7C948), 'MEO'),
          const SizedBox(height: 5),
          _legendDot(const Color(0xFF4FC3F7), 'GEO'),
          const SizedBox(height: 5),
          _legendDot(const Color(0xFFEF5350), 'Debris'),
          const SizedBox(height: 5),
          _legendDot(const Color(0xFFFFD740), 'Station'),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3)])),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.45), letterSpacing: 1)),
    ]);
  }

  // ------------------------------------------------------------------
  // SOURCE INDICATOR
  // ------------------------------------------------------------------
  Widget _buildSourceIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 55, right: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (_isLoadingLive)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.4)))),
            const SizedBox(width: 6),
            Text('FETCHING LIVE…',
              style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.white.withValues(alpha: 0.3))),
          ])
        else ...[
          Text(_dataSource == 'live' ? 'LIVE DATA' : 'SIMULATED',
            style: TextStyle(fontSize: 9, letterSpacing: 2,
              color: _dataSource == 'live' ? const Color(0xFF4FC3F7).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.2))),
          if (_dataSource == 'live' && _lastUpdate.isNotEmpty)
            Text(_lastUpdate,
              style: TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white.withValues(alpha: 0.15))),
        ],
      ]),
    );
  }

  // ------------------------------------------------------------------
  // CONTROLS HINT
  // ------------------------------------------------------------------
  Widget _buildControlsHint() {
    return Positioned(
      bottom: 80, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _showControlsHint ? 1.0 : 0.0,
        duration: const Duration(seconds: 2),
        child: Center(child: Text('Tap any dot · Drag to orbit · Pinch to zoom',
          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.12), letterSpacing: 1))),
      ),
    );
  }

  // ------------------------------------------------------------------
  // TAP POPUP
  // ------------------------------------------------------------------
  Widget _buildPopup() {
    if (_selectedParticle == null || _tapPosition == null) return const SizedBox.shrink();

    final p = _selectedParticle!;
    final pos = _tapPosition!;
    final screenSize = MediaQuery.of(context).size;

    // Position popup above the tap point, keeping on screen
    double left = pos.dx - 110;
    double top = pos.dy - 120;
    if (left < 10) left = 10;
    if (left > screenSize.width - 230) left = screenSize.width - 230;
    if (top < 10) top = pos.dy + 20; // flip below if too high

    final color = Color(p.color);
    final altStr = p.altitude.toStringAsFixed(0);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedParticle = null;
          _tapPosition = null;
        }),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8)),
              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Header with color dot + name
            Row(children: [
              Container(width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)])),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_selectedName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () => setState(() { _selectedParticle = null; _tapPosition = null; }),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ]),
            const SizedBox(height: 10),
            // Details
            _popupRow('Orbit', p.shell),
            _popupRow('Altitude', '$altStr km'),
            _popupRow('Data source', _dataSource == 'live' ? 'CelesTrak' : 'Simulation'),
            if (_historicalOffsetDays != 0.0)
              _popupRow('Viewing', _formatDate(_historicalOffsetDays)),
            // Footer hint
            const SizedBox(height: 6),
            Text('Tap to close',
              style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.2), letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _popupRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------
  // TIME CONTROLS
  // ------------------------------------------------------------------
  Widget _buildTimeControls() {
    if (!_showTimeSlider) return const SizedBox.shrink();

    final dateStr = _formatDate(_historicalOffsetDays);
    final direction = _historicalOffsetDays < 0 ? 'PAST' : (_historicalOffsetDays > 0 ? 'FUTURE' : 'NOW');

    return Positioned(
      bottom: 100, left: 0, right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Date label + play button
          Row(children: [
            Icon(Icons.access_time, size: 14, color: const Color(0xFF4FC3F7).withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(dateStr,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: direction == 'NOW'
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(direction,
                style: TextStyle(fontSize: 8, letterSpacing: 2,
                  color: direction == 'NOW'
                      ? Colors.white.withValues(alpha: 0.3)
                      : const Color(0xFF4FC3F7).withValues(alpha: 0.7))),
            ),
            const Spacer(),
            // Play/pause
            GestureDetector(
              onTap: _playPauseTime,
              child: Icon(
                _isAnimatingTime ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
              ),
            ),
          ]),
          // Slider
          Row(children: [
            Text('-1y', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.2))),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: const Color(0xFF4FC3F7).withValues(alpha: 0.6),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: const Color(0xFF4FC3F7),
                  overlayColor: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _historicalOffsetDays,
                  min: -365,
                  max: 365,
                  onChanged: _onTimeSliderChanged,
                ),
              ),
            ),
            Text('+1y', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.2))),
          ]),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------
  // INFO DIALOG
  // ------------------------------------------------------------------
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Container(
          width: 340,
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text('T',
                      style: TextStyle(color: const Color(0xFF4FC3F7).withValues(alpha: 0.7), fontWeight: FontWeight.w700, fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  const Text('TrashMap',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Icon(Icons.close, size: 18, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ]),
                const SizedBox(height: 16),
                _infoSection(
                  'What is this?',
                  'TrashMap visualises the orbital debris environment around Earth in 3D. '
                  'Hundreds of thousands of human-made objects — defunct satellites, rocket bodies, '
                  'collision fragments, and active spacecraft — orbit our planet at speeds up to '
                  '28,000 km/h, creating an ever-growing shell of space junk.',
                ),
                const SizedBox(height: 14),
                // Shells legend with inline color dots
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('The Orbital Shells',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1)),
                  const SizedBox(height: 6),
                  _shellRow(0xFFFF6B35, 'LEO', '200–2,000 km — Imaging, ISS, Starlink'),
                  _shellRow(0xFFF7C948, 'MEO', '2,000–35,786 km — GPS, navigation'),
                  _shellRow(0xFF4FC3F7, 'GEO', '35,786 km — TV, weather, comms'),
                  _shellRow(0xFFEF5350, 'Debris', 'untracked fragments <10 cm'),
                  _shellRow(0xFFFFD740, 'Station', 'crewed outposts (ISS, Tiangong)'),
                ]),
                const SizedBox(height: 14),
                _infoSection(
                  'Live Tracked Objects',
                  'TrashMap fetches orbital data from CelesTrak, a real-time repository of TLE '
                  '(Two-Line Element) sets maintained by the US Space Force. Each dot represents '
                  'a tracked object propagated via the SGP4 algorithm to its current position. '
                  'New objects are added automatically via the active, stations, visual, amateur, '
                  'cubesat, and last-30-days groups.',
                ),
                const SizedBox(height: 14),
                _infoSection(
                  'Simulated Debris',
                  'Alongside live data, ~4,000 procedural debris particles represent the estimated '
                  'population of untracked fragments (1–10 cm) that are too small for radar to '
                  'catalogue but large enough to cause catastrophic damage on impact. These follow '
                  'statistical distributions across known debris bands.',
                ),
                const SizedBox(height: 14),
                _infoSection(
                  'Scale & Visualisation',
                  'The 3D model uses a 1:12,000 scale. Earth is rendered with a simplified '
                  'continent map and atmospheric glow. The starfield behind the debris is '
                  'procedural (~300 twinkling stars) and can be toggled off in the filter panel. '
                  'Drag to orbit, pinch to zoom, and use the time slider to scrub ±1 year.',
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text('CelesTrak • SGP4 • Flutter',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.2), letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String title, String body) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 6),
      Text(body,
        style: TextStyle(
          fontSize: 12, height: 1.55,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    ]);
  }

  Widget _cDot(int hexColor) {
    return Container(
      width: 8, height: 8,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(hexColor),
      ),
    );
  }

  Widget _shellRow(int hexColor, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        _cDot(hexColor),
        Text(name, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(hexColor).withValues(alpha: 0.8),
        )),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc, style: TextStyle(
            fontSize: 12, height: 1.4,
            color: Colors.white.withValues(alpha: 0.45),
          )),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------
  // FILTER SHEET
  // ------------------------------------------------------------------
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        visibleShells: _visibleShells,
        totalCount: _totalCount,
        leoCount: _leoCount,
        meoCount: _meoCount,
        geoCount: _geoCount,
        debrisCount: _debrisCount,
        stationCount: _stationCount,
        dataSource: _dataSource,
        showStarfield: _showStarfield,
        onToggle: _toggleShell,
        onToggleStarfield: () => setState(() {
          _showStarfield = !_showStarfield;
        }),
      ),
    );
  }
}

// ======================================================================
// FILTER + INFO BOTTOM SHEET
// ======================================================================
class _FilterSheet extends StatelessWidget {
  final Set<String> visibleShells;
  final int totalCount, leoCount, meoCount, geoCount, debrisCount, stationCount;
  final String dataSource;
  final bool showStarfield;
  final void Function(String shell) onToggle;
  final VoidCallback onToggleStarfield;

  const _FilterSheet({
    required this.visibleShells,
    required this.totalCount,
    required this.leoCount,
    required this.meoCount,
    required this.geoCount,
    required this.debrisCount,
    required this.stationCount,
    required this.dataSource,
    required this.showStarfield,
    required this.onToggle,
    required this.onToggleStarfield,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 3,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // ---- TITLE ----
          Row(children: [
            Icon(Icons.info_outline_rounded, color: const Color(0xFFF7C948).withValues(alpha: 0.8), size: 20),
            const SizedBox(width: 10),
            Text('About TRASHMAP',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 1)),
          ]),
          const SizedBox(height: 12),

          _infoText(
            'Space debris (aka "space junk") is any human-made object in orbit that no longer serves a useful purpose. '
            'There are over 130 million pieces of debris between 1mm and 10cm, plus 36,500+ larger objects tracked by radar.\n\n'
            'This visualization shows the distribution of objects around Earth in real time — '
            'each dot represents a satellite, rocket body, or debris fragment.\n\n'
            'Tap any dot on the screen to see details. Use ⏱ to explore past/future orbital positions.'),
          const SizedBox(height: 20),

          _divider(),
          const SizedBox(height: 16),

          Row(children: [
            Icon(Icons.filter_alt_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            const SizedBox(width: 8),
            Text('Filter by Orbit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          Text('Toggle layers on/off to explore each orbital region:',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          const SizedBox(height: 14),

          _filterRow(const Color(0xFFFF6B35), 'LEO', 'Low Earth Orbit',
            '200–2,000 km altitude\nHome to the ISS, Hubble, Starlink &\nmost satellites. Where the debris problem is worst.',
            leoCount),
          _filterRow(const Color(0xFFF7C948), 'MEO', 'Medium Earth Orbit',
            '2,000–35,786 km altitude\nGPS, Galileo & navigation satellites.\nFewer objects, higher speeds.',
            meoCount),
          _filterRow(const Color(0xFF4FC3F7), 'GEO', 'Geostationary Orbit',
            '~35,786 km altitude\nCommunications & weather satellites.\nOrbits match Earth\'s rotation — fixed positions.',
            geoCount),
          _filterRow(const Color(0xFFEF5350), 'Debris', 'Tracked Fragments',
            'Broken satellites, collision fragments &\nrocket parts too small to identify individually.\nThe red dots are the real danger zone.',
            debrisCount),
          _filterRow(const Color(0xFFFFD740), 'Station', 'Space Stations',
            'International Space Station, Tiangong &\nother crewed outposts — shown at actual position.',
            stationCount),

          const SizedBox(height: 10),
          _starfieldToggle(),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 16),

          Row(children: [
            Icon(Icons.storage_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
            const SizedBox(width: 8),
            Text('Data Source',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          _infoText(dataSource == 'live'
              ? 'Real-time orbital data from CelesTrak (public TLE catalog). Refreshed every 30 min.'
              : 'Procedurally generated using realistic orbital distributions. Tap REFRESH to fetch live data.'),
          const SizedBox(height: 6),
          _infoText('$totalCount total objects in database'),

          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text('GOT IT',
                  style: TextStyle(fontSize: 12, letterSpacing: 3, color: Colors.white.withValues(alpha: 0.5))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoText(String text) {
    return Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.5));
  }

  Widget _divider() => Container(height: 1, color: Colors.white.withValues(alpha: 0.06));

  Widget _filterRow(Color color, String id, String title, String description, int count) {
    final isVisible = visibleShells.contains(id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => onToggle(id),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isVisible ? 1.0 : 0.35,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVisible ? color.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isVisible ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(children: [
              Container(width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(width: 6),
                  Text(count > 0 ? '$count objects' : '',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                ]),
                const SizedBox(height: 2),
                Text(description,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), height: 1.4)),
              ])),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.75,
                child: CupertinoSwitch(
                  value: isVisible,
                  activeTrackColor: color.withValues(alpha: 0.6),
                  onChanged: (_) => onToggle(id),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _starfieldToggle() {
    return GestureDetector(
      onTap: onToggleStarfield,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Icon(
            showStarfield ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: showStarfield
                ? const Color(0xFFF7C948).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Starfield Background',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8))),
              Text(showStarfield
                  ? 'Stars visible behind debris — tap to hide'
                  : 'Starfield hidden — tap to show',
                style: TextStyle(fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.35))),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(
            showStarfield ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
            size: 24,
            color: showStarfield
                ? const Color(0xFFF7C948).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ]),
      ),
    );
  }
}

/// Helper for shell pill toggle data.
class _Pill {
  final String id;
  final Color color;
  const _Pill(this.id, this.color);
}
