import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

// ─── Study Spot model ────────────────────────────────────────────────────────
class StudySpot {
  final String id;
  final String name;
  final String notes;
  final double lat;
  final double lng;
  final String type; // 'custom' | 'library' | 'cafe' | 'campus'

  StudySpot({
    required this.id,
    required this.name,
    required this.notes,
    required this.lat,
    required this.lng,
    this.type = 'custom',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'notes': notes, 'lat': lat, 'lng': lng, 'type': type};

  factory StudySpot.fromJson(Map<String, dynamic> j) => StudySpot(
        id: j['id'],
        name: j['name'],
        notes: j['notes'] ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        type: j['type'] ?? 'custom',
      );
}

// ─── Map Page ────────────────────────────────────────────────────────────────
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String _apiKey = 'AIzaSyDoPAM28DmlbOFDPSWpvHh-HFCzr5g-oAM';

  // Default to a central UK location — user sets uni from settings
  static const LatLng _defaultUni = LatLng(51.5074, -0.1278);

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng _uniLocation = _defaultUni;

  final StorageService _storage = StorageService();
  List<StudySpot> _spots = [];

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _loadingRoute = false;
  bool _locationReady = false;
  String? _routeInfo; // e.g. "12 min · 1.4 km"
  String _travelMode = 'walking'; // walking | transit | bicycling

