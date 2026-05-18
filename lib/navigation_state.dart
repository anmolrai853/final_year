// lib/navigation_state.dart
// Shared types used by home_screen, map_page and event_location_dialog.

/// Holds a building name and address for the map to navigate to.
class MapDestination {
  final String name;
  final String address;

  const MapDestination({
    required this.name,
    required this.address,
  });
}