  final TextEditingController _uniSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _initLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _uniSearchController.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _locationReady = true;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15),
    );
    _refreshMarkers();
  }

  // ── Study spots persistence ───────────────────────────────────────────────

  void _loadSpots() {
    final raw = _storage.loadStudySpots();
    setState(() {
      _spots = raw.map((j) => StudySpot.fromJson(j)).toList();
    });
    _refreshMarkers();
  }

  Future<void> _saveSpots() async {
    await _storage.saveStudySpots(_spots.map((s) => s.toJson()).toList());
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  void _refreshMarkers() {
    final markers = <Marker>{};

    // Uni marker
    markers.add(Marker(
      markerId: const MarkerId('uni'),
      position: _uniLocation,
      infoWindow: const InfoWindow(title: '🎓 University'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    // Study spot markers
    for (final spot in _spots) {
      final hue = spot.type == 'library'
          ? BitmapDescriptor.hueGreen
          : spot.type == 'cafe'
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueViolet;
      markers.add(Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.lat, spot.lng),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: spot.notes.isEmpty ? null : spot.notes,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => _showSpotDetails(spot),
      ));
    }

    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  Future<void> _getDirections() async {
    if (_currentPosition == null) {
      _showSnack('Enable location to get directions');
      return;
    }
    setState(() { _loadingRoute = true; _polylines.clear(); _routeInfo = null; });

    final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest = '${_uniLocation.latitude},${_uniLocation.longitude}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&mode=$_travelMode&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        _showSnack('Could not get directions: ${data['status']}');
        setState(() => _loadingRoute = false);
        return;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];
      final duration = leg['duration']['text'] as String;
      final distance = leg['distance']['text'] as String;
      final encodedPolyline = route['overview_polyline']['points'] as String;

      final points = _decodePolyline(encodedPolyline);
      setState(() {
        _routeInfo = '$duration · $distance';
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF3B82F6),
          width: 5,
        ));
        _loadingRoute = false;
      });

      // Fit camera to route
      final bounds = _boundsFromLatLngList(points);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (e) {
      _showSnack('Error getting directions');
      setState(() => _loadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double minLat = list[0].latitude, maxLat = list[0].latitude;
    double minLng = list[0].longitude, maxLng = list[0].longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ── Add / manage study spots ──────────────────────────────────────────────

  void _onLongPress(LatLng position) => _showAddSpotDialog(position);

  void _showAddSpotDialog(LatLng position) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'custom';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('Pin Study Spot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _textField(nameCtrl, 'Name', 'e.g. Quiet corner, Library level 3'),
              const SizedBox(height: 12),
              _textField(notesCtrl, 'Notes (optional)', 'WiFi, power outlets, noise level...'),
              const SizedBox(height: 16),
              // Type selector
              Row(children: [
                _typeChip('Custom', 'custom', type, (v) => setModal(() => type = v), const Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                _typeChip('Library', 'library', type, (v) => setModal(() => type = v), const Color(0xFF22C55E)),
                const SizedBox(width: 8),
                _typeChip('Café', 'cafe', type, (v) => setModal(() => type = v), const Color(0xFFF97316)),
                const SizedBox(width: 8),
                _typeChip('Campus', 'campus', type, (v) => setModal(() => type = v), const Color(0xFF3B82F6)),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final spot = StudySpot(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      lat: position.latitude,
                      lng: position.longitude,
                      type: type,
                    );
                    setState(() => _spots.add(spot));
                    await _saveSpots();
                    _refreshMarkers();
                    if (mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Spot', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpotDetails(StudySpot spot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_spotIcon(spot.type), color: _spotColor(spot.type), size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(spot.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                onPressed: () async {
                  setState(() => _spots.removeWhere((s) => s.id == spot.id));
                  await _saveSpots();
                  _refreshMarkers();
                  if (mounted) Navigator.pop(ctx);
                },
              ),
            ]),
            if (spot.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(spot.notes, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _getDirectionsToSpot(spot);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Directions to this spot'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getDirectionsToSpot(StudySpot spot) async {
    if (_currentPosition == null) { _showSnack('Enable location first'); return; }
    setState(() { _loadingRoute = true; _polylines.clear(); _routeInfo = null; });
    final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest = '${spot.lat},${spot.lng}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&mode=$_travelMode&key=$_apiKey',
    );
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') { _showSnack('No route found'); setState(() => _loadingRoute = false); return; }
      final leg = data['routes'][0]['legs'][0];
      final points = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
      setState(() {
        _routeInfo = '${leg['duration']['text']} · ${leg['distance']['text']}';
        _polylines.add(Polyline(
          polylineId: const PolylineId('spot_route'),
          points: points,
          color: const Color(0xFF22C55E),
          width: 5,
        ));
        _loadingRoute = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(points), 80));
    } catch (_) {
      _showSnack('Error getting directions');
      setState(() => _loadingRoute = false);
    }
  }

  // ── Set university location ───────────────────────────────────────────────

  void _showSetUniDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Set University Location', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Long-press anywhere on the map to drop the uni pin at that location, or type an address below.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            _textField(_uniSearchController, 'University name or address', 'e.g. University of Manchester'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _geocodeAndSetUni(_uniSearchController.text.trim());
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Search & Set', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _geocodeAndSetUni(String address) async {
    if (address.isEmpty) return;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey');
    try {
      final res = await http.get(url);
      final data = jsonDecode(res.body);
      if (data['status'] == 'OK') {
        final loc = data['results'][0]['geometry']['location'];
        setState(() => _uniLocation = LatLng(loc['lat'], loc['lng']));
        _refreshMarkers();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_uniLocation, 15));
        _showSnack('University location set ✓');
      } else {
        _showSnack('Address not found');
      }
    } catch (_) {
      _showSnack('Error searching address');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating));
  }

  IconData _spotIcon(String type) {
    switch (type) {
      case 'library': return Icons.local_library;
      case 'cafe': return Icons.local_cafe;
      case 'campus': return Icons.school;
      default: return Icons.push_pin;
    }
  }

  Color _spotColor(String type) {
    switch (type) {
      case 'library': return const Color(0xFF22C55E);
      case 'cafe': return const Color(0xFFF97316);
      case 'campus': return const Color(0xFF3B82F6);
      default: return const Color(0xFF8B5CF6);
    }
  }

  Widget _textField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        hintStyle: const TextStyle(color: Color(0xFF334155)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6))),
      ),
    );
  }

  Widget _typeChip(String label, String value, String current, Function(String) onTap, Color color) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : const Color(0xFF334155)),
        ),
        child: Text(label, style: TextStyle(color: active ? color : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(_darkMapStyle);
              if (_currentPosition != null) {
                c.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _uniLocation,
              zoom: 14,
            ),
            myLocationEnabled: _locationReady,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onLongPress: _onLongPress,
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // ── Top bar ─────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(children: [
                const Icon(Icons.map_rounded, color: Color(0xFF3B82F6), size: 22),
                const SizedBox(width: 10),
                const Text('Campus Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                // Set uni button
                GestureDetector(
                  onTap: _showSetUniDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.school, size: 14, color: Color(0xFF94A3B8)),
                      SizedBox(width: 4),
                      Text('Set Uni', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // My location button
                GestureDetector(
                  onTap: () {
                    if (_currentPosition != null) {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 16));
                    } else {
                      _initLocation();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.my_location, size: 18, color: Color(0xFF3B82F6)),
                  ),
                ),
              ]),
            ),
          ),

          // ── Legend / spots count ─────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendChip(Icons.school, 'University', const Color(0xFF3B82F6)),
                const SizedBox(height: 6),
                _legendChip(Icons.push_pin, '${_spots.length} study spot${_spots.length == 1 ? '' : 's'}', const Color(0xFF8B5CF6)),
              ],
            ),
          ),

          // ── Route info banner ────────────────────────────────────────────
          if (_routeInfo != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_walk, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(_routeInfo!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() { _polylines.clear(); _routeInfo = null; }),
                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ]),
              ),
            ),

          // ── Bottom panel ─────────────────────────────────────────────────
          Positioned(
            bottom: 16, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.97),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Travel mode selector
                  Row(children: [
                    _modeChip(Icons.directions_walk, 'Walk', 'walking'),
                    const SizedBox(width: 8),
                    _modeChip(Icons.directions_transit, 'Transit', 'transit'),
                    const SizedBox(width: 8),
                    _modeChip(Icons.directions_bike, 'Cycle', 'bicycling'),
                  ]),
                  const SizedBox(height: 12),
                  // Directions button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadingRoute ? null : _getDirections,
                      icon: _loadingRoute
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.directions),
                      label: Text(_loadingRoute ? 'Getting route...' : 'Directions to University'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        disabledBackgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.touch_app, size: 12, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text('Long-press map to pin a study spot',
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(IconData icon, String label, String mode) {
    final active = _travelMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _travelMode = mode; _polylines.clear(); _routeInfo = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFF334155)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: active ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _legendChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Dark map style JSON ───────────────────────────────────────────────────────
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0f172a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f172a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0f172a"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#334155"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#020617"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#0f172a"}]}
]
''';